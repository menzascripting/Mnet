# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_Poll_Cisco.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; };
&plan(skip_all => "perl File::Temp module not installed") if $@;

# requires mnet poll module
eval { require Mnet::Poll; };
&plan(skip_all => "perl Mnet::Poll module not installed") if $@;

# requires mnet poll cisco module
eval { require Mnet::Poll::Cisco; };
&plan(skip_all => "perl Mnet::Poll::Cisco module not installed") if $@;

# requires mnet silent module
eval { require Mnet::Silent; };
&plan(skip_all => "perl Mnet::Silent module not installed") if $@;

# Insert your test code below, refer to Test::More man page

# detect cisco device
ok(&poll_test( {}, { ".1.3.6.1.2.1.1.1.0" => 'cisco' })
    =~ /^dbg 7 \S+ \S*cisco poll_mod processing current object/mi,
    'cisco poll_mod detected cisco device');

# skip non-cisco device
ok(&poll_test( {}, { ".1.3.6.1.2.1.1.1.0" => 'device' })
    !~ /^dbg 7 \S+ \S*cisco poll_mod processing current object/mi,
    'cisco poll_mod skipped non-cisco device');

# define all interfaces to test, including mtypes output to look for
my @interfaces = (
    "0/0 utp ethernet (cat 0/0)", 6,
        "skip lan skip lan skip lan skip lan........",
    "0/0/0 utp ethernet", 6, "skip lan skip lan skip lan skip lan........",
    "aggregated interface", 53, "up... virtual... up... virtual...",
    "atm0/0/0-aal0 layer", 49, "wan...............",
    "atm0/0/0-atm layer", 37, "up...............",
    "atm0/0/0.0-aal0 layer", 49, "wan...............",
    "atm0/0/0.0-atm subif", 134, "up...............",
    "atm0/0/0", 30, "up...............",
    "casa0", 24, "other...............",
    "e0 0/0", 18, "up...............",
    "eobc0/0", 53, "up... virtual... up... virtual...",
    "eobc0/0", 6, "skip lan skip lan skip lan skip lan........",
    "ethernet0/0", 6, "skip lan skip lan skip lan skip lan........",
    "ethernet0", 6, "skip lan skip lan skip lan skip lan........",
    "fastethernet0/0.0-0.0q vlan subif", 135,
        "up... virtual... up... virtual...",
    "fastethernet0/0.0", 135, "virtual. up. virtual..... up. virtual...",
    "fastethernet0/0", 6, "skip lan skip lan skip lan skip lan........",
    "fastethernet0/0", 62, "skip lan skip lan skip lan skip lan........",
    "foreign exchange office 0/0/0", 101, "voice...............",
    "foreign exchange station 0/0/0", 102, "voice...............",
    "fxo null 0/0/0:0", 101, "voice...............",
    "fxo null 0/0:0", 101, "voice...............",
    "gigabit ethernet without gbic installed", 6,
        "skip lan skip lan skip lan skip lan........",
    "gigabitethernet0/0.0", 135, "virtual. up. virtual..... up. virtual...",
    "gigabitethernet0/0-mpls layer", 166, "up... virtual... up... virtual...",
    "gigabitethernet0/0", 117, "skip lan skip lan skip lan skip lan........",
    "gigabitethernet0/0", 6, "skip lan skip lan skip lan skip lan........",
    "inband", 53, "up... virtual... up... virtual...",
    "loopback0", 24, "other...............",
    "macedon_ctlvlan0", 53, "up...............",
    "multi mode fiber fast ethernet", 6,
        "skip lan skip lan skip lan skip lan........",
    "multilink0", 108, "virtual...............",
    "multilink0", 23, "virtual...............",
    "netflow_vlan0", 6, "up...............",
    "null0", 1, "skip...............",
    "port-channel0", 53, "up... virtual... up... virtual...",
    "pos0/0/0--sonet/sdh medium/section/line", 39, "up...............",
    "pos0/0/0-mpls layer", 166, "up... virtual... up... virtual...",
    "pos0/0/0.0", 32, "virtual. wan. virtual. wan. virtual. wan. virtual. wan.",
    "pos0/0/0", 171, "wan...............",
    "pos0/0/0", 32, "wan...............",
    "sc0", 53, "up...............",
    "serial0.0", 32, "virtual. wan. virtual. wan. virtual. wan. virtual. wan.",
    "serial0/0.0", 32,
        "virtual. wan. virtual. wan. virtual. wan. virtual. wan.",
    "serial0/0:0-bearer channel", 81, "dial...............",
    "serial0/0:0-signaling", 63, "signal...............",
    "serial0/0:0.0", 32,
        "virtual. wan. virtual. wan. virtual. wan. virtual. wan.",
    "serial0/0:0", 22, "wan...............",
    "serial0/0:0", 23, "wan...............",
    "serial0/0:0", 32, "wan...............",
    "serial0/0:0", 77, "signal...............",
    "serial0/0", 1, "other...............",
    "serial0/0", 17, "other...............",
    "serial0/0", 22, "wan...............",
    "serial0/0", 23, "wan...............",
    "serial0/0", 32, "wan...............",
    "short wave fiber gigabit ethernet", 6,
        "skip lan skip lan skip lan skip lan........",
    "t0 0/0", 18, "up...............",
    "t0 0/0", 30, "up...............",
    "t0 interface", 18, "up...............",
    "tengigabitethernet0/0-mpls layer", 166,
        "up... virtual... up... virtual...",
    "tengigabitethernet0/0", 6, "skip lan skip lan skip lan skip lan........",
    "tokenring0/0", 9, "skip lan skip lan skip lan skip lan........",
    "tunnel0-mpls layer", 166, "up... virtual... up... virtual...",
    "tunnel0", 131, "up... virtual... up... virtual...",
    "tunnel0", 150, "up... virtual... up... virtual...",
    "unrouted vlan 0", 53, "up...............",
    "v0", 135, "up... virtual... up... virtual...",
    "vlan 0", 53, "up...............",
    "vlan router", 6, "up...............",
    "vlan0", 53, "up...............",
    "vlan0", 6, "up...............",
    "voice transcoding interface", 18, "up...............",
    "voice-port 0/0", 102, "voice...............",
);

# check all interface types defined above
while (1) {
    my $descr = shift @interfaces;
    my $type = shift @interfaces;
    my $mtypes = shift @interfaces;
    last if not defined $mtypes;
    ok(&mtype_cisco($descr, $type) eq $mtypes, "$descr, type $type");
}

# check that parent lan int for lan subint is set to mtype lan
my $pn = {
    'int' => {
        'FastEthernet0/0' => { 'mtype' => 'skip', }
    }
};
&mtype_cisco("FastEthernet0/0.0", 135, undef, 0, undef, "10.9.8.7", $pn);
ok($pn->{'int'}->{'FastEthernet0/0'}->{'mtype'} eq 'lan',
    'lan subint parent set to mtype lan');

# check that bearer int associated with serial int is set to mtype skip
$pn = {
    'int' => {
        'Serial0/0:0-Bearer Channel' => { 'mtype' => 'dial', }
    }
};
&mtype_cisco("Serial0/0:0", 22, undef, undef, undef, undef, $pn);
ok($pn->{'int'}->{'Serial0/0:0-Bearer Channel'}->{'mtype'} eq 'skip',
    'serial bearer int set to mtype skip');

# detect running config change
ok(&poll_test(
    { ".1.3.6.1.4.1.9.9.43.1.1.1.0" => 9 },
    { ".1.3.6.1.4.1.9.9.43.1.1.1.0" => 1 })
    =~ /^log \d \S+ detected change to cisco running config/mi,
    'detected change to running config');

# detect startup newer than running config
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.9.43.1.1.2.0" => 1, ".1.3.6.1.4.1.9.9.43.1.1.3.0" => 9 })
    =~ /^alr \d \S+ detected cisco startup config newer than running config/mi,
    'detected startup config newer than running config');

# detect unsaved running config
ok(&poll_test(
    { ".1.3.6.1.4.1.9.9.43.1.1.1.0" => 9 },
    { ".1.3.6.1.4.1.9.9.43.1.1.2.0" => 1 })
    =~ /^alr \d \S+ detected unsaved change to cisco running config/mi,
    'detected unsaved change to running config');

# detect old cpu no alerts
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.2.1.58.0" => 50 })
    !~ /^alr \d+ \S+ cisco cpu utilization/mi,
    'detected old cpu no alerts');

# detect old cpu over alert 4 threshold
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.2.1.58.0" => 95 })
    =~ /^alr 4 \S+ cisco cpu utilization 95\%/mi,
    'detected old cpu alert 4');

# detect new cpu over alert 5 threshold
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.9.109.1.1.1.1.8.9" => 85 })
    =~ /^alr 5 \S+ cisco cpu utilization 85\%/mi,
    'detected old cpu alert 5');

# detect new cpu over alert 6 threshold
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.9.109.1.1.1.1.8.9" => 75 })
    =~ /^alr 6 \S+ cisco cpu utilization 75\%/mi,
    'detected old cpu alert 6');

# detect env-power not normal
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.9.13.1.5.1.3.1" => 2 })
    =~ /^alr \d .+ cisco env-power not normal/mi,
    'detected env-power not normal');

# detect env-fans not normal
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.9.13.1.4.1.3.1" => 2 })
    =~ /^alr \d .+ cisco env-fans not normal/mi,
    'detected env-fans not normal');

# detect env-temp not normal
ok(&poll_test( {},
    { ".1.3.6.1.4.1.9.9.13.1.3.1.6.1" => 2 })
    =~ /^alr \d .+ cisco env-temp not normal/mi,
    'detected env-temp not normal');

# finished
&done_testing;
exit;



sub mtype_cisco {

    # $mtype = &mtype_cisco($descr,$type,$alias,$biti,$erri,$ipv4,$pn);
    # purpose: test poll mtypes

    # prepare for call, read descr and type used all the time
    my $cfg = {};
    $cfg->{'poll-skip-alias'} = undef;
    my $pn_int = {};
    $pn_int->{'descr'} = shift;
    $pn_int->{'type'} = shift;

    # read optional settings for call where pn is defined
    $pn_int->{'alias'} = shift;
    $pn_int->{'biti'} = shift;
    $pn_int->{'erri'} = shift;
    $pn_int->{'ipv4'} = shift;
    my $pn = shift;

    # have poll module calculate mtype if pn was defined
    if (defined $pn) {
        $pn_int->{'mtype'} = &Mnet::Poll::snmp_int_mtype($cfg, $pn_int);
        my $mtype = &Mnet::Poll::Cisco::snmp_int_mtype($cfg, $pn_int, $pn);
        return $mtype;
    }

    # initialize output for mtype(s)
    my $output = undef;

    # loop through alias, biti, erri and ipv4 inputs
    foreach my $alias ("", "alias") {
        $pn_int->{'alias'} = $alias;
        foreach my $biti (undef, 0) {
            $pn_int->{'biti'} = $biti;
            foreach my $erri (undef, 0) {
                $pn_int->{'erri'} = $erri;
                foreach my $ipv4 ("", "10.9.8.7") {
                    $pn_int->{'ipv4'} = $ipv4;

                    # set mtype for cisco device
                    $pn_int->{'mtype'}
                        = &Mnet::Poll::snmp_int_mtype($cfg, $pn_int);
                    my $pn_temp = {};
                    my $mtype = &Mnet::Poll::Cisco::snmp_int_mtype(
                        $cfg, $pn_int, $pn_temp);

                    # append mtype to output, or "." for duplicates
                    if (not defined $output) {
                        $output = $mtype;
                    } elsif ($output =~ /(^|\s)\Q$mtype\E\.*$/) {
                        $output .= ".";
                    } else {
                        $output .= " $mtype";
                    }

                # finish looping through ipv4, erri, biti and alias inputs
                }
            }
        }
    }

    # return output mtype(s)
    return $output;
}
    


sub output {
    # purpose: command output with optional debug
    my $command = shift or die;
    my $output = `( $command ) 2>&1`;
    print "\n\n$command\n\n$output\n\n"
        if "@ARGV" =~ /(^|\s)(-d|--?debug)(\s|$)/;
    return $output;
}



sub poll_test {
    # purpose: test poll using snmp-replay

    # read hash ref of oids to change both before and after, and after only
    my ($both, $second) = @_;
    $both = {} if not defined $both;
    $second = {} if not defined $second;

    # read base snmp data file
    my $snmp1_text = "";
    if (open(my $fh, "t/data/Mnet_Poll_Cisco.snmp")) {
        $snmp1_text .= "$_" while (<$fh>);
        close $fh;
    } else {
        die "unable to open t/data/Mnet_Poll_Cisco.snmp file, $!";
    }

    # apply snmp keys/value pairs specified for both first and second samples
    foreach my $key (sort keys %$both) {
        $snmp1_text =~ s/^(SNMP: \Q$key\E) = .*/$1 = $both->{$key}/m
            or $snmp1_text .= "SNMP: $key = $both->{$key}\n";
    }

    # create first snmp1 file, get filename
    my $snmp1_fh = File::Temp->new() or die "unable to open snmp1 tempfile $!";
    print $snmp1_fh $snmp1_text;
    close $snmp1_fh;
    my $snmp1_file = $snmp1_fh->filename;

    # copy snmp1 to snmp2
    my $snmp2_text = $snmp1_text;

    # apply snmp keys/value pairs specified for second sample only
    foreach my $key (sort keys %$second) {
        $snmp2_text =~ s/^(SNMP: \Q$key\E) = .*/$1 = $second->{$key}/m
            or $snmp2_text .= "SNMP: $key = $second->{$key}\n";
    }

    # create second snmp2 file, get filename
    my $snmp2_fh = File::Temp->new() or die "unable to open snmp2 tempfile $!";
    print $snmp2_fh $snmp2_text;
    close $snmp2_fh;
    my $snmp2_file = $snmp2_fh->filename;

    # create temp db file, get filename
    my $db_fh = File::Temp->new() or die "unable to open db tempfile $!";
    close $db_fh;
    my $db_file = $db_fh->filename;

    # define test poll script
    my $poll_test_perl = '
        perl -e \'
            use warnings;
            use strict;
            use Mnet;
            use Mnet::Poll;
            my $cfg = &object;
            my $data = &poll_data;
        \' - --object-name router1 --object-address 127.0.0.1 \\
             --poll-alerts --poll-detail \\
             --log-level 7 --conf-noinput --log-diff \\
             --ping-replay \\
    ';
    $poll_test_perl .= "--db-name $db_file ";

    # get command output for first and second snmp samples, if clean exit
    my $output = &output("$poll_test_perl --snmp-replay $snmp1_file 2>&1");
    if ($output =~ /^inf 6 \S+ mnet script perl-e clean exit/mi) {
        $output = &output("$poll_test_perl --snmp-replay $snmp2_file 2>&1");
    }

    # remove temp db file
    unlink $db_file or die "unable to delete temp db file $db_file, $!";

    # return null on error
    return "" if $output !~ /^inf 6 \S+ mnet script perl-e clean exit/mi;

    # finished poll_test
    return $output;
}

