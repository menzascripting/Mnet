# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_data.t'

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
my $perl_test_data = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        my $cfg = &object;
        warn "warning";
    \' - --log-level 7 \\
';

# create temp directory for data-dir testing
my $dir_data = File::Temp->newdir(TMPDIR => 1); 
# test data-dir
$cmd = "$perl_test_data --data-dir $dir_data --object-name test";
$out = &output($cmd);
ok(chdir $dir_data, 'data dir exists');
ok(chdir "test", 'data object subdir exists');
ok(-e 'perl-e.err', 'test object file exists');
chdir "..";
chdir "..";

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

