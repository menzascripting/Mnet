# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_Poll.t'

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

# requires mnet silent module
eval { require Mnet::Silent; };
&plan(skip_all => "perl Mnet::Silent module not installed") if $@;

# Insert your test code below, refer to Test::More man page

# initialize command arguments and command output
my ($cmd_arg, $cmd_out) = ("", "");

# define test poll script
my $perl_test_poll = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        BEGIN {
            $INC{"Mnet_Client/Poll/Custom1.pm"} = __FILE__;
            package Mnet_Client::Poll::Custom1;
                use Mnet;
                sub poll_mod {
                    my $cfg = shift or die "poll_mod cfg arg missing";
                    my $pn = shift or die "poll_mod pn arg missing";
                    my $po = shift;
                    $po = {} if ref $po ne "HASH";
                    $pn->{"custom1_value"} = $po->{"custom1_value"};
                    $pn->{"custom1_value"} = 0 if not $pn->{"custom1_value"};
                    $pn->{"custom1_value"}++;
                    &dbg("poll_mod custom1_value = " . $pn->{"custom1_value"});
                    &dbg("poll_mod custom1 function finished");
                }
            1;
        }
        package main;
        use Mnet::Poll;
        my $cfg = &object;
        my $data = &poll_data;
        &alert(3, "main test alert");
    \' - --object-name localhost --log-level 7 \\
         --poll-detail --poll-mod-dir t/data/Mnet_Poll.mods/Mnet_Client/Poll \\
         --custom2-arg 2 --poll-alerts \\
';

# check output from poll test, one ping to loopback, check modules
$cmd_arg = "--object-address 127.0.0.1 --poll-snmp 0 ";
$cmd_out = &output("$perl_test_poll $cmd_arg 2>&1");
ok($cmd_out =~ /mnet script perl-e starting/m,
    'poll1 output present');
ok($cmd_out =~ /confirmed Mnet\/Poll\/Cisco\.pm is loaded/m,
    'poll1 cisco module is loaded');
ok($cmd_out =~ /confirmed Mnet_Client\/Poll\/Custom1\.pm is loaded/m,
    'poll1 custom1 module is loaded');
ok($cmd_out =~ /confirmed Mnet_Client\/Poll\/Custom2\.pm is loaded/m,
    'poll1 custom2 module is loaded');
ok($cmd_out =~ /ping attempt to 127\.0\.0\.1 replied/m,
    'poll1 test ping to 127.0.0.1 replied');
ok($cmd_out =~ /data_poll ping was successful/m,
    'poll1 data_poll ping was successful');
ok($cmd_out =~ /poll-snmp set false, skipping snmp polling/m,
    'poll1 snmp poll skipped');
ok($cmd_out =~ /returned from mnet\/poll\/cisco/m,
    'poll1 returned from cisco poll module');
ok($cmd_out =~ /poll_mod custom1 function finished/m,
    'poll1 custom1 module executed');
ok($cmd_out =~ /poll_mod custom2 function finished/m,
    'poll1 custom2 module executed');
ok($cmd_out =~ /poll_mod custom2 custom2-default = 1\s*$/m,
    'poll1 custom2 default config correct');
ok($cmd_out =~ /poll_mod custom2 custom2-arg = 2\s*$/m,
    'poll1 custom2 arg config correct');
ok($cmd_out =~ /^ALR .+ main test alert/m,
    'poll1 main test alert present');
ok($cmd_out =~ /poll dump poll:\s+'success' => 1/m,
    'poll1 poll dump poll success');
ok($cmd_out =~ /poll dump poll:\s+'ping' => 1/m,
    'poll1 poll dump ping success');
ok($cmd_out !~ /poll dump poll:\s+'snmp' =>/m,
    'poll1 poll dump snmp suppressed');
ok($cmd_out !~ /^ALR 2 \S+ object poll failed/m,
    'poll1 did not alert poll failed');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'poll1 script clean exit');

# check output from poll test, one ping to invalid loopback, check failure
$cmd_arg = "--object-address 127.0.0.2 --poll-snmp 0 ";
$cmd_arg .= "--ping-retries 0 --ping-timeout 1 ";
$cmd_out = &output("$perl_test_poll $cmd_arg 2>&1");
ok($cmd_out =~ /poll dump poll:\s+'success' => 0/m,
    'poll2 poll dump poll success');
ok($cmd_out =~ /poll dump poll:\s+'ping' => 0/m,
    'poll2 poll dump ping success');
ok($cmd_out =~ /^ALR 2 \S+ object poll failed/m,
    'poll2 alerted object poll failed');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'poll2 script clean exit');

# check output from poll test, one ping to invalid loopback, check failure
$cmd_arg = "--object-address 127.0.0.1 --poll-snmp 0 --poll-sample 2 ";
$cmd_out = &output("$perl_test_poll $cmd_arg 2>&1");
ok($cmd_out =~ /poll dump poll-1:\s+'ping' => 1/m,
    'poll3 poll-1 dump ping success');
ok($cmd_out =~ /poll dump poll-2:\s+'ping' => 1/m,
    'poll3 poll-2 dump ping success');
ok($cmd_out =~ /custom1 poll_mod custom1_value = 1/m,
    'poll3 poll-1 new data custom value setup');
ok($cmd_out =~ /custom1 poll_mod custom1_value = 2/m,
    'poll3 poll-1 old data custom value found');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'poll3 script clean exit');

# prepare to check mtype set from interface information
my @mtypes = (
      1,  "test",  "other",
     17, "test",  "other",
     24, "test",  "other",
     28, "test",  "other",
      1,  "null", "skip",
     17, "null", "skip",
     24, "null", "skip",
     28, "null", "skip",
     71, "test", "other",
      6, "int0", "skip",    # also checks vlan, wlan, alias and ipv4
      9, "int0", "skip",    # also checks vlan, wlan, alias and ipv4
     62, "int0", "skip",    # also checks vlan, wlan, alias and ipv4
     96, "int0", "skip",    # also checks vlan, wlan, alias and ipv4
    117, "int0", "skip",    # also checks vlan, wlan, alias and ipv4
     22, "test", "wan",
     23, "test", "wan",
     32, "test", "wan",
     49, "test", "wan",
    171, "test", "wan",
     18, "test", "up",
     30, "test", "up",
     37, "test", "up",
     39, "test", "up",
     81, "test", "up",
    134, "test", "up",
     53, "tun0", "up",
    108, "tun0", "up",
    131, "tun0", "up",
    135, "tun0", "up",
    150, "tun0", "up",
    166, "tun0", "up",
     63, "test", "signal",
     77, "test", "signal",
    100, "test", "voice",
    101, "test", "voice",
    102, "test", "voice",
    103, "test", "hide",
    104, "test", "hide",
    160, "test", "skip",
);

# check all interface types defined above
while (1) {
    my $type = shift @mtypes;
    my $descr = shift @mtypes;
    my $mtype = shift @mtypes;
    last if not defined $mtype;
    ok(&mtype_test($descr, $type) eq $mtype, "$descr, type $type = $mtype");
    if ($descr eq "int0") {
        ok(&mtype_test('vlan0', $type) eq 'up',
            "$descr, type $type = up");
        ok(&mtype_test('wlan0', $type) eq 'other',
            "$descr, type $type = other");
        ok(&mtype_test('lan0', $type, "alias") eq 'lan',
            "$descr, type $type = lan");
        ok(&mtype_test('lan0', $type, undef, undef, undef, "10.9.8.7") eq 'lan',
            "$descr, type $type = lan");
    } elsif ($descr eq "tun0") {
        ok(&mtype_test('lan0', $type, undef, 0) eq 'virtual',
            "$descr, type $type = virtual");
    }
}

# fail snmp poll only, succeeded otherwise
ok(&alert_test =~ /^alr \d \S+ object snmp failed/mi,
    'poll-snmp failed correctly');

# detect new and old poll data interfaces
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1}}',
    '"int"=>{"test2"=>{"descr"=>"test2","index"=>2}}')
    =~ /old poll data has int test2 at index test2/mi,
    'old poll data interface detected');
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1}}',
    '"int"=>{"test2"=>{"descr"=>"test2","index"=>2}}')
    =~ /new poll data has int test1 at index test1/mi,
    'new poll data interface detected');

# detect interface adds and removes
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1}}',
    '"int"=>{"test2"=>{"descr"=>"test2","index"=>2}}')
    =~ /detected interface test1 added since last poll/mi,
    'interface add detected');
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1}}',
    '"int"=>{"test2"=>{"descr"=>"test2","index"=>2}}')
    =~ /detected interface test2 removed since last poll/mi,
    'interface remove detected');

# check for mtype skip
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "mtype"=>"skip"}}')
    =~ /alerts_int test1 mtype set skip/mi,
    'mtype skip detected');

# check for admin not up
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"down"}}')
    =~ /alerts_int test1 admin status not up at this time/mi,
    'admin down detected');

# check for non-normal status
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up"}}')
    =~ /^alr \d \S+ interface test1\s+status not normal/mi,
    'status alert');

# check for bounce
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "bounce"=>"1"}}')
    =~ /^log .+ interface test1 online status changed since last poll/mi,
    'bounce alert');


# check wan untilization
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "online"=>"1",
    "mtype"=>"wan","pcti"=>"95","pcto"=>"85"}}')
    =~ /alr 5 \S+ interface test1 wan bandwidth utilization over/mi,
    'wan bw alert sev 5');
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "online"=>"1",
    "mtype"=>"wan","pcti"=>"5","pcto"=>"85"}}')
    =~ /alr 6 \S+ interface test1 wan bandwidth utilization over/mi,
    'wan bw alert sev 6');

# check lan untilization
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "online"=>"1",
    "mtype"=>"lan","pcti"=>"75","pcto"=>"50"}}')
    =~ /alr 5 \S+ interface test1 lan bandwidth utilization over/mi,
    'lan bw alert sev 5');
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "online"=>"1",
    "mtype"=>"lan","pcti"=>"5","pcto"=>"50"}}')
    =~ /alr 6 \S+ interface test1 lan bandwidth utilization over/mi,
    'lan bw alert sev 6');

# check error per minute alerts
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "online"=>"1",
    "mtype"=>"lan","epmi"=>"1"}}')
    =~ /alr 5 \S+ interface test1 seeing 1\+ errs\/min/mi,
    'int error alert sev 5');
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "online"=>"1",
    "mtype"=>"wan","epmi"=>"2"}}')
    =~ /alr 4 \S+ interface test1 seeing 2\+ errs\/min/mi,
    'int error alert sev 4');

# operating normally
ok(&alert_test('"int"=>{"test1"=>{"descr"=>"test1","index"=>1,
    "admin"=>"up", "status"=>"1", "online"=>"1", "mtype"=>"wan"}}')
    =~ /setting interface alert status to operating normally/mi,
    'int normal');

# check hide mtype, not that adescr is also checked, including for truncation
ok(&data_poll_int_test("hide", "up") eq 'h',
    'hide mtype deleted');

# check skip mtype
ok(&data_poll_int_test("skip", "up") eq '1 0',
    'skip up status=1 and online=0');
ok(&data_poll_int_test("skip", "down") eq '1 0',
    'skip down status=1 and online=0');
ok(&data_poll_int_test("skip", "down", "down") eq '1 0',
    "skip admin down status=1 and online=0");

# check down mtype
ok(&data_poll_int_test("down", "up") eq '0 1',
    'down up status=0 and online=0');
ok(&data_poll_int_test("down", "down") eq '1 0',
    'down down status=1 and online=0');

# check up mtype
ok(&data_poll_int_test("up", "up") eq '1 1',
    'up up status=1 and online=1');
ok(&data_poll_int_test("up", "down") eq '0 0',
    'up down status=0 and online=0');

# check dial mtype
ok(&data_poll_int_test("dial", "up") eq '0 1',
    'dial up status=0 and online=1');
ok(&data_poll_int_test("dial", "down") eq '1 0',
    'dial down status=1 and online=0');
ok(&data_poll_int_test("dial", "dormant") eq '1 0',
    'dial dormant status=1 and online=0');

# check admin down status of down, up and dial mtypes
foreach my $mtype (qw/down up dial/) {
    ok(&data_poll_int_test($mtype, "down", "down") eq '1 0',
        "$mtype admin down status=1 and online=0");
}

# check all other mtypes
foreach my $mtype (qw/lan other signal unknown virtual voice wan/) {
    ok(&data_poll_int_test($mtype, "up") eq '1 1',
        "$mtype up status=0 and online=1");
    ok(&data_poll_int_test($mtype, "dormant") eq '1 1',
        "$mtype dormant status=1 and online=0");
    ok(&data_poll_int_test($mtype, "down") eq '0 0',
        "$mtype down status=1 and online=0");
    ok(&data_poll_int_test($mtype, "down", "down") eq '1 0',
        "$mtype admin down status=1 and online=0");
}

# retrieve data from test poll
$cmd_out = &poll_test({}, {
    '.1.3.6.1.2.1.2.2.1.9.2'     => 1,          # Fa1/0 iftable last, bounce
    '.1.3.6.1.2.1.2.2.1.10.2'    => 10000000,   # Fa1/0 iftable biti
    '.1.3.6.1.2.1.2.2.1.11.2'    => 4000,       # Fa1/0 iftable ucpi
    '.1.3.6.1.2.1.2.2.1.12.2'    => 2000,       # Fa1/0 iftable nupi
    '.1.3.6.1.2.1.2.2.1.13.2'    => 1000,       # Fa1/0 iftable errors
    '.1.3.6.1.2.1.2.2.1.14.2'    => 1000,       # Fa1/0 iftable discards
    '.1.3.6.1.2.1.2.2.1.16.2'    => 20000000,   # Fa1/0 iftable bito
    '.1.3.6.1.2.1.2.2.1.17.2'    => 5000,       # Fa1/0 iftable ucpo
    '.1.3.6.1.2.1.2.2.1.18.2'    => 3000,       # Fa1/0 iftable nupo
    '.1.3.6.1.2.1.31.1.1.1.6.1'  => 10000000,   # Fa0/0 ifxtable biti
    '.1.3.6.1.2.1.31.1.1.1.7.1'  => 40000,      # Fa0/0 ifxtable upci
    '.1.3.6.1.2.1.31.1.1.1.8.1'  => 20000,      # Fa0/0 ifxtable nupi 1
    '.1.3.6.1.2.1.31.1.1.1.9.1'  => 2000,       # Fa0/0 ifxtable nupi 2
    '.1.3.6.1.2.1.31.1.1.1.10.1' => 20000000,   # Fa0/0 ifxtable bito
    '.1.3.6.1.2.1.31.1.1.1.11.1' => 50000,      # Fa0/0 ifxtable ucpo
    '.1.3.6.1.2.1.31.1.1.1.12.1' => 30000,      # Fa0/0 ifxtable nupo 1
    '.1.3.6.1.2.1.31.1.1.1.13.1' => 3000,       # Fa0/0 ifxtable nupo 2
    '.1.3.6.1.2.1.31.1.1.1.15.1' => 10000,      # Fa0/0 ifxtable speed, 10gb
});

# check poll and sys data from test poll
ok($cmd_out !~ /poll_mod processing current object/mi,
    'poll no modules used');
ok($cmd_out =~ /^log 5 \S+ \Qpoll->address = 127.0.0.1\E\s*$/mi,
    'poll->address ok');
ok($cmd_out =~ /^log 5 \S+ \Qpoll->success = 1\E\s*$/mi,
    'poll->success ok');
ok($cmd_out =~ /^log 5 \S+ \Qpoll->ping = 1\E\s*$/mi,
    'poll->ping ok');
ok($cmd_out =~ /^log 5 \S+ \Qpoll->snmp = 1\E\s*$/mi,
    'poll->snmp ok');
ok($cmd_out =~ /^log 5 \S+ \Qpoll->time = \E\d{9}\d+\s*$/mi,
    'poll->time ok');
ok($cmd_out =~ /^log 5 \S+ \Qsys->contact = 555-5555\E\s*$/mi,
    'sys->contact ok');
ok($cmd_out =~ /^log 5 \S+ \Qsys->descr = test system description\E\s*$/mi,
    'sys->descr ok');
ok($cmd_out =~ /^log 5 \S+ \Qsys->location = virtual\E\s*$/mi,
    'sys->location ok');
ok($cmd_out =~ /^log 5 \S+ \Qsys->name = router1\E\s*$/mi,
    'sys->name ok');
ok($cmd_out =~ /^log 5 \S+ \Qsys->uptime = \E\d\d\d\d+\s*$/mi,
    'sys->uptime ok');

# check ipv4 data from test poll
ok($cmd_out =~ /^log 5 \S+ ipv4->172\.26\.240\.98\/28 = FastEthernet0\/0\s*$/mi,
    'ipv4 first address ok');
ok($cmd_out =~ /^log 5 \S+ \Qipv4->10.1.1.1\/24 = FastEthernet0\/0\E\s*$/mi,
    'ipv4 second address ok');
ok($cmd_out =~ /^log 5 \S+ \Qipv4->10.2.2.2\/24 = FastEthernet1\/0\E\s*$/mi,
    'ipv4 third address ok');
my $ipv4_both = '10\.1\.1\.1\/24 172\.26\.240\.98\/28';
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->ipv4 = $ipv4_both\s*$/mi,
    'ipv4 first interface ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->ipv4 = 10\.2\.2\.2\/24\s*$/mi,
    'ipv4 second interface ok');

# check iftable interface data
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->adescr = FastE\D+1\/0\s*$/mi,
    'iftable int adescr ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->admin = 2\s*$/mi,
    'iftable int admin ok');
my $admin_alert1 = 'admin status not up at this time';
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->alerts = $admin_alert1\s*$/mi,
    'iftable int alerts ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->biti = 80000000\s*$/mi,
    'iftable int biti ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->bito = 160000000\s*$/mi,
    'iftable int bito ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->bpsi = \d\d+\s*$/mi,
    'iftable int bpsi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->bpso = \d\d+\s*$/mi,
    'iftable int bpso ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->bounce = 1\s*$/mi,
    'iftable int bounce ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->descr = FastE\D+1\/0\s*$/mi,
    'iftable int descr ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->erri = 2000\s*$/mi,
    'iftable int erri ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->epmi = \d\d+\s*$/mi,
    'iftable int epmi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->etime = [1-9]\d*\s*$/mi,
    'iftable int etime ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->fast = 100 mb\/s\s*$/mi,
    'iftable int fast ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->index = 2\s*$/mi,
    'iftable int index ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->last = 1\s*$/mi,
    'iftable int last ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->mtype = lan\s*$/mi,
    'iftable int mtype ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->name = FastE\S+1\/0\s*$/mi,
    'iftable int name ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->nupi = 2000\s*$/mi,
    'iftable int ucpi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->nupo = 3000\s*$/mi,
    'iftable int ucpo ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->npsi = \d\d+\s*$/mi,
    'iftable int npsi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->npso = \d\d+\s*$/mi,
    'iftable int npso ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->online = 0\s*$/mi,
    'iftable int online ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->oper = 2\s*$/mi,
    'iftable int oper ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->pcti = [1-9]\d*\s*$/mi,
    'iftable int pcti ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->pcto = [1-9]\d*\s*$/mi,
    'iftable int pcto ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->pkti = 6000\s*$/mi,
    'iftable int pkti ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->pkto = 8000\s*$/mi,
    'iftable int pkto ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->ppsi = \d\d+\s*$/mi,
    'iftable int ppsi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->ppso = \d\d+\s*$/mi,
    'iftable int ppso ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->speed = 100000000\s*$/mi,
    'iftable int speed ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->status = 1\s*$/mi,
    'iftable int status ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->time = \d{9}\d+\s*$/mi,
    'iftable int time ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->ucpi = 4000\s*$/mi,
    'iftable int ucpi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet1\/0->ucpo = 5000\s*$/mi,
    'iftable int ucpo ok');

# check ifxtable interface data
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->fast = 10 gb\/s\s*$/mi,
    'ifxtable int fast 10gb ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->speed = 10000000000\s*$/mi,
    'ifxtable int 10gb speed ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->biti = 80000000\s*$/mi,
    'ifxtable int biti ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->bito = 160000000\s*$/mi,
    'ifxtable int bito ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->nupi = 22000\s*$/mi,
    'iftable int nupi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->nupo = 33000\s*$/mi,
    'iftable int nupo ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->ucpi = 40000\s*$/mi,
    'iftable int ucpi ok');
ok($cmd_out =~ /^log 5 \S+ int->FastEthernet0\/0->ucpo = 50000\s*$/mi,
    'iftable int ucpo ok');

# finished
&done_testing;
exit;



sub alert_test {

    # internal: $outut = &alert_test($pn, $po);
    # purpose: execute mnet::poll::alerts with new/old test data, log output

    # read new/old test data string, ex: "'poll' => { 'snmp' => 1 }"
    my ($pn_in, $po_in) = @_;
    $pn_in = "" if not defined $pn_in;
    $po_in = "" if not defined $po_in;
    my $flag = 0;
    $flag = 1 if $pn_in or $po_in;

    # init perl test code
    my $alert_test_perl = '
        use warnings; use strict;
        use Mnet;
        use Mnet::Poll;
        my $cfg = &object({
            "log-level"           => 7,
            "object-name"        => "localhost",
            "poll-alerts"        => 1,
            "poll-detail"        => 1,
            "poll-ping"          => 0,
            "poll-alerts-wpctl5" => 95,
            "poll-alerts-wpctl6" => 85,
            "poll-alerts-lpctl5" => 75,
            "poll-alerts-lpctl6" => 50,
            "poll-alerts-epmi4"  => 2,
            "poll-alerts-epmi5"  => 1,
        });
        my $pn = {' . $pn_in . '};
        my $po = {' . $po_in . '};
        $pn->{"poll"}->{"snmp"} = 1 if "' . $flag . '";
        $pn->{"poll"}->{"success"} = 1;
        use Data::Dumper; syswrite STDOUT, Dumper($pn);
        &Mnet::Poll::alerts($cfg, $pn, $po);
    ';

    # finish alert_test function
    return &output("perl -e '$alert_test_perl' 2>&1");
}



sub data_poll_int_test {

    # internal: $result = &data_poll_int_test($mtype, $oper, $admin);
    # purpose: used to check that online and status are set correctly

    # read inputs
    my ($mtype, $oper, $admin) = @_;

    # initialize data
    my $pn = {};
    $pn->{'int'}->{'test12345'}->{'descr'} = "test12345";
    $pn->{'int'}->{'test12345'}->{'mtype'} = $mtype;
    $pn->{'int'}->{'test12345'}->{'oper'} = $oper;
    $pn->{'int'}->{'test12345'}->{'admin'} = "up";
    $pn->{'int'}->{'test12345'}->{'admin'} = $admin if defined $admin;
    $pn->{'int'}->{'test12345'}->{'index'} = 1;
    my $cfg = {};
    $cfg->{'poll-adescr-length'} = 5;
    my $int_table = {};

    # call data poll int function
    &Mnet::Poll::data_poll_int($cfg, $pn, $int_table);

    # return if hide interface was correctly removed
    return "h" if $mtype eq "hide"
        and not exists $pn->{'int'}->{'test12345'};

    # check that alias and adescr were set correctly
    return "a" if not $pn->{'int'}->{'test12345'}->{'alias'};
    return "d" if not $pn->{'int'}->{'test12345'}->{'adescr'};
    return "t" if $pn->{'int'}->{'test12345'}->{'adescr'} ne "test1...";

    # initialize output data
    my ($status, $online) = ("u", "u");
    $status = $pn->{'int'}->{'test12345'}->{'status'}
        if defined $pn->{'int'}->{'test12345'}->{'status'};
    $online = $pn->{'int'}->{'test12345'}->{'online'}
        if defined $pn->{'int'}->{'test12345'}->{'online'};

    # finished data_poll_int_test
    print "mtype=$mtype, oper=$oper => status=$status, online=$online\n"
        if "@ARGV" =~ /(^|\s)(-d|--?debug)(\s|$)/;
    return "$status $online";
}



sub mtype_test {
    # internal: $mtype = &mtype_test($descr, $type, $alias, $biti, $erri, $ipv4)
    # purpose: test poll mtypes

    # prepare for call
    my $cfg = {};
    $cfg->{'poll-skip-alias'} = undef;
    my $pn_int = {};
    $pn_int->{'descr'} = shift;
    $pn_int->{'type'} = shift;
    $pn_int->{'alias'} = shift;
    $pn_int->{'biti'} = shift;
    $pn_int->{'erri'} = shift;
    $pn_int->{'ipv4'} = shift;

    # have poll module calculate mtype
    my $mtype = &Mnet::Poll::snmp_int_mtype($cfg, $pn_int);

    # return output mtype
    return $mtype;
}
    


sub poll_test {
    # purpose: test poll using snmp-replay

    # read hash ref of oids to change both before and after, and after only
    my ($both, $second) = @_;
    $both = {} if not defined $both;
    $second = {} if not defined $second;

    # read base snmp data file
    my $snmp1_text = "";
    if (open(my $fh, "t/data/Mnet_Poll.snmp")) {
        $snmp1_text .= "$_" while (<$fh>);
        close $fh;
    } else {
        die "unable to open t/data/Mnet_Poll.snmp file, $!";
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
            &log("poll->$_ = " . $data->{"poll"}->{$_})
                foreach sort keys %{$data->{"poll"}};
            &log("sys->$_ = " . $data->{"sys"}->{$_})
                foreach sort keys %{$data->{"sys"}};
            &log("ipv4->$_ = " . $data->{"ipv4"}->{$_})
                foreach sort keys %{$data->{"ipv4"}};
            foreach my $int (keys %{$data->{"int"}}) {
                next if $int eq "Null0";
                &log("int->${int}->$_ = " . $data->{"int"}->{$int}->{$_})
                    foreach sort keys %{$data->{"int"}->{$int}};
            }
            sleep 1;
        \' - --object-name router1 --object-address 127.0.0.1 \\
             --poll-alerts --poll-detail \\
             --log-level 7 --conf-noinput --log-diff \\
             --ping-replay \\
    ';
    $poll_test_perl .= "--db-name $db_file ";

    # get command output for first and second snmp samples, if clean exit
    my $output = &output("$poll_test_perl --snmp-replay $snmp1_file 2>&1");
    if ($output =~ /inf 6 \S+ mnet script perl-e clean exit/mi) {
        $output = &output("$poll_test_perl --snmp-replay $snmp2_file 2>&1");
    }
    
    # remove temp db file
    unlink $db_file or die "unable to delete temp db file $db_file, $!";

    # return null on error
    return "" if $output !~ /inf 6 \S+ mnet script perl-e clean exit/mi;

    # finished poll_test
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

