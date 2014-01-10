# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_input.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; };
&plan(skip_all => "perl File::Temp module not installed") if $@;

# Insert your test code below, refer to Test::More man page

# init testing command and output vars
my ($cmd, $out);

# setup perl test input code
my $perl_test_input = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        my $cfg = &object({ "1" => "def" });
        &input("1");
        &input("2", "hide");
        &input("3");
        foreach my $key (keys %$cfg) {
            print "$key=$$cfg{$key}=\n";
        }
    \' - \\
';

# test mnet terminal input
$cmd = '( echo in1 && echo err && echo in1 && echo in1 && echo in2 ) | ';
$cmd .= $perl_test_input . '--object-name test';
$out = &output($cmd);
ok($out =~ /^verification error/mi, "input verification");
ok($out !~ /:\s*in1/, "input windows_skip" );
ok($out =~ /^1=def=/m, "input default setting");
SKIP: {
    skip('input win32 os', 2) if $^O !~ /win32/i;
    ok($out =~ /^2=in1\s=/m, "input win32 os in1");
    ok($out =~ /^3=in2\s=/m, "input win32 os in2");
}
SKIP: {
    skip('input non-win32 os', 2) if $^O =~ /win32/i;
    ok($out =~ /^2=in1=/m, "input non-win32 os in1");
    ok($out =~ /^3=in2=/m, "input non-win32 os in2");
}

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

