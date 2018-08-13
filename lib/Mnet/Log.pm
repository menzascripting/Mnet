package Mnet::Log;

=head1 NAME

Mnet::Log

=head1 SYNOPSIS

This module supports generating the following types of log entries

 dbg   stdout   detailed info, visible when debug option is set
 inf   stdout   normal informational entries intended for users
 log   stdout   reserved for script start and finish log entries
 WRN   stderr   logged warning entries, execution will continue
 ERR   stderr   perl die and warn outputs with stack trace
 DIE   stderr   logged fatal errors, execution aborts

The following options can be used to control log outputs:

 debug      enable dbg log outputs
 quiet      disable all stdout log outputs
 silent     disable all stdout and stderr log outputs

Log entries can be called as functions or as methods, as follows:

 # imports DEBUG, INFO, WARN, and FATAL
 use Mnet::Log qw(DEBUG INFO WARN FATAL);

 # options can be set for Mnet::Log objects
 my $log = Mnet::Log->new();

 # output to standard out and err is captured
 syswrite STDOUT, $text;
 syswrite STDERR, $text;

 # dbg entries
 DEBUG($text);
 $log->debug($text);

 # inf entries
 INFO($text);
 $log->info($text);

 # WRN entries
 WARN($text);
 $log->warn($text);

 # ERR entries
 #  note that eval warnings are output as normal
 #  evals can use local $SIG{__WARN__} = sub { die @_ };
 warn $text;
 die $text;

 # DIE entries
 FATAL($text);
 $log->fatal($text);

 # first line of first WRN/ERR/DIE entry
 $text = Mnet::Log::errors();

Note that this module also installed die, warn, int, and term signal handlers,
in order to augment the logging of these events. These are made to pass through
compile and eval warn and die events as normal.

Note that timestamps and other varying data are filtered out of log outputs
when the --record, --replay, or --test cli options are enabled or if the
Mnet::Log::Test module is otherwise loaded.

=head1 TESTING

When used with the Mnet::Test --record option all stdout and stderr log entry
output from this module is captured with the exception of dbg and log entries.

Refer to the Mnet::Test module for more information.

=cut

# required modules
#   perl 5.8 required for decent signal handling, refer to man perlipc
#   note that Mnet modules should use Mnet::Log::Conditional, not this module
use warnings;
use strict;
use 5.008;
use Carp;
use Exporter qw( import );
use Mnet::Opts;
use Mnet::Opts::Cli::Cache;
use Mnet::Version;

# export function names
our @EXPORT_OK = qw( DEBUG INFO WARN FATAL );



# begin block runs before init blocks of other modules
BEGIN {

    # autoflush standard output
    $| = 1;

    # note start time of script
    our $start_time = $^T;

    # init global flag to track that first log message was output
    #   this is used to output log entry when script started and finished
    #   output() sets to 1 if start entry output, 0 if start entry suppressed
    my $first = undef;

    # init global error flag, user to track first error message
    #   should be set for perl warn and die, and warn and fatal Mnet::Log calls
    my $errors = undef;

    # declare sub used by SIG handlers to log error and stack trace info
    sub _sig_handler {
        my ($label, $caller, $error, $sev) = (shift, shift, shift, 7);
        $sev = 3 if not defined $Mnet::Log::errors;
        output(undef, "ERR", 3, $caller, "$label, $error");
        output(undef, "err", $sev, $caller, "$label, $_")
            foreach split(/\n/, Carp::longmess());
        output(undef, "err", $sev, $caller, "$label, \$! = $!") if $! ne "";
        output(undef, "err", $sev, $caller, "$label, \$@ = $@") if $@ ne "";
        output(undef, "err", $sev, $caller, "$label, \$? = $?") if $? ne "";
        output(undef, "err", $sev, $caller, "$label, \$^E = $^E") if $^E ne "";
    }

    # trap perl die signal, log as error and exit with a failed status
    #   CORE::die handles propogated, compile, and eval warnings
    #   $^S is undef while compiling/parsing, true in eval, false otherwise
    #   exit with error after _sig_handler call to output error and stack trace
    $SIG{__DIE__} = sub {
        if (not @_ or not defined $^S or $^S) {
            &CORE::die;
        } else {
            _sig_handler("perl die", scalar(caller), "@_");
        }
        exit 1;
    };

    # trap perl warn signal, log as error and resume execution
    #   CORE::warn handles propogated and compile warnings
    #   $^S is undef while compiling/parsing, true in eval, false otherwise
    #   return after _sig_handler call to output error and stack trace
    $SIG{__WARN__} = sub {
        if (not @_ or not defined $^S) {
            &CORE::warn;
        } else {
            _sig_handler("perl warn", scalar(caller), "@_");
        }
        return 1;
    };

    # trap system interrupt signal, log as error and exit with failed status
    #   output a linefeed to stderr after ^C put there by shell
    $SIG{INT} = sub {
        syswrite STDERR, "\n";
        output(undef, "ERR", 3, scalar(caller), "terminate signal received");
        exit 1;
    };

    # trap terminate signal, log as error and exit with failed status
    $SIG{TERM} = sub {
        output(undef, "ERR", 3, scalar(caller), "terminate signal received");
        exit 1;
    };

# begin block finished
}



# init Mnet::Test stdout bypass for debug and cli options used by this module
INIT {

    # init stdout file handle to bypass Mnet::Test output capture if loaded
    our $stdout = undef;
    if ($INC{"Mnet/Test.pm"}) {
        $stdout = $Mnet::Test::stdout;
    } else {
        open($stdout, ">&STDOUT");
    }

    # init --debug option
    Mnet::Opts::Cli::define({
        getopt      => 'debug!',
        help_tip    => 'set to display extra debug log entries',
        help_text   => '
            note that the --quiet and --silent options override this option
            refer also to the Mnet::Opts::Set::Debug pragma module
            refer to perldoc Mnet::Log for more information
        ',
    }) if $INC{"Mnet/Opts/Cli.pm"};

    # init --quiet option
    Mnet::Opts::Cli::define({
        getopt      => 'quiet!',
        help_tip    => 'set to suppress terminal standard output',
        help_text   => '
            suppresses Mnet::Log stdout entries, not necessarily other stdout
            use shell redirection if necessary to suppress all script stdout
            note that setting this option overrides the --silent option
            refer also to the Mnet::Opts::Set::Quiet pragma module
            refer to perldoc Mnet::Log for more information
        ',
    }) if $INC{"Mnet/Opts/Cli.pm"};

    # init --silent option
    Mnet::Opts::Cli::define({
        getopt      => 'silent!',
        help_tip    => 'set to suppress standard output and error',
        help_text   => '
            suppresses all Mnet::Log output, but not necessarily other output
            use shell redirection if necessary to suppress all script output
            note that this option can be overridden by the --quiet option
            refer also to the Mnet::Opts::Set::Silent pragma module
            refer to perldoc Mnet::Log for more information
        ',
    }) if $INC{"Mnet/Opts/Cli.pm"};

# finished init code block
}



sub new {

=head1 $self = Mnet::Log->new(\%opts)

This class method creates a new Mnet::Log object. The opts hash ref argument is
not requried but may be used to override any parsed cli options parsed with the
Mnet::Opts::Cli module.

The returned object may be used to call other documented methods in this module.

The input opts hash ref may contain a log_id key which may be set to a device
name or other identifier which will be prepended to all entries made using the
returned Mnet::Log object. A warning will be issued if the log_id contains any
spaces.

Refer to the SYNOPSIS section of this perldoc for more information.

=cut

    # read input class and optional opts hash ref
    my $class = shift // croak("missing class arg");
    croak("invalid call to class new") if ref $class;
    my $opts = shift // {};

    # warn if log_id contains non-space characters
    carp("invalid spaces in log_id $opts->{log_id}")
        if defined $opts->{log_id} and $opts->{log_id} !~ /^\S+$/;

    # create object, apply input opts over any cached cli options
    my $self = bless Mnet::Opts::Cli::Cache::get($opts), $class;

    # finished new method
    return $self;
}



sub batch_fork {

# Mnet::Log::batch_fork()
# purpose: called to reset start time for forked batch child
# note: this is meant to be called from Mnet::Batch::fork only

    # reset start time for forked batch child
    $Mnet::Log::start_time = time;
}



sub errors {

=head1 $error = Mnet::Log::errors();

This function returns the first line of error text from the perl warn or die
commands or Mnet::Log warn or fatal outputs.

A value of undefined is returned if there have not yet been any errors.

=cut

    # return contents of global error flag
    return $Mnet::Log::errors;
}



sub output {

# output($self, $prefix, $severity, $caller, $text)
# purpose: used by other methods in this module to output Mnet::Log entries
# $self: object instance passed from public methods in this module, or undef
# $prefix: set to keyword dbg, inf, WRN, ERR, or " - " to bypass Mnet::Test
# $severity: 7=debug, 6=info, 5=notice (no Mnet::Test), 4=warn, 3=error, 2=fatal
# $caller: original caller of method or function making log entry
# $text: zero or more lines of log text

    # read args for object and/or text, level, and caller
    my ($self, $prefix, $severity, $caller) = (shift, shift, shift, shift);
    my $text = shift // "undef log text";
    $text = " " if $text eq "";

    # set self to hash ref of cached cli opts if we weren't called as a method
    $self = Mnet::Opts::Cli::Cache::get({}) if not defined $self;

    # output first log entry, honoring current logging options
    #   Mnet::Opts::Set pragmas are in effect until Mnet::Opts::Cli->new call
    #   project scripts should call Mnet::Opts::Cli->new before Mnet::Log calls
    #   output log prefix " - " bypasses Mnet::Test recording of first line
    #   first line not output if Mnet::Log->new called with quiet or silent opt
    #   filter pid if Mnet::Log::Test loaded, perhaps by Mnet::Opts::Cli->new
    #   set $Mnet::Log::first after output of first entry
    if (not defined $Mnet::Log::first) {
        if (defined $self and ($self->{quiet} or $self->{silent})) {
            $Mnet::Log::first = 0;
        } else {
            $Mnet::Log::first = 1;
            my $script_name = $0;
            $script_name =~ s/^.*\///;
            my $started = "$script_name started";
            $started .= ", pid $$, ".localtime if not $INC{"Mnet/Log/Test.pm"};
            notice($self, "script $started");
            if ($self->{debug}) {
                output($self, "dbg", 7, "Mnet::Version", Mnet::Version::info());
            }
        }
    }

    # return for debug entries if --debug is not set
    return 1 if $severity > 6 and not $self->{debug};

    # return if Mnet::Test not used and --silent is set, unless --quiet is set
    #   if Mnet::Test is loaded we want to allow it to capture all output
    if (not $INC{"Mnet/Test.pm"}) {
        if ($self->{silent}) {
            if (not defined $self->{quiet} or not $self->{quiet}) {
                return 1;
            }
        }
    }

    # return for non-warning entries if Mnet::Test not used and --quiet is set
    #   if Mnet::Test is loaded we want to allow it to capture all output
    if (not $INC{"Mnet/Test.pm"}) {
        return 1 if $severity > 4 and $self->{quiet};
    }

    # update global error flag with first line of first error entry
    $Mnet::Log::errors = (split(/\n/, $text))[0]
        if $severity < 5 and not defined $Mnet::Log::errors;

    # set hh:mm:ss timestamp for entries as long as --test is not set
    #   timestamps are filtered out of output with --record/replay/test cli opt
    my ($timestamp, $sec, $min, $hr, $mday, $mon, $yr) = ("", localtime());
    $timestamp = sprintf("%02d:%02d:%02d ", $hr, $min, $sec)
        if not $INC{"Mnet/Log/Test.pm"}
        and not $self->{record} and not $self->{replay} and not $self->{test};

    # note identifier for Mnet::Log entries
    my $log_id  = $self->{log_id} // "-";

    # otherwise output entry as lines of text for each line of input entry text
    #   sev 6+ dbg sev 5 log entries bypass Mnet::Test using $stdout filehandle
    #       prefix - entries used in this module for first and last log entries
    #       Mnet::Log::stdout could be undef for sig handler compile errors
    #   inf entries are output to stdout, otherwise output to stderr
    foreach my $line (split(/\n/, $text)) {
        $line = "${timestamp}$prefix $log_id $caller $line";
        if ($severity > 6 or $severity == 5) {
            if (not $INC{"Mnet/Opts/Set/Silent.pm"}
                and not $INC{"Mnet/Opts/Set/Quiet.pm"}
                and defined $Mnet::Log::stdout) {
                syswrite $Mnet::Log::stdout, "$line\n";
            }
        } elsif ($severity > 4) {
            syswrite STDOUT, "$line\n";
        } else {
            syswrite STDERR, "$line\n";
        }
    }

    # finished output function
    return 1;
}



sub debug {

=head1 $self->debug($text)

Method call to output a debug entry to stdout with an Mnet::Log prefix of dbg.

=cut

    # call output function
    my ($self, $text) = (shift, shift);
    return $self->output("dbg", 7, scalar(caller), $text);
}



sub info {

=head1 $self->info($text)

Method call to output an info entry to stdout with an Mnet::Log prefix of inf.

=cut

    # call output function
    my ($self, $text) = (shift, shift);
    return $self->output("inf", 6, scalar(caller), $text);
}



sub notice {

# $self->notice($text)
# purpose: output log text to stdout, bypassing Mnet::Test log capture

    # call output function
    my ($self, $text) = (shift, shift);
    return output($self, " - ", 5, scalar(caller), $text);
}


sub warn {

=head1 $self->warn($text)

Method call to output a warn entry to stderr with an Mnet::Log prefix of WRN.

=cut

    # call output function
    my ($self, $text) = (shift, shift);
    return $self->output("WRN", 4, scalar(caller), $text);
}



sub fatal {

=head1 $self->fatal($text)

Method to output a fatal entry to stderr with an Mnet::log prefix of DIE.

=cut

    # call output function
    my ($self, $text) = (shift, shift);
    return $self->output("DIE", 2, scalar(caller), $text);
}



sub DEBUG {

=head1 DEBUG($text)

Function to output a debug entry to stdout with an Mnet::Log prefix of dbg.

=cut

    # call output function
    my $text = shift;
    return output(undef, "dbg", 7, scalar(caller), $text);
}



sub INFO {

=head1 INFO($text)

Function to output an info entry to stdout with an Mnet::Log prefix of inf.

=cut

    # call output function
    my $text = shift;
    return output(undef, "inf", 6, scalar(caller), $text);
}



sub NOTICE {

# NOTICE($text)
# purpose: output log text to stdout, bypassing Mnet::Test log capture

    # call output function
    my $text = shift;
    return output(undef, " - ", 5, scalar(caller), $text);
}



sub WARN {

=head1 INFO($text)

Function to output a warn entry to stderr with an Mnet::Log prefix of WRN.

=cut

    # call output function
    my $text = shift;
    return output(undef, "WRN", 4, scalar(caller), $text);
}



sub FATAL {

=head1 FATAL($text)

Function to output a fatal entry to stderr with an Mnet::Log prefix of DIE.

=cut

    # call output function
    my $text = shift;
    output(undef, "DIE", 2, scalar(caller), $text);
    exit(1);
}



# output Mnet::Log finished entry at end of script
#   note that $^T, aka $BASETIME, is the unixtime script started running
#   output log prefix " - " bypasses Mnet::Test recording of these entries
END {

    # output last line of log text if first line was output
    #   note if there were any errors during execution
    #   note pid and elapsed time if not Mnet::Log::Test was not loaded
    #       Mnet::Log::Test loaded by Mnet::Opts::Cli->new w/record/replay/test
    if ($Mnet::Log::first) {
        my $finished = "with errors";
        $finished = "with no errors" if not defined $Mnet::Log::errors;
        my $elapsed = (time-$Mnet::Log::start_time)." seconds elapsed";
        $finished .= ", pid $$, $elapsed" if not $INC{"Mnet/Log/Test.pm"};
        NOTICE("finished $finished");
    }

    # call Mnet::Test to process record and test cli options, if loaded
    #   called here so that tests occur after last line of Mnet::Log output
    #   --test diff undef if --replay --test diff was not attempted
    #   --test diff is null for no diff, exit clean even if output had warnings
    #   --test diff is non-null for failed diff, exit with a failed status
    if ($INC{"Mnet/Test.pm"}) {
        my $diff = Mnet::Test::done();
        if (defined $diff) {
            exit 0 if not $diff;
            exit 1 if $diff;
        }
    }

    # set failed exit status if any errors were caught by signal handlers
    exit 1 if defined $Mnet::Log::errors;

# finished end block
}



=head1 SEE ALSO

 Mnet
 Mnet::Log::Test
 Mnet::Opts
 Mnet::Opts::Cli
 Mnet::Opts::Cli::Cache
 Mnet::Opts::Set::Debug
 Mnet::Opts::Set::Quiet
 Mnet::Opts::Set::Silent
 Mnet::Test
 Mnet::Version

=cut

# normal end of package
1;

