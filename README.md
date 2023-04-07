# NAME

Mnet - Testable network automation and reporting

# SYNOPSIS

    # sample.pl script to report Loopback0 ip on cisco devices
    #
    #   demonstrates typical use of all major Mnet modules
    #
    #   --help to list all options, also --help <option>
    #   --device <address> to connect to device with logging
    #   --username and --password should be set if necessary
    #   --debug to generate extra detailed logging outputs
    #   --batch <file.batch> to process multiple --device lines
    #   --report csv:<file.csv> to create an output csv file
    #   --record <file.test> to create replayable test file
    #   --test --replay <file.test> for regression test output
    #
    #   refer to various Mnet modules' perldoc for more info

    # load needed modules
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
    Mnet::Opts::Cli::define({ getopt => "device=s", record => 1 });
    Mnet::Opts::Cli::define({ getopt => "username=s" });
    Mnet::Opts::Cli::define({ getopt => "password=s", redact  => 1 });
    Mnet::Opts::Cli::define({ getopt => "report=s", default => undef,
        help_tip    => "specify report output, csv, json, sql, etc",
        help_text   => "perldoc Mnet::Report::Table for more info",
    });

    # create object to access command line options and Mnet env variable
    #   export Mnet="--password '<secret>'" env var from secure file
    my $cli = Mnet::Opts::Cli->new("Mnet");

    # define output --report table, will include first of any errors
    #   use --report cli opt to output data as csv, json, or sql, etc
    my $report = Mnet::Report::Table->new({
        columns => [
            device  => "string",
            error   => "error",
            ip      => "string",
        ],
        output  => $cli->report,
    });

    # fork children if in --batch mode, cli opts set for current child
    #   process one device or ten thousand devices with the same script
    #   exit --batch parent process here when finished forking children
    $cli = Mnet::Batch::fork($cli);
    exit if not $cli;

    # output report row for device error if script dies before finishing
    $report->row_on_error({ device => $cli->device });

    # call logging function, also create log object for current --device
    FATAL("missing --device") if not $cli->device;
    my $log = Mnet::Log->new({ log_id => $cli->device });
    $log->info("processing device");

    # uncomment the push commands below to skip ssh host key checks
    #   ideally host keys are already accepted, perhaps via manual ssh
    my @ssh = qw(ssh);
    #push @ssh, qw(-o StrictHostKeyChecking=no);
    #push @ssh, qw(-o UserKnownHostsFile=/dev/null);

    # create an expect ssh session to current --device
    #   log ssh login/auth prompts as info, instead of default debug
    #   password_in set to prompt for password if --password opt not set
    #   for non-ios devices refer to perldoc Mnet::Expect::Cli
    my $ssh = Mnet::Expect::Cli::Ios->new({
        spawn       => [ @ssh, "$cli->{username}\@$cli->{device}" ],
        log_id      => $cli->{device},
        log_login   => "info",
        password    => $cli->password,
        password_in => 1,
    });

    # retrieve ios config using ssh command, warn otherwise
    my $config = $ssh->command("show running-config");
    WARN("unable to read config") if not $config;

    # parse interface loopack0 stanza from device config
    #   returns int loop0 line and lines indented under int loop0
    #   see perldoc Mnet::Stanza for more ios config templating info
    my $loop = Mnet::Stanza::parse($config, qr/^interface Loopback0$/);

    # parse primary ip address from loopback config stanza
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

- [Mnet::Test](https://metacpan.org/pod/Mnet%3A%3ATest) module can record and replay [Mnet](https://metacpan.org/pod/Mnet) script options, connected
expect sessions, and compare outputs, speeding development and allowing for
integration and regression testing of complex automation scripts.
- [Mnet::Expect::Cli::Ios](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli%3A%3AIos) and [Mnet::Expect::Cli](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli) modules for reliable
automation of cisco ios and other command line sessions, including
authentication and command prompt handling.
- [Mnet::Stanza](https://metacpan.org/pod/Mnet%3A%3AStanza) module for templated config parsing and generation on cisco ios
devices and other similar indented stanza text data.
- [Mnet::Batch](https://metacpan.org/pod/Mnet%3A%3ABatch) can run automation scripts in batch mode to concurrently process
a list of devices, using command line arguments and a device list file.
- [Mnet::Log](https://metacpan.org/pod/Mnet%3A%3ALog) and [Mnet::Tee](https://metacpan.org/pod/Mnet%3A%3ATee) modules facilitate easy log, debug, alert and
error output from automation scripts, along with redirection to per-device
output files.
- [Mnet::Opts::Cli](https://metacpan.org/pod/Mnet%3A%3AOpts%3A%3ACli) module for config settings via command line, environment
variable, and/or batch scripts, with help, tips, and password redaction.
device list files.
- [Mnet::Report::Table](https://metacpan.org/pod/Mnet%3A%3AReport%3A%3ATable) module for aggregating report data from scripts,
supporting output in formats such as csv, json, and sql.

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
copied the lib/Mnet directory somewhere instead of using the included
Makefile.PL script. Refer to [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils%3A%3AMakeMaker) for more information

# FAQ

Below are answers to some frequently asked questions.

## How should I get started?

Copy the sample script code from the SYNOPSIS above to a new .pl file, read
through the comments, make changes as necessary, use the --debug cli option to
troubleshoot execution.

## What's the easiest way to get more log output?

Use both the [Mnet::Log](https://metacpan.org/pod/Mnet%3A%3ALog) and [Mnet::Opts::Set::Debug](https://metacpan.org/pod/Mnet%3A%3AOpts%3A%3ASet%3A%3ADebug) modules in your script
for more output, mostly from other Mnet modules unless you add [Mnet::Log](https://metacpan.org/pod/Mnet%3A%3ALog)
calls, which are a compatible subset of log4perl calls, to your script.

## How should passwords be secured?

Environment variables should be used to provide passwords for scripts, not
command line options. Command line options can be seen in the system process
list by other users.

The [Mnet::Opts::Cli](https://metacpan.org/pod/Mnet%3A%3AOpts%3A%3ACli) new method allows a named environment variable to be
specified that will also be parsed for command line options. Your script can
be called from a shell script containing authentication, which is accessible
only to authorized users, such as in the example below:

    #!/bin/sh
    #   sample.sh script, chmod 700 to restrict access to current user
    #   works with Mnet::Opts calls in above SYNOPISIS sample.pl script
    #   "$@" passes throuh all command line options, modify as needed
    export Mnet='--username <user> --password <secret>'
    perl -- sample.pl "$@"

The [Mnet::Opts::Cli](https://metacpan.org/pod/Mnet%3A%3AOpts%3A%3ACli) module define function has a redact property that should
be set for password options so that the value of the option is value is always
redacted form [Mnet::Log](https://metacpan.org/pod/Mnet%3A%3ALog) outputs.

Also note that the [Mnet::Expect](https://metacpan.org/pod/Mnet%3A%3AExpect) module log\_expect method is used by the
[Mnet::Expect::Cli](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli) modules to temporarily disable expect session logging
during password entry. Any user code bypassing the [Mnet::Expect::Cli](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli)
modules to send passwords directly, using the expect method in the
[Mnet::Expect](https://metacpan.org/pod/Mnet%3A%3AExpect) module, may need to do the same.

## Why should I use the Mnet::Expect module?

The [Mnet::Expect](https://metacpan.org/pod/Mnet%3A%3AExpect) module works with the [Mnet::Log](https://metacpan.org/pod/Mnet%3A%3ALog) and [Mnet::Opts::Cli](https://metacpan.org/pod/Mnet%3A%3AOpts%3A%3ACli)
modules, for easy logging of normal [Expect](https://metacpan.org/pod/Expect) module activity, with extra
options for logging, debugging, raw pty, and session tty rows and columns.

However, you still have to handle all the expect session details, including
send and expect calls for logging in, detecting of command prompts, capturing
output, etc. It's easier to use the [Mnet::Expect::Cli](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli) module which handles
all of this, if you can.

## Why should I use the Mnet::Expect::Cli module?

The [Mnet::Expect::Cli](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli) module makes it easy to login and obtain outputs from
command line interfaces, like ssh. This module builds on the [Mnet::Expect](https://metacpan.org/pod/Mnet%3A%3AExpect)
module mentioned above, adding features to handle a variety of typical username
and password prompts, command prompts, pagination prompts on long outputs, and
caching of session command output.

This module also works with the [Mnet::Test](https://metacpan.org/pod/Mnet%3A%3ATest) module, allowing expect session
activity to be recorded and replayed while offline. This can be of tremendous
value, both during development, and for sustainability.

Refer also the the [Mnet::Expect::Cli::Ios](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli%3A%3AIos) module mentioned below, which has
a couple of features relevant when working with cisco ios and other similar
devices.

## Why should I use the Mnet::Expect::Cli::Ios module?

The [Mnet::Expect::Cli::Ios](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli%3A%3AIos) builds on the [Mnet::Expect::Cli](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli) module
mentioned above, also handling enable mode authentication, the prompt changes
going from user to enable mode, and the prompt changes in configuration modes.

# AUTHOR

The [Mnet](https://metacpan.org/pod/Mnet) perl distribution has been created and is maintained by Mike Menza.
Feedback and bug reports are welcome, feel free to contact Mike via email
at <mmenza@cpan.org> with any comments or questions.

# COPYRIGHT AND LICENSE

Copyright 2006 Michael J. Menza Jr.

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

[Mnet::Batch](https://metacpan.org/pod/Mnet%3A%3ABatch)

[Mnet::Expect::Cli](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli)

[Mnet::Expect::Cli::Ios](https://metacpan.org/pod/Mnet%3A%3AExpect%3A%3ACli%3A%3AIos)

[Mnet::Log](https://metacpan.org/pod/Mnet%3A%3ALog)

[Mnet::Opts::Cli](https://metacpan.org/pod/Mnet%3A%3AOpts%3A%3ACli)

[Mnet::Report::Table](https://metacpan.org/pod/Mnet%3A%3AReport%3A%3ATable)

[Mnet::Stanza](https://metacpan.org/pod/Mnet%3A%3AStanza)

[Mnet::Test](https://metacpan.org/pod/Mnet%3A%3ATest)
