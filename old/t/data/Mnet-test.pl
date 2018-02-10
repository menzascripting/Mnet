#!/usr/bin/env perl

# purpose: generate test output used for testing script/Mnet-test
# usage: t/data/Mnet-test.pl [--test-nums 'x y z'] [--test-error]
# note: this script will output lines numbered 0 through 9
# the --test-nums arg can be used at append an X to specified lines
# the --test-error arg can be used to cause a fatal error before exit

# use modules
use warnings;
use strict;
use Mnet;

# initialize config
my $cfg = &object;
$cfg->{'test-nums'} = '' if not defined $cfg->{'test-nums'};

# output test data from 0 to 9, appending an X according to test-nums arg
syswrite STDOUT, "\nTEST OUTPUT STARTING\n\n";
foreach my $number (0..9) {
    my $out = $number;
    $out .= " X" if $cfg->{'test-nums'} =~ /(^|\s)$number(\s|$)/;
    syswrite STDOUT, "line $out\n";
}
syswrite STDOUT, "\nTEST OUTPUT FINISHED\n\n";

# output test error, if one was configured
die "test error\n" if $cfg->{'test-error'};
 
# exit if test-filters not configured
exit if not $cfg->{'test-filters'};

print "
dbg 7 00:00:00 mnet config setting test-record = 1
dbg 7 00:00:00 mnet config setting test-replay = 2

dbg 7 00:00:00 mnet config setting expect-record = 1
dbg 7 00:00:00 mnet config setting expect-replay = 2
inf 6 00:00:00 expect start ssh to localhost
dbg 7 00:00:00 expect command 'ls' timeout 45s
dbg 7 00:00:00 expect command 'ls' returned 97 chars
dbg 7 00:00:00 expect session initiating
Enter localhost expect-enable:
Verify localhost expect-enable:
dtl 7 00:00:00 expect read started with 45s timeout

dbg 7 00:00:00 mnet creating missing data-dir dir localhost
dbg 7 00:00:00 mnet input localhost expect-enable from terminal
Verification error...!
dtl 7 00:00:00 mnet config sub called from mnet

dbg 7 00:00:00 mnet config setting ping-record = 1
dbg 7 00:00:00 mnet config setting ping-replay = 2
dtl 7 00:00:00 ping sub called from main

dbg 7 00:00:00 mnet config setting snmp-record = 1
dbg 7 00:00:00 mnet config setting snmp-replay = 2
Enter localhost snmp-community:
Verify localhost snmp-community:
dtl 7 00:00:00 snmp snmp_bulkget sub called from main
dbg 7 00:00:00 snmp snmp_get snmp-record set to 1
dbg 7 00:00:00 snmp snmp_get snmp-replay set to 2
dbg 7 00:00:00 snmp snmp_get preparing for oid .1.3.6.1.2.1.1.5.0
dbg 7 00:00:00 snmp snmp_get oid .1.3.6.1.2.1.1.5.0 value = 'localhost'
dbg 7 00:00:00 snmp snmp_bulkget preparing for 2 oids
dbg 7 00:00:00 snmp snmp_bulkget for 2 oids = 2 values
dbg 7 00:00:00 snmp snmp_bulkwalk preparing for oid .1.3.6.1.2.1.2.2.1
dbg 7 00:00:00 snmp snmp_bulkwalk oid .1.3.6.1.2.1.2.2.1 = 110 values
";

# finished
exit;
