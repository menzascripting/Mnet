#!/usr/bin/env perl

#? connect to ios/juniper/other devices available via http://routeserver.org
#   make use of expect ios, batch mode, reports, testing, etc

#? does `--replay test.file --test --record` update test.file with test diff?
#   what about --batch --test --record and child with --replay test.file?
#       does test_done code update filed replay file with null record opt?
#       does this work in batch mode? maybe remove batch fork record warning?

#? consider creating some type of outline parsing subroutine or module
#   @output or $output = outline_parse($input_outline, $match_re)
#   returns all outline sections that match regex
#   or where would be a good spot to put this code?

# required modules
use warnings;
use strict;
use Mnet::Batch;
use Mnet::Expect::Cli;
use Mnet::Log qw(DEBUG INFO WARN FATAL);
use Mnet::Opts::Cli;
use Mnet::Report::Table;
use Mnet::Test;

# define cli option --telnet <address>
Mnet::Opts::Cli::define({
    getopt   => "telnet=s",
    help_tip => "required connect address",
});

# defined authentication options
Mnet::Opts::Cli::define({ getopt => "username=s" });
Mnet::Opts::Cli::define({ getopt => "password=s", redact => 1 });

# define cli option --report <output>
Mnet::Opts::Cli::define({
    getopt    => "report=s",
    default   => "log",
    help_tip  => "Mnet::Report::Table output",
    help_text => "refer to OUPTUT in perldoc Mnet::Table::Report",
});

# parse cli options
my $cli = Mnet::Opts::Cli->new;

# init report output, will croak on errors
my $report = Mnet::Report::Table->new({
    columns => [
        telnet  => "string",
        result  => "string",
        error   => "error",
    ],
    output  => $cli->report,
});

# fork children if --batch is set
$cli = Mnet::Batch::fork($cli);
exit if not $cli;

# abort if --telnet option is not set
FATAL("missing --telnet option") if not $cli->telnet;

# init report data for the current execution
$report->row_on_error({ telnet => $cli->telnet });

# open a session to --telnet address
#my $expect = Mnet::Expect::Cli->new({
#    spawn => [ "telnet", $cli->telnet ],
#    username => $cli->username,
#    password => $cli->password,
#});

# retrieve output from command on device
#my $sh_ver = $expect->command("show version");
#$expect->command("set cli screen-length 25");
#my $sh_bgp = $expect->command("show bgp summary");
#syswrite STDOUT, "\n\n$sh_bgp\n\n";

my $ping_out = `ping -c 2 $cli->{telnet} 2>&1`;
my $result = "ping" if $ping_out =~ /received/ and $ping_out !~ /0 received/;

# output report row after collecting data
$report->row({ telnet => $cli->telnet, result => $result });

# finished
exit;

