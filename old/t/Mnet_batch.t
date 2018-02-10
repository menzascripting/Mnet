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

# init testing command and output vars
my ($cmd, $out);

# setup perl test config code
my $perl_test_batch = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        my $cfg = &object({
            "log-level"    => 7,
            "log-stdout" => 1,
            "log-stderr" => 1,
        });
        &log(5, "starting");
        &log(5, "finished");
    \' - \\
';

# create temporary test batch-list file
my $fh_batch = File::Temp->new() or die "unable to open batch tempfile";
print $fh_batch '
--object-name test1 
--object-name test2
--object-name test3
--object-name test4
--object-name test5
';
close $fh_batch;
my $file_batch = $fh_batch->filename;

# create temporary test batch-list error file
my $fh_error = File::Temp->new() or die "unable to open error tempfile";
print $fh_error '
--object-name test1 
--object-name test2
--object-name test3 error
--object-name test4
--object-name test5
';
close $fh_error;
my $file_error = $fh_error->filename;

# test single process batch-list processing
$cmd="$perl_test_batch --batch-list $file_batch ";
$out = &output("$cmd --batch-procs 1 --log-level 7");
#die $out;
ok($out !~ /^\S+\s(0|1|2|3|4)\s/m, 'batch no warnings');
ok($out =~ /inf 6 \S+ : mnet read \d+ line batch-list \Q$file_batch\E$/m,
    'batch read batch-list');
for (my $loop = 1; $loop < 5; $loop++) {
    ok($out =~ /^dbg 7 \S+ test$loop: mnet config setting object-name /m,
        "batch object-name test$loop");
    my $obj_init = "object test$loop initiated";
    ok($out =~ /^inf 6 \S+ test$loop: mnet $obj_init, pid (\d+)$/m,
        "batch initiated test$loop");
    my $cpid = $1;
    ok($out =~ /dbg 7 \S+ : mnet batch_fork child pid $cpid forked/m,
        "batch forked test$loop");
    ok($out =~ /^log 5 \S+ test$loop: starting$/m,
        "batch started test$loop");
    ok($out =~ /^log 5 \S+ test$loop: finished$/m,
        "batch finished test$loop");
    ok($out =~ /dbg 7 \S+ : mnet batch_reaper child pid $cpid status 0$/m,
        "batch reaper test $loop");
}
ok($out =~ /^inf 6 \S+ : mnet batch-list finished processing \d+ items/m,
    "batch parent finished");

# test concurrent batch-list processing
$out = &output("$perl_test_batch --batch-list $file_batch --batch-procs 4");
ok($out !~ /^\S+\s(0|1|2|3|4)\s/m, 'batch concurrent no warnings');
ok($out =~ /inf 6 \S+ : mnet read \d+ line batch-list \Q$file_batch\E$/m,
    'batch concurrent starting');
for (my $loop = 1; $loop < 5; $loop++) {
    ok($out =~ /^log 5 \S+ test$loop: starting$/m,
        "batch concurrent test$loop starting");
    ok($out =~ /^log 5 \S+ test$loop: finished$/m,
        "batch concurrent test$loop finished");
}
ok($out =~ /^inf 6 \S+ : mnet batch-list finished processing \d+ items/m,
    'batch concurrent finished');  


# test batch-parse config setting
$cmd = "$perl_test_batch --batch-list $file_error --batch-parse";
$out = &output($cmd);
ok($out =~ /inf 6 \S+ : mnet read \d+ line batch-list \Q$file_error\E$/m,
    'batch parse file');
ok($out =~ /inf 6 \S+ : mnet batch-list batch-parse complete$/m,
    'batch parse complete');
ok($out =~ /DIE 0 \S+ test3: mnet batch-list line 4 parse error/m,
    'batch parse working');

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

