# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_standalone.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; };
&plan(skip_all => "perl File::Temp module not installed") if $@;

# Insert your test code below, refer to Test::More man page

# create temporary test standalone_src file
my $fh_standalone_src = File::Temp->new()
    or die "unable to open standalone_src tempfile";
print $fh_standalone_src '
#!/usr/bin/perl
use warnings;
use strict;
use Mnet;
use Mnet::Poll;
use MnetClient::Test;
&log("test executed");
';
close $fh_standalone_src;
my $file_standalone_src = $fh_standalone_src->filename;

# create temporary test standalone_dst file
my $fh_standalone_dst = File::Temp->new()
    or die "unable to open standalone_dst tempfile";
print $fh_standalone_dst ''; 
close $fh_standalone_dst;
my $file_standalone_dst = $fh_standalone_dst->filename;

# prepare standalone script command
my $standalone_cmd = "script/Mnet-standalone ";
$standalone_cmd .= "--standalone-src $file_standalone_src ";
$standalone_cmd .= "--standalone-dst $file_standalone_dst ";
$standalone_cmd .= "--standalone-path-MnetClient t/data/Mnet-standalone.tar.gz";

# execute standalone script command, check for clean exit
my $cmd_out = &output("$standalone_cmd 2>&1");
ok($cmd_out =~ /mnet script Mnet-standalone clean exit/,
    'standalone test output exit clean');

# check output standalone embedded script
my $dst_out = &output("cat $file_standalone_dst 2>&1");
foreach my $module (qw/
    Mnet.pm
    Mnet\/RRD.pm
    Mnet\/SNMP.pm
    Mnet\/Poll\/Cisco.pm
    MnetClient\/Poll\/TestPoll.pm
    Mnet\/IP.pm
    Mnet\/Ping.pm
    Mnet\/Poll.pm
    MnetClient\/Test.pm
    /) {
    ok($dst_out =~ /^# embedded \Q$module\E starting/m,
        "embedded $module present");
}
ok($dst_out =~ /^\&log\("test executed"\);/m, 'embedded script present');

# check output from running embedded script
my $run_out = &output("perl $file_standalone_dst 2>&1");
ok($run_out =~ /^log .+ test executed/m, 'embedded script executed');
ok($run_out =~ /mnet script \S+ clean exit/m, 'embedded script clean exit');

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

