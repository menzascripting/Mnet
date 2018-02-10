# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_HPNA.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; } or die "perl File::Temp module not found";

# Insert your test code below, refer to Test::More man page

# initialize command arguments and command output
my ($cmd_arg, $cmd_out) = ("", "");

# define test script
my $perl_test_hpna1 = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        use Mnet::HPNA;
        my $cfg = &object({"hpna-suicide" => 30 });
        &hpna_arg("object-name", "\$tc_device_hostname\$");
        &hpna_arg("object-address", "\$tc_device_ip\$");
        &hpna_arg("test-value", "\$test_value\$");
        foreach my $key (qw/
            object-name object-address test-value conf-noinput
        /) {
            &inf("testing $key = " . $cfg->{$key}) if defined $cfg->{$key};
        }
        exit;
    \' - --object-name localhost --log-level 7 \\
';

# define test script
my $perl_test_hpna2 = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        use Mnet::HPNA;
        my $cfg = &object({ "hpna-suicide" => 30 });
        &hpna_arg("object-name", "localhost");
        &hpna_arg("object-address", "127.0.0.1");
        &hpna_arg("test-value", "123456789");
        foreach my $key (qw/
            object-name object-address test-value conf-noinput
        /) {
            &inf("testing $key = " . $cfg->{$key}) if defined $cfg->{$key};
        }
        exit;
    \' - --object-name localhost --log-level 7 \\
';

# define test script
my $perl_test_hpna3 = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        use Mnet::HPNA;
        my $cfg = &object({ "hpna-suicide" => 30 });
        &hpna_arg("object-address", "127.0.0.1");
        &hpna_arg("test-value", "123456789");
        foreach my $key (qw/
            object-name object-address test-value conf-noinput
        /) {
            &inf("testing $key = " . $cfg->{$key}) if defined $cfg->{$key};
        }
        my $test_input = &input("test-input");
        exit;
    \' - --object-name localhost --log-level 7 --test-value abcdefgh \\
';


# check hpna processing, should be skipped for this script
$cmd_out = &output("$perl_test_hpna1 $cmd_arg 2>&1");
ok($cmd_out =~ /mnet script perl-e starting/m,
    'hpna1 output present');
ok($cmd_out =~ /^inf .+ main testing object-name = localhost/m,
    'hpna1 object-address configured from command line');
ok($cmd_out =~ /^inf .+ main testing object-address = localhost/m,
    'hpna1 object-address configured from object-name');
ok($cmd_out !~ /^inf .+ main testing test-value =/m,
    'hpna1 test-value correctly left unset');
ok($cmd_out !~ /^inf .+ main testing conf-noinput =/m,
    'hpna1 conf-noinput correctly left unset');
ok($cmd_out !~ /hpna config/m,
    'hpna1 config correctly not set');
ok($cmd_out !~ /hpna suicide timer being set/m,
    'hpna1 suicide timer correctly left unset');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'hpna1 script clean exit');

# check ospware processing, should be triggered for this script
$cmd_out = &output("$perl_test_hpna2 $cmd_arg 2>&1");
ok($cmd_out =~ /mnet script perl-e starting/m,
    'hpna2 output present');
ok($cmd_out =~ /^dbg .+ hpna config setting object-name set = localhost/m,
    'hpna2 object-name correctly substituted');
ok($cmd_out =~ /^inf .+ main testing object-name = \Qlocalhost\E/m,
    'hpna2 object-name correctly set from hpna');
ok($cmd_out =~ /^inf .+ main testing object-address = \Q127.0.0.1\E/m,
    'hpna2 object-address correctly set from hpna');
ok($cmd_out =~ /^inf .+ main testing test-value = 123456789/m,
    'hpna2 test-value correctly set from hpna');
ok($cmd_out =~ /^inf .+ main testing conf-noinput = 1/m,
    'hpna2 conf-noinput correctly set with hpna');
ok($cmd_out =~ /hpna suicide timer being set/m,
    'hpna1 suicide timer correctly set');
ok($cmd_out =~ /mnet script perl-e clean exit/m,
    'hpna2 script clean exit');

# check ospware processing, should be triggered for this script
$cmd_out = &output("$perl_test_hpna3 $cmd_arg 2>&1");
ok($cmd_out =~ /mnet script perl-e starting/m,
    'hpna3 output present');
ok($cmd_out =~ /^inf .+ main testing test-value = 123456789/m,
    'hpna3 test-value correctly set from hpna');
ok($cmd_out =~ /^die .+ mnet input call while conf-noinput in effect/mi,
    'hpna3 died due to input call under hpna');
ok($cmd_out =~ /mnet script perl-e error exit/m,
    'hpna3 script error exit, as expected');


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

