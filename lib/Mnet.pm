package Mnet;

# version number used by Makefile.PL
#   these should be set to "dev", expect when creating a new release
#   refer to developer build notes in Makefile.PL for more info
our $VERSION = "dev";

=head1 NAME

Mnet - Testable network automation and reporting

=head1 SYNOPSIS

    # sample script to report Loopback0 address on cisco devices
    #
    #   demonstrates typical use of all major Mnet modules
    #   refer to perldoc for various Mnet modules for complete api info
    #
    #   use --help to list all options, or --help <option>
    #   use --device <address> to connect to device with logging
    #   use --batch <file.batch> to process multiple --device lines
    #   add --report csv:<file.csv> to create an output csv file
    #   add --record <file.test> to create a --device test file
    #   use --test --replay <file.test> to show script test diff

    # load modules
    use warnings;
    use strict;
    use Mnet::Batch;
    use Mnet::Expect::Cli::Ios;
    use Mnet::Log qw(DEBUG INFO WARN FATAL);
    use Mnet::Opts::Cli;
    use Mnet::Report::Table;
    use Mnet::Stanza;
    use Mnet::Test;

    # define --device name and --report output cli options
    #   options can also be set via Mnet environment variable
    Mnet::Opts::Cli::define({ getopt => "device=s" });
    Mnet::Opts::Cli::define({ getopt => "username=s" });
    Mnet::Opts::Cli::define({ getopt => "password=s" });
    Mnet::Opts::Cli::define({ getopt => "report=s" });

    # parse cli options, also parses Mnet environment variable
    my $cli = Mnet::Opts::Cli->new;

    # define output --report table, will include first of any errors
    #   use --report cli opt to output data as csv, json, sql, etc
    my $report = Mnet::Report::Table->new({
        columns => [
            device  => "string",
            error   => "error",
            ip      => "string",
        ],
        output  => $cli->report,
    });

    # handle concurrent --batch processing, parent exits when finished
    #   process a list of thousands of devices, hundreds at a time, etc
    $cli = Mnet::Batch::fork($cli);
    exit if not $cli;

    # ensure that errors are reported if script aborts for any reason
    $report->row_on_error({ device => $cli->device });

    # use log function and set up log object for device
    FATAL("missing --device") if not $cli->device;
    my $log = Mnet::Log->new({ log_id => $cli->device });
    $log->info("processing device");

    # create an expect ssh session to --device
    #   perldoc Mnet::Expect shows how to disable ssh host/key checks
    my $ssh = Mnet::Expect::Cli::Ios->new({
        spawn => [ "ssh", $cli->{device} ],
    });

    # retrieve config from ssh command, warn otherwise
    my $config = $ssh->command("show running-config");
    WARN("unable to read config") if not $config;

    # retrieve interface vlan 1 stanza from config
    my $loop = Mnet::Stanza::parse($config, qr/^interface loopback0$/i);

    # parse primary ip address from loopback config
    my $ip = undef;
    $ip = $1 if $loop and $loop =~ /^ ip address (\S+) \S+$/m;

    # report on parsed loopback interface ip addres
    $report->row({ device => $cli->device, ip => $ip });

    # finished
    exit;

=head1 DESCRIPTION

The L<Mnet> modules are for perl programmers who want to create testable
network automation and/or reporting scripts as simply as possible.

The main features are:

=over

=item *

Facilitate easy log, debug, alert and error output from automation scripts,
outputs can be redirected to per-device files

=item *

Automation scripts can run in batch mode to concurrently process a list of
devices, using a simple command line argument and a device list file.

=item *

Flexible config settings via command line, environment variable, and/or batch
device list files.

=item *

Reliable automation of cisco IOS and other command line sessions, including
reliable authentication and command prompt handling.

=item *

Report data from scripts can be output as plain .csv files, json, or sql.

=item *

Record and replay connected command line sessions, speeding the development
of automation scripts and allowing for proper regression testing.

=back

Most of the L<Mnet> isub-modules can be used independently of each other,
unless otherwise noted.

Refer to the individual modules listed in the SEE ALSO section below
for more detail.

=head1 INSTALLATION

The L<Mnet> perl modules should work in just about any unix perl environment.

The latest release can be installed from CPAN

    cpan install Mnet

Or downloaded and installed from L<https://github.com/menzascripting/Mnet>

    tar -xzf Mnet-X.y.tar.gz
    cd Mnet-X.y
    perl Makefile.PL  # INSTALL_BASE=/specify/path
    make install

You might need to update your PERL5LIB environment variable if you uncommented
the INSTALL_BASE option above.

=head1 AUTHOR

The L<Mnet> perl distribution has been created and is maintained by Mike Menza.
Mike can be reached via email at <mmenza@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2019 Michael J. Menza Jr.

L<Mnet> is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>

=head1 SEE ALSO

L<Mnet::Batch>

L<Mnet::Expect::Cli>

L<Mnet::Expect::Cli::Ios>

L<Mnet::Log>

L<Mnet::Opts::Cli>

L<Mnet::Opts::Set>

L<Mnet::Report::Table>

L<Mnet::Stanza>

L<Mnet::Test>

=cut

# required modules
#   cpan complians if use strict is missing
use warnings;
use strict;

# normal end of package
1;

