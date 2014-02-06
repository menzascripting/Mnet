package Mnet::Expect;

=head1 NAME

Mnet::Expect - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

Usage examples:

 use Mnet;
 use Mnet::Expect;
 my $cfg = &object;
 my $expect1 = new Mnet::Expect or die;
 my $sh_ver_out = $expect1->command("show version");
 $expect1->close("exit");
 my $expect2 = new Mnet::Expect({
     'object-address'  => 'hub1-rtr',
     'expect-username' => 'jdoe',
 }) or die;
 my $sh_int_out = $expect2->command("show interface");
 $expect2->close("exit");

=head1 DESCRIPTION

This mnet expect module can be used to create new expect sessions,
send commands and receive the output of those commands.

By default Expect will be used to attempt a device connection, 
trying ssh first and then telnet. The expect-command settings may
be used to change the commands used to connect, or to specify that
Net::Telnet be used instead of Expect.

This mnet expect module uses a perl object for each session. An
invoking script can open as many sessions as necessary.

Each call to create a new session can be passed an optional
hash reference of config settings. The object-address set for the
invoking script can be changed for the new expect session. Also
other expect config settings such as username, the default read
timeout, etc. can be set or changed from default. Refer to the
configation section below for more information.

A new expect session will attempt to login using the current
expect-username and expect-password config option values.

The expect-enable setting is ignored if not changed from its
default value. If set as a value of one then the terminal user
will be prompted for an enable mode password. Any other value
set for expect-enable is considered the enable password to be
used when connecting to a new expect session.

The expect-batch option is enabled by default and will prompt the
user terminal once if the script is run in batch-list mode for
the expect-username and expect-password, unless they are already
set. A prompt expect-enable password is generated in batch mode
if it is set true.
  
The expect module command method should be used when a command
prompt is returned after command entry and command output. The
send and clear methods exist to handle other situations. It is
also possible to access the underlying Expect module properties
and methods stored in the objects created by this module.

The expect-replay and expect-record settings can be used for
testing. Session activity can be recorded to a file and replayed
back from the file at a later time. Calls to the new, close and
command functions can be recorded. These arguments would usually
be used from the command line, but could be passed when creating
a new Mnet::Expect object.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --object-address <addr>          address expect will connect to
 --object-name <object>           host name expect will connect to
 --expect-bastion <host>          set to specify host for bastion login
 --expect-bastion-command <cmd>   defaults ssh -p port user@bastion
 --expect-bastion-password <pass> bastion host password, default unset
 --expect-bastion-port <1-65535>  bastion host ssh port, default 22
 --expect-bastion-username <user> defaults to expect-username
 --expect-batch                   default input user, pass, enable once
 --expect-command <cmd>           default enabled, set ssh or telnet
 --expect-command1 <cmd>          defaults to ssh
 --expect-command2 <cmd>          defaults to telnet
 --expect-command3 <cmd>          defaults to ssh with no key checking
 --expect-command4 <cmd>          defaults to telnet with -K option
 --expect-detail                  enable for extra expect debug detail
 --expect-detail-clean            enable for expect clean func detail
 --expect-enable <1|pass>         1 will prompt, default disabled
 --expect-nologin                 disables expect-command login code
 --expect-noverify                set for rsa tokens, no password verify
 --expect-password <pass>         specify password, default will prompt
 --expect-port-ssh <0-65535>      default 22, port connection for ssh
 --expect-port-telnet <0-65535>   default 23, 0 to disable net::telnet
 --expect-prompt-badopen <regex>  default to recognize bad connection
 --expect-prompt-badpass <regex>  default to recognize bad password
 --expect-prompt-command <regex>  default to recognize command prompt
 --expect-prompt-enable <regex>   default to '#' for enable prompt
 --expect-prompt-paging <regex>   default to recognize more prompt
 --expect-prompt-goodpass <regex> default to recognize password prompt
 --expect-prompt-username <regex> default to recognize username prompt
 --expect-record <file>           record the session commands in a file
 --expect-replay <file>           replay file created with expect-record
 --expect-retries <0+>            default 0 retries for new session
 --expect-version                 set at compilation to build number
 --expect-stderr <0|1|all>        default 0=none, set 1=login, 2=all
 --expect-telnet-timeout <1+>     initial tcp timeout, default 15 secs
 --expect-term <termcap>          defaults to dumb termcap entry
 --expect-timeout-command <1+>    during command output, default 45 secs
 --expect-timeout-login <1+>      login prompt timeout, default 30 secs
 --expect-username <user>         login user or null, default prompts

Note: Multiple expect-command options can be set. They will be tried
one after the other for each connection attempt if expect-command is
left set as true. When successfully connected the working command will
be left as expect-command. If expect-command is set to the keyword ssh
or telnet then only matching expect commands 1-4 will be tried. If
expect-command is set to some other text then that expect-command only
will be attempted. If expect-command is set clear then the Net::Telnet
module only will be used to connect.

Note: expect-prompt-command is a regex prompt match pattern that can
be changed. This regex is used during initial login, and also from
the command method. To handle prompts that may change the $1 variable
should be set in the regex to the beginning part of a prompt that is
not expected to change.

List of hidden properties and methods used by this module:

 _expect                   perl Expect module session object
 _expect-logfile-dtl       dtl logs of session activity, not dbg
 _expect-login-auth        set when login authentication in progress
 _expect-telnet            perl Net::Telnet session, if exists

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and libraries:

=cut

# modules used
use warnings;
use strict;
use Carp;
use Expect;
use Mnet;
use Net::Telnet;
use Time::HiRes;

# module initialization
BEGIN {

    # access config and set package defaults
    our $cfg = &Mnet::config({
        'expect-bastion-command'
            => 'ssh -p {expect-bastion-port} '
             .  '{expect-bastion-username}@{expect-bastion}',
        'expect-bastion-port'    => 22,
        'expect-batch'           => 1,
        'expect-command'         => 1,
        'expect-command1'
            => 'ssh -p {expect-port-ssh} -o UserKnownHostsFile=/dev/null '
             . '-o StrictHostKeyChecking=no {expect-username}@{object-address}',
        'expect-command2'
            => 'telnet {object-address} {expect-port-telnet}',
        'expect-command3'
            => 'ssh -p {expect-port-ssh} {expect-username}@{object-address}',
        'expect-command4'
            => 'telnet -K {object-address} {expect-port-telnet}',
        'expect-enable'          => 0,
        'expect-prompt-enable'   => '#',
        'expect-port-ssh'        => 22,
        'expect-port-telnet'     => 23,
        'expect-prompt-badopen'
            => '(?i)(can.t assign requested address|can.t be established.|'
             . 'fail|refuse|denied|sorry|timed out)\s*(\r|\n)',
        'expect-prompt-badpass'
            => '(?i)(error|denied|fail|incorrect|invalid|sorry)',
        'expect-prompt-command'  => '^(\S+)\s?(>|#|\$|\(|\%).*$',
        'expect-prompt-paging'   => '--(M|m)ore--',
        'expect-prompt-goodpass' => '\s*(?i)pass(word|code):?\s*\r?$',
        'expect-prompt-username' => '\s*(?i)(login|user(name)?):?\s*\r?$',
        'expect-version'        => '+++VERSION+++',
        'expect-term'            => 'dumb',
        'expect-timeout-login'   => 30,
        'expect-timeout-command' => 45,
        'expect-telnet-timeout'  => 15,
    });

    # init storage for replay file contents
    my $expect_replay = '';

    # set input for username and passwords if batch mode configured
    if ($cfg->{'batch-list'} and $cfg->{'expect-batch'}) {
        &Mnet::input("expect-username");
        &Mnet::input("expect-password", "hide");
        &Mnet::input("expect-enable", "hide")
            if $cfg->{'expect-enable'} and $cfg->{'expect-enable'} eq '1';
    }

# end of module initialization
}



sub clean {

# internal: $text = &clean($text)
# purpose: used to remove strange output characters from $text
# note: will output extra debug detail if expect-detail-clean set

    # read text arg, remove upper ascii, backspaces and linefeeds
    my $text = shift;
    my $original = $text;
    $text =~ s/[\x80-\xFF]//g;
    $text =~ s/^(\x08)(\x08|\s)+(\x08)//m;
    $text =~ s/\r//g;
    if ($Mnet::Expect::cfg->{'expect-detail-clean'}) {
        sub chars {
            my $output = "";
            for my $letter (split(//, shift)) {
                my $dletter = $letter;
                $dletter = "." if $letter =~ /(\r|\n|\t)/;
                $output .= " $dletter," . sprintf("%02x", ord($letter));
            }
            return $output;
        }
        &dtl("clean before =" . &chars($original));
        &dtl("clean after  =" . &chars($text));
    }
    return $text;
}



sub clear {

=head2 clear method

 $expect->clear

This is a low level method that can be used to clear any data
currently in a session expect buffer.

Typically this would only be used when bypassing the command
method by using the send method or directly calling the
underlying Expect methods stored in objects created by this
module.

=cut

    # read instance arg, log debug message, clear buffer and return
    my $self = shift;
    croak "not called as an instance" if not ref $self;
    $self->dtl("clear sub called from " . lc(caller));
    return if $self->{'expect-replay'};
    while ($self->{'_expect'}->expect(1, "-re", '\S')) {
        $self->{'_expect'}->clear_accum;
    }   
    return;
}



sub close {

=head2 close method

 $expect->close($exit);

Closes the current expect session, sending optional exit command
first.  A hard close is then called for on the session.

Note that the _expect object is set to undefined as part of the
close process.

=cut

    # send optional exit text then do a hard close on session
    my ($self, $exit) = @_;
    croak "not called as an instance" if not ref $self;
    $self->dbg("close sub called from " . lc(caller));
    if ($self->{'expect-replay'}) {
        $self->{'_expect'} = undef;
        return;
    }

    # send exit command if defined
    if (defined $exit) {
        if (not ref $self->{'_expect'}
            or not $self->{'_expect'}->can('send')) {
            $self->dtl("close cannot access expect send for $exit command");
        } else {
            $self->dtl("close sending $exit command");
            $self->{'_expect'}->send("$exit\r")
                or $self->dtl("close unable to confirm sending $exit command");
        }
    }
    
    # attempt to execute hard close
    if (not ref $self->{'_expect'}
        or not $self->{'_expect'}->can('hard_close')) {
        $self->dtl("close cannot access expect hard_close");
    } else {
        $self->dtl("close executing hard_close");
        $self->{'_expect'}->hard_close()
            or $self->dtl("close unable to confirm hard close");
    }

    # close complete
    $self->{'_expect'} = undef;
    $self->dbg("close session complete");

    # finished close method
    return;
}



sub command {

=head2 command method

 $output = $expect->command($command, $timeout, \%prompt_answers)

The purpose of this method is to retrieve the output for the
specified command sent over the already defined expect session.

Output will be set to undefined if there are prompt or timeout
problems.

The command method should only be used already logged in and at
a command prompt in the expect session. Also it is required that
the expect session return to a command prompt within the timeout
after running the input command. The command prompts do not need
to be identical, but the prompts must start at the beginning of a
line and match up to the first special character.

The specified $command is sent to the device. The $timeout
parameter is an optional timeout waiting for output to start.
Otherwise output must stall for expect-timeout-command seconds for
a timeout error to be logged.

The command method will stop gathering output when a prompt is
returned on a new line. The command method knows how to send a
space for paging if a 'more paging' prompt is returned.

The optional prompt_answers hash reference can be used to handle
special prompts that occur after entering a command, such as
confirmation prompts. The hash should contain regex keys and
response values. The regex key string values should be what goes
in between the forward slash characters of a regular expression.
These responses are sent without a carriage return - append a /r
or /n to send the response with a carriage return.

If a prompt answer key is set to an undefined hash value then the
reponse will be to immediately return the matching output.

If the prompt answer undefined hash key is is to a value of undef
then this method will return a value of undef if the command
times out.

=cut

    # read args, set default output start timeout
    my ($self, $command, $timeout, $prompt_answers) = @_;
    croak "not called as an instance" if not ref $self;
    $self->dtl("command sub called from " . lc(caller));
    $command="" if not defined $command;
    $timeout=$self->{'expect-timeout-command'} if not defined $timeout;
    my $delim = '----:::: expect data ::::----';
    my $output = '';

    # output debug entry for command
    $self->dbg("command '$command' timeout ${timeout}s");

    # read command output if expect-replay is enabled
    if ($self->{'expect-replay'} and $Mnet::Expect::expect_replay) {
        $Mnet::Expect::expect_replay =~ s/^COMMAND:\Q$command\E\n\Q$delim\E\n//
            or croak "expect-replay expected '$command' as next line";
        $output = $Mnet::Expect::expect_replay;
        $output =~ s/\Q$delim\E\n((\S|\s)*)$//;
        $Mnet::Expect::expect_replay = $1;
        foreach my $line (split(/\n/, $output)) {
            $self->dbg("|| $line");
        }
        croak "expect-replay $self->{'expect-replay'} output error"
            if $output =~ /\Q$delim\E/;

    # retrieve command output from real expect session
    } else {

        # build prompt match list from input prompt answers
        my @prompt_matches = ();
        my @prompt_responses = ();
        my $response_count = 3;
        foreach my $key (keys %$prompt_answers) {
            push @prompt_matches, '-re';
            push @prompt_matches, $key;
            $prompt_responses[$response_count] = $prompt_answers->{$key};
            my $display = "undef";
            $display = "'" . $prompt_answers->{$key} . "'"
                if defined $prompt_answers->{$key};
            $self->dtl("prompt_response $response_count, $key = $display");
            $response_count++;
        }

        # check on current prompt and exit or return on errors
        my $prompt = $self->prompt;
        return $self->expect_err('unable to find command prompt')
            if not defined $prompt or $prompt !~ /\S/;

        # set timeout for complete output stall only, not output completion
        $self->{'_expect'}->restart_timeout_upon_receive(1);

        # clear any old expect data and send command 
        $self->{'_expect'}->clear_accum;
        $self->dtl("sending command $command");
        $self->{'_expect'}->send("$command\r");

        # loop to collect all command output until next command prompt
        while (1) {

            # retrieve output text until possible command prompt or more prompt
            my $match = $self->{'_expect'}->expect($timeout,
                '-re', '\n\r?'.$prompt.'.*\r?$',
                '-re', '\n\r?\s*'.$self->{'expect-prompt-paging'}.'.*\r?$',
                @prompt_matches);

            # reset this
            $self->{'_expect-logfile-dtl'} = 0;

            # return without error with undefined prompt response on timeout
            if (not defined $match and not defined $prompt_answers->{undef}) {
                $self->dbg("returning on undefined prompt_response undef");
                $output = undef;
                last;
            }

            # exit or return if command timed out
            return $self->expect_err("timeout on command '$command'")
                if not defined $match;

            # set timeout after first output to normal read timeout
            $timeout = $self->{'expect-timeout-command'};

            # chomp and clean retrieved output before possible prompt
            chomp( my $new_before = &clean($self->{'_expect'}->before) );
            chomp( my $new_match = &clean($self->{'_expect'}->match) );

            # handle special prompt matches and prompt answer responses
            if ($match > 2) {
                $output .= $new_before . $new_match;
                if (not defined $prompt_responses[$match]) {
                    $self->dbg("returning on undefined prompt_response $match");
                    last;
                }
                my $response = $prompt_responses[$match];
                $response =~ s/\n/\r/g;
                $self->dtl("sending prompt_response $match");
                $self->{'_expect'}->send($response);

            # handle more prompt by appending new output sending a space
            } elsif ($match == 2) {
                $output .= "$new_before\n";
                $self->dtl("responding to more prompt");
                $self->{'_expect'}->send(" ");

            # append output and send enter key to test we are at command prompt
            } elsif ($new_before =~ /\S/) {
                $output .= $new_before . "\n" . $new_match;
                $self->dtl("responding to candidate command prompt");
                $self->{'_expect-logfile-dtl'} = 1;
                $self->{'_expect'}->send("\r");

            # exit loop if we get prompt right away and have output already
            } elsif ($new_before !~ /\S/ and $output ne "") {
                $self->dtl("exiting command loop on detected prompt");
                $output =~ s/\r?\n$prompt.*\r?$//;
                last;
            }

        # continue looping to collect command output
        }

        # remove echod command from start of output and restore normal timeout
        $output =~ s/^[^\n]*\Q$command\E\s*\n// if defined $output;
        $self->{'_expect'}->restart_timeout_upon_receive(0);

    # finished session command
    }

    # chomp output and make log entry for returned command output
    if (defined $output) {
        chomp($output);
        my $len = length($output);
        $self->dbg("command '$command' returned $len chars");
    } else {
        $self->dbg("command '$command' returned undefined output");
    }

    # save command output if expec-record is enabled
    if ($self->{'expect-record'}) {
        my $record_output = $output;
        $record_output = "" if not defined $output;
        $record_output = "COMMAND:$command\n$delim\n$record_output\n$delim\n";
        open(FILE, ">>$self->{'expect-record'}")
            or croak "expect-record $self->{'expect-record'} append err $!";
        print FILE $record_output
            and $self->dbg("expect-record saved '$command' output");
        $Mnet::Expect::expect_replay .= $record_output;
        CORE::close FILE;
    }

    # finshed command method
    return $output;
}



sub connect {

# internal: $success = $self->connect
# purpose: attempt to connect expect session to object

    # read instance
    my $self = shift;
    croak "not called as an instance" if not ref $self;

    # set the number of attempts we will make to start the session
    my $attempts = $self->{'expect-retries'};
    $attempts = 0 if not $attempts or $attempts !~ /^\d+$/;
    $attempts = $attempts + 1;

    # set termcap
    $self->dtl("setting term env variable to $self->{'expect-term'}");
    $ENV{'TERM'} = $self->{'expect-term'};

    # set descriptive object name and/or address
    my $object_text = $self->{'object-name'};
    $object_text .= " ($self->{'object-address'})"
        if $self->{'object-name'} ne $self->{'object-address'};

    # log use of bastion
    if ($self->{'expect-bastion'} and $self->{'expect-bastion-command'}) {
        my $bastion_cmd = $self->{'expect-bastion-command'};
        $bastion_cmd =~ s/\{([^\}]+)\}/$Mnet::Expect::cfg->{$1}/g;
        $self->inf("using bastion host $self->{'expect-bastion'}");
        $self->dbg("bastion host $self->{'expect-bastion'} cmd $bastion_cmd");
    }

    # initialize connection success flag
    my $success = 0;

    # cycle through retries
    for (my $loop = 1; $loop <= $attempts; $loop++) {
        $self->dbg("new session attempt $loop");

        # loop through expect commands 1-4, attempt to connect based on config
        foreach my $command ('expect-command', 'expect-command1',
            'expect-command2', 'expect-command3', 'expect-command4') {

            # skip these connection attempts if expect-command is clear
            next if not $self->{'expect-command'};

            # skip current connection attempt if current command doesn't exist
            next if not $self->{$command};

            # skip current connection if it is expect-command set reserved
            next if $command eq 'expect-command'
                and $self->{$command} =~ /^(1|telnet|ssh)$/;

            # skip if expect-command keyword ssh or telnet no match for current
            next if $self->{'expect-command'} =~ /^(telnet|ssh)$/
                and $self->{$command} !~ /^\S*$1/;

            # attempt to connect using current command, or continue loop
            next if not $self->expect_connect($self->{$command});

            # set expect-command to what worked
            $self->{'expect-command'} = $self->{$command}
                if $self->{'expect-command'} eq "1";

            # exit loop with success flag set
            $success = 1;
            last;

        # finished looping through expect command connection attempts
        }

        # attempt Net::telnet if expect command was clear
        $success = $self->expect_connect if not $self->{'expect-command'};

        # exit retry loop on success
        last if $success;

    # continue looping through retries
    }

    # return undefined if unable to create new expect session
    return $self->expect_err("new session to $object_text failed")
        if not $success;

    # log new expect session initiated, and return
    $self->dbg("new session to $object_text initiated");
    return 1;
}



sub expect_connect {

    # internal: $self->expect_connect($expect_command)
    # purpose: method to handle attempt to login using expect session

    # read instance data
    my ($self, $expect_command) = @_;
    croak "not called as an instance" if not ref $self;
    $self->dtl("expect_connect sub called from " . lc(caller));

    # reset some stuff
    $self->{'_expect-logfile-dtl'} = 0;

    # create new expect session
    $self->dbg("session initiating");
    $self->{'_expect'} = undef;
    $self->{'_expect'} = new Expect;
    $self->{'_expect'}->raw_pty(1);
    $self->{'_expect'}->log_stdout(0);

    # set description for start messages
    my $start_txt = "to $self->{'object-name'}";

    # handle net::telnet connection and return early
    if (not $self->{'expect-command'} and $self->{'expect-port-telnet'}) {

        # output net telnet session start to stderr, if configured
        $start_txt = "net telnet $start_txt";
        $start_txt .= " ($self->{'object-address'})"
            if $self->{'object-address'} ne $self->{'object-name'};
        $self->inf("start $start_txt");
        $self->expect_stderr("\n\nSTART: $start_txt\n\n");

        # connect net::telnet to object-address on expect-port-telnet
        my $dbg_text = "Net::Telnet to $self->{'object-address'} ";
        $dbg_text .= "port $self->{'expect-port-telnet'} initiating";
        $self->dbg($dbg_text);
        $self->{'_expect-telnet'} = new Net::Telnet(
            Errmode => "return",
            Host    => $self->{'object-address'},
            Port    => $self->{'expect-port-telnet'},
            Timeout => $self->{'expect-telnet-timeout'},
        );
        return $self->expect_err("session error $!")
            if not $self->{'_expect-telnet'};
        $self->{'_expect-telnet'}->max_buffer_length(1024*1024);
        $self->dbg("Net::Telnet session initiated");

        # connect with expect to net::telnet session
        $self->dbg("connecting to telnet session");
        $self->{'_expect'} = Expect->exp_init($self->{'_expect-telnet'})
        or return $self->expect_err("connect error to telnet session");
        $self->dbg("connected to Net::Telnet session");

        # initiate session logging
        $self->{'_expect'}->raw_pty(1);
        $self->{'_expect'}->log_stdout(0);
        $self->dbg("enabling session log");
        $self->{'_expect'}->log_file(sub { &expect_logfile($self, shift); })
            or return $self->expect_err("expect logging init error $!");

        # handle expect-nologin, or null username and password
        if ($self->{'expect-nologin'}
            or $self->{'expect-username'} eq ''
            and $self->{'expect-password'} eq '') {
            $self->inf("connected to $self->{'object-name'}");

        # handle expect-command with normal username/password/enable login code
        } else {
            $self->expect_login(
                'expect-username',
                'expect-password',
                'expect-enable',
                $start_txt,
            ) or return undef;
            $self->inf("logged into $self->{'object-name'}");
        }

        # log new expect session initiated and return
        return $self;

    # return early if no expect command nor bastion host is configured
    } elsif (not $self->{'expect-command'}
        and not $self->{'bastion-host'}) {

        # log new expect session initiated and return
        $self->inf("connected to empty session");
        return $self;

    # continue with more flexible expect-command and optional expect-bastion
    }

    # bastion host command spawn 
    if ($self->{'expect-bastion'}) {

        # default expect-bastion-username to expect-username
        $self->{'expect-bastion-username'} = $self->{'expect-username'}
            if not $self->{'expect-bastion-username'};

        # perform substitutions on expect-command, if configured
        $self->dbg("bastion '$self->{'expect-bastion-command'}' init");
        my $expect_cmd = $self->{'expect-bastion-command'};
        $expect_cmd =~ s/\{([^\}]+)\}/$Mnet::Expect::cfg->{$1}/g;

        # remove leading @ when username is blank, usually needed for ssh
        $expect_cmd =~ s/\s\@/ / if not $self->{'expect-username'};

        # attempt to connect using expect-command
        my ($command, @parameters) = (split(/\s+/, $expect_cmd));
        $self->dbg("bastion $command, parameters '@parameters'");
        my $start_bastion_txt = "bastion '$command @parameters'";
        $start_bastion_txt .= " to $self->{'expect-bastion'}";
        $self->expect_stderr("\n\nSTART: $start_bastion_txt\n\n");
        $self->{'_expect'} = Expect->spawn($command, @parameters)
            or return $self->expect_err("spawn error to bastion $command");
        $self->dbg("bastion $command spawned");

        # initiate session logging
        $self->dbg("enabling session log");
        $self->{'_expect'}->raw_pty(1);
        $self->{'_expect'}->log_stdout(0);
        $self->{'_expect'}->log_file(sub { &expect_logfile($self, shift); })
            or return $self->expect_err("expect logging init error $!");

        # attempt login into bastion host
        my $success = $self->expect_login(
            'expect-bastion-username',
            'expect-bastion-password',
            undef,
            $start_bastion_txt,
        );
        return undef if not $success;

        # return if no expect command is configured with bastion host
        if ($self->{'bastion-host'} and not $self->{'expect-command'}) {
            $self->inf("connected to bastion $self->{'expect-bastion'}");
            return $self;
        }

        # send expect-command from bastion host session
        $self->clear;
        $self->dbg("command '$expect_command' initiating");
        $expect_cmd = $expect_command;
        $expect_cmd =~ s/\{([^\}]+)\}/$Mnet::Expect::cfg->{$1}/g;
        ($command, @parameters) = (split(/\s+/, $expect_cmd));
        $start_txt = "bastion command connect $start_txt";
        $self->inf("start $start_txt");
        $self->dbg("sending bastion command '$command @parameters'");
        $self->{'_expect'}->send("$expect_cmd\r");
        
    # command spawn
    } else {

        # attempt to initiate session using expect-command, if configured
        $self->dbg("expect command '$expect_command' initiating");
        my $expect_cmd = $expect_command;
        while ($expect_cmd =~ /\{([^\}]+)\}/) {
            my $tmp = $1;
            if (not defined $Mnet::Expect::cfg->{$tmp}
                and $tmp eq 'expect-username') {
                my $user = $ENV{'USER'};
                my $err = "'$expect_command' requires $tmp to be available";
                return $self->expect_err("expect-command $err")
                    if not defined $user;
                $expect_cmd =~ s/\{\Q$tmp\E\}/$user/g;
            } elsif (not defined $Mnet::Expect::cfg->{$tmp}) {
                my $err = "'$expect_command' requires $tmp to be configured";
                return $self->expect_err("expect-command $err");
                $expect_cmd =~ s/\{\Q$tmp\E\}//g;
            } else {
                $expect_cmd =~ s/\{\Q$tmp\E\}/$Mnet::Expect::cfg->{$tmp}/g;
            }
        }
        my ($command, @parameters) = (split(/\s+/, $expect_cmd));
        $self->inf("start $command $start_txt");
        $start_txt = "command '$command @parameters' $start_txt";
        $self->dbg("spawning command '$command @parameters' $start_txt");
        $self->expect_stderr("\n\nSTART: $start_txt\n\n");
        $self->{'_expect'} = Expect->spawn($command, @parameters)
            or return $self->expect_err("spawn error to command $command");
        $self->dbg("command $command spawned");

        # initiate session logging
        $self->dbg("enabling session log");
        $self->{'_expect'}->raw_pty(1);
        $self->{'_expect'}->log_stdout(0);
        $self->{'_expect'}->log_file(sub { &expect_logfile($self, shift); })
            or return $self->expect_err("session logging init error $!");

    # we now have a expect session to object-address
    }

    # handle login if username or password is set
    if ($self->{'expect-nologin'}) {
        $self->inf("connected to $self->{'object-name'}");
    } else {
        $self->expect_login(
            'expect-username',
            'expect-password',
            'expect-enable',
            $start_txt,
        ) or return undef;
        $self->inf("logged into $self->{'object-name'}");
    }

    # log new expect session initiated, and return
    $self->dtl("expect_connect method finished");
    return $self;
}



sub expect_err {

# internal: undef = $self->expect_err($text);
# purpose: debug and expect-stderr text output

    my ($self, $text) = @_;
    croak "not called as an instance" if not ref $self;
    croak "missing expect_err text" if not defined $text;
    my $trace = Carp::longmess;
    $self->inf("error $text");
    $self->dbg("error $_") foreach split(/\n/, $trace);
    $self->expect_stderr("\n\nERROR: $text\n\n");
    return undef;
}



sub expect_logfile {

# internal: $self->expect_logfile($text)
# purpose: output expect session activity to debug log

    # read instance and text to log
    my ($self, $text) = @_;
    $text = $self if not ref $self and not defined $text;
    
    # return if called with no text to output
    return if not defined $text;

    # normalize end of line characters
    $text =~ s/\r?\n\r?/\n/g;

    # loop through each line of session activity
    foreach my $line (split(/\n/, $text)) {
        if ($self->{'_expect-logfile-dtl'}) {
            $self->dtl("session | $line");
        } else {
            if ($self->{'expect-stderr'}) {
                $self->expect_stderr("$line\n")
                    if $self->{'expect-stderr'} =~ /^all$/i
                    or $self->{'_expect-login-auth'};
            }
            $self->dbg("session | $line");
        }
    }

    # finished
    return;
}



sub expect_login {

# internal: $success = $self->expect_login($username,$password,$enable,$text);
# purpose: handle login auth prompts for already connected session
# $username: config setting with username, such as 'expect-username'
# $password: config setting with password, such as 'expect-bastion-password'
# $enable: config setting with enable password, such as 'expect-enable'
# $text: descriptive stderr text, such as 'neti telnet to localhost (127.0.0.1)'
# note: username, password, enable and/or text are optional

    # read instance data
    my ($self, $username, $password, $enable, $text) = @_;
    croak "not called as an instance" if not ref $self;
    $self->dtl("expect_login sub called from " . lc(caller));
    return 1 if $self->{'expect-replay'};

    # starting login auth
    $self->{'_expect-login-auth'} = 1;
    $self->expect_stderr("\n\nLOGIN: $text\n\n") if $text;

    # wait for first username or password prompt
    $self->dbg("waiting for first prompt");
    my $prompt = $self->{'_expect'}->expect($self->{'expect-timeout-login'},
        '-re', $self->{'expect-prompt-username'},
        '-re', $self->{'expect-prompt-goodpass'},
        '-re', $self->{'expect-prompt-badopen'},
        '-re', $self->{'expect-prompt-command'},
    );

    # hit enter and look one more time for first prompt
    if (not defined $prompt) {
        $self->dbg("still waiting for first prompt");
        $self->{'_expect'}->send("\r");
        $prompt = $self->{'_expect'}->expect($self->{'expect-timeout-login'},
            '-re', $self->{'expect-prompt-username'},
            '-re', $self->{'expect-prompt-goodpass'},
            '-re', $self->{'expect-prompt-badopen'},
            '-re', $self->{'expect-prompt-command'},
        ) or return $self->expect_err("no first prompt");
    }

    # log first prompt response
    my $match = $self->{'_expect'}->match;
    $match =~ s/(\s\s+|\r?\n\r?|\r)/ /g;
    $self->dtl("first prompt=$prompt, match=$match");

    # return right away on connect refused, timed out, etc
    return $self->expect_err("received badopen message") if $prompt == 3;

    # initialize first line received
    my $line = '';

    # enter username when prompted and check for next prompt
    if ($prompt == 1) {
        $self->dbg("received username prompt");
        if (not $self->{$username}) {
            $self->input($username);
            $self->{$username} = $Mnet::Expect::cfg->{$username};
        }
        $self->dbg("sending username");
        $self->{'_expect'}->send("$self->{$username}\r");
        $self->dbg("waiting for next prompt");
        $prompt = $self->{'_expect'}->expect($self->{'expect-timeout-login'},
            '-re', $self->{'expect-prompt-username'},
            '-re', $self->{'expect-prompt-goodpass'},
            '-re', $self->{'expect-prompt-command'},
        ) or return $self->expect_err("no next prompt");
        my $match = $self->{'_expect'}->match;
        $match =~ s/(\s\s+|\r?\n\r?|\r)/ /g;
        $match =~ s/(^\s+|\s+$)//g;
        $self->dtl("next prompt=$prompt, $match");

        # attempt password if echod username triggering expect-prompt-username
        if ($prompt == 1 and $self->{$username} =~ /\Q$match\E/i) {
            $self->dbg("unsure of what happened, got part of username back");
            $prompt =$self->{'_expect'}->expect($self->{'expect-timeout-login'},
                '-re', $self->{'expect-prompt-username'},
                '-re', $self->{'expect-prompt-goodpass'},
                '-re', $self->{'expect-prompt-command'},
            ) or return $self->expect_err("no next prompt");
        }

    # finished handling first username prompt
    }

    # return an error if the username prompt comes up yet again
    if ($prompt == 1) {
        return $self->expect_err("unable to get past username prompt");

    # handle password prompt
    } elsif ($prompt == 2) {

        # send login password and check that it was accepted
        $self->dbg("received password prompt");
        my $temp_password = $self->{$password};
        if (not $temp_password) {
            $temp_password = $self->input(
                $password, 'hide', $self->{'expect-noverify'}
            );
        }
        $self->dbg("sending password");
        $self->{'_expect'}->send("$temp_password\r");
        $line = $self->read;
        return $self->expect_err("password not accepted")
            if not defined $line
            or $line =~ /$self->{'expect-prompt-badpass'}/i;

        # retrieve current prompt
        $self->dbg("password accepted");

    # finished handling username and/or password
    }

    # log that we already appear to be in enable mode
    if ($line =~ /$self->{'expect-prompt-enable'}/) {
        $self->dbg("enable mode prompt present");

    # attempt to enter enable mode if configured, always set from expect-enable
    } elsif ($enable and $self->{$enable}) {

        # ensure that we have a command prompt
        $self->prompt;

        # enter enable mode command
        $self->dbg("sending enable command");
        $self->{'_expect'}->send("enable\r");
        $self->{'_expect'}->expect($self->{'expect-timeout-login'},
            '-re', '(?i)password:?')
            or return $self->expect_err("no enable password prompt");

        # input expect enable password if necessary
        my $temp_enable = $self->{$enable};
        if ($temp_enable eq "1") {
            $temp_enable = $self->input(
                $enable, "hide", $self->{'expect-noverify'}
            );
        }

        # enter enable password
        $self->dbg("sending enable password");
        $self->{'_expect'}->send("$temp_enable\r");

        # check that enable password was accepted
        my $line = $self->read;
        return $self->expect_err("enable password failed")
            if not defined $line
                or $line =~ /$self->{'expect-prompt-badpass'}/i;
        $self->dbg("enable password accepted");
    }

    # clear expect buffer
    $self->clear;

    # ensure we have a good command prompt
    $self->prompt;

    # finished login activity
    $self->{'_expect-login-auth'} = 0;

    # finished expect_login method
    return 1;
}



sub expect_stderr {

# internal: &expect_stderr($text);
# purpose: expect-stderr text output

    # read text arg, output if expect-stderr is set and return
    my ($self, $text) = @_;
    croak "not called as an instance" if not ref $self;
    return if not defined $text;
    syswrite STDERR, &clean($text) if $self->{'expect-stderr'};
    return;
}



sub new {

=head2 new class method

 $expect = new Mnet::Expect(\%args)

Creates a new expect session object. Default expect module config
settings, or settings in effect, may be changed with the optional
hash reference argument. This can be used to connect to different
hosts specified by object-address as an ip address or resolvable
domain name.

The user will be prompted on the terminal to enter a username,
password and enable password if necessary. The prompts for the
expect-username and expect-password are generated if these values
are undefined.

If expect-enable is set then an enable mode login will be
attempted from a command prompt after user mode login. The user
is prompted for the enable password is expect-enable is set to a
value of 1.

Note that a telnet session is opened if the username and password
are set to null values, without prompting or executing a login.
This can be used to handle custom login scenarios.

Also note that the expect-command setting can be used to open a
session using something besides telnet, such as ssh.

=cut

    # read optional input args and set up new class instance
    my ($class, $args) = @_;
    $args = {} if not defined $args;
    croak "new method for class only" if ref $class;
    croak "invalid expect config args" if ref $args ne "HASH";
    &dtl("new sub called from " . lc(caller));
    my $self = &config({}, $args);
    bless $self, $class;

    # dump new object data
    &dump("new", $self);

    # read expect-replay file and return right away
    if ($self->{'expect-replay'}) {
        if (not $Mnet::Expect::expect_replay or $args->{'expect-replay'}) {
            $Mnet::Expect::expect_replay = '';
            $self->dbg("reading expect-replay $self->{'expect-replay'}");
            open(FILE, $self->{'expect-replay'}) or croak
                "expect-replay file $self->{'expect-replay'} open err $!";
            while (<FILE>) { $Mnet::Expect::expect_replay .= $_; }
            CORE::close FILE;
            $self->dbg("finished reading expect-replay file");
        }
        $self->dbg("returning new expect-replay session");
        return $self;
    }

    # remove any old expect-record file
    if ($self->{'expect-record'} and not $Mnet::Expect::expect_replay
        or $args->{'expect-replay'}) {
        $Mnet::Expect::expect_replay = '';
        $self->dbg("creating expect-record $self->{'expect-record'}");
        unlink($self->{'expect-record'})
            or croak "expect-record $self->{'expect-record'} del err $!"
            if -e $self->{'expect-record'};
        $self->dbg("old expect-record $self->{'expect-record'} erased");
    }

    # return undefined if unable to connect to expect session
    return undef if not $self->connect;

    # finished new classs method
    return $self;
}



sub prompt {

# internal: $prompt = $expect->prompt
# purpose: verify we are at a command prompt and set for future use
# $prompt: return current command prompt or undefined
# note: prompt starts at beginning of line
# note: prompt ends before the first special character
# note: prompt repeats when carriage return is sent

    # read instance data
    my $self = shift;
    croak "not called as an instance" if not ref $self;
    croak "call not supported with expect-replay" if $self->{'expect-replay'};

    # debug log for prompt determination
    $self->dtl("determining current prompt");
    $self->{'_expect-logfile-dtl'} = 1;
    
    # initialize possible prompt and start a loop
    my ($prompt1, $prompt2) = ("", "");
    my $count = 0;
    while (1) {
        $count++;

        # clear read accumulator in expect session
        $self->clear if not $self->{'expect-replay'};

        # hit enter and parse possible prompt line
        $self->{'_expect'}->clear_accum;
        $self->{'_expect'}->send("\r");
        $prompt1 = $self->read;
        if (defined $prompt1) {
            chomp $prompt1;
            $prompt1 =~ s/.*(\n|\r)//;
            $prompt1 =~ s/(^\s+|\s+$)//g;
            $self->dtl("debug prompt1 '$prompt1'");
        } 

        # return with error if timeout determining prompt
        if (not defined $prompt1) {
            carp "timeout determining prompt";
            return undef;
        }

        # hit enter and parse possible prompt line
        $self->{'_expect'}->clear_accum;
        $self->{'_expect'}->send("\r");
        $prompt2 = $self->read;
        if (defined $prompt2) {
            chomp $prompt2;
            $prompt2 =~ s/.*(\n|\r)//;
            $prompt2 =~ s/(^\s+|\s+$)//g;
            $self->dtl("debug prompt2 '$prompt2'");
        }

        # check if prompt repeated itself and exit loop
        last if defined $prompt2 and $prompt1 eq $prompt2;

        # failsafe that will give up if unable to find prompt
        if ($count == 25) {
            carp "unable to determine prompt";
            return undef;
        }

    # continue loop until we get a consistant prompt
    }

    # remove suffix characters from prompt and store
    $prompt1 =~ s/$self->{'expect-prompt-command'}/$1/;

    # output debug log entry
    $self->dtl("current prompt '$prompt1' found");
    $self->{'_expect-logfile-dtl'} = 0;

    # finished prompt method
    return $prompt1;
}
 


sub read {

# internal: $output = $self->read($timeout)
# purpose: used to read next output packet from session
# $output: text read from session or undefined on timeout
# $timeout: seconds to wait without text before timing out

    # read input args
    my ($self, $timeout)=@_;
    croak "not called as an instance" if not ref $self;
    croak "call not supported with expect-replay" if $self->{'expect-replay'};

    # set default timeout from session read timeout and log debug entry
    $timeout=$self->{'expect-timeout-command'} if not defined $timeout;
    $self->dtl("read started with ${timeout}s timeout");

    # wait for and grab the next character or return undefined value
    $self->{'_expect'}->expect($timeout, "-re", '\S') or return undef;
    my $output = &clean($self->{'_expect'}->match);

    # delay then grab the rest of output that came in on that packet
    &Time::HiRes::usleep(1000);
    $self->{'_expect'}->expect(0);
    $output .= &clean($self->{'_expect'}->before);

    # log debug entry for read
    my $length = length($output);
    $self->dtl("read returned $length chars");

    # finished read function
    return $output;
}



sub send {

=head2 send method

 $expect->send($text)

The purpose of this method is to blindly send text to the
currently open session. This can be useful where a regular
command prompt is not guaranteed to be returned.

=cut

    # validate text arg, log, send and return
    my ($self, $text) = @_;
    $text = "" if not defined $text;
    croak "not called as an instance" if not ref $self;
    $self->dtl("send '$text' called from " . lc(caller));
    croak "call not supported with expect-replay" if $self->{'expect-replay'};
    $self->{'_expect'}->send("$text\r") if $text ne "";
    return;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Expect, Mnet, Mnet::Expect::IOS, Net::Telnet

=cut



# normal package return
1;

