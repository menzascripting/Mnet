package Mnet;

our $VERSION = "dev";

=head1 NAME

Mnet - Testable network automation and reporting

=head1 SYNOPSIS

    # usage: perl sample.pl --device <address>

    # load modules
    use warnings;
    use strict;
    use Mnet::Batch;
    use Mnet::Expect::Cli;
    use Mnet::Log qw(DEBUG INFO WARN FATAL);
    use Mnet::Opts::Cli;
    use Mnet::Report::Table;
    use Mnet::Test;

    # define --device name and --report output cli options
    Mnet::Opts::Cli::define({ getopt => "device=s" });
    Mnet::Opts::Cli::define({ getopt => "username=s" });
    Mnet::Opts::Cli::define({ getopt => "password=s" });
    Mnet::Opts::Cli::define({ getopt => "report=s" });

    # parse cli options, also parses Mnet environment variable
    my $cli = Mnet::Opts::Cli->new;

    # define output --report table, will include first of any errors
    my $report = Mnet::Report::Table->new({
        columns => [
            device  => "string",
            error   => "error",
            diff    => "string",
        ],
        output  => $cli->report,
    });

    # handle concurrent --batch processing, parent exits when finished
    $cli = Mnet::Batch::fork($cli);
    exit if not $cli;

    # ensure that errors show up in report if we don't end normally
    $report->row_on_error({ device => $cli->device });

    # use log function and set up log object for device
    FATAL("missing --device") if not $cli->device;
    my $log = Mnet::Log->new({ log_id => $cli->device });
    $log->info("processing device");

    # create an expect ssh session to --device
    my $ssh = Mnet::Expect::Cli->new({
        spawn => [ "ssh", $cli->{device} ],
    });

    # retrieve config from ssh command, warn otherwise
    my $config = $ssh->command("show running-config");
    WARN("unable to read config") if not $config;

    # retrieve interface vlan 1 stanza from config
    my $data = Mnet::Stanza::parse($config, qr/^interface vlan1$/i);

    # report on parsed vlan1 interface config data
    $report->row({ device => $cli->device, data => $data });

    # finished
    exit;

=head1 DESCRIPTION

The Mnet modules are for perl programmers who want to create testable network
automation and/or reporting scripts.

The above SYNOPSIS sample.pl script can be executed as follows:

 # list options, or get more help on a specific option
 sample.pl --help [<option>]

 # ssh to device, log output to terminal
 sample.pl --device router1

 # record device ssh session then replay and show test diffs
 sample.pl --device router1 --record router1.test
 sample.pl --test --replay router1.test

 # concurrently process and report on a list of devices
 echo '
    --device router1
    --device router2
 ' | sample.pl --batch /dev/stdin --report csv:/dev/stdout

Most of the Mnet modules can be used independely of each other, except where
otherwise noted.

Refer to the modules listed in the SEE ALSO section below for more details.

=head1 AUTHOR

The Mnet perl distribution has been created and is maintained by Mike Menza.
Mike can be reached via email at <mmenza@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2019 Michael J. Menza Jr.

Mnet is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>

=head1 SEE ALSO

L<Mnet::Batch>

L<Mnet::Expect>

L<Mnet::Expect::Cli>

L<Mnet::Expect::Cli::Ios>

L<Mnet::Log>

L<Mnet::Opts::Cli>

L<Mnet::Opts::Set::Debug>

L<Mnet::Opts::Set::Quiet>

L<Mnet::Opts::Set::Silent>

L<Mnet::Report::Table>

L<Mnet::Tee>

L<Mnet::Test>

=cut

# normal end of package
1;

