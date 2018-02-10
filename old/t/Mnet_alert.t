# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_alert.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; } or die "perl File::Temp module not installed";;

# Insert your test code below, refer to Test::More man page

# init testing command and output vars
delete $ENV{'MNET'};
my ($cmd, $out);

# setup perl test log code
my $perl_test_alert = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        my $cfg = &object();
        &alert(1, "test1-b") if $cfg->{"alert1"};
        &alert(2, "test2-b") if $cfg->{"alert2"};
        sleep 2;
        &alert(1, "test1-a") if $cfg->{"alert1"};
        &alert(2, "test2-a") if $cfg->{"alert2"};
    \' - \\
';

# test unsorted alert output to stdout
$cmd = "$perl_test_alert --object-name test";
$out = &output("$cmd --log-stderr 0 --alert1 --alert2");
ok($out =~ s/^ALR 1 \d\d:\d\d:\d\d test1-b$//m, 'alert 1-b');
ok($out =~ s/^ALR 2 \d\d:\d\d:\d\d test2-b$//m, 'alert 2-b');
ok($out =~ s/^ALR 1 \d\d:\d\d:\d\d test1-a$//m, 'alert 1-a');
ok($out =~ s/^ALR 2 \d\d:\d\d:\d\d test2-a$//m, 'alert 2-a');

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

