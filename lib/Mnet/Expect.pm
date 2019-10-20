package Mnet::Expect;

=head1 NAME

Mnet::Expect - Create Expect objects with Mnet::Log support

=head1 SYNOPSIS

    use Mnet::Expect;

    my $expect = Mnet::Expect->new({ spawn => [qw(
        ssh
         -o StrictHostKeyChecking=no
         -o UserKnownHostsFile=/dev/null
         1.2.3.4
    )]});

    $expect->send("ls\r");

    $expect->close;

=head1 DESCRIPTION

This module can be used to create new Mnet::Expect objects, log spawned process
expect activity, and close Mnet::Expect sessions.

This module requires that the perl Expect module is installed.

The methods in this object are used by other Mnet::Expect modules.

=cut

# required modules
use warnings;
use strict;
use parent qw( Mnet::Log::Conditional );
use Carp;
use Errno;
use Mnet::Dump;
use Mnet::Opts::Cli::Cache;



sub new {

=head2 new

    $expect = Mnet::Expect->new(\%opts)

This method can be used to create new Mnet::Expect objects.

The following input opts may be specified:

    log_id      refer to perldoc Mnet::Log new method
    raw_pty     can be set 0 or 1, refer to perldoc Expect
    spawn       command and args array ref, or space separated string
    winsize     specify session rows and columns, default 99999x999

An error is issued if there are spawn problems.

For example, the following will spawn an ssh expect session to a device:

    my $expect = Mnet::Expect->new({ spawn => [qw/
        ssh
         -o StrictHostKeyChecking=no
         -o UserKnownHostsFile=/dev/null
         1.2.3.4
    /]});

Note that all Mnet::Expect session activity is logged for debugging, refer to
the Mnet::Log module for more information.

=cut

    # read input class and options hash ref merged with cli options
    my $class = shift // croak("missing class arg");
    my $opts = Mnet::Opts::Cli::Cache::get(shift // {});

    # create log object with input opts hash, cli opts, and pragmas in effect
    #   ensures we can log correctly even if inherited object creation fails
    my $log = Mnet::Log::Conditional->new($opts);
    $log->debug("new starting");

    # create hash that will become new object from input opts hash
    my $self = $opts;

    # note default options for this class
    #   includes recognized input opts and cli opts for this object
    #   the following keys starting with underscore are used internally:
    #       _expect     => spawned Expect object, refer to Mnet::Expect->expect
    #       _log_filter => set to password text to filter from debug log once
    #       _no_spawn   => set true to skip spawn, used by sub-modules' replay
    #   in addition refer to perldoc for input opts and Mnet::Log0->new opts
    #   update perldoc for this sub with changes
    my $defaults = {
        debug       => $opts->{debug},
        _expect     => undef,
        _log_filter => undef,
        log_id      => $opts->{log_id},
        _no_spawn   => undef,
        quiet       => $opts->{quiet},
        raw_pty     => undef,
        silent      => $opts->{silent},
        spawn       => undef,
        winsize     => "99999x999",
    };

    # update future object $self hash with default opts
    foreach my $opt (sort keys %$defaults) {
        $self->{$opt} = $defaults->{$opt} if not exists $self->{$opt};
    }

    # debug output opts if creating object of this class and not internal opt
    #   hide options that have a corresponding _option_ name with underscores
    foreach my $opt (sort keys %$self) {
        next if $opt =~ /^_/ or not defined $self->{$opt};
        my $value = Mnet::Dump::line($self->{$opt});
        $value = "****" if defined $self->{$opt} and exists $self->{"_${opt}_"};
        $log->debug("new opts $opt = $value");
    }

    # bless new object
    bless $self, $class;

    # return undef if Expect spawn does not succeed
    $self->debug("new calling spawn");
    if (not $self->spawn) {
        $self->debug("new finished, spawn failed, returning undef");
        return undef;
    }

    # finished new method, return Mnet::Expect object
    $self->debug("new finished, returning $self");
    return $self;
}



sub spawn {

# $ok = $self->spawn
# purpose: used to spawn Expect object
# $ok: set true on success, false on failure

    # read input object
    my $self = shift;
    $self->debug("spawn starting");

    # return true if _no_spawn is set
    #   this is used for replay from sub-modules
    #   this avoids interference with replay in the module
    if ($self->{_no_spawn}) {
        $self->debug("spawn skipped for _no_spawn");
        return 1;
    }

    # error if spawn option was not set
    croak("missing spawn option") if not defined $self->{spawn};

    # conditionally load perl Expect module and create new expect object
    #   we are only loading the Expect module if this method is called
    #   require is used so as to not import anything into this namespace
    eval("require Expect; 1") or croak("missing Expect perl module");
    $self->{_expect} = Expect->new;

    # set raw_pty for expect session if defined as an input option
    $self->{_expect}->raw_pty($self->{raw_pty}) if defined $self->{raw_pty};

    # set default window size for expect tty session
    #   this defaults to a large value to minimize pagination and line wrapping
    #   IO::Tty::Constant module is pulled into namespace when Expect is used
    croak("bad winsize $self->{winsize}")
        if $self->{winsize} !~ /^(\d+)x(\d+)$/;
    my $tiocswinsz = IO::Tty::Constant::TIOCSWINSZ();
    my $winsize_pack = pack('SSSS', $1, $2, 0, 0);
    ioctl($self->expect->slave, $tiocswinsz, $winsize_pack);

    # set Mnet::Expect->log method for logging
    #   disable expect stdout logging
    $self->expect->log_stdout(0);
    $self->expect->log_file(sub { $self->log(shift) });

    # note spawn command and arg list
    #   this can be specified as a list reference or a space-separated string
    my @spawn = ();
    @spawn = @{$self->{spawn}} if ref $self->{spawn};
    @spawn = split(/\s/, $self->{spawn}) if not ref $self->{spawn};

    # call Expect spawn method
    #   disable Mnet::Tee stdout/stderr ties if not Mnet::Tee is loaded
    #   stdout/stderr ties cause spawn problems, but can be re-enabled after
    #   init global Mnet::Expect error to undef, set on expect spawn failures
    if ($INC{'Mnet/Tee.pm'}) {
        $self->debug("spawn calling Mnet::Tee::tie_disable");
        Mnet::Tee::tie_disable();
        $self->debug("spawn calling Expect module spawm method");
        $self->fatal("spawn error, $!") if not $self->expect->spawn(@spawn);
        $self->debug("spawn calling Mnet::Tee::tie_enable");
        Mnet::Tee::tie_enable();
    } else {
        $self->fatal("spawn error, $!") if not $self->expect->spawn(@spawn);
    }

    # note spawn process id
    $self->debug("spawn pid ".$self->expect->pid);

    # finished spawn method, return true for success
    $self->debug("spawn finished, returning true");
    return 1;
}



sub close {

=head2 close

    $expect->close

Attempt to call hard_close for the current Expect session, and send a kill
signal if the process still exists. The Expect sesssion is set to udnefined.

=cut

    # read input object
    my $self = shift;
    $self->debug("close starting");

    # return if expect object no longer defined
    if (not defined $self->expect) {
        $self->debug("close finished, expect not defined");
        return;
    }

    # note process id of spawned expect command
    my $spawned_pid = $self->expect->pid;

    # return if there's no expect process id
    if (not defined $spawned_pid) {
        $self->debug("close finished, no expect pid");
        $self->{_expect} = undef;
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
                $self->debug("close finished, $label confirmed");
                $self->{_expect} = undef;
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
        $self->expect->hard_close;
    };
    return if _close_confirmed($self, "hard_close", $spawned_pid);

    # if hard_close failed then send kill -9 signal
    $self->debug("close sending kill signal");
    kill(9, $spawned_pid);
    return if _close_confirmed($self, "kill", $spawned_pid);

    # undefine expect object since nothing else worked
    $self->{_expect} = undef;

    # finished close method
    $self->debug("close finished, expect undef after kill");
    return;
}



sub expect {

=head2 expect

    $expect->expect

Returns the underlying expect object used by this module, for access to fetures
that may not be supported directly by Mnet::Expect modules.  Refer to perldoc
Expect for more information.

=cut

    # return underlying expect object
    my $self = shift;
    return $self->{_expect};
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
        #   apply then clear _log_filter to remove passwords from line_txt
        if (ord($char) < 32) {
            $line_hex .= sprintf(" %02x", ord($char));
            if (defined $line_txt) {
                if (defined $self->{_log_filter}) {
                    if ($line_txt =~ s/\Q$self->{_log_filter}\E/****/g) {
                        $self->{_log_filter} = undef;
                    }
                }
                $self->debug("log txt: $line_txt");
                $line_txt = undef;
            }

        # append printable ascii characters to line_txt
        } else {
            $line_txt .= $char;
            if (defined $line_hex) {
                $self->debug("log hex:$line_hex");
                $line_hex = undef;
            }
        }

    # continue looping through input characters
    }

    # output any remaining log hex of txt lines after finishing loop
    #   apply and clear _log_filter to remove passwords from line_txt
    $self->debug("log hex:$line_hex") if defined $line_hex;
    if (defined $line_txt) {
        if (defined $self->{_log_filter}) {
            if ($line_txt =~ s/\Q$self->{_log_filter}\E/****/g) {
                $self->{_log_filter} = undef;
            }
        }
        $self->debug("log txt: $line_txt");
    }

    # finished log method
    return;
}



=head1 TESTING

This module supports Mnet::Test --replay functionality for other Mnet::Expect
submodules. Refer to those other Mnet::Expect submodules for more information.

=head1 SEE ALSO

L<Expect>

L<Mnet>

L<Mnet::Expect::Cli>

L<Mnet::Expect::Cli::Ios>

=cut

# normal package return
1;

