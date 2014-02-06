# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_batch.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; } or die "perl File::Temp module not found";

# Insert your test code below, refer to Test::More man page

# create temp directory for data-dir testing
my $test_dir = File::Temp->newdir(TMPDIR => 1);

# init testing command and output vars
my ($cmd, $out);

# invalid test-dir 
$cmd = "script/Mnet-test --test-dir $test_dir";
$out = &output("script/Mnet-test");
ok($out =~ /^die 0 \S+ main required test-dir is not set/mi,
    'missing test-dir arg ok');
$out = &output("script/Mnet-test --test-dir '$test_dir has space'");
ok($out =~ /^die 0 \S+ main test-dir should not contain spaces/mi,
    'invalid test-dir arg ok');

# create diff filter
$out = &output("script/Mnet-test --test-dir $test_dir");
ok($out =~ /main creating diff filter file \Q$test_dir\E\/Mnet-test-filter\.pl/,
    'test-dir created diff filter file');
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-dir diff filter output exit clean');
$out = &output("cat '$test_dir/Mnet-test-filter.pl'");
ok($out =~ /input/, 'test-dir diff filter file input is present');
ok($out =~ /foreach/, 'test-dir diff filter file foreach is present');
ok($out =~ /output/, 'test-dir diff filter file output is present');

# missing scenarios
$cmd = "script/Mnet-test --test-dir $test_dir";
$out = &output("$cmd --test-accept");
ok($out =~ /^die 0 \S+ main test-accept no scenarios found in test-dir/mi,
    'missing test-replay scenarios ok');
$out = &output("$cmd --test-diff");
ok($out =~ /^die 0 \S+ main test-diff no scenarios found in test-dir/mi,
    'missing test-replay scenarios ok');
$out = &output("$cmd --test-replay");
ok($out =~ /^die 0 \S+ main test-replay no scenarios found in test-dir/mi,
    'missing test-replay scenarios ok');
$out = &output("$cmd --test-replay --test-diff");
ok($out =~ /^die 0 \S+ main test-replay no scenarios found in test-dir/mi,
    'missing test-replay --test-diff scenarios ok');
$out = &output("$cmd --test-record test");
ok($out =~ /^die 0 \S+ main \S+\/test\.sh read open error no such file/mi,
    "missing test-record scenario ok");
$out = &output("$cmd --test-replay test");
ok($out =~ /^die 0 \S+ main \S+\/test\.sh read open error no such file/mi,
    "missing test-replay scenario ok");
$out = &output("$cmd --test-replay test --test-diff");
ok($out =~ /^die 0 \S+ main \S+\/test\.sh read open error no such file/mi,
    "missing test-replay test-diff scenario ok");
system("rm -R $test_dir");

# create diff filter
$out = &output("script/Mnet-test --test-dir $test_dir");
ok($out =~ /main creating diff filter file \Q$test_dir\E\/Mnet-test-filter\.pl/,
    'test-dir created diff filter file');
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-dir diff filter output exit clean');
$out = &output("cat '$test_dir/Mnet-test-filter.pl'");
ok($out =~ /input/, 'test-dir diff filter file input is present');
ok($out =~ /foreach/, 'test-dir diff filter file foreach is present');
ok($out =~ /output/, 'test-dir diff filter file output is present');

# test diff filters
$cmd = "script/Mnet-test --test-dir $test_dir "
    . "--test-script t/data/Mnet-test.pl --test-create scenario1 "
    . "--object-name localhost --test-filters";
$out = &output($cmd);
$cmd = "script/Mnet-test --test-dir $test_dir --test-replay scenario1";
$out = &output($cmd);
$out = &output("cat $test_dir/scenario1/scenario1.test");
foreach my $config (qw/test-record|test-replay expect-record|expect-replay
    ping-record|ping-replay snmp-record|snmp-replay test-record|test-replay/) {
    ok($out =~ /^dbg 7 00:00:00 mnet config setting \Q$config\E = 1/m,
        "test-filters dbg $config 1 set");
    ok($out =~ /^dbg 7 00:00:00 mnet config setting \Q$config\E = 2/m,
        "test-filters dbg $config 2 set");
}
ok($out !~ /^inf 6 \S+ expect/m, 'test-filters expect inf ok');
ok($out =~ s/^dbg 7 \S+ expect command .+ timeout //m,
    'test-filters expect command timeout ok');
ok($out =~ s/^dbg 7 \S+ expect command .+ returned //m,
    'test-filters expect command returned ok');
ok($out !~ /^dbg 7 \S+ expect/, 'test-filters expect dbg ok');
ok($out !~ /^Enter localhost expect/m, 'test-filters enter expect ok');
ok($out !~ /^Verify localhost expect/m, 'test-filters verify expect ok');
ok($out !~ /^dtl 7 \S+ expect/, 'test-filters expect dtl ok');
ok($out !~ /^dbg 7 \S+ mnet creating missing data-dir/m,
    'test-filters mnet data-dir ok');
ok($out !~ /^dbg 7 \S+ mnet input/m, 'test-filters mnet input ok');
ok($out !~ /^Verification error/m, 'test-filters verification error ok');
ok($out !~ /^dtl 7 \S+ mnet/, 'test-filters mnet dtl ok');
ok($out !~ /^dtl 7 \S+ ping/, 'test-filters ping dtl ok');
ok($out !~ /^Enter localhost snmp/m, 'test-filters enter snmp ok');
ok($out !~ /^Verify localhost snmp/m, 'test-filters verify snmp ok');
ok($out !~ /^dtl 7 \S+ snmp/m, 'test-filter snmp dtl ok');
ok($out =~ /^dbg 7 \S+ snmp snmp_get snmp-record|snmp-replay set to 1/m,
    'test-filters snmp-record ok');
ok($out =~ /^dbg 7 \S+ snmp snmp_get snmp-record|snmp-replay set to 2/m,
    'test-filters snmp-reply ok');
foreach my $snmp (qw/snmp_get snmp_bulkget snmp_bulkwalk/) {
    ok($out =~ /^dbg 7 00:00:00 snmp $snmp preparing/m,
        "test-filters snmp $snmp preparing ok");
    ok($out =~ /^dbg 7 00:00:00 snmp $snmp.+oid.*=/m,
        "test-filters snmp $snmp oid value ok");
}
system("rm -R $test_dir/scenario1");

# test1 test-create
$cmd = "script/Mnet-test --test-dir $test_dir "
    . "--test-script t/data/Mnet-test.pl --test-create scenario1 "
    . "--object-name localhost --test-nums '2 4' --log-level 7";
$out = &output($cmd);
ok($out =~ /main test-create \Q$test_dir\E\/scenario1\s*$/m,
    'test-create scenario1 dir specified');
ok(-d "$test_dir/scenario1", 'test-create test-dir/scenario1 dir exists');
my $test1_sh_out = &output("cat $test_dir/scenario1/scenario1.sh");
my $test1_sh_chk = "t/data/Mnet-test.pl --test-scenario scenario1 "
    . "--log-diff --log-stderr 0 --log-summary 0 "
    . "--data-dir $test_dir/scenario1 "
    . "--test-dir $test_dir --test-script t/data/Mnet-test.pl "
    . "--test-create --object-name localhost --test-nums '2 4' "
    . "--log-level 7";
ok($test1_sh_out =~ /^\Q$test1_sh_chk\E$/, 'test-create scenario1.sh args ok');
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-create scenario1 output exit clean');

# test1 test-record terminal output check
$cmd = "script/Mnet-test --test-dir $test_dir --test-record scenario1";
$out = &output($cmd);
ok(-d "$test_dir/scenario1/localhost", 'test-record scenario1 data-dir exists');
my $test1_rec_chk = "test-record cmd_line = t/data/Mnet-test.pl "
    . "--expect-record scenario1.expect "
    . "--snmp-record scenario1.snmp --ping-record "
    . "--test-scenario scenario1 --log-diff --log-stderr 0 "
    . "--log-summary 0 --data-dir $test_dir/scenario1 "
    . "--test-dir $test_dir --test-script t/data/Mnet-test.pl "
    . "--test-record --object-name localhost --test-nums '2 4' --log-level 7";
ok($out =~ /\Q$test1_rec_chk\E$/m, 'test-record scenario1 args ok');
my $test1_date = '\S+\s+\S+\s+\d+\s+\d\d:\d\d:\d\d\s+\d\d\d\d';
ok($out =~ /^dbg 7 00:00:00 mnet script Mnet-test\.pl starting $test1_date/m,
    'test-record scenario1 record starting');
foreach my $config (qw/data-dir expect-record log-diff log-stderr log-summary
    ping-record snmp-record test-dir test-record test-scenario test-script/) {
    ok($out =~ /^dbg 7 00:00:00 mnet config setting $config = \S/m,
        "test-record scenario1 record config dbg $config set");    
}
ok($out =~ /^dbg 7 00:00:00 mnet creating missing data-dir dir localhost/m,
    'test-record scenario1 record creating data-dir');
ok($out =~ /^test output starting$/mi,
    'test-record scenario1 test stdout started');
ok($out =~ /^line 0$/m,
    'test-record scenario1 test stdout data line 0 ok');
ok($out =~ /^line 1$/m,
    'test-record scenario1 test stdout data line 1 ok');
ok($out =~ /^line 2 X$/m,
    'test-record scenario1 test stdout data line 2 ok');
ok($out =~ /^line 9$/m,
    'test-record scenario1 test stdout data line 9 ok');
ok($out =~ /^test output finished$/mi,
    'test-record scenario1 test stdout finished');
ok($out =~ /inf 6 00:00:00 mnet script Mnet-test\.pl clean exit, 0\.000 sec/,
    'test-record scenario1 record output exit clean');
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-record scenario1 output exit clean');

# test1 test-record raw output check
my $test1_rec_cmp = "";
foreach my $line (split(/\n/, $out)) {
    next if $line =~ /^\S+ \d \d\d:\d\d:\d\d/ and $line !~ /^\S+ \d 00:00:00/;
    $test1_rec_cmp .= "$line\n";
}
my $test1_rec_raw = &output("cat $test_dir/scenario1/scenario1.raw");
$test1_rec_raw = "\n$test1_rec_raw\n";
ok($test1_rec_cmp eq $test1_rec_raw, 'test-record scenario1.raw file ok');

# test1 test-record test output check
$out = &output("cat $test_dir/scenario1/scenario1.test");
foreach my $config (qw/data-dir expect-record|expect-replay
    log-diff log-stderr log-summary snmp-record|snmp-replay
    test-dir test-record|test-replay test-scenario test-script/) {
    ok($out =~ /^dbg 7 00:00:00 mnet config setting \Q$config\E = \S/m,
        "test-record scenario1 record config dbg $config set");
}
ok($out !~ /^dbg 7 00:00:00 mnet creating missing data-dir dir localhost/m,
    'test-record scenario1 test file record creating data-dir');
ok($out =~ /^test output starting$/mi,
    'test-record scenario1 test file started');
ok($out =~ /^line 0$/m,
    'test-record scenario1 test file data line 0 ok');
ok($out =~ /^line 1$/m,
    'test-record scenario1 test file data line 1 ok');
ok($out =~ /^line 2 X$/m,
    'test-record scenario1 test file data line 2 ok');
ok($out =~ /^line 9$/m,
    'test-record scenario1 test filer data line 9 ok');
ok($out =~ /^test output finished$/mi,
    'test-record scenario1 test file finished');
ok($out =~ /inf 6 00:00:00 mnet script Mnet-test\.pl clean exit, 0\.000 sec/,
    'test-record scenario1 record file exit clean');
ok($out !~ /mnet script Mnet-test clean exit/,
    'test-record scenario1 output file clean');

# test test-create with test-noreconfig
$cmd = "script/Mnet-test --test-dir $test_dir "
    . "--test-script t/data/Mnet-test.pl --test-create scenario2 "
    . "--object-name localhost --test-nums '1 3' --log-level 7 "
    . "--test-noreconfig";
$out = &output($cmd);
ok($out =~ /main test-create \Q$test_dir\E\/scenario2\s*$/m,
    'test-create test-noreconfig scenario2 dir specified');
ok(-d "$test_dir/scenario2", 'test-create test-dir/scenario2 dir exists');
my $test2_sh_out = &output("cat $test_dir/scenario2/scenario2.sh");
my $test2_sh_chk = "t/data/Mnet-test.pl --test-scenario scenario2 "
    . "--log-diff --log-stderr 0 --log-summary 0 "
    . "--data-dir $test_dir/scenario2 --test-dir $test_dir "
    . "--test-script t/data/Mnet-test.pl --test-create "
    . "--object-name localhost --test-nums '1 3' "
    . "--log-level 7 --test-noreconfig";
ok($test2_sh_out =~ /^\Q$test2_sh_chk\E$/, 'test-create scenario2.sh args ok');
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-create scenario2 output exit clean');

# test2 test-record
$cmd = "script/Mnet-test --test-dir $test_dir --test-record scenario2";
$out = &output($cmd);
my $test2_rec_chk = "test-record cmd_line = t/data/Mnet-test.pl "
    . "--test-scenario scenario2 --log-diff --log-stderr 0 "
    . "--log-summary 0 --data-dir $test_dir/scenario2 --test-dir $test_dir "
    . "--test-script t/data/Mnet-test.pl --test-record "
    . "--object-name localhost --test-nums '1 3' --log-level 7 "
    . "--test-noreconfig";
ok($out =~ /\Q$test2_rec_chk\E$/m, 'test-record scenario2 args ok');
my $test2_date = '\S+\s+\S+\s+\d+\s+\d\d:\d\d:\d\d\s+\d\d\d\d';
ok($out =~ /^dbg 7 00:00:00 mnet script Mnet-test\.pl starting $test2_date/m,
    'test-record scenario2 record starting');
foreach my $config (qw/data-dir log-diff log-stderr log-summary
    test-dir test-scenario test-script/) {
    ok($out =~ /^dbg 7 00:00:00 mnet config setting $config = \S/m,
        "test-record scenario2 record config dbg $config set");    
}
ok($out !~ /^dbg 7 00:00:00 mnet config setting expect-record = \S/m,
    "test-record scenario2 record config dbg expect-record no set");
ok($out !~ /^dbg 7 00:00:00 mnet config setting snmp-record = \S/m,
    "test-record scenario2 record config dbg snmp-record no set");
ok($out =~ /^dbg 7 00:00:00 mnet creating missing data-dir dir localhost/m,
    'test-record scenario2 record creating data-dir');
ok($out =~ /^test output starting$/mi,
    'test-record scenario2 test stdout started');
ok($out =~ /^line 0$/m,
    'test-record scenario2 test stdout data line 0 ok');
ok($out =~ /^line 1 X$/m,
    'test-record scenario2 test stdout data line 1 ok');
ok($out =~ /^line 2$/m,
    'test-record scenario2 test stdout data line 2 ok');
ok($out =~ /^line 9$/m,
    'test-record scenario2 test stdout data line 9 ok');
ok($out =~ /^test output finished$/mi,
    'test-record scenario2 test stdout finished');
ok($out =~ /inf 6 00:00:00 mnet script Mnet-test\.pl clean exit, 0\.000 sec/,
    'test-record scenario2 record output exit clean');
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-record scenario2 output exit clean');

# test-accept with missing, empty and identical files
$cmd = "script/Mnet-test --test-dir $test_dir";
$out = &output("$cmd --test-accept test");
ok($out =~ /^die 0 \S+ main \S+\/test\.test read open error no such file/mi,
    "missing test-accept .test file ok");
system("mkdir $test_dir/test; touch $test_dir/test/test.test");
$out = &output("$cmd --test-accept test");
ok($out =~ /^die 0 \S+ main cannot accept empty \S+\/test\.test/mi,
    "empty test-accept .test file ok");
system("echo test > $test_dir/test/test.test");
system("echo test > $test_dir/test/test.accepted");
$out = &output("$cmd --test-accept test --log-level 7");
ok($out =~ /^dbg 7 \S+ main skipped identical test .accepted and .test/mi,
    "identical test-accept files skipped");
system("rm -R $test_dir/test");

# test-accept scenario1
$cmd = "script/Mnet-test --test-dir $test_dir --test-accept scenario1";
$out = &output($cmd);
ok($out =~ /main updated missing scenario1\.accepted from \.test output/,
    "test-accept updated missing scenario1.accepted");
ok(-f "$test_dir/scenario1/scenario1.accepted",
    "test-accept scenario1.accepted exists");
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-accept scenario1 output exit clean');

# test-replay scenario1
system("rm $test_dir/scenario1/scenario1.test 2>/dev/null");
ok(not (-f "$test_dir/scenario1/scenario1.test"),
    'test-replay scenario1.test file reset');
$cmd = "script/Mnet-test --test-dir $test_dir --test-replay scenario1";
$out = &output($cmd);
ok(-f "$test_dir/scenario1/scenario1.test",
    'test-replay scenario1.test file recreated');
my $test1_rep_chk = "test-replay cmd_line = t/data/Mnet-test.pl "
    . "--expect-replay scenario1.expect "
    . "--snmp-replay scenario1.snmp --ping-replay "
    . "--conf-noinput --test-scenario scenario1 --log-diff --log-stderr 0 "
    . "--log-summary 0 --data-dir $test_dir/scenario1 "
    . "--test-dir $test_dir --test-script t/data/Mnet-test.pl "
    . "--test-replay --object-name localhost --test-nums '2 4' --log-level 7";
ok($out =~ /\Q$test1_rep_chk\E$/m, 'test-replay scenario1 args ok');
ok($out =~ /^test output finished$/mi,
    'test-replay scenario1 test stdout finished');
ok($out =~ /mnet script Mnet-test clean exit/,
    'test-replay scenario1 output exit clean');
my $test1_rep_out = &output("cat $test_dir/scenario1/scenario1.test");
ok($test1_rep_out =~ /^test output finished$/mi,
    'test-replay scenario1.test file output finished');

# test-accept the test-diff right away to check for identical 
$cmd = "script/Mnet-test --test-dir $test_dir";
$out = &output($cmd);
system("mkdir $test_dir/test; echo test > $test_dir/test/test.test");
$out = &output("$cmd --test-accept test");
ok(-f "$test_dir/test/test.accepted", 'test-accept test file accepted');
$out = &output("$cmd --test-diff test");
ok($out =~ s/^diff identical, test\.accepted = test\.test//m,
    'test-accepted identical detected');
system("rm -R $test_dir/test");

# check diff with missing, empty and identical files
$cmd = "script/Mnet-test --test-dir $test_dir";
$out = &output("$cmd --test-diff test");
ok($out =~ /^die 0 \S+ main \S+\/test\.test error no such file/mi,
    "missing test-diff .test file ok");
system("mkdir $test_dir/test; touch $test_dir/test/test.test");
$out = &output("$cmd --test-diff test");
ok($out =~ /^die 0 \S+ main \S+\/test\.accepted error no such file/mi,
    "missing test-diff .accepted file ok");
system("touch $test_dir/test/test.accepted");
$out = &output("$cmd --test-diff test");
ok($out =~ /^die 0 \S+ main cannot accept empty \S+\/test\.test/mi,
    "empty test-diff .test file ok");
system("echo test > $test_dir/test/test.test");
system("touch $test_dir/test/test.accepted");
$out = &output("$cmd --test-diff test");
ok($out =~ /^die 0 \S+ main cannot accept empty \S+\/test\.accepted/mi,
    "empty test-diff .accepted file ok");
system("echo test > $test_dir/test/test.accepted");
$out = &output("$cmd --test-diff test");
ok($out =~ s/^diff identical, test\.accepted = test\.test//m,
    'test-diff identical detected');
ok($out !~ /^diff/, 'test-diff identical no extra output');
ok($out =~ /mnet script Mnet-test clean exit/, 'test-diff clean exit');
system("rm -R $test_dir");

# combinations of test-diff and test-replay and multiple scenarios
$cmd = "script/Mnet-test --test-dir $test_dir";
$out = &output($cmd);
$out = &output("$cmd --test-script t/data/Mnet-test.pl --test-create test1"
    . " --object-name localhost --test-nums '1 3'");
$out = &output("$cmd --test-script t/data/Mnet-test.pl --test-create test2"
    . " --object-name localhost --test-nums '2 4'");
$out = &output("$cmd --test-replay");
$out = &output("$cmd --test-accept test1");
$out = &output("$cmd --test-accept test2");
$out = &output("$cmd --test-diff");
ok($out =~ s/^diff identical, test1\.accepted = test1\.test//m,
    'test-diffs identical test1 detected');
ok($out =~ s/^diff identical, test2\.accepted = test2\.test//m,
    'test-diffs identical test2 detected');
$out = &output("$cmd --test-script t/data/Mnet-test.pl --test-create test2"
    . " --object-name localhost --test-nums '2 4 6'");
$out = &output("$cmd --test-replay --test-diff");
ok($out =~ s/^diff identical, test1\.accepted = test1\.test//m,
    'test-diffs identical test1 detected');
ok($out =~ /^diff test2: < line 6/m, 'test-diffs test2 diff 1 detected');
ok($out =~ /^diff test2: > line 6 x/mi, 'test-diffs test2 diff 2 detected');
system("rm -R $test_dir");

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

