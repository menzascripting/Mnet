# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_config.t'

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

# setup perl test config code
my $perl_test_config = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        package test_config;
            use Mnet;
            BEGIN {
                our $cfg = &config({
                    "10" => "mod",
                    "11" => "mod",
                    "21" => "mod",
                });
            }
            sub test_mod {
                print "mod 20=$test_config::cfg->{20}=\n";
                print "mod 21=$test_config::cfg->{21}=\n";
                print "mod 22=$test_config::cfg->{22}=\n";
            }
        1;
        &config({
            "1"  => "def",
            "2"  => "def",
            "3"  => "def",
            "4"  => "def",
            "5"  => "def",
            "10" => "def",
            "20" => "def",
        });
        my $cfg = &object();
        foreach my $key (keys %$cfg) {
            next if not defined $cfg->{$key};
            next if $key eq "multiline";
            print "$key=$cfg->{$key}=\n";
        }
        if ($cfg->{"multiline"}) {
            my $line_count = 0;
            foreach my $line (split(/\n/, $cfg->{"multiline"})) {
                $line =~ s/(^\s+|\s+$)//g;
                next if $line !~ /\S/;
                $line_count++;
                print "line-$line_count=$line=\n";
            }
        }
        &test_config::test_mod;
    \' - \\
';

# create temporary test conf-file file
my $fh_conf = File::Temp->new() or die "unable to open conf tempfile";
print $fh_conf '
--3 conf
--4 conf
--5 conf
--6 conf # comment
#--7 conf
';
close $fh_conf;
my $file_conf = $fh_conf->filename;

# create temporary test conf-auth file
my $fh_auth = File::Temp->new() or die "unable to open auth tempfile";
print $fh_auth '
--4 auth
--5 auth
';
close $fh_auth;
my $file_auth = $fh_auth->filename;

# purpose: ensure config and object functions sets config with good data
$cmd = "$perl_test_config --object-name test";
$ENV{'MNET'} = " --2 env --3 env --4 env --5 env";
$cmd .= " --conf-file $file_conf --conf-auth $file_auth";
$cmd .= " --5 arg --22 arg";
$out = &output("export MNET=\'$ENV{'MNET'}\'; $cmd");
delete $ENV{'MNET'};
ok($out =~ /^mnet-script=perl-e=/m, 'config mnet-script set');
ok($out =~ /^log-level=\d=/m, 'config log-level set');
ok($out =~ /^1=def=/m, 'config 1 def set');
ok($out =~ /^2=env=/m, 'config 2 env set');
ok($out =~ /^3=conf=/m, 'config 3 conf set');
ok($out =~ /^4=auth=/m, 'config 4 auth set');
ok($out =~ /^5=arg=/m, 'config 5 arg set');
ok($out =~ /^6=conf=/m, 'config 6 conf set');
ok($out !~ /^7=conf=/m, 'config 7 conf set');
ok($out =~ /^10=def=/m, 'config 10 def set');
ok($out =~ /^11=mod=/m, 'config 11 mod set');
ok($out =~ /^mod 20=def=/m, 'config 20 mod def set');
ok($out =~ /^mod 21=mod=/m, 'config 21 mod mod set');
ok($out =~ /^mod 22=arg=/m, 'config 22 mod arg set');

# purpose: ensure config line error parsing works
$cmd = $perl_test_config . '--object-name test --1 arg error';
$out = &output($cmd);
ok($out =~ /command line parsing near 'error'/, 'config line parsing');

# purpose: ensure config line double quoting works
$cmd = $perl_test_config . '--object-name test ';
$cmd .= "--1 \"a b\" --2 'a b' --4 \"a 'b'\" --5 'a \"b\"'";
$out = &output($cmd);
ok($out =~ /^1=a b=/m, 'config double quotes');
ok($out =~ /^2=a b=/m, 'config single quotes');
ok($out =~ /^4=a 'b'=/m, 'config single nested quotes');
ok($out =~ /^5=a "b"=/m, 'config double nested quotes');

# purpose: test config file missing
$cmd = $perl_test_config . '--conf-file test_config.missing';
$out = &output($cmd);
ok($out =~ /no such file or directory/mi, "config conf-file missing");

# purpose: test object-address and object-name
$cmd = $perl_test_config . '--log-stdout --log-level 7';
$out = &output("$cmd --object-name test1 --object-address test2");
ok($out =~ /^dbg 7 \S+ mnet config setting object-name = test1$/m,
    "config object-name with object-address");
ok($out =~ /^dbg 7 \S+ mnet config setting object-address = test2$/m,
    "config object-address with object-name");
$out = &output("$cmd --object-name test1");
ok($out =~ /^dbg 7 \S+ mnet config setting object-address = test1$/m,
    "config object-address from object-name");
$out = &output("$cmd --object-address test2");
ok($out =~ /^dbg 7 \S+ mnet config setting object-name = test2$/m,
    "config object-name from object-address");

# purpose: test config file missing
$cmd = $perl_test_config . '--multiline "
    line1
    line2
    line3
" --object-name test';
$out = &output($cmd);
ok($out =~ /^dbg 7 \S+ mnet config setting object-name = test$/m,
    "config object-name for multiline test");
ok($out =~ /^line-1=line1=$/m,
    "config line1 for multiline test");
ok($out =~ /^line-2=line2=$/m,
    "config line1 for multiline test");
ok($out =~ /^line-3=line3=$/m,
    "config line1 for multiline test");

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

