# NAME

Mnet - Testable network automation and reporting

# SYNOPSIS

    # sample script to report Loopback0 ip on cisco devices
    #
    #   demonstrates typical use of all major Mnet modules
    #   refer to various Mnet modules for complete api info
    #
    #   use --help to list all options, or --help <option>
    #   use --device <address> to connect to device with logging
    #   use --batch <file.batch> to process multiple --device lines
    #   add --report csv:<file.csv> to create an output csv report
    #   add --record <file.test> to create replayable test file
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

    # define --device, --username, --password, and --report cli options
    #   help tips and text can be viewed with --help and --help report
    #   use the Mnet environment variable to securely set --password
    #   refer to Mnet::Opts::Cli for more information
    Mnet::Opts::Cli::define({ getopt => "device=s" });
    Mnet::Opts::Cli::define({ getopt => "username=s", default => $ENV{USER} });
    Mnet::Opts::Cli::define({ getopt => "password=s", redact  => 1 });
    Mnet::Opts::Cli::define({ getopt => "report=s",
        help_tip    => "specify report output, like 'csv:<file>'",
        help_text   => "refer to Mnet::Report::Table for more info",
    });

    # parse command line and Mnet environment variable options
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
    #   process one device or ten thousand devices with the same script

    # read command line options, fork children if in --batch mode
    #   exit --batch parent process when finished forking children
    $cli = Mnet::Batch::fork($cli);
    exit if not $cli;

    # ensure that errors are reported if script aborts before finishing
    $report->row_on_error({ device => $cli->device });

    # use log function and set up log object for device
    FATAL("missing --device") if not $cli->device;
    my $log = Mnet::Log->new({ log_id => $cli->device });
    $log->info("processing device");

    # create an expect ssh session to --device
    #   username set undef since this is included in spawn argument
    #   password_in set to prompt for password if not set via cli option
    #   ssh host/key checks can be skipped, see Mnet::Expect::Cli
    my $ssh = Mnet::Expect::Cli::Ios->new({
        spawn       => [ "ssh", "$cli->{username}\@$cli->{device}" ],
        username    => undef,
        password    => $cli->password,
        password_in => 1,
    });

    # retrieve config from ssh command, warn otherwise
    my $config = $ssh->command("show running-config");
    WARN("unable to read config") if not $config;

    # parse interface loopack0 stanza from config
    my $loop = Mnet::Stanza::parse($config, qr/^interface loopback0$/i);

    # parse primary ip address from loopback0 config stanza
    my $ip = undef;
    $ip = $1 if $loop and $loop =~ /^ ip address (\S+) \S+$/m;

    # report on parsed loopback0 interface ip addres
    $report->row({ device => $cli->device, ip => $ip });

    # finished
    exit;

# DESCRIPTION

The [Mnet](https://metacpan.org/pod/Mnet) modules are for perl programmers who want to create testable
network automation and/or reporting scripts as simply as possible.

The main features are:

- Record and replay connected command line sessions, speeding development
and allowing for regression testing of complex automation scripts.
- Reliable automation of cisco IOS and other command line sessions, including
reliable authentication and command prompt handling.
- Automation scripts can run in batch mode to concurrently process a list of
devices, using a simple command line argument and a device list file.
- Facilitate easy log, debug, alert and error output from automation scripts,
outputs can be redirected to per-device files
- Flexible config settings via command line, environment variable, and/or batch
device list files.
- Report data from scripts can be output as plain .csv files, json, or sql.

Most of the [Mnet](https://metacpan.org/pod/Mnet) sub-modules can be used independently of each other,
unless otherwise noted.

Refer to the individual modules listed in the SEE ALSO section below
for more detail.

# INSTALLATION

The [Mnet](https://metacpan.org/pod/Mnet) perl modules should work in just about any unix perl environment.

The latest release can be installed from CPAN

    cpan install Mnet

Or downloaded and installed from [https://github.com/menzascripting/Mnet](https://github.com/menzascripting/Mnet)

    tar -xzf Mnet-X.y.tar.gz
    cd Mnet-X.y
    perl Makefile.PL  # INSTALL_BASE=/specify/path
    make test
    make install

Check your PERL5LIB environment variable if INSTALL\_BASE was used, or if you
copied the lib/Mnet directory somewhere instead of using Makefile.PL. Refer
to [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils::MakeMaker) for more information

# AUTHOR

The [Mnet](https://metacpan.org/pod/Mnet) perl distribution has been created and is maintained by Mike Menza.
Mike can be reached via email at <mmenza@cpan.org>.

# COPYRIGHT AND LICENSE

Copyright 2006, 2013-2019 Michael J. Menza Jr.

[Mnet](https://metacpan.org/pod/Mnet) is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see [http://www.gnu.org/licenses/](http://www.gnu.org/licenses/)

# SEE ALSO

[Mnet::Batch](https://metacpan.org/pod/Mnet::Batch)

[Mnet::Expect::Cli](https://metacpan.org/pod/Mnet::Expect::Cli)

[Mnet::Expect::Cli::Ios](https://metacpan.org/pod/Mnet::Expect::Cli::Ios)

[Mnet::Log](https://metacpan.org/pod/Mnet::Log)

[Mnet::Opts::Cli](https://metacpan.org/pod/Mnet::Opts::Cli)

[Mnet::Opts::Set](https://metacpan.org/pod/Mnet::Opts::Set)

[Mnet::Report::Table](https://metacpan.org/pod/Mnet::Report::Table)

[Mnet::Stanza](https://metacpan.org/pod/Mnet::Stanza)

[Mnet::Test](https://metacpan.org/pod/Mnet::Test)
