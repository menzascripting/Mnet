package Mnet::Poll::Cisco;

=head1 NAME

Mnet::Poll::Cisco - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

This module performs custom polling of cisco objects.

This module is called by the Mnet::Poll module. It is not meant to be
invoked on its own.

=head1 DESCRIPTION

If the snmp system description was gathered and contains the keyword
'cisco' then this poll module does the following:

 - adjusts interface mtype values for cisco specific interfaces
 - does an snmp bulk get of cpu, config and environmental status
 - alerts on high cpu utilization, graphs cpu utilization
 - log config changes, alert on unsaved or unprocessed config changes
 - alert on fan, power or temperature abnormal states

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --cisco-detail       extra debug logging, default disabled
 --cisco-alerts-cpu4  default 95 percentage sev 4 alert 5 minute cpu
 --cisco-alerts-cpu5  default 85 percentage sev 5 alert 5 minute cpu
 --cisco-alerts-cpu6  default 75 percentage sev 6 alert 5 minute cpu
 --cisco-version      set at compilation to build number
 --cisco-sev-change   default sev 5 log for detected config change
 --cisco-sev-fans     default sev 5 alert for abnormal fan state
 --cisco-sev-power    default sev 5 alert for abnormal power state
 --cisco-sev-save     default sev 5 alert for unsaved config change
 --cisco-sev-start    default sev 5 alert for startup newer than running
 --cisco-sev-temp     default sev 5 alert for abnormal temperature state

=head1 OUTPUT DATA

The following data may be included in the output from the poll_data
function:

 data -> {
   cisco -> {
     cfg-change -> seconds since reboot of last running config change
     cfg-save   -> seconds since reboot of last running config save
     cfg-start  -> seconds since reboot of last startup config change
     cpu        -> cpu utilization percentage
     env-fans   -> state of fans, 1=normal, 5=not present
     env-power  -> state of power supplies, 1=normal, 5=not present
     env-temp   -> state of temperature, 1=normal, 5=not present
   }
 }

Detail for env-* data environmental monitor state values:

 1   normal
 2   warning
 3   critical
 4   shutdown
 5   not present
 6   not functioning

Note that the above data elements are present in addition to the
standard data collected by the main mnet poll module.

=cut

# modules used
use warnings;
use strict;
use Carp;
use Mnet;
use Mnet::RRD;
use Mnet::SNMP;

# module initialization, set module defaults
BEGIN {
    our $cfg = &Mnet::config({
        'cisco-alerts-cpu4' => 95,
        'cisco-alerts-cpu5' => 85,
        'cisco-alerts-cpu6' => 75,
        'cisco-version'     => '+++VERSION+++',
        'cisco-sev-change'  => 5,
        'cisco-sev-fans'    => 5,
        'cisco-sev-power'   => 5,
        'cisco-sev-save'    => 5,
        'cisco-sev-start'   => 5,
        'cisco-sev-temp'    => 5,
    });
}



sub poll_mod {

# internal: &poll_mod($cfg, $pn, $po)
# purpose: execute custom poll module code
# \%cfg: hash reference to current config settings
# \%po: hash reference to object old poll data
# \%po: hash reference to object new poll data

    # begin, initialize input arguments and config
    my $cfg = shift or croak "poll_mod cfg arg missing";
    my $pn = shift or croak "poll_mod pn arg missing";
    my $po = shift;
    $po = {} if ref $po ne "HASH";

    # return if current poll data doesn't indicate proper device type
    if (not $pn->{'sys'}->{'descr'} or $pn->{'sys'}->{'descr'} !~ /cisco/i) {
        &dtl("poll_mod exiting, new snmp descr not set for cisco device");
        return;
    }

    # process this device
    &dbg("poll_mod processing current object");

    # update interfaces with cisco specific mtype rules
    &dtl("poll_mod checking interface mtype settings");
    foreach my $int (keys %{$pn->{'int'}}) {
        my $pn_int = $pn->{'int'}->{$int};
        $pn_int->{'mtype'} = &snmp_int_mtype($cfg, $pn_int, $pn);
    }

    # set other snmp values to monitor
    my $oid_cpu_old = ".1.3.6.1.4.1.9.2.1.58.0";
    my $oid_cpu_new = ".1.3.6.1.4.1.9.9.109.1.1.1.1.8.9";
    my $oid_change = ".1.3.6.1.4.1.9.9.43.1.1.1.0";
    my $oid_save = ".1.3.6.1.4.1.9.9.43.1.1.2.0";
    my $oid_start = ".1.3.6.1.4.1.9.9.43.1.1.3.0";
    my $oid_power = ".1.3.6.1.4.1.9.9.13.1.5.1.3.1";
    my $oid_fans = ".1.3.6.1.4.1.9.9.13.1.4.1.3.1";
    my $oid_temp = ".1.3.6.1.4.1.9.9.13.1.3.1.6.1";

    # set bulk get oid values and retrieve them
    my @oids = ();
    push @oids, $oid_cpu_old, $oid_cpu_new;
    push @oids, $oid_change, $oid_save, $oid_start;
    push @oids, $oid_power, $oid_fans, $oid_temp;

    # retrieve snmp results for bulk get data, warn on errors
    my $snmp_res = {};
    my $error = &snmp_bulkget(\@oids, $snmp_res);
    carp "poll_mod snmp_bulkget error $error" if $error;

    # save config change, config save and config start times
    $pn->{'cisco'}->{'cfg-change'} = $snmp_res->{$oid_change};
    $pn->{'cisco'}->{'cfg-save'} = $snmp_res->{$oid_save};
    $pn->{'cisco'}->{'cfg-start'} = $snmp_res->{$oid_start};

    # set running config change time, and log if different than last poll
    if ($po->{'cisco'}->{'cfg-change'} and $pn->{'cisco'}->{'cfg-change'}
        and $po->{'cisco'}->{'cfg-change'}
        ne $pn->{'cisco'}->{'cfg-change'}) {
        &log($cfg->{'cisco-sev-change'},
            "detected change to cisco running config");

    # alert if startup config is newer than config save
    } elsif ($pn->{'cisco'}->{'cfg-start'} and $pn->{'cisco'}->{'cfg-save'}
        and $pn->{'cisco'}->{'cfg-start'}
        > $pn->{'cisco'}->{'cfg-save'}) {
        &alert($cfg->{'cisco-sev-start'},
            "detected cisco startup config newer than running config");

    # alert on unsaved change to cisco running config
    } elsif ($pn->{'cisco'}->{'cfg-save'} and $pn->{'cisco'}->{'cfg-change'}
        and $pn->{'cisco'}->{'cfg-save'}
        < $pn->{'cisco'}->{'cfg-change'}) {
        &alert($cfg->{'cisco-sev-save'},
            "detected unsaved change to cisco running config");
    }

    # store cpu utiliation, rrd graph it, and alert if exceeds thresholds
    $pn->{'cisco'}->{'cpu'} = $snmp_res->{$oid_cpu_old};
    $pn->{'cisco'}->{'cpu'} = $snmp_res->{$oid_cpu_new}
        if not defined $pn->{'cisco'}->{'cpu'};
    if ($pn->{'cisco'}->{'cpu'}) {
        &rrd_value("cpu", "percent", "gauge",
            $pn->{'cisco'}->{'cpu'}, 0, 100);
        if ($pn->{'cisco'}->{'cpu'} >= $cfg->{'cisco-alerts-cpu4'}) {
            &alert(4, "cisco cpu utilization $pn->{'cisco'}->{'cpu'}\%"); 
        } elsif ($pn->{'cisco'}->{'cpu'} >= $cfg->{'cisco-alerts-cpu5'}) {
            &alert(5, "cisco cpu utilization $pn->{'cisco'}->{'cpu'}\%");
        } elsif ($pn->{'cisco'}->{'cpu'} >= $cfg->{'cisco-alerts-cpu6'}) {
            &alert(6, "cisco cpu utilization $pn->{'cisco'}->{'cpu'}\%");
        }
    }

    # check that power supply state is normal
    $pn->{'cisco'}->{'env-power'} = $snmp_res->{$oid_power};
    if ($pn->{'cisco'}->{'env-power'}
        and $pn->{'cisco'}->{'env-power'} =~ /^(2|3|4|6)$/) {
        &alert($cfg->{'cisco-sev-power'}, "cisco env-power not normal");
    }

    # check that fan state is normal
    $pn->{'cisco'}->{'env-fans'} = $snmp_res->{$oid_fans};
    if ($pn->{'cisco'}->{'env-fans'}
        and $pn->{'cisco'}->{'env-fans'} =~ /^(2|3|4|6)$/) {
        &alert($cfg->{'cisco-sev-fans'}, "cisco env-fans not normal");
    }

    # check that temperature state is normal
    $pn->{'cisco'}->{'env-temp'} = $snmp_res->{$oid_temp};
    if ($pn->{'cisco'}->{'env-temp'}
        and $pn->{'cisco'}->{'env-temp'} =~ /^(2|3|4|6)$/) {
        &alert($cfg->{'cisco-sev-temp'}, "cisco env-temp not normal");
    }

    # finished poll_data_custom function
    &dtl("poll_mod function finished");
    return;
}



sub snmp_int_mtype {

# internal: $mtype = &snmp_int_mtype(\%cfg, \%pn_int, \%pn)
# purpose: determine interface monitor type
# $mtype: assign monitor type based on interface type and descr
# \%cfg: current configuration settings in effect
# \%pn_int: reference hash of poll data for current interface
# \%pn: reference hash of new poll data
# note: mtype = up,down,lan,wan,virtual,signal,skip,dial,voice,other,unknown

    # begin, read inputs and intialize mtype
    my $cfg = shift or croak "snmp_int_mtype cfg arg missing";
    my $pn_int = shift or croak "snmp_int_mtype pn_int arg missing";
    my $pn = shift or croak "snmp_int_mtype pn arg missing";
    my $mtype = $pn_int->{'mtype'};
    my $type = $pn_int->{'type'};
    my $descr = $pn_int->{'descr'};

    # skip cisco system interfaces
    if ($descr =~ /^(contr|ds|efxs|sl0|span|sysclock)/i) {
        $mtype = "hide";

    # cisco multilink and virtual interfaces as virtual
    } elsif ($descr =~ /^(multilink|virtual)/i) {
        $mtype = "virtual";

    # cisco async interfaces as dial
    } elsif ($descr =~ /^async/i) {
        $mtype = "dial";

    # cisco subinterfaces as virtual, set parent lan interface as lan
    } elsif ($descr =~ /\.\d+$/ and not defined $pn_int->{'erri'}) {
        $mtype = "virtual";
        if ($descr =~ /(^|\s)(\S+(ethernet|token)\S+)\.\d+/i) {
            my $parent_int = $2;
            $pn->{'int'}->{$parent_int}->{'mtype'} = "lan"
                if exists $pn->{'int'}->{$parent_int};
        }

    # proprietary virtual cisco sc or port channel as up
    } elsif ($type eq "53" and $descr =~ /^(sc|.*vlan)/i) {
        $mtype = "up";

    # set serials with bearer int to dial, set bearer as skip
    } elsif ($descr =~ /^serial/i
        and defined $pn->{'int'}->{"$descr-Bearer Channel"}) {
        $pn->{'int'}->{"$descr-Bearer Channel"}->{'mtype'} = "skip";
        $mtype = "dial"

    # set dso serial bearers as dial, skip if associated serial exists
    } elsif ($type eq "81" and $descr =~ /(isdn|bri|bearer)/i) {
        $mtype = "dial";
        $mtype = "skip" if $descr =~ /(serial\S+)-Bearer Channel/i
            and defined $pn->{'int'}->{$1};

    # finished mtype checks
    }

    # output detail debug message if mtype has changed
    if ($mtype ne $pn_int->{'mtype'}) {
        &dtl("snmp_int_mtype for descr=$descr, type=$type reset mtype=$mtype");
    } else {
        &dtl("snmp_int_mtype for descr=$descr, type=$type, ok mtype=$mtype");
    }

    # finished snmp_int_mtype
    return $mtype;
}



=head1 SNMP

Here is a list of SNMP OID MIB values:

 Cisco:
    HistoryRunningLastChanged   .1.3.6.1.4.1.9.9.43.1.1.1.0
    HistoryRunningLastSaved     .1.3.6.1.4.1.9.9.43.1.1.2.0
    HistoryStartupLastChanged   .1.3.6.1.4.1.9.9.43.1.1.3.0
    CiscolocIfDescr             .1.3.6.1.4.1.9.2.2.1.1.28
    EnvMonFanState              .1.3.6.1.4.1.9.9.13.1.4.1.3.1
    EnvMonSupplyState           .1.3.6.1.4.1.9.9.13.1.5.1.3.1
    EnvMonTemperatureState      .1.3.6.1.4.1.9.9.13.1.3.1.6.1
    Memory                      .1.3.6.1.4.1.9.9.48.1.1.1.5.1
    MemoryPoolFree              .1.3.6.1.4.1.9.9.48.1.1.1.6.1
    MemoryPoolLargestFree       .1.3.6.1.4.1.9.9.48.1.1.1.7.1
    MemoryPoolLargestFree       .1.3.6.1.4.1.9.9.48.1.1.1.7.2
    CPU5secOld                  .1.3.6.1.4.1.9.2.1.56.0 
    CPU1minOld                  .1.3.6.1.4.1.9.2.1.57.0 
    CPU5minOld                  .1.3.6.1.4.1.9.2.1.58.0 
    CPUTotal5secNew             .1.3.6.1.4.1.9.9.109.1.1.1.1.3.1
    CPUTotal1minNew             .1.3.6.1.4.1.9.9.109.1.1.1.1.4.1
    CPUTotal5minNew             .1.3.6.1.4.1.9.9.109.1.1.1.1.5.1
    CPUTotal5secRev             .1.3.6.1.4.1.9.9.109.1.1.1.1.6.1
    CPUTotal1minRev             .1.3.6.1.4.1.9.9.109.1.1.1.1.7.1
    CPUTotal5minRev             .1.3.6.1.4.1.9.9.109.1.1.1.1.8.1

Refer to the Mnet::SNMP documentation for additional MIBs.

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, Mnet::Poll, Mnet::SNMP

=cut



# normal package return
1;

