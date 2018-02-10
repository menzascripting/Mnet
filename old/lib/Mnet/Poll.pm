package Mnet::Poll;

=head1 NAME

Mnet::Poll - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

 Usage example:

 # sample1.pl --object-name test --db-name mnet
 # nb: test object polled via snmp, last poll data stored in database
 #     mnet alerts will be logged and also stored in the mnet database
 use Mnet;
 use Mnet::Poll;
 my $cfg = &object;
 &poll_data({'poll-alerts' => 1});

 # sample2.pl
 # nb: any poll data is always accessible, even with no mnet object call
 #     data for any object can be read directly from the database 
 use Mnet::Poll;
 $data = &poll_data({
    'object-name' => 'test',
    'poll-db'     => 'mnet',
 });
 &inf("localhost snmp contact " . $data->{'sys'}->{'contact'});

 # sample3.pl
 # nb: a shell perl command can snmp poll an object and output alerts
 perl -e "use Mnet::Poll; &poll_data;" - --poll-alerts --poll-sample \
    --snmp-community public --object-name test

=head1 DESCRIPTION

The poll module can be used in several ways to gather or examine
data about an object-name.

Data can be polled from an object using this module. More data,
reflecting state change and rate data, can be obtained using the
db-name option and data stored from a previous poll. Also, already
collected data for an object can be read directly from the database.
Finally, without using the database, state change and rate data can
be collected for an object over two separate poll samples.

Alerts can be generated based on poll data, including state change
and rate data if that is also available.

The poll module collects data from mnet objects using snmp. Refer
to the mnet snmp man page for more additional snmp related config
settings.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --data-dir </path/dir>  specify directory for object subdirectories
 --db-name <database>    database name to connect to, default not set

 --poll-adescr-length    default 40 char max for alert descriptions
 --poll-alerts           default disabled, alerts based on poll data
 --poll-alerts-lpct5     default 75% lan utilization sev 5 alert
 --poll-alerts-lpct6     default 50% lan utilization sev 6 alert
 --poll-alerts-wpct5     default 95% wan utilization sev 5 alert
 --poll-alerts-wpct6     default 80% wan utilization sev 6 alert
 --poll-alerts-epmi4     default 2+ err packets/minute sev 4 alert
 --poll-alerts-epmi5     default 1+ err packets/minute sev 5 alert
 --poll-db [<database>]  read poll data, specify db, or use db-name
 --poll-detail           enable for extra debug detail
 --poll-mod-dir <dir>    optional location for custom polling modules
 --poll-mod-skip-*       set to run skip running specified poll module
 --poll-ping             default enabled, disable to skip ping check
 --poll-version          set at compilation to build number
 --poll-sample <secs>    set to poll object via snmp twice
 --poll-sev-ping         default sev 4 for poll ping alerts
 --poll-sev-snmp         default sev 5 for poll snmp alerts
 --poll-sev-success      default sev 2 for poll success alerts
 --poll-skip-alias       default to not skip alerts for ints with alias
 --poll-snmp             default enabled, can disable to skip snmp poll
 --poll-time-max <secs>  timeout, def batch-repeat*2, poll-sample*2, 600

Note that if poll-db is set then poll-sample will be ignored.

=head1 OUTPUT DATA

The following data, depending on the above configuration settings,
may be included in the output from the poll_data function:

 data -> {
   poll -> {
     address  -> object-address used for current poll attempt
     last     -> unix epoch time of last successful poll
     ping     -> ping poll, undef=skipped, 0=failed, 1=complete
     snmp     -> snmp poll, undef=skipped, 0=failed, 1=complete
     success  -> overall poll results, undef=skipped, 0=no, 1=yes
     time     -> unix epoch time of current poll attempt
   }
   sys -> {
     contact  -> configured system contact
     descr    -> system description
     location -> configured system location
     name     -> configured system hostname
     uptime   -> system uptime in seconds
   }
   int -> {
     descr1     -> {
       adescr   -> config description shortened if needed for alerts
       admin    -> numeric admin status, see details below
       alerts   -> alert status message if poll-alerts configured
       alias    -> smiv2 alias, possibly configured description
       biti     -> count of input bits
       bito     -> count of output bits
       bpsi     -> rate of input bits
       bpso     -> rate of output bits
       bounce   -> set on last status change since old poll data
       descr    -> interface descriptive name
       epmi     -> rate per minute of error and discard packets
       erri     -> count of input error and discard packets
       etime    -> elapsed time in seconds since old poll data
       fast     -> human readable speed in kb/s, mb/s or gb/s
       index    -> snmp interface index from standard mib
       ipv4     -> space separated list of associated ip/cidr pairs 
       last     -> seconds since reboot of last status change 
       mtype    -> interface monitor type keyword, see details below
       name     -> snmpv2 name, possibly interface short name
       nupi     -> count of input non-unicast packets
       nupo     -> count of output non-unicast packets
       npsi     -> rate of input non-unicast packets
       npso     -> rate of output non-unicast packets
       online   -> set if oper status is normal, based on mtype and oper
       oper     -> numeric operator status, see details below
       pcti     -> percentage inbound bandwidth utilization
       pcto     -> percentage outbound bandwidth utilization
       pkti     -> count of input packets
       pkto     -> count of output packets
       ppsi     -> rate of input packets
       ppso     -> rate of output packets
       rrd      -> interface rrd filename
       speed    -> interface speed in bits per second
       status   -> set for normal status based on admin, mtype and oper
       time     -> seconds into epoch when poll data was collected
       type     -> integer representing interface type as per rfc1700
       ucpi     -> count of input unicast packets
       ucpo     -> count of output unicast packets
     }       
     descr2     -> ... additional interfaces keyed by snmp int descr
   }
   ipv4 -> {
     ip/cidr1 -> descr key from int hash, undef if no int poll data
     ip/cidr2 -> ... additional addresses keyed in dotted decimal
   }
 }

Note that data keys mentioning a rate are not present if old persist
data from a last poll is not available. Rates will be calculated over
the elapsed time since that last poll, stored in etime. Also note
that any other data keys mentioning old poll data will not be present
if data from the last poll is not available.

Detail for interface admin and oper status keys:

 1   up
 2   down
 3   testing
 4   unknown
 5   dormant
 6   not present
 7   lower layer down

Detail for interface mtype key:

 dial        alert if not oper down/dormant, rrd created
 down        alert if not oper down, no rrd
 hide        no data kept for this interface
 lan         alert if not oper up/dormant, rrd created
 other       alert if not oper up/dormant, rrd created with biti
 signal      alert if not oper up/dormant, no rrd
 skip        no alerts, no rrd
 unknown     alert if not oper up/dormant, rrd with biti present
 up          alert if not oper up, no rrd
 virtual     alert if not oper up, rrd created
 voice       alert if not oper up/dormant, no rrd
 wan         alert if not oper up, rrd created

Note that lan interfaces without an ip address or a configured alias
description are set to an mtype of skip. Custom poll modules may
supplement or modify the rules for interface mtype settings. Also
note that IPv6 addresses on a lan interface are not seen by this
module because IPv6 addresses are not found in the standard snmp
interface mib.

=head1 ALERTS
 
The poll-alerts config setting can be used to enable alert output
based on polling data. Custom modules should honor the poll-alerts
setting and use poll data success, ping and snmp connectivity results
to control the generation of alerts.

This module includes alerts for object polling success, ping and snmp
connectivity. This module also alerts on abnormal interfaces conditions
based on admin and operator status, errors and bandwidth utilization.
Log messages are generated when interfaces are added and removed. Poll
data interface mtype values get used to determine how alerts are
generated for specific interfaces.

Note that alerts are normally output with log messages and that the
db-name setting must be used to save alerts to a database where they
can be tracked over time.

Note also that custom modules can maniplulate the alert thresholds
use by this module to influence the generation of alerts.

=head1 CUSTOM POLL MODULES

Custom poll modules are used to handle vendor specific or other custom
polling tasks. The mnet distribution includes a number of poll modules.
The poll-mod-dir config setting can be used to specify the location of
other custom poll modules.

When poll module is loaded all Mnet::Poll polling submodules and any
custom poll modules found under the Poll directory of the specified
poll-mod-dir setting are loaded. Custom poll modules are normal .pm
perl module files with a poll_mod function.

Each time the main poll module poll_data function is called for an
object all loaded poll modules are called. This happens after snmp
standard polling occurs. Modules are called in alphabetical order.
Custom module names may be prefixed or suffixed with an underscore
to execute before or after an mnet poll module with the same name.
If a custom module has the same name as an mnet mnet module, the
mnet poll module will execute first.

A poll module must include a poll_mod function. This function will be
executed with the eval command for matching objects. The call to the
poll_mod function will be invoked with hash references to the current
config settings, current new poll data and old poll data.

 &poll_mod(\%cfg, \%pn, \%po);

Refer to the configuration and output data section for details on the
format of these hash references. The new poll data will be data that is
collected via snmp. The old poll data, if present, is from the mnet
database.

The first thing a poll module should do is examine its inputs to
determine if it should return right away or continue executing. New
polling data, old polling data, and/or config can be examined. For
example, the snmp description can be examined for a vendor string.
New data can be gathered if necessary.

A poll module may examine and/or modify current config setting, new
and old poll data. Any mnet or other perl or system calls may be
invoked. It may be useful for a custom poll module to modify current
configuration settings and collected poll data, such as alert
thresholds and interface mtype values.

When finished executing the custom module code the poll module can
set missing interface adescr from alias values, truncating them if too
long. Also the rrd module can be called to update interface graphs
depending on the mtype value for each interface. Alert processing can
occur. The sys->success boolean value in the new poll data controls
if new poll data is considered complete.

Note that the poll-mod-skip-* setting can be used to suppress the
execution of a specified poll module. The name of the poll module
is not case sensitive for purposes of skip settings. Leading and
trailing underscores in the poll module name are ignored. This can
be set from one poll module to suppress other poll modules.

Following is a sample shell for a custom polling module:

 # use config option --poll-mod-dir ./Mnet_Client
 package Mnet_Client::Poll::Vendor;
 use Mnet;
 BEGIN {
     our $cfg = &Mnet::config({'vendor-default' => 1});
 }
 sub poll_mod {
     &dtl("poll_mod function starting");
     my $cfg = shift or die "poll_mod cfg arg missing";
     my $pn = shift or die "poll_mod pn arg missing";
     my $po = shift;
     $po = {} if ref $po ne "HASH";
     if (not $pn->{'sys'}->{'descr'}
         or $pn->{'sys'}->{'descr'} !~ /vendor/) {
         &dtl("poll_mod exiting, device doesn't match module");
         return;
     }
     # include custom code here
     &dtl("poll_mod function finished");
 }
 1;

In batch-list mode the poll-mod-dir setting must be passed on the
command line in order for those custom poll modules to be compiled
before forking, or as follows in the main script:

 use Mnet;
 BEGIN {
     &Mnet::config({
         'poll-mod-dir' => '/home/data/Mnet_Client',
     });
 }
 use Mnet::Poll;

Note that the poll-mod-dir config setting will be ignored if passed
to the poll_data function.

Refer to the 'see also' section of this document for a list of poll
modules included with this distribution. 

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and libraries:

=cut

# modules used
use warnings;
use strict;
use Carp;
use Data::Dumper;
use Exporter;
use Mnet;
use Mnet::IP;
use Mnet::Ping;
use Mnet::RRD;
use Mnet::SNMP;

# export module function names
our @ISA = qw( Exporter );
our @EXPORT = qw( poll_data );

# module initialization
BEGIN {

    # set module config defaults
    our $cfg = &Mnet::config({
        'poll-adescr-length'    => 40,
        'poll-alerts-lpct5'     => 75,
        'poll-alerts-lpct6'     => 50,
        'poll-alerts-wpct5'     => 95,
        'poll-alerts-wpct6'     => 80,
        'poll-alerts-epmi4'     => 2,
        'poll-alerts-epmi5'     => 1,
        'poll-ping'             => 1,
        'poll-version'          => '+++VERSION+++',
        'poll-sev-ping'         => 4,
        'poll-sev-snmp'         => 4,
        'poll-sev-success'      => 2,
        'poll-snmp'             => 1,
    });

    # set poll-sample default interval
    our $poll_sample_default = 15;

    # set database handle as a global variable
    our $dbh = undef;

    # set flag used for snmp polling, undef=untried, 0=timeout, 1=ok
    our $success = undef;

    # determine path for the currently loaded mnet poll module
    my $mnet_poll_dir = $INC{'Mnet/Poll.pm'};
    $mnet_poll_dir = $INC{'Mnet.pm'} if not defined $mnet_poll_dir;
    croak "unable to determine Mnet/Poll.pm directory from %INC"
        if not $mnet_poll_dir;
    &Mnet::dtl("poll_mods mnet poll module loaded from $mnet_poll_dir");

    # process mnet_poll_dir and poll_mod_dir directories, skip if embedded
    foreach my $dir ($mnet_poll_dir, $cfg->{'poll-mod-dir'}) {
        next if not defined $dir;
        $dir =~ s/\/Poll(\.pm)?$//;
        next if $dir !~ /\S/ or $dir eq $0;
        &Mnet::dtl("poll_mods processing directory $dir");
        opendir(my $dh, "$dir/Poll") or croak "dir open error $dir/Poll $!";

        # loop through .pm files in current poll mod directory
        foreach my $file (readdir($dh)) {
            next if $file !~ /\.pm$/;
            &Mnet::dtl("poll_mods processing file $dir/Poll/$file");

            # set lib dir and package, based on custom or mnet poll module
            my $lib = $dir;
            croak "poll_mods unable to determine use lib for $lib"
                if $lib !~ s/\/([^\/]+)$//;
            my $package = "$1::Poll::$file";
            $package =~ s/\.pm//;

            # compile the current perl module, abort on errors
            &Mnet::dtl("poll_mods compiling $package using lib $lib");
            eval "use lib \"$lib\"; require $package;";
            croak "poll_mods $dir/Poll/$file compile error $@" if $@;

        # continue looping through .pm files in the current directory
        }
        closedir $dh;

    # continue processing both mnet_poll_path and poll_mod_dir directories
    }

    # output polling modules loaded and count
    my $count = 0;
    foreach my $key (sort keys %INC) {
        next if not $key or $key !~ /^([^\/]+\/)?Poll\/[^\/]+\.pm$/;
        &Mnet::dbg("poll_mods confirmed $key is loaded");
        $count++;
    }
    &Mnet::dbg("poll_mods total of $count modules are ready");

# finished module initialization
}



sub poll_data {

=head2 poll_data function

 \%data = &poll_data(\%args)

This is a method that can be used to retrieve poll data for the
currently configured object or an object-name specified as one of
settings in the optional input hash reference for this function.

Refer to the data section above for an explanation of what keys may
be present in the output data hash reference.

There are four ways that data may be gathered using this function,
depending on the following configuration settings:

- Use poll-db to return the most recent poll data for the object from
the specified database. No snmp polling occurs when this setting is
used. The data returned will not honor the poll-snmp settings nor
is rate information guaranteed to be present. The poll-db setting
overrides poll-sample.

- The poll-sample setting can be used to execute two consecutive snmp
polls to the configured object. Rate data will be calculated based
on the two data sets and the results returned as output. No poll
data will be read or written to the db-name, if configured. The
poll-db setting overrides poll-sample.

- With db-name set data from the prior poll for the current object is
read from the database, snmp is used to collect another data set,
rate data is calculated, the database is updated and the new data
is returned as output.
 
- A call to this funciton without poll-db, poll-sample or db-name set
in the config will result in a snmp poll of data from the object and
this data will be returned as output. Rate information will not be
present and the no database updates to poll data will occur.

The poll-alerts setting, if enabled, will cause alert processing to
occur on the returned poll data output. Refer to the alerts section,
above, for more details.

=cut

    # read input config args, validate and add to module config
    my $args = shift;
    &dbg("poll_data sub called from " . lc(caller));
    $args = {} if not defined $args;
    croak "poll_data config args not a hash ref" if ref $args ne "HASH";
    my $cfg = &config({}, $args);

    # output an error if poll-db name not set nor db-name configured
    croak "poll_data poll-db requires database name or db-name configured"
        if defined $cfg->{'poll-db'} and $cfg->{'poll-db'} eq "1"
        and not defined $cfg->{'db-name'};

    # output an error if an mnet object was not specified
    croak "poll_data call requires object-name to be defined"
        if not defined $cfg->{'object-name'};

    # set poll-sample to default interface if non-numeric or set as one
    if ($cfg->{'poll-sample'} and $cfg->{'poll-sample'} !~ /^\d+$/
        or $cfg->{'poll-sample'} and $cfg->{'poll-sample'} == 1) {
        &dbg("poll_data set poll-sample to default interval");
        $cfg->{'poll-sample'} = $Mnet::Poll::poll_sample_default;
    }

    # disable poll-sample if poll-db is configured
    if ($cfg->{'poll-db'} and $cfg->{'poll-sample'}) {
        &inf("disabling poll-sample when poll-db is set");
        $cfg->{'poll-sample'} = 0;
    }

    # output a log entry if poll-sample is configured
    &inf("poll-sample is set to $cfg->{'poll-sample'} seconds")
        if $cfg->{'poll-sample'};

    # output a log entry if poll-db is configured
    &inf("poll-db is set to read poll data from database")
        if $cfg->{'poll-db'};

    # set poll-time-max from batch-repeat, if batch-repeat is set
    if (not $cfg->{'poll-time-max'}) {
        $cfg->{'poll-time-max'} = 600;
        if ($cfg->{'poll-sample'}) {
            $cfg->{'poll-time-max'} = $cfg->{'poll-sample'} * 2;
        } elsif ($cfg->{'batch-repeat'}) {
            $cfg->{'poll-time-max'} = $cfg->{'batch-repeat'} * 2
        }
    }

    # initialize old and new poll data
    my $po = {};
    my $pn = {};

    # set poll modules from function arg if different than prior config
    &dbg("poll_data ignoring poll-mod-dir passed as argument")
        if defined $args->{'poll-mod-dir'};

    # set poll loop start time
    my $start_time = time;

    # if poll-sample set execute two consecutive poll for old and new data
    if ($cfg->{'poll-sample'}) {
        &dbg("poll_data poll-sample set to do two consecutive data polls");
        &dbg("poll_data poll-sample set as $cfg->{'poll-sample'}");
        &dbg("poll_data executing first sample poll");
        %$po = &data_poll($cfg);

        # on failed first poll dump data and nothing else
        if (not $po->{'poll'}->{'success'}) {
            $pn = $po;
            $po = {};
            &data_dump($cfg, "poll-1", $pn, "final");
            &dbg("poll_data poll-sample aborting after failed first poll");

        # on successful first poll dump data then execute second poll
        } else {
            &data_dump($cfg, "poll-1", $po);
            &dbg("poll_data poll-sample delay $cfg->{'poll-sample'} seconds");
            sleep $cfg->{'poll-sample'};
            &dbg("poll_data executing second sample poll");
            %$pn = &data_poll($cfg, $po);
            &data_dump($cfg, "poll-2", $pn, "final");

            # set output data from first poll if second poll failed
            if (not $pn->{'poll'}->{'success'}) {
                &dbg("poll_data second poll failed, set data from first poll");
                $pn = $po;
                $po = {};
            }

        # finished both poll-sample runs
        }

    # if poll-db option set output old poll data
    } elsif ($cfg->{'poll-db'}) {
        &dbg("poll_data poll-db set to get old poll data from database");
        $pn = &dbh_read($cfg);
        &data_dump($cfg, "poll-db", $pn, "final");

    # handle normal poll_data call with db-name
    } elsif ($cfg->{'db-name'}) {
        &dbg("poll_data normal poll, old poll data with db-name set");
        $po = &dbh_read($cfg);
        &data_dump($cfg, "db-name", $po);
        %$pn = &data_poll($cfg, $po);

        # on failed poll, output old poll data except keep new poll subkey
        if (not $pn->{'poll'}->{'success'}) {
            &dbg("poll_data returning db-name old poll data after failed poll");
            my $poll = $pn->{'poll'};
            $pn = $po;
            $po = {};
            $pn->{'poll'} = $poll;
            &dbh_write($cfg, $pn);
            &data_dump($cfg, "db-name", $pn, "final");

        # on successful poll write and dump new poll data
        } else {
            &dbh_write($cfg, $pn);
            &data_dump($cfg, "poll", $pn, "final");

        # finished handling normal poll results
        }

    # handle normal poll_data without db-name
    } else {
        &dbg("poll_data normal poll, no old poll data with db-name unset");
        %$pn = &data_poll($cfg, $po);
        &dbh_write($cfg, $pn);
        &data_dump($cfg, "poll", $pn, "final");

    # finished current poll-sample, poll-db or normal poll
    }

    # finished poll_data
    &dbg("finished poll_data function");
    return $pn; 
}



sub alerts {

# internal: \%data = &alerts($cfg, \%pn, \%po)
# purpose: generate alerts based on available poll data
# \%cfg: current configuration settings in effect
# \%pn: hash reference to new object persist data used for poll
# \%po: hash reference to old object persist data used for poll

    # begin, initialize input arguments
    my $cfg = shift or croak "alerts cfg arg missing";
    my $pn = shift or croak "alerts pn arg missing";
    my $po = shift;
    $po = {} if ref $po ne "HASH";
    &dbg("alerts function starting");

    # return right away if poll-alerts not configured
    if (not $cfg->{'poll-alerts'}) {
        &dbg("alerts poll-alerts not configured");
        return;
    }

    # retrieve time of last poll
    my $ltime = "last poll";
    $ltime = lc(localtime($po->{'poll'}->{'time'}))
        if exists $po->{'poll'}->{'time'};
    $ltime =~ s/\s+\d+$//;
    $ltime =~ s/\s\s+/ /g;

    # alert if object was not polled successfully
    if (not $pn->{'poll'}->{'success'}) {
        &alert($cfg->{'poll-sev-success'}, "object poll failed");

    # if poll successful then handle other alerts
    } else {

        # alert if object ping configured and failed
        &alert($cfg->{'poll-sev-ping'}, "object ping failed")
            if $cfg->{'poll-ping'} and not $pn->{'poll'}->{'ping'};

        # alert if object ping configured and failed
        &alert($cfg->{'poll-sev-snmp'}, "object snmp failed")
            if $cfg->{'poll-snmp'} and not $pn->{'poll'}->{'snmp'};

        # start interface alert checks if new polling data has interface data
        if (keys %{$pn->{'int'}}) {

            # build hash of interfaces with old and new poll index subkeys
            my $ints = {};
            foreach my $index (keys %{$po->{'int'}}) {
                my $descr = $po->{'int'}->{$index}->{'descr'};
                &dtl("alerts old poll data has int $descr at index $index");
                $ints->{$descr}->{'po_index'} = $index;
            }
            foreach my $index (keys %{$pn->{'int'}}) {
                my $descr = $pn->{'int'}->{$index}->{'descr'};
                &dtl("alerts new poll data has int $descr at index $index");
                $ints->{$descr}->{'pn_index'} = $index;
            }

            # generate log messages for each added or removed interface
            if (keys %{$po->{'int'}}) {
                &dbg("alerts checking for added or removed interfaces");
                foreach my $descr (keys %$ints) {
                    my $pn_index = $ints->{$descr}->{'pn_index'}
                        if defined $ints->{$descr}->{'pn_index'};
                    my $po_index = $ints->{$descr}->{'po_index'}
                        if defined $ints->{$descr}->{'po_index'};
                    next if defined $pn_index
                        and defined $pn->{'int'}->{$pn_index}->{'mtype'}
                        and $pn->{'int'}->{$pn_index}->{'mtype'} eq 'skip';
                    &log(5, "detected interface $descr added since $ltime")
                        if not $ints->{$descr}->{'po_index'};
                    &log(5, "detected interface $descr removed since $ltime")
                        if not $ints->{$descr}->{'pn_index'};
                }
            }

            # check alerts on new poll interface data
            &dbg("alerts checking for alerts using new poll data");
            foreach my $index (sort keys %{$pn->{'int'}}) {
                &alerts_int($cfg, $pn->{'int'}->{$index}, $ltime);
            }

        # finished checking new interface poll data
        }

    # finished checking all alerts on successful poll
    }

    &dbg("alerts function finishing");
    return;
}



sub alerts_int {

# internal: alerts_int($cfg, \%int, $ltime)
# purpose: used to check for alerts on an interface in new poll data
# \%cfg: current configuration settings in effect
# \%int: hash referernce in new poll data to an int->index subkey
# $ltime: local time the last poll was executed

    # begin, initialize input arguments
    my $cfg = shift or croak "alerts_int cfg arg missing";
    my $int = shift or croak "alerts_int int arg missing";
    my $ltime = shift or croak "alerts_int ltime arg missing";
    &dbg("alerts_int function starting for int $int->{'descr'}");

    # skip alerts if monitoring type is set to skip
    if ($int->{'mtype'} and $int->{'mtype'} eq 'skip') {
        &dtl("alerts_int $int->{'descr'} mtype set skip");
        $int->{'alerts'} = "skipped alert processing";
        return;
    }

    # retrieve alert description because it will be used often
    my $descr = $int->{'descr'};
    my $adescr = $int->{'adescr'};
    $adescr = "" if not defined $adescr or $adescr eq $descr;
    $adescr = " ($adescr)" if $adescr ne "";

    # for admin down interfaces set alert status and return
    if ($int->{'admin'} and $int->{'admin'} !~ /^(1|up)$/i) {
        &dtl("alerts_int $int->{'descr'} admin status not up at this time");
        $int->{'alerts'} = "admin status not up at this time";

    # check if interface status is not normal
    } elsif (not $int->{'status'}) {
        my $mtype = "";
        $mtype = $int->{'mtype'} if defined $int->{'mtype'};
        &alert (3, "interface $descr $mtype status not normal$adescr");
        $int->{'alerts'} = "online status not normal at this time";

    # handle an interface that bounced since the last poll
    } elsif ($int->{'bounce'}) {
        &log(4, "interface $descr online status changed since $ltime$adescr");
        $int->{'alerts'} = "online status changed since $ltime";

    # finished mutually exclusive interface status alerts
    }

    # start online interface rate-based alert checks
    if ($int->{'online'}) {
    
        # set bandwidth utilization percentage to greater of inbound or outbound
        my $bw = $int->{'pcti'} if $int->{'pcti'};
        $bw = $int->{'pcto'} if $int->{'pcto'} and $bw and $int->{'pcto'} > $bw;

        # check for excessive wan bandwidth utilization
        if ($bw and $int->{'mtype'} eq 'wan') {
            if ($bw >= $cfg->{'poll-alerts-wpct5'}) {
                my $pct = "$cfg->{'poll-alerts-wpctl5'}\%";
                $int->{'alerts'} ="wan bandwidth utilization over $pct";
                &alert(5, "interface $descr $int->{'alerts'}$adescr");
            } elsif ($bw >= $cfg->{'poll-alerts-wpct6'}) {
                my $pct = "$cfg->{'poll-alerts-wpctl6'}\%";
                $int->{'alerts'} ="wan bandwidth utilization over $pct";
                &alert(6, "interface $descr $int->{'alerts'}$adescr");
            }
        }

        # check for excessive lan bandwidth utilization
        if ($bw and $int->{'mtype'} eq 'lan') {
            if ($bw >= $cfg->{'poll-alerts-lpct5'}) {
                my $pct = "$cfg->{'poll-alerts-lpctl5'}\%";
                $int->{'alerts'} ="lan bandwidth utilization over $pct";
                &alert(5, "interface $descr $int->{'alerts'}$adescr");
            } elsif ($bw >= $cfg->{'poll-alerts-lpct6'}) {
                my $pct = "$cfg->{'poll-alerts-lpctl6'}\%";
                $int->{'alerts'} ="lan bandwidth utilization over $pct";
                &alert(6, "interface $descr $int->{'alerts'}$adescr");
            }
        }

        # check errors per minute
        my $epmi = $int->{'epmi'};
        if ($epmi and $epmi >= $cfg->{'poll-alerts-epmi4'}) {
            $int->{'alerts'} = "seeing $cfg->{'poll-alerts-epmi4'}+ errs/min";
            &alert(4, "interface $descr $int->{'alerts'}$adescr");
        } elsif ($epmi and $epmi >= $cfg->{'poll-alerts-epmi5'}) {
            $int->{'alerts'} = "seeing $cfg->{'poll-alerts-epmi5'}+ errs/min";
            &alert(5, "interface $descr $int->{'alerts'}$adescr");
        }

    # finished online interface rate-based alert checks
    }

    # update interface alert status to normal if not set to anything else
    &dtl("setting interface alert status to operating normally");
    $int->{'alerts'} = "operating normally at this time"
        if not $int->{'alerts'};

    &dtl("alerts_int function finishing");
    return;
}



sub data_dump {

# internal &data_dump(\%cfg, $prefix, \%data, $final)
# purpose: output debug messages of dump of referenced data hash
# \%cfg: current configuration settings in effect
# $prefix: prefix for debug messages for data dump
# \%data: referenced hash to have debug messages dumped
# $final: set for normal debug output instead of requiring detail

    # read inputs
    my $cfg = shift or croak "data_dump cfg arg missing";
    my $prefix = shift or croak "data_dump prefix arg missing";
    my $data = shift;
    my $final = shift;

    # return if log-level not set for debug
    return if $cfg->{'log-level'} < 7;

    # output poll data dump log entries
    &dtl("data_dump for $prefix starting") if not $final;
    &dbg("data_dump for $prefix starting") if $final;
    my $data_dump = Dumper($data);
    foreach my $line (split(/\n/, $data_dump)) {
        &dtl("dump $prefix: $line") if not $final;
        &dbg("dump $prefix: $line") if $final;
    }
    &dtl("data_dump for $prefix finished") if not $final;
    &dbg("data_dump for $prefix finished") if $final;

    # finished data_dump function
    return;
}



sub data_poll {

# internal: \%data = &data_poll($cfg, \%po)
# purpose: execute standard snmp and custom module polling 
# \%cfg: current configuration settings in effect
# \%po: hash reference to old object persist data used for poll

    # begin, read config and old poll data
    my $cfg = shift or croak "data_poll cfg arg missing";
    my $po = shift;
    $po = {} if ref $po ne "HASH";
    &dtl("data_poll function starting");

    # initialize new poll data and interface mib table
    my $pn = {};
    my $int_table = {};

    # set poll time in data hash and clear success flag
    my $poll_time = time;
    $pn->{'poll'}->{'time'} = $poll_time;
    $Mnet::Poll::success = undef;

    # set object-address used for current poll
    $pn->{'poll'}->{'address'} = $cfg->{'object-address'};

    # execute ping polling, as per poll-ping configuration
    if (not $cfg->{'poll-ping'}) {
        &dbg("data_poll poll-ping set false, skipping ping polling");
    } else {
        &dbg("data_poll poll-ping set true, starting ping polling");
        if (&ping_check($cfg)) {
            &dbg("data_poll ping was successful");
            $pn->{'poll'}->{'ping'} = 1;
        } else {
            &dbg("data_poll ping was not successful");
            $pn->{'poll'}->{'ping'} = 0;
        }
        my $ping = 0;
        $ping = 100 if $pn->{'poll'}->{'ping'};
        &rrd_value('ping', 'percentage', 'gauge', $ping, 0, 100);
    }

    # execute snmp polling, as per poll-snmp configuration
    if (not $cfg->{'poll-snmp'}) {
        &dbg("data_poll poll-snmp set false, skipping snmp polling");
    } elsif (not defined $Mnet::Poll::success or $Mnet::Poll::success) {
        &dbg("data_poll poll-snmp set true, starting snmp polling");
        $pn->{'poll'}->{'snmp'} = 0;
        $pn->{'sys'} = &snmp_sys($cfg)
            if not defined $Mnet::Poll::success or $Mnet::Poll::success;
        ($pn->{'int'}, $int_table) = &snmp_int($cfg, $po)
            if not defined $Mnet::Poll::success or $Mnet::Poll::success;
        $pn->{'ipv4'} = &snmp_ipv4($cfg, $pn)
            if not defined $Mnet::Poll::success or $Mnet::Poll::success;
        foreach my $int (keys %{$pn->{'int'}}) {
            my $pn_int = $pn->{'int'}->{$int};
            $pn_int->{'mtype'} = &snmp_int_mtype($cfg, $pn_int);
        }
        if ($Mnet::Poll::success) {
            &dbg("data_poll snmp polling was successful");
            $pn->{'poll'}->{'snmp'} = 1;
        } else {
            &dbg("data_poll snmp polling was not successful");
            $pn->{'poll'}->{'snmp'} = 0;
        }
        my $snmp = 0;
        $snmp = 100 if $pn->{'poll'}->{'snmp'};
        &rrd_value('snmp', 'percentage', 'gauge', $snmp, 0, 100);
    }

    # set poll snmp flag in output if snmp timed out or was successful
    $pn->{'poll'}->{'success'} = $Mnet::Poll::success
        if defined $Mnet::Poll::success;

    # loop through all loaded Poll then Mnet::Poll poll mods
    &dtl("data_poll executing all loaded poll modules");
    foreach my $key (
        sort {
            my ($cmp_a, $cmp_b) = ($a, $b);
            $cmp_a =~ s/^[^\/]+\/Poll\///;
            $cmp_b =~ s/^[^\/]+\/Poll\///;
            return -1 if $cmp_a eq $cmp_b and $a =~ /^Mnet/;
            $cmp_a =~ s/^_/-/;
            $cmp_b =~ s/^_/-/;
            return $cmp_a cmp $cmp_b;
        } grep { /^[^\/]+\/Poll\// } keys %INC) {
        &dtl("data_poll module processing for $key");

        # skip invalid poll mods, determine short name of current poll mod
        next if not $key or $key !~ /^([^\/]+\/Poll\/[^\/]+)\.pm/;
        my $mod_name = lc($1);

        # determine poll mod calling syntax from %INC key
        my $mod_call = $key;
        $mod_call =~ s/\.pm$//;
        $mod_call =~ s/\//::/g;
        $mod_call = "\&${mod_call}::poll_mod";

        # skip execution if poll-mod-skip-* is set for this module
        my $skip_check = $mod_name;
        $skip_check =~ s/(^_+|_+$)//g;
        if ($cfg->{lc("poll-mod-skip-$skip_check")}) {
            &dtl("data_poll poll-mod-skip-$skip_check set for $mod_call");
            next;
        }

        # execute current custom poll module
        &dtl("data_poll executing $mod_name, $mod_call");
        eval "${mod_call}(\$cfg, \$pn, \$po);";
        carp "data_poll $mod_name, $mod_call error $@" if $@;
        &dtl("data_poll returned from $mod_name, $mod_call");

    # finished processing all poll modules
    }

    # update last successful poll time if this poll was successful
    $pn->{'poll'}->{'last'} = $poll_time if $pn->{'poll'}->{'success'};

    # execute interface post processing if this poll was successful
    &data_poll_int($cfg, $pn, $int_table) if $pn->{'poll'}->{'success'};

    # process alerts
    &alerts($cfg, $pn, $po);

    # finished poll_data
    &dtl("data_poll function finished");
    return %$pn;
}



sub data_poll_int {

# internal: &data_poll_int($cfg, \%pn, \%int_table)
# purpose: execute post processing on current interface data
# \%cfg: current configuration settings in effect
# \%pn: hash reference to object data from new poll
# \%int_table: output hash reference of all snmp mib data

    # begin, read config and new poll data
    my $cfg = shift or croak "data_poll_int cfg arg missing";
    my $pn = shift or croak "data_poll_int pn arg missing";
    my $int_table = shift or croak "data_poll_int int_table ar missing";
    &dtl("data_poll_int function starting");

    # loop through all interfaces in current poll data
    foreach my $int (keys %{$pn->{'int'}}) {
        my $pn_int = $pn->{'int'}->{$int};
        &dtl("data_poll_int processing interface $pn_int->{'descr'}");

        # remove hidden interfaces
        if ($pn_int->{'mtype'} eq 'hide') {
            &dbg("data_poll_int removing hidden interface $pn_int->{'descr'}");
            delete $pn->{'int'}->{$int};
            next;
        }

        # ensure that alias and adescr are set
        $pn_int->{'alias'} = $pn_int->{'descr'}
            if not defined $pn_int->{'alias'};
        $pn_int->{'adescr'} = $pn_int->{'alias'}
            if not defined $pn_int->{'adescr'};

        # truncate adescr if necessary
        if (length($pn_int->{'adescr'}) > $cfg->{'poll-adescr-length'}) {
            $pn_int->{'adescr'} = substr($pn_int->{'adescr'},
                0, $cfg->{'poll-adescr-length'});
            $pn_int->{'adescr'} =~ s/\s*$/.../;
        }

        # init status normal flag and online flag
        ($pn_int->{'status'}, $pn_int->{'online'}) = (undef, undef);

        # for mtype skip set status normal, online clear
        if ($pn_int->{'mtype'} eq "skip") {
            ($pn_int->{'status'}, $pn_int->{'online'}) = (1, 0);

        # for admin down set status ok and online clear
        } elsif ($pn_int->{'admin'} !~ /^(1|up)$/i) {
            ($pn_int->{'status'}, $pn_int->{'online'}) = (1, 0);

        # for mytpe down set status ok if oper status is down
        } elsif ($pn_int->{'mtype'} =~ /^(down)$/) {
            if ($pn_int->{'oper'} =~ /^(2|down)$/i) {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (1, 0);
            } else {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (0, 1);
            }

        # for mtype up set status ok if oper status is up
        } elsif ($pn_int->{'mtype'} =~ /^(up)$/) {
            if ($pn_int->{'oper'} =~ /^(1|up)$/i) {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (1, 1);
            } else {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (0, 0);
            }

        # for mtype dial set status ok if down or dormant
        } elsif ($pn_int->{'mtype'} =~ /^(dial)$/) {
            if ($pn_int->{'oper'} =~ /^(2|down|5|dormant)$/i) {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (1, 0);
            } else {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (0, 1);
            }

        # for all other interfaces set status ok if up or dormant
        } else {
            if ($pn_int->{'oper'} =~ /^(1|up|5|dormant)$/i) {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (1, 1);
            } else {
                ($pn_int->{'status'}, $pn_int->{'online'}) = (0, 0);
            }

        # finished setting status and online
        }

        # update interface rrd graphs based on mtype
        next if $pn->{'int'}->{$int}->{'mtype'}
            =~ /^(down|signal|skip|up|voice)$/;
        next if $pn->{'int'}->{$int}->{'mtype'} =~ /^(other|unknown)$/
            and not defined $pn->{'int'}->{$int}->{'biti'};
        &dtl("data_poll_int rrd updating $pn->{'int'}->{$int}->{'descr'}");
        my $file = &rrd_interface($int_table, $pn->{'int'}->{$int}->{'index'});
        $pn_int->{'rrd'} = $file if defined $file and $file ne '';

    # finished looping through interfaces in current poll data
    }

    # finished poll_data_int
    &dtl("data_poll_int function finished");
    return;
}



sub dbh_read {

# internal: \%po = &dbh_read(\%cfg)
# purpose: open poll database table and read data from prior poll
# \%cfg: current configuration settings in effect
# \%po: hash reference to object old poll data read from database

    # begin, read arguments
    my $cfg = shift or croak "dbh_read cfg arg missing";
    &dtl("dbh_read function starting");
    my $po = {};

    # set database to use for reading polling data, or return
    my $poll_db = undef;
    if (defined $cfg->{'poll-db'} and $cfg->{'poll-db'} ne "1") {
        &dbg("dbh_read using poll-db $cfg->{'poll-db'}");
        $poll_db = $cfg->{'poll-db'};
    } elsif (defined $cfg->{'db-name'}) {
        &dbg("dbh_read using db-name $cfg->{'db-name'}");
    } else {
        &dbg("dbh_read skipped, no db-name or poll-db defined");
        return $po;
    }

    # open database connection and read table list from database, exit on errors
    my $dbh_tables = [];
    my $dbh_err;
    ($Mnet::Poll::dbh, $dbh_err) = &database($dbh_tables, $poll_db);
    croak "dbh_read database error, $dbh_err" if defined $dbh_err;
    croak "dbh_read database error, database handle not defined"
        if not defined $Mnet::Poll::dbh;

    # create poll table if not present
    if (" @$dbh_tables " !~ /\s+_poll\s+/) {
        &dbg("dbh_read attempting to create missing _poll table");
        my $sql = "create table _poll ( ";
        $sql .= "_time int, ";
        $sql .= "_expire int, ";
        $sql .= "_object varchar, ";
        $sql .= "_data text ); ";
        $sql .= "create index _poll_idx1 on _poll (_expire); ";
        $sql .= "create index _poll_idx2 on _poll (_object); ";
        $Mnet::Poll::dbh->do($sql);
    }

    # attempt ot read poll data from database
    &dbg("dbh_read attempting to read old poll data");
    my $sql_po_read = "select _data from _poll where _object = ?";
    my $db_po_read = $Mnet::Poll::dbh->selectall_arrayref(
        $sql_po_read, {}, $cfg->{'object-name'});

    # return if no persist data found
    if (not @$db_po_read) {
        &dbg("dbh_read no old poll data found");
        return $po;
    }

    # restore persist data from database
    my $po_data = $$db_po_read[0];
    my $po_dump = $$po_data[0];
    my $VAR1;
    $VAR1 = eval $po_dump;
    $po = $VAR1;

    # debug log after persist data was restored
    &dbg("dbh_read read old poll data with " . length($po_dump) . " bytes");

    # output old poll data poll time
    if ($po->{'poll'}->{'time'}) {
        my $ltime = lc(localtime($po->{'poll'}->{'time'}));
        &dbg("dbh_read old poll attempt time $ltime");
    }

    # output old poll data last success time
    if ($po->{'poll'}->{'last'}) {
        my $ltime = lc(localtime($po->{'poll'}->{'last'}));
        &dbg("dbh_read old poll success last $ltime");
    }

    # finished dbh_read
    &dtl("dbh_read finished");
    return $po;
}



sub dbh_write {

# internal: &dbh_write(\%cfg, \%pn)
# purpose: write new poll data to database
# \%cfg: current configuration settings in effect
# \%pn: hash reference for object new poll data to write to database

    # begin, read arguments
    my $cfg = shift or croak "dbh_write cfg arg missing";
    my $pn = shift or croak "dbh_write pn arg missing";
    &dtl("dbh_write function starting");

    # return if poll-sample set, mnet database not open, or poll not successful
    if ($cfg->{'poll-sample'}) {
        &dbg("dbh_write skipped when poll-sample set");
        return;
    } elsif (not $Mnet::Poll::dbh) {
        &dbg("dbh_write skipped when db-name not set");
        return;
    } elsif (not $pn->{'poll'}->{'success'}) {
        &dbg("dbh_write skipped when current poll not successful");
        return;
    }

    # create dump of new poll data and return if no data exists
    my $pn_dump = "";
    if (defined $pn and %$pn) {
        &dtl("dbh_write preparing new data hash dump");
        $pn_dump = Dumper($pn);
    } else {
        &dbg("dbh_write no new poll data to update");
        return;
    }

    # set timestamp for database update
    my $time = int(time);
    my $expire = int(time + $Mnet::cfg->{'db-expire'} * 86400);

    # prepare query to update poll data
    my $sql_pn_update = "update _poll set _data=?, _time=? where _object=?";
    my $db_pn_update = $Mnet::Poll::dbh->prepare($sql_pn_update);

    # update poll data entry, create if necessary, report errors
    &dbg("dbh_write updating poll data with " . length($pn_dump) . " bytes");
    if ($db_pn_update->execute($pn_dump, $time, $cfg->{'object-name'}) ne "1") {

        # we will need to attempt to create a new poll data entry
        &dtl("dbh_write attempting to create new poll data entry");

        # prepare query for new poll data entry
        my $sql_pn_new = "insert into _poll (_time, _expire, _object, _data) ";
        $sql_pn_new .= "values (?, ?, ?, ?)";
        my $db_pn_new =  $Mnet::Poll::dbh->prepare($sql_pn_new);

        # execute new poll data entry query, warn with error on fail
        if ($db_pn_new->execute($time, $expire,
            $cfg->{'object-name'}, $pn_dump) ne "1") {
            my $err = "unknown error";
            $err = $Mnet::Poll::dbh->errstr if $Mnet::Poll::dbh->errstr;
            carp "dbh_write unable to write new poll data, $err";
        }
        &dtl("dbh_write new poll data entry created");
    }

    # finished dbh_write function
    &dtl("dbh_write finished");
    return;
}



sub ping_check {

# internal: $success = &ping(\%cfg)
# purpose: test ping to current object ip address
# \%cfg: current configuration settings in effect

    # begin, initialize output interface data and success
    my $cfg = shift or croak "ping_check cfg arg missing";
    &dtl("ping_check function starting");
    $Mnet::Poll::success = 0;

    # check ping response to current object address
    if (not &ping($cfg)) {
        &dtl("ping_check function returned a timeout");
        return 0;
    }

    # finished
    &dtl("ping_check function returned success");
    $Mnet::Poll::success = 1;
    return 1;
}



sub snmp_int {

# internal: (\%int, \%int_table) = &snmp_int(\%cfg, \%po)
# purpose: retrieve interface data from current object using snmp
# \%cfg: current configuration settings in effect
# \%po: hash reference to object old persist data for this module
# \%int: output hash reference of collected snmp data
# \%int_table: output hash reference of all snmp mib data

    # begin, initialize output interface data and success
    my $cfg = shift or croak "snmp_int cfg arg missing";
    my $po = shift or croak "snmp_int persist_old arg missing";
    &dtl("snmp_int function starting");
    $Mnet::Poll::success = 0;
    my $int = {};

    # interface oid to walk
    my $int_oid = ".1.3.6.1.2.1.2.2.1";
    my $intx_oid = ".1.3.6.1.2.1.31.1.1.1";

    # walk iftable and high speed ifxtable
    my $int_table = {};
    &snmp_bulkwalk($int_oid, $int_table, $cfg);
    &snmp_bulkwalk($intx_oid, $int_table, $cfg);

    # loop through indexed interfaces in snmp interface mib data, set success
    foreach my $oid (keys %$int_table) {
        next if $oid !~ /^\S+\.1\.(\d+)$/;
        $Mnet::Poll::success = 1;

        # set base oid and int index number, try to set idx hash key from descr
        my ($index, $idx) = ($1, $1);
        $idx = $int_table->{"$int_oid.2.$index"}
            if $int_table->{"$int_oid.2.$index"};

        # log start of processing, set ecpoch timestamp for this interface poll
        &dbg("snmp_int processing starting for interface index $idx");
        $int->{$idx}->{'time'} = time;

        # set interface index and description from iftable
        $int->{$idx}->{'index'} = $int_table->{"$int_oid.1.$index"};
        $int->{$idx}->{'descr'} = $int_table->{"$int_oid.2.$index"};

        # set interface name from ifxtable, or set from description
        $int->{$idx}->{'name'} = $int_table->{"$intx_oid.1.$index"};
        $int->{$idx}->{'name'} = $int->{$idx}->{'descr'}
            if not defined $int->{$idx}->{'name'};

        # set interface alias from ifxtable
        $int->{$idx}->{'alias'} = $int_table->{"$intx_oid.18.$index"};

        # set interface type, admin, oper and last change from iftable
        $int->{$idx}->{'type'} = $int_table->{"$int_oid.3.$index"};
        $int->{$idx}->{'admin'} = $int_table->{"$int_oid.7.$index"};
        $int->{$idx}->{'oper'} = $int_table->{"$int_oid.8.$index"};
        $int->{$idx}->{'last'} = $int_table->{"$int_oid.9.$index"};

        # set interface speed from iftable or ifxtable
        $int->{$idx}->{'speed'} = undef;
        $int->{$idx}->{'speed'} = $int_table->{"$int_oid.5.$index"}
            if defined $int_table->{"$int_oid.5.$index"};
        $int->{$idx}->{'speed'} = $int_table->{"$intx_oid.15.$index"}
            * 1000000 if defined $int_table->{"$intx_oid.15.$index"}
            and $int_table->{"$intx_oid.15.$index"} > 20;

        # set input and output bits from iftable or high speed ifxtable
        $int->{$idx}->{'biti'} = undef;
        $int->{$idx}->{'biti'} = $int_table->{"$int_oid.10.$index"} * 8
            if defined $int_table->{"$int_oid.10.$index"};
        $int->{$idx}->{'biti'} = $int_table->{"$intx_oid.6.$index"} * 8
            if defined $int_table->{"$intx_oid.6.$index"}
            and $int->{$idx}->{'speed'} > 19999999;
        $int->{$idx}->{'bito'} = undef;
        $int->{$idx}->{'bito'} = $int_table->{"$int_oid.16.$index"} * 8
            if defined $int_table->{"$int_oid.16.$index"};
        $int->{$idx}->{'bito'} = $int_table->{"$intx_oid.10.$index"} * 8
            if defined $int_table->{"$intx_oid.10.$index"}
            and $int->{$idx}->{'speed'} > 19999999;

        # set unicast packet counters from iftable or high speed ifxtable
        $int->{$idx}->{'ucpi'} = $int_table->{"$int_oid.11.$index"};
        $int->{$idx}->{'ucpi'} = $int_table->{"$intx_oid.7.$index"}
            if defined $int_table->{"$intx_oid.7.$index"}
            and $int->{$idx}->{'speed'} > 19999999;
        $int->{$idx}->{'ucpo'} = $int_table->{"$int_oid.17.$index"};
        $int->{$idx}->{'ucpo'} = $int_table->{"$intx_oid.11.$index"}
            if defined $int_table->{"$intx_oid.11.$index"}
            and $int->{$idx}->{'speed'} > 19999999;

        # set non unicast packet counters from iftable or high speed ifxtable
        $int->{$idx}->{'nupi'} = $int_table->{"$int_oid.12.$index"};
        $int->{$idx}->{'nupi'} = $int_table->{"$intx_oid.8.$index"}
            + $int_table->{"$intx_oid.9.$index"}
            if defined $int_table->{"$intx_oid.8.$index"}
            and defined $int_table->{"$intx_oid.9.$index"}
            and $int->{$idx}->{'speed'} > 19999999;
        $int->{$idx}->{'nupo'} = $int_table->{"$int_oid.18.$index"};
        $int->{$idx}->{'nupo'} = $int_table->{"$intx_oid.12.$index"}
            + $int_table->{"$intx_oid.13.$index"}
            if defined $int_table->{"$intx_oid.12.$index"}
            and defined $int_table->{"$intx_oid.13.$index"}
            and $int->{$idx}->{'speed'} > 19999999;

        # set interface input error and discard packets
        $int->{$idx}->{'erri'} = $int_table->{"$int_oid.13.$index"};
        $int->{$idx}->{'erri'} += $int_table->{"$int_oid.14.$index"}
            if defined $int_table->{"$int_oid.14.$index"}
            and $int->{$idx}->{'speed'} > 19999999;

        # calculate total packets per second in as sum of unicast and multicast
        $int->{$idx}->{'pkti'} = undef;
        $int->{$idx}->{'pkti'} = $int->{$idx}->{'ucpi'} + $int->{$idx}->{'nupi'}
	        if defined $int->{$idx}->{'ucpi'} and defined $int->{$idx}->{'nupi'}
            and $int->{$idx}->{'ucpi'} =~ /^\d+$/
            and $int->{$idx}->{'nupi'} =~ /^\d+$/;

        # calculate total packets per second out as sum of unicast and multicast
        $int->{$idx}->{'pkto'} = undef;
        $int->{$idx}->{'pkto'} = $int->{$idx}->{'ucpo'} + $int->{$idx}->{'nupo'}
            if defined $int->{$idx}->{'ucpo'} and defined $int->{$idx}->{'nupo'}
            and $int->{$idx}->{'ucpo'} =~ /^\d+$/
            and $int->{$idx}->{'nupo'} =~ /^\d+$/;

        # calculate human readable speed in rate per second
        if ($int->{$idx}->{'speed'} and $int->{$idx}->{'speed'} =~ /^\d+$/) {
                my $fast = $int->{$idx}->{'speed'};
                my $label = "b/s";
                if ($fast >= 2000000*1000) {
                        $fast = int($fast/(1000000*1000)*100)/100;
                        $label = "gb/s";
                } elsif ($fast >= 2000000) {
                        ($fast, $label) = (int($fast/1000000*100)/100, "mb/s");
                        ($fast, $label) = ("1", "gb/s") if $fast eq "1000";
                } elsif ($fast >= 2000) {
                        ($fast, $label) = (int($fast/1000*100)/100, "kb/s");
                }
                $int->{$idx}->{'fast'} = "$fast $label";
        } else {
                $int->{$idx}->{'fast'} = "?? mb/s";
        }

        # attempt to set elapsed time since list poll of this interface
        my $etime = undef;
        $etime = $int->{$idx}->{'time'} - $po->{'int'}->{$idx}->{'time'}
            if $po->{'int'}->{$idx} and $po->{'int'}->{$idx}->{'time'};

        # skip rate and rrd processing if old poll data does not exist
        if (ref $po->{'int'}->{$idx} ne "HASH") {
            &dtl("snmp_int index $idx old poll data key does not exists");

        # skip rate and rrd processing if etime is undefined or negative
        } elsif (not defined $etime or $etime < 0) {
            &dbg("snmp_int index $idx invalid elapsed time since old poll");

        # skip rate and rrd processing if too much elapsed time since old data
        } elsif ($etime > $cfg->{'poll-time-max'}) {
            &dtl("snmp_int index $idx etime $etime greater than poll-time-max");

        # add new data based on old data if old poll persist data is present
        } else {
            &dtl("snmp_int index $idx persist_old key does exists");

            # set elapsed time between old and new polls
            $int->{$idx}->{'etime'} = $etime;

            # calculate input bit rate since last poll
            $int->{$idx}->{'bpsi'} = &snmp_int_rate($po->{'int'}->{$idx},
                $int->{$idx}, 'biti', $int->{$idx}->{'etime'});

            # calculate percentage of inbound bandwidth utilization
            $int->{$idx}->{'pcti'}
                = int(($int->{$idx}->{'bpsi'} / $int->{$idx}->{'speed'}) * 100)
                if defined $int->{$idx}->{'bpsi'} and $int->{$idx}->{'speed'} 
                and $int->{$idx}->{'speed'} =~ /^\d+$/;

            # calculate output bit rate since last poll
            $int->{$idx}->{'bpso'} = &snmp_int_rate($po->{'int'}->{$idx},
                $int->{$idx}, 'bito', $int->{$idx}->{'etime'});

            # calculate percentage of outbound bandwidth utilization
            $int->{$idx}->{'pcto'}
                = int(($int->{$idx}->{'bpso'} / $int->{$idx}->{'speed'}) * 100)
                if defined $int->{$idx}->{'bpso'} and $int->{$idx}->{'speed'}
                and $int->{$idx}->{'speed'} =~ /^\d+$/;

            # calculate input packets per second since last poll
            $int->{$idx}->{'ppsi'} = &snmp_int_rate($po->{'int'}->{$idx},
                $int->{$idx}, 'pkti', $int->{$idx}->{'etime'});

            # calculate output packets per second since last poll
            $int->{$idx}->{'ppso'} = &snmp_int_rate($po->{'int'}->{$idx},
                $int->{$idx}, 'pkto', $int->{$idx}->{'etime'});

            # calculate input multicast packets per second since last poll
            $int->{$idx}->{'npsi'} = &snmp_int_rate($po->{'int'}->{$idx},
                $int->{$idx}, 'nupi', $int->{$idx}->{'etime'});

            # calculate output multicast packets per second since last poll
            $int->{$idx}->{'npso'} = &snmp_int_rate($po->{'int'}->{$idx},
                $int->{$idx}, 'nupo', $int->{$idx}->{'etime'});

            # calculate input error packets per second since last poll
            $int->{$idx}->{'epmi'} = &snmp_int_rate($po->{'int'}->{$idx},
                $int->{$idx}, 'erri', ($int->{$idx}->{'etime'} / 60));

            # explicity set bounce if last state change for both polls present
            if (defined $int->{$idx}->{'last'}
                and defined $po->{'int'}->{$idx}->{'last'}) {
                if ($int->{$idx}->{'last'}
                    eq $po->{'int'}->{$idx}->{'last'}) {
                    $int->{$idx}->{'bounce'} = 0;
                } else {
                    $int->{$idx}->{'bounce'} = 1;
                }
            }

        # finished adding new data based on old poll persist data
        }

        # debug message that we finished this interface
        &dtl("snmp_int loop finished interface index $idx");

    # continue looping through indexed interfaces in snmp interface mib
    }

    # finished snmp_int function
    &dtl("snmp_int function finished");
    return ($int, $int_table);
}



sub snmp_int_mtype {

# internal: $mtype = &snmp_int_mtype(\$cfg, \%pn_int)
# purpose: determine interface monitor type
# $mtype: assign monitor type based on interface type and descr
# \%cfg: current configuration settings in effect
# \%pn_int: reference hash of poll data for current interface
# note: mtype = up,down,lan,wan,virtual,signal,skip,dial,voice,other,unknown
# note: refer to rfc1700, network management parameters
# note: also refer to http://www.iana.org/assignments/ianaiftype-mib

    # begin, read inputs and intialize mtype
    my $cfg = shift or croak "snmp_int_mtype cfg arg missing";
    my $pn_int = shift or croak "snmp_int_mtype pn_int arg missing";
    my $mtype = "unknown";
    my $type = $pn_int->{'type'};
    my $descr = $pn_int->{'descr'};

    # iana type other, sdlc, loopback and slip, skip cisco system ints
    if ($type =~ /^(1|17|24|28)$/) {
        $mtype = "other";
        $mtype = "skip" if $descr =~ /^nul/i;

    # iana type radio spread spectrum, wlan on freebsd
    } elsif ($type eq "71") {
        $mtype = "other";

    # eth, token, old faste/faste-fx/gige, vlans, freebsd wlans
    } elsif ($type =~ /^(6|9|62|96|117)$/) {
        $mtype = "lan";

        # set vlan ints to mtype up
        if ($descr =~ /vlan/i) {
            $mtype = "up";

        # set freebsd wlan ints to type other
        } elsif ($descr =~ /wlan/i) {
            $mtype = "other";

        # skip ints without ipv4 address skip configured or no alias description
        } elsif (not $pn_int->{'ipv4'} and 
            ($Mnet::Poll::cfg->{'poll-skip-alias'} or not $pn_int->{'alias'})) {
            $mtype = "skip";
        }
        
    # ptp, ppp, frame dte, atm aal5, packet over sonet
    } elsif ($type =~ /^(22|23|32|49|171)$/) {
        $mtype = "wan";

    # ds1, ds3, atm, sonet, ds0, atm subint
    } elsif ($type =~ /^(18|30|37|39|81|134)$/) {
        $mtype = "up";

    # propriatary virtual, ppp multilink, tunnel, l2vlan, mpls tunnel, mpls
    } elsif ($type =~ /^(53|108|131|135|150|166)$/) {
        $mtype = "virtual";
        $mtype = "up" if not defined $pn_int->{'biti'};

    # idsn/x25 and isdn-u
    } elsif ($type eq "63" or $type eq "77") {
        $mtype = "signal";

    # voice em, fx0 or fxs, voice encap, voip encap
    } elsif ($type =~ /^(100|101|102|103|104)$/) {
        $mtype = "voice";
        $mtype = "hide" if $type =~ /^(103|104)$/;

    # usb interfaces get skipped
    } elsif ($type eq "160") {
        $mtype = "skip";

    # finished checking interface types
    }

    # output detail debug message
    &dtl("snmp_int_mtype for descr=$descr, type=$type set mtype=$mtype");

    # finished snmp_int_mtype
    return $mtype;
}



sub snmp_int_rate {

# internal: $rate = &snmp_int_rate(\%new, \%old, $key, $etime)
# purpose: calculate rate for givin key, using elapsed time between polls
# \%old: old poll data for a specific interface
# \%new: new poll data for a specific interface
# $key: spcific key interface attribute to calculate rate for
# $etime: elapsed units of time between old and new poll samples

    # begin, read input args
    my ($old, $new, $key, $etime) = @_;

    # read numeric key value from old and new data, return otherwise
    my $oval = $old->{$key} if defined $old->{$key}
        and $old->{$key} =~ /^\d+$/;
    my $nval = $new->{$key} if defined $new->{$key}
        and $new->{$key} =~ /^\d+$/;

    my $dbg = $key;
    $dbg .= ", oval=$oval" if defined $oval;
    $dbg .= ", nval=$nval" if defined $nval;
    $dbg .= ", etime=$etime" if defined $etime;
    &dtl("snmp_int_rate starting for key $dbg");

    # return if any of the necessary values are not defined
    return undef if not $etime or not defined $oval or not defined $nval;

    # calculate rate over elapsed time between new and old key data
    my $rate = ($nval - $oval) / $etime;
    $rate = 1 if $rate > 0 and $rate < 1;
    $rate = int($rate + .5);

    # finished snmp_int_rate function
    return $rate;
}



sub snmp_ipv4 {

# internal: \%ipv4 = &snmp_ipv4(\%cfg, \%pn)
# purpose: retrieve ipv4 data from current device using snmp
# \%cfg: current configuration settings in effect
# \%pn: new persist data, used to store addresses with int data if present
# \%ipv4: output hash reference of collected snmp data

    # begin, initialize output interface data and snmp ok flag
    my $cfg = shift or croak "snmp_ipv4 cfg arg missing";
    my $pn = shift or croak "snmp_ipv4 persist_new arg missing";
    &dtl("snmp_ipv4 function starting");
    $Mnet::Poll::success = 0;
    my $ipv4 = {};

    # ip oid to walk
    my $ipv4_oid = ".1.3.6.1.2.1.4.20.1";

    # walk ip table
    my $ipv4_table = {};
    &snmp_bulkwalk($ipv4_oid, $ipv4_table, $cfg);

    # loop through snmp ip address data, set snmp ok, processing each address
    foreach my $oid (keys %$ipv4_table) {
        next if $oid !~ /^\S+\.1\.(\d+\.\d+\.\d+\.\d+)$/;
        my $address = $1;
        my ($index, $mask, $cidr) = (undef, undef, undef);
        $Mnet::Poll::success = 1;

        # skip default network address
        next if $address eq '0.0.0.0';
    
        # retrieve network mask for current address
        if (defined $ipv4_table->{"$ipv4_oid.2.$address"}
            and defined $ipv4_table->{"$ipv4_oid.3.$address"}) {

            # retrieve index and mask for current address
            $index = $ipv4_table->{"$ipv4_oid.2.$address"};
            $mask = $ipv4_table->{"$ipv4_oid.3.$address"};

            # convert mask to cidr
            $cidr = &ipv4_mask2cidr($mask)
                if $mask and $mask =~ /^\d+\.\d+\.\d+\.\d+$/;
    
            # store address and cidr in ipv4 data
            $ipv4->{"$address/$cidr"} = undef;

            # continue to next address if interface data not prepsent
            next if not exists $pn->{'int'};

            # find associated int, store int with address and address with int
            foreach my $int (keys %{$pn->{'int'}}) {
                if (exists $pn->{'int'}->{$int}->{'index'}
                    and $pn->{'int'}->{$int}->{'index'} eq $index) {
                    $ipv4->{"$address/$cidr"} = $int;
                    $pn->{'int'}->{$int}->{'ipv4'} .= " $address/$cidr";
                    $pn->{'int'}->{$int}->{'ipv4'} =~ s/^\s+//;
                    last;
                }
            }

        # finished retrieving and storing address
        }
        
    # continue looping through snmp ip data looking for other addresses
    }

    # finished poll_data_ip
    &dtl("snmp_ipv4 function finished");
    return $ipv4;
}



sub snmp_sys {

# internal: \%sys = &snmp_sys(\%cfg)
# purpose: retrieve system data from current device using snmp
# \%cfg: current configuration settings in effect
# \%sys: output hash reference of collected snmp data

    # begin, initialize output system data and success flag
    my $cfg = shift or croak "snmp_sys cfg arg missing";
    &dbg("snmp_sys function starting");
    $Mnet::Poll::success = 0;
    my $sys = {};

    # list of system oid values to retrieve
    my $sys_oids = {
        ".1.3.6.1.2.1.1.1.0" => 'descr',
        ".1.3.6.1.2.1.1.3.0" => 'uptime',
        ".1.3.6.1.2.1.1.4.0" => 'contact',
        ".1.3.6.1.2.1.1.5.0" => 'name',
        ".1.3.6.1.2.1.1.6.0" => 'location',
    };

    # push system oid values to array for bulkget
    my @bulkget_oids = ();
    foreach my $key (keys %$sys_oids) {
        push @bulkget_oids, $key;
    }

    # retrieve system values using snmp bulkget
    my $snmp_table = {};
    &snmp_bulkget(\@bulkget_oids, $snmp_table, $cfg);

    # move retrieved values to labeled output hash, set success with data output
    foreach my $key (keys %$snmp_table) {
        next if not $sys_oids->{$key};
        $sys->{$sys_oids->{$key}} = $snmp_table->{$key}; 
        $Mnet::Poll::success = 1;
    }

    # finished snmp_sys function
    &dbg("snmp_sys function finished");
    return $sys;
}



# module end task, output an alert if script did not exit normally
END {
    &Mnet::alert(0, "poll module script exited with errors or warnings")
        if $Mnet::error and $Mnet::Poll::cfg->{'poll-alerts'};
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, Mnet::Model, Mnet::Ping, Mnet::SNMP, Mnet::Poll::Cisco,

=cut



# normal package return
1;

