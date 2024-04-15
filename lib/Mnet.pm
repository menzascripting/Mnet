package Mnet;

# version number used by Makefile.PL
#   these should be set to "dev", expect when creating a new release
#   refer to developer build notes in Makefile.PL for more info
our $VERSION = "dev";

=head1 NAME

Mnet - Testable network automation and reporting

=head1 SYNOPSIS

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
    use Mnet::IP;
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

    # parse primary ip address and mask from loopback config stanza
    my ($ip, $mask) = (undef, undef);
    ($ip, $mask) = ($1, $2) if $loop =~ /^ ip address (\S+) (\S+)$/m;

    # calculate cidr value from dotted decimal mask
    my $cidr = Mnet::IP::cidr($mask);

    # report on parsed loopback0 interface ip address and cidr value
    $report->row({ device => $cli->device, ip => $ip, cidr => $cidr });

    # finished
    exit;

=head1 DESCRIPTION

The L<Mnet> modules are for perl programmers who want to create testable
network automation and/or reporting scripts as simply as possible.

The main features are:

=over

=item *

L<Mnet::Expect::Cli::Ios> and L<Mnet::Expect::Cli> modules for reliable
automation of cisco ios and other command line sessions, including
authentication and command prompt handling.

=item *

L<Mnet::Stanza> module for templated config parsing and generation on cisco ios
devices and other similar indented stanza text data.

=item *

L<Mnet::Report::Table> module for aggregating report data from scripts,
supporting output in formats such as csv, json, and sql.

=item *

L<Mnet::Test> module can record and replay L<Mnet> script options, connected
expect sessions, and compare outputs, speeding development and allowing for
integration and regression testing of complex automation scripts.

=item *

L<Mnet::Batch> can run automation scripts in batch mode to concurrently process
a list of devices, using command line arguments and a device list file.

=item *

L<Mnet::Log> and L<Mnet::Tee> modules facilitate easy log, debug, alert and
error output from automation scripts, along with redirection to per-device
output files.

=item *

L<Mnet::Opts::Cli> module for config settings via command line, environment
variable, and/or batch scripts, with help, tips, and password redaction.
device list files.

=item *

L<Mnet::IP> module to parse IPv4 and IPv6 addresses and network masks.

=back

Most of the L<Mnet> sub-modules can be used independently of each other,
unless otherwise noted.

Refer to the individual modules listed in the SEE ALSO section below
for more detail.

=head1 INSTALLATION

The L<Mnet> perl modules should work in just about any unix perl environment,
some modules require perl 5.12 or newer.

The latest release can be installed from CPAN

    cpan install Mnet

Or download and install from L<https://github.com/menzascripting/Mnet>

    tar -xzf Mnet-X.y.tar.gz
    cd Mnet-X.y
    perl Makefile.PL  # INSTALL_BASE=/specify/path
    make test
    make install

Check your PERL5LIB environment variable if INSTALL_BASE was used, or if you
copied the lib/Mnet directory somewhere instead of using the included
Makefile.PL script. Refer to L<ExtUtils::MakeMaker> for more information

=head1 FAQ

Below are answers to some frequently asked questions.

=head2 How should I get started?

Copy the sample script code from the SYNOPSIS above to a new .pl file, read
through the comments, make changes as necessary, use the --debug cli option to
troubleshoot execution.

=head2 What's the easiest way to get more log output?

Use both the L<Mnet::Log> and L<Mnet::Opts::Set::Debug> modules in your script
for more output, mostly from other Mnet modules unless you add L<Mnet::Log>
calls, which are a compatible subset of log4perl calls, to your script.

=head2 How should passwords be secured?

Environment variables should be used to provide passwords for scripts, not
command line options. Command line options can be seen in the system process
list by other users.

The L<Mnet::Opts::Cli> new method allows a named environment variable to be
specified that will also be parsed for command line options. Your perl network
automation script can be called from a secured shell script that contains the
usernames and passwords, this secure shell script accessible only to authorized
users, such as in the example below:

    #!/bin/sh
    #   sample.sh script, chmod 700 to restrict access to current user
    #   works with Mnet::Opts calls in above SYNOPISIS sample.pl script
    #   "$@" passes throuh all command line options, modify as needed
    export Mnet='--username <user> --password <secret>'
    perl -- sample.pl "$@"

The L<Mnet::Opts::Cli> module define function has a redact property that should
be set for password options. The input value for options with redact set are
hidden in L<Mnet::Log> output.

Also note that the L<Mnet::Expect> module log_expect method is used by the
L<Mnet::Expect::Cli> modules to temporarily disable expect session logging
during password entry. Any user code bypassing the L<Mnet::Expect::Cli>
modules to send passwords directly, using the expect method in the
L<Mnet::Expect> module, may need to do the same.

=head2 Why should I use the Mnet::Expect module?

The L<Mnet::Expect> module works with the L<Mnet::Log> and L<Mnet::Opts::Cli>
modules, for easy logging of normal L<Expect> module activity, with options
to control logging, debugging, raw pty, and session tty rows and columns.

However, you still have to handle all the expect session details, including
send and expect calls for logging in, detection of command prompts, capturing
device output, etc. It's easier to use the L<Mnet::Expect::Cli> module which
handles all of this, if you can.

=head2 Why should I use the Mnet::Expect::Cli module?

The L<Mnet::Expect::Cli> module makes it easy to login and obtain outputs from
command line interfaces, like ssh. This module builds on the L<Mnet::Expect>
module mentioned above, adding features to handle a variety of typical username
and password prompts, command prompts, pagination prompts on long outputs, and
caching of session command output.

This module also works with the L<Mnet::Test> module, allowing expect session
activity to be recorded and replayed while offline. This can be of tremendous
value, during development and for sustainability.

Refer also the the L<Mnet::Expect::Cli::Ios> module mentioned below, which has
a couple of features relevant when working with cisco ios and other similar
devices.

=head2 Why should I use the Mnet::Expect::Cli::Ios module?

The L<Mnet::Expect::Cli::Ios> builds on the L<Mnet::Expect::Cli> module
mentioned above, also handling enable mode authentication, the prompt changes
going from user to enable mode, and the prompt changes in configuration modes.

=head1 AUTHOR

The L<Mnet> perl distribution has been created and is maintained by Mike Menza.
Feedback and bug reports are welcome, feel free to contact Mike via email
at <mmenza@cpan.org> with any comments or questions.

=head1 COPYRIGHT AND LICENSE

Copyright 2006 Michael J. Menza Jr.

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

L<Mnet::IP>

L<Mnet::Log>

L<Mnet::Opts::Cli>

L<Mnet::Report::Table>

L<Mnet::Stanza>

L<Mnet::Test>

=cut

# required modules
#   note that cpan complians if use strict is missing
#   perl 5.12 or higer required for some Mnet modules, they all use this module
#       perl 5.8.9 warning: use of "shift" without parentheses is ambiguous
#       see 'use x.xxx' commands in other modules for additional info
#       update Makefile.PL and INSTALLATION in this perldoc if changed
use warnings;
use strict;
use 5.012;

# normal end of package
1;

