# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_SNMP.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; };
&plan(skip_all => "perl File::Temp module not installed") if $@;

# Insert your test code below, refer to Test::More man page

# initialize command arguments and command output
my ($cmd_arg, $cmd_out) = ("", "");

# check that snmp is responding local to public community
$cmd_out = `snmpwalk -v 2c -c public 127.0.0.1 .1.3.6.1.2.1.1 2>/dev/null`;
&plan(skip_all => 'snmp v2c public is not working on test system')
    if $cmd_out !~ /\S/;
ok($cmd_out =~ /\S/, 'snmp v2c public working on test system');

# define test snmp script
my $perl_test_snmp = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        use Mnet::SNMP;
        my $cfg = &object({
            "object-name"  => "localhost",
        });
        my $oid_sysname = ".1.3.6.1.2.1.1.5.0";
        my $get = &snmp_get($oid_sysname);
        &log("get $oid_sysname = $get") if defined $get;
        if ($cfg->{"snmp-replay"}) {
            my $oid_nonexistant = ".1.2.3.4.5.6.7.8.9.10.11.nonexistant";
            my $get2 = &snmp_get($oid_nonexistant);
            $get2 = "<undef>" if not defined $get2;
            &log("get2 $oid_nonexistant = $get2");
        }
        my $oid_sysdescr = ".1.3.6.1.2.1.1.1.0";
        my $oid_sysuptime = ".1.3.6.1.2.1.1.3.0";
        my $bulkget = {};
        my $bulkget_err = &snmp_bulkget(
            [$oid_sysname, $oid_sysdescr, $oid_sysuptime], $bulkget);
        if (not $bulkget_err) {
            &log("bulkget $_ = $bulkget->{$_}")
                foreach sort keys %$bulkget;
        } else {
            &log("bulkget_err = $bulkget_err");
        }
        my $oid_sys = ".1.3.6.1.2.1.1";
        my $bulkwalk1 = {};
        my $bulkwalk1_err = &snmp_bulkwalk($oid_sys, $bulkwalk1);
        if (not $bulkwalk1_err) {
            &log("bulkwalk1 $_ = $bulkwalk1->{$_}")
                foreach ($oid_sysname, $oid_sysdescr, $oid_sysuptime);
        } else {
            &log("bulkwalk1_err = $bulkwalk1_err");
        }
        my $bulkwalk2 = {};
        my $oid_physaddress = ".1.3.6.1.2.1.2.2.1.6";
        my $bulkwalk2_err = &snmp_bulkwalk($oid_physaddress, $bulkwalk2);
        if (not $bulkwalk2_err) {
            &log("bulkwalk2 $_ = $bulkwalk2->{$_}")
                foreach sort keys %$bulkwalk2;
        }
    \' - --log-level 7 --snmp-detail \\
';

# create temporary snmp record/replay file
my $fh_snmp = File::Temp->new() or die "unable to open snmp file";
print $fh_snmp '';
close $fh_snmp;
my $file_snmp = $fh_snmp->filename;

# check output from snmp test and recording of test
$cmd_arg = "--snmp-record $file_snmp --snmp-community public ";
$cmd_arg .= "--object-address 127.0.0.1 --snmp-warn ";
$cmd_out = &output("$perl_test_snmp $cmd_arg 2>&1");
ok($cmd_out =~ /snmp snmp_get snmp-record set to \Q$file_snmp\E\s*$/m,
    'snmp1 record is set');
ok($cmd_out =~ /\Qget .1.3.6.1.2.1.1.5.0\E = \S+\s*$/m,
    'snmp1 get returned data');
ok($cmd_out =~ /\Qbulkget .1.3.6.1.2.1.1.1.0\E = \S+\s+\S+/m,
    'snmp1 bulkget returned data1');
ok($cmd_out =~ /\Qbulkget .1.3.6.1.2.1.1.3.0\E = \d+\s*$/m,
    'snmp1 bulkget returned data2');
ok($cmd_out =~ /\Qbulkget .1.3.6.1.2.1.1.5.0\E = \S+\s*$/m,
    'snmp1 bulkget returned data3');
ok($cmd_out =~ /\Qbulkwalk1 .1.3.6.1.2.1.1.1.0\E = \S+\s+\S+/m,
    'snmp1 bulkwalk1 returned data1');
ok($cmd_out =~ /\Qbulkwalk1 .1.3.6.1.2.1.1.3.0\E = \d+\s*$/m,
    'snmp1 bulkwalk1 returned data2');
ok($cmd_out =~ /\Qbulkwalk1 .1.3.6.1.2.1.1.5.0\E = \S+\s*$/m,
    'snmp1 bulkwalk1 returned data3');
ok($cmd_out =~ /\Qbulkwalk2 .1.3.6.1.2.1.2.2.1.6.\E\d+ = \S+/m,
    'snmp1 bulkwalk2 returned data1');
ok($cmd_out =~ /\Qbulkwalk2 .1.3.6.1.2.1.2.2.1.6.\E\d+ =\s*/m,
    'snmp1 bulkwalk2 returned data2');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'snmp1 script clean exit');

# check output from snmp test and recording of test
$cmd_arg = "--snmp-replay $file_snmp --snmp-community notworking ";
$cmd_arg .= "--object-address 127.0.0.1 --snmp-warn ";
$cmd_out = &output("$perl_test_snmp $cmd_arg 2>&1");
ok($cmd_out =~ /snmp snmp_get snmp-replay set to \Q$file_snmp\E\s*$/m,
    'snmp2 replay is set');
ok($cmd_out =~ /\Qget .1.3.6.1.2.1.1.5.0\E = \S+\s*$/m,
    'snmp2 get returned data');
ok($cmd_out =~ /get2 \S+\.nonexistant = <undef>\s*$/m,
    'snmp2 get handled nonexistant replay data');
ok($cmd_out =~ /\Qbulkget .1.3.6.1.2.1.1.1.0\E = \S+\s+\S+/m,
    'snmp2 bulkget returned data1');
ok($cmd_out =~ /\Qbulkget .1.3.6.1.2.1.1.3.0\E = \d+\s*$/m,
    'snmp2 bulkget returned data2');
ok($cmd_out =~ /\Qbulkget .1.3.6.1.2.1.1.5.0\E = \S+\s*$/m,
    'snmp2 bulkget returned data3');
ok($cmd_out =~ /\Qbulkwalk1 .1.3.6.1.2.1.1.1.0\E = \S+\s+\S+/m,
    'snmp2 bulkwalk1 returned data1');
ok($cmd_out =~ /\Qbulkwalk1 .1.3.6.1.2.1.1.3.0\E = \d+\s*$/m,
    'snmp2 bulkwalk1 returned data2');
ok($cmd_out =~ /\Qbulkwalk1 .1.3.6.1.2.1.1.5.0\E = \S+\s*$/m,
    'snmp2 bulkwalk1 returned data3');
ok($cmd_out =~ /\Qbulkwalk2 .1.3.6.1.2.1.2.2.1.6.\E\d+ = \S+/m,
    'snmp2 bulkwalk2 returned data1');
ok($cmd_out =~ /\Qbulkwalk2 .1.3.6.1.2.1.2.2.1.6.\E\d+ =\s*/m,
    'snmp2 bulkwalk2 returned data2');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'snmp2 script clean exit');

# test snmp warnings to invalid ip address
$cmd_arg = "--snmp-retries 0 --snmp-community notworking ";
$cmd_arg .= "--object-address 127.0.0.2 --snmp-warn ";
$cmd_out = &output("$perl_test_snmp $cmd_arg 2>&1");
ok($cmd_out =~ /^WRN .+ snmp snmp_get query error/m,
    'snmp3 query error warning');
ok($cmd_out =~ /^WRN .+ snmp snmp_bulkget query error/m,
    'snmp3 query error warning');
ok($cmd_out =~ /^WRN .+ snmp snmp_bulkwalk query error/m,
    'snmp3 query error warning');

# test snmp warnings to invalid community, warnings generated
$cmd_arg = "--snmp-retries 0 --snmp-community notworking ";
$cmd_arg .= "--object-address 127.0.0.1 --snmp-warn ";
$cmd_out = &output("$perl_test_snmp $cmd_arg 2>&1");
ok($cmd_out =~ /^WRN .+ snmp snmp_get query error/m,
    'snmp4 get query error warning');
ok($cmd_out =~ /^dbg .+ snmp snmp_get oid \S+ value = <undef>/m,
    'snmp4 get query data undefined');
ok($cmd_out =~ /^WRN .+ snmp snmp_bulkget query error/m,
    'snmp4 bulkget query error warning');
ok($cmd_out =~ /^dbg .+ snmp snmp_bulkget for 3 oids = <undef>/m,
    'snmp4 bulkget query data undefined');
ok($cmd_out =~ /^WRN .+ snmp snmp_bulkwalk query error/m,
    'snmp4 query error warning');
ok($cmd_out =~ /^dbg .+ snmp snmp_bulkwalk oid \S+ = <undef>/m,
    'snmp4 bulkwalk query data undefined');

# test snmp invalid ip address, no warnings generated
$cmd_arg = "--snmp-retries 0 --snmp-community notworking ";
$cmd_arg .= "--object-address 127.0.0.2 ";
$cmd_out = &output("$perl_test_snmp $cmd_arg 2>&1");
ok($cmd_out =~ /^dbg .+ snmp_get query error/m,
    'snmp5 get query error debug');
ok($cmd_out =~ /^dbg .+ snmp_bulkget query error/m,
    'snmp5 bulkget query error debug');
ok($cmd_out =~ /^log 5 .+ bulkget_err = \S+/m,
    'snmp5 bulkget query error logged');
ok($cmd_out =~ /^dbg .+ snmp_bulkwalk query error/m,
    'snmp3 bulkwalk query error debug');
ok($cmd_out =~ /^log 5 .+ bulkget_err = \S+/m,
    'snmp5 bulkwalk query error logged');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'snmp5 script clean exit');

# finished
&done_testing;
exit;

sub output {
    # purpose: command output with optional debug
    my $command = shift or die;
    my $output = `( $command ) 2>&1`;
    print "\n\n$command\n\n$output\n\n"
        if "@ARGV" =~ /(^|\s)(-d|--?debug)(\s|$)/;
    return $output;
}

