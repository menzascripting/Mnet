# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_batch.t'

#? git add and put this in manifest when finished

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

#? use t/Mnet_batch.t content to get started with report testing
&plan(skip_all => "Mnet::Report tests not created yet");

#? old test_report.sh
#    ~/work/Mnet/dev/test_report.pl \
#        --batch-list ~/work/Mnet/dev/test_report.batch \
#        --db-name ~/work/Mnet/dev/test_poll/mnet.sql \
#        --data-dir ~/work/Mnet/dev/test_poll \
#        --report-csv $1 $2 $3 $4 $5 $6 $7 $8 $9

#? old test_report.batch
#    --object-name localhost

#? old test_report.pl
#    #!/usr/bin/env perl
#    # sample.pl --log-quiet --batch-list list \
#    #  | perl -e 'use Mnet::Report; &Mnet::Report::csv' - --log-quiet
#    use Mnet;
#    use Mnet::Report;
#    my $cfg = &object;
#    &report("compliant", 1) if $cfg->{'object-name'} =~ /-rtr\d$/;
#    &report("test5", 'this is a "quote and comma" test, ok?');
#    &report("test4", 'hello! equal = sign');
#    &report("test3", 'comma, only');
#    &report("test2", 'wrapup!', "int");
#    &report("test1", $cfg->{'test'});

#? old test_report.sql
#    sqlite3 ~/work/Mnet/dev/test_poll/mnet.sql '
#        select * from _report
#        where _script = "test_report.pl"
#        order by _script, _object;
#    '

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

