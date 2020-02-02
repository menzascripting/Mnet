# NAME

Mnet - Testable network automation and reporting

# SYNOPSIS

    # sample script to report Loopback0 ip on cisco devices
    #
    #   demonstrates typical use of all major Mnet modules
    #   refer to various Mnet modules' perldoc for more info
    #
    #   --help to list all options, or --help <option>
    #   --device <address> to connect to device with logging
    #   --username and --password should be set if necessary
    #   --batch <file.batch> to process multiple --device lines
    #   --report csv:<file.csv> to create an output csv report
    #   --record <file.test> to create replayable test file
    #   --test --replay <file.test> for regression test output

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
    #   record, redact, default, and help option attributes are shown
    #   export Mnet="--password '<secret>'" env var to secure password
    Mnet::Opts::Cli::define({ getopt => "device=s", record => 1 });
    Mnet::Opts::Cli::define({ getopt => "username=s" });
    Mnet::Opts::Cli::define({ getopt => "password=s", redact  => 1 });
    Mnet::Opts::Cli::define({ getopt => "report=s", default => undef,
        help_tip    => "specify report output, like 'csv:<file>'",
        help_text   => "perldoc Mnet::Report::Table for more info",
    });

    # create object to access command line and Mnet env variable options
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

    # recreate cli option obejct, forking children if in --batch mode
    #   process one device or ten thousand devices with the same script
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
    #   log ssh login/auth prompts as info, instead of default debug
    #   password_in set to prompt for password if --password opt not set
    #   ssh host/key checks can be skipped, refer to Mnet::Expect::Cli
    my $ssh = Mnet::Expect::Cli::Ios->new({
        spawn       => [ "ssh", "$cli->{username}\@$cli->{device}" ],
        log_id      => $cli->{device},
        log_login   => "info",
        password    => $cli->password,
        password_in => 1,
    });

    # retrieve ios config from ssh command, warn otherwise
    my $config = $ssh->command("show running-config");
    WARN("unable to read config") if not $config;

    # parse interface loopack0 stanza from config
    #   returns int loop line0 and lines indented under int loop0
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
and allow for regression testing of complex automation scripts.
- Reliable automation of cisco ios and other command line sessions, including
reliable authentication and command prompt handling.
- Automation scripts can run in batch mode to concurrently process a list of
devices, using a simple command line argument and a device list file.
- Facilitate easy log, debug, alert and error output from automation scripts,
outputs can be redirected to per-device files
- Flexible config settings via command line, environment variable, and/or batch
device list files.
- Report data from scripts can be output as csv, json, or sql.

Most of the [Mnet](https://metacpan.org/pod/Mnet) sub-modules can be used independently of each other,
unless otherwise noted.

Refer to the individual modules listed in the SEE ALSO section below
for more detail.

# INSTALLATION

The [Mnet](https://metacpan.org/pod/Mnet) perl modules should work in just about any unix perl environment.

The latest release can be installed from CPAN

    cpan install Mnet

Or download and install from [https://github.com/menzascripting/Mnet](https://github.com/menzascripting/Mnet)

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

Copyright 2006, 2013-2020 Michael J. Menza Jr.

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

[Mnet::Report::Table](https://metacpan.org/pod/Mnet::Report::Table)

[Mnet::Stanza](https://metacpan.org/pod/Mnet::Stanza)

[Mnet::Test](https://metacpan.org/pod/Mnet::Test)
