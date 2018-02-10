# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_log.t'

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

# setup perl test log code
my $perl_test_log = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        my $cfg = &object();
        if (not defined $$cfg{"test-rotate"}) {
            &log($$cfg{"sev"}, $$cfg{"text"});
        } else {
            my $max = $$cfg{"log-rotate"} * 15000;
            for (my $loop = 1; $loop < $max; $loop++) {
                &log(1, "log rotation test");
            }
        }
    \' - \\
';

# test logging to standard out and standard error
$cmd = "$perl_test_log --object-name test --log-stderr";
$out = &output("$cmd --sev 1 --text test --log-level 6");
ok($out =~ /^LOG 1 \S+ test/m, 'log test text');
$out = &output("$cmd --sev 1 --log-level 6");
ok($out =~ /^LOG 1 \S+ unspecified log text$/m, 'log unspecified text');
$out = &output("$cmd --sev 1 --text 'a test' --log-level 6");
ok($out =~ /^LOG 1 \S+ a test/m, 'log multiword test');
$cmd =~ s/\s--log-stderr//;
$out = &output("$cmd --sev 3  --log-stderr 0 --log-level 6");
ok($out =~ /^LOG 3 /m, 'log critical uppercase');
$out = &output("$cmd --sev 3 --log-stderr 0 --log-stdout --log-level 2");
ok($out !~ /^log 3 /m, 'log critical suppressed');
$out = &output("$cmd --sev 7 --log-stdout --log-level 6");
ok($out !~ /^log 7 /m, 'log debug suppressed');
$out = &output("$cmd --sev 6 --log-stdout --log-level 6");
ok($out =~ /^log 6 \S+ main unspecified log text$/m, 'log exact severity');
$out = &output("$cmd --sev 6 --log-stdout 0 --log-level 6");
ok($out !~ /^log 6 /m, 'log stdout suppressed');

# test logging of config setting debug information
$cmd = "$perl_test_log --object-name test ";
$cmd .= " --log-level 7 --log-stdout --config-debug";
$out = &output("$cmd --sev 7 --text test");
ok($out =~ /^dbg 7 \d\d:\d\d:\d\d mnet config setting sev = 7$/m,
    'log config debug set');
ok($out =~ /^dbg 7 \S+ mnet config setting text = test$/m,
    'log config text');
ok($out =~ /^dbg 7 \S+ mnet config setting object-name = test$/m,
    'log config object-name host');
ok($out =~ /^dbg 7 \S+ mnet config setting object-address = test$/m,
    'log config object-address from object-name');
ok($out =~ /^dbg 7 \S+ mnet config setting log-level = 7$/m,
    'log config log-level');
ok($out !~ /^dbg 7 \S+ mnet config setting log-stdout = 1$/m,
    'log config log-stdout');
$out = &output("$cmd --object-address 127.0.0.1");
ok($out =~ /^dbg 7 \S+ mnet config setting object-address = \Q127.0.0.1\E/m,
    'log config object-address ip');
ok($out =~ /^dbg 7 \S+ mnet config setting object-name = test$/m,
    'log config object-name from object-address');

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

