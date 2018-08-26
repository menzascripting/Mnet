package Mnet::Expect;

=head1 NAME

Mnet::Expect

=head1 SYNOPSIS

This module can be used to create new Mnet::Expect objects, log spawned process
expect activity, and close Mnet::Expect sessions.

The methods in this object are used by other Mnet::Expect modules.

=head1 TESTING

#? When used with the Mnet::Test --record option this module will...

=cut

# required modules
use warnings;
use strict;
use parent qw( Mnet::Log::Conditional );
use Carp;
use Errno;
use Mnet::Opts::Cli::Cache;



sub new {

=head1 $self = Mnet::Expect->new(\%opts)

This method can be used to create new Mnet::Expect objects. The following input
hash options may be specified:

 log_id     note that other Mnet::Log opts may be specified
 spawn      command and arguments array ref, or space separated string
 winsize    specify session rows and columns, defaults to 99999x999

For example, the following call will start an ssh expect session to a device:

 my $expect = Mnet::Expect->new({ spawn => "ssh 1.2.3.4" });

Note that all Mnet::Expect session activity is logged for debugging, refer to
the Mnet::Log module for more information.

=cut

    # read input class and optional opts hash ref
    my $class = shift // croak("missing class arg");
    croak("invalid call to class new") if ref $class;
    my $opts = shift // {};

    # create new object hash from input opts, the following keys are used:
    #   debug   => option for methods inherited from Mnet::Log module
    #   expect  => undelying Expect method, refer to perldoc Expect
    #   log_id  => option for methods inherited from Mnet::Log module
    #   quiet   => option for methods inherited from Mnet::Log module
    #   silent  => option for methods inherited from Mnet::Log module
    #   spawn   => command and arguments array ref, or space separated string
    #   winsize => specify session rows and columns, defaults to 99999x999
    my $self = bless Mnet::Opts::Cli::Cache::get($opts), $class;
    $self->debug("new starting");

    # conditionally load perl Expect module and create new expect object
    #   we are only loading the Expect module if this method is called
    #   require is used so as to not import anything into this namespace
    eval("require Expect; 1") or croak("missing Expect perl module");
    $self->{expect} = Expect->new;

    # set default window size for expect tty session
    #   winsize option to this method defaults to 999999 rows x 999 columns
    #   this is set to a large value to minimize pagination and line wrapping
    #   IO::Tty::Constant module is pulled into namespace when Expect is used
    $self->debug("new winsize $self->{winsize}") if defined $self->{winsize};
    $self->{winsize} = "999999x999" if not defined $self->{winsize};
    carp("bad winsize $self->{winsize}") if $self->{winsize} !~ /^(\d+)x(\d+)$/;
    my $winsize_pack = pack('SSSS', $1, $2, 0, 0);
    ioctl($self->{expect}->slave, IO::Tty::Constant::TIOCSWINSZ(), $winsize_pack);

    # set Mnet::Expect->log method for logging
    #   disable expect stdout logging
    $self->{expect}->log_stdout(0);
    $self->{expect}->log_file(sub { $self->log(shift) });

    # note spawn command and arg list
    #   this can be specified as a list reference or a space-separated string
    my @spawn = ();
    @spawn = @{$self->{spawn}} if ref $self->{spawn};
    @spawn = split(/\s/, $self->{spawn}) if not ref $self->{spawn};
    $self->debug("new spawn list = $_") foreach @spawn;

    # call Expect spawn method
    #   temporarily disable Mnet::Test stdout/stderr ties
    #   stdout/stderr ties cause spawn problems, but can be re-enabled after
    Mnet::Test::disable_tie() if $INC{'Mnet/Test.pm'};
    my $spawn_result = $self->{expect}->spawn(@spawn);
    Mnet::Test::enable_tie() if $INC{'Mnet/Test.pm'};

    # return undef if there was an error with expect spawn
    if (not $spawn_result) {
        $self->debug("new expect session spawn error, $!");
        return undef;
    }

    # finished new method, return Mnet::Expect object
    $self->debug("new finished, pid ".$self->{expect}->pid);
    return $self;
}



sub close {

=head1 $self->close

Attempt to call hard_close for the current Expect session, and send a kill
signal if the process still exists. The Expect sesssion is set to udnefined.

=cut

    # read input object
    my $self = shift;
    $self->debug("close starting");

    # return if expect object no longer defined
    if (not defined $self->{expect}) {
        $self->debug("close returning, expect not defined");
        return;
    }

    # note process id of spawned expect command
    my $spawned_pid = $self->{expect}->pid;

    # return if there's no expect process id
    if (not defined $spawned_pid) {
        $self->debug("close returning, no expect pid");
        $self->{expect} = undef;
        return;
    }

    # continue processing
    $self->debug("close proceeding for pid $spawned_pid");

    # usage: $result = _close_confirmed($self, $label, $spawned_pid)
    #   kill(0,$pid) is true if pid signalable, Errno::ESRCH if not found
    #   purpose: return true if $spawned_pid is gone, $label used for debug
    #   note: if result is true then expect object will have been set undefined
    sub _close_confirmed {
        my ($self, $label, $spawned_pid) = (shift, shift, shift);
        if (not kill(0, $spawned_pid)) {
            if ($! == Errno::ESRCH) {
                $self->debug("close returning, $label confirmed");
                $self->{expect} = undef;
                return 1;
            }
            $self->debug("close pid check error after $label, $!");
        }
        return 0;
    }

    # call hard close
    #   ignore int and term signals to avoid hung processes
    $self->debug("close calling hard_close");
    eval {
        local $SIG{INT} = "IGNORE";
        local $SIG{TERM} = "IGNORE";
        $self->{expect}->hard_close;
    };
    return if _close_confirmed($self, "hard_close", $spawned_pid);

    # if hard_close failed then send kill -9 signal
    $self->debug("close sending kill signal");
    kill(9, $spawned_pid);
    return if _close_confirmed($self, "kill", $spawned_pid);

    # undefine expect object since nothing else worked
    $self->{expect} = undef;

    # finished close method
    $self->debug("close finished");
    return;
}



sub log {

# $self->log($chars)
# purpose: output Mnet::Expect session activity to --debug log
# $chars: logged text, non-printable characters are output as hexadecimal
# note: Mnet::Expect->new sets Expect log_file to use this method

    # read the current Mnet::Expect object and character string to log
    my ($self, $chars) = (shift, shift);

    # init text and hex log output lines
    #   separate hex lines are used to show non-prinatbel characters
    my ($line_txt, $line_hex) = (undef, undef);

    # loop through input hex and text characters
    foreach my $char (split(//, $chars)) {

        # append non-printable ascii characters to line_hex
        if (ord($char) < 32) {
            $line_hex .= sprintf("%02x ", ord($char));
            if (defined $line_txt) {
                $self->debug("log txt: $line_txt");
                $line_txt = undef;
            }

        # append printable ascii characters to line_txt
        } else {
            $line_txt .= $char;
            if (defined $line_hex) {
                $self->debug("log hex: $line_hex");
                $line_hex = undef;
            }
        }

    # continue looping through input characters
    }

    # output any remaining log hex of txt lines after finishing loop
    $self->debug("log hex: $line_hex") if defined $line_hex;
    $self->debug("log txt: $line_txt") if defined $line_txt;

    # finished log method
    return;
}



#? finish me
#   Mnet::Expect::Cli
#       opt_def --username, --password
#       new($opts)
#       _clear (clear expect cache, uses while loop to empty, etc)
#       login
#       cmd($cmd, \@prompts)
#           @prompts is an ordered list of expect match conditions
#           @prompts processing needs to be able to handle the following:
#               prompt detection    (to disable or override default detection)
#               pagination          (should we have some kind of default?)
#               throttling          (to disable or override default?)
#               progress bars       (to disable or override default?)
#               timeouts            (gracefully return after disconnect)
#               match+response      (wait for a regex, then send response)
#               code references     (used to implement many/all of the above?)
#           maybe @prompts would need to be more complex, to hook in via expect
#       cmd_prompt (call Expect->_clean, confirm and return prompt)
#       close($cmd) (call Expect->close, pass through command)
#       support for --record and --replay lives in this module?
#   Mnet::Expect::Cli::Cisco
#       opt_def --enable
#       new (calls Cli->new with pagination default for cisco)
#       login (calls Cli->login, with --enable opt defined in this module)
#       cmd (calls Cli->cmd, Expect->_clean after, has pagination/etc prompts)
#       close (call Cli->close("end\nexit\n") for cisco devs)
#   add -re '\r\N' progress bar handling ability
#       $match = $expect->match;
#       $match =~ /\N*\r(\N)/$1/;
#       $match .= $expect->after;
#       expect->set_accum($match);
#   also remember testing record and replay
#       along with the capability to handle multiple test sessions



=head1 SEE ALSO

 Expect
 Mnet
 Mnet::Expect::Cli
 Mnet::Expect::Cli::Cisco
 Mnet::Log::Conditional

=cut

# normal package return
1;

