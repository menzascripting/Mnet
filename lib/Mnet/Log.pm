package Mnet::Log;

=head1 NAME

Mnet::Log

=head1 SYNOPSIS

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

 # first line of first error entry
 $text = Mnet::Log::errors();

=cut

# required modules
#   note that Mnet modules should use Mnet::Log::Conditional, not this module
use warnings;
use strict;
use 5.010;
use Carp;
use Exporter qw( import );
use Mnet::Opts;
use Mnet::Opts::Cli;
use Mnet::Opts::Cli::Cache;

# export function names
our @EXPORT_OK = qw( DEBUG INFO WARN FATAL );



# begin block runs before init blocks of other modules
BEGIN {

    # autoflush standard output
    $| = 1;

    # init global flag to track that first log message was output
    #   this is used to output an informational log entry when script starts
    my $first = undef;

    # init global error flag, user to track first error message
    #   should be set for perl warn and die, and warn and fatal Mnet::Log calls
    my $errors = undef;

    # override perl warn command
    #   we do this so as not to interfere with SIG handlers
    #   CORE::warn can be used to call original perl warn command
    #   first goto propagates propagated errors, second handles warn from evals
    #   carp longmess output as error for first error, otherwise as debug
    *CORE::GLOBAL::warn = sub {
        goto &CORE::warn unless @_;
        goto &CORE::warn if $^S;
        my $error = "@_";
        my @trace = split(/\n/, Carp::longmess());
        $error .= shift(@trace) if $error !~ /\n$/;
        if (not defined $Mnet::Log::errors) {
            _output(undef, "ERR", 3, scalar(caller), "perl warning, $error");
            _output(undef, "err", 3, scalar(caller), "@trace") if $trace[0];
        } else {
            _output(undef, "ERR", 3, scalar(caller), "perl warning, $error");
            _output(undef, "err", 7, scalar(caller), "@trace") if $trace[0];
        }
    };

    # override perl die command
    #   we do this so as not to interfere with SIG handlers
    #   CORE::die can be used to call original perl die command
    #   first goto propagates propagated errors, second handles die from evals
    #   carp longmess output as error for first error, otherwise as debug
    *CORE::GLOBAL::die = sub {
        goto &CORE::die unless @_;
        goto &CORE::die if $^S;
        my $error = "@_";
        my @trace = split(/\n/, Carp::longmess());
        $error .= shift(@trace) if $error !~ /\n$/;
        if (not defined $Mnet::Log::errors) {
            _output(undef, "ERR", 3, scalar(caller), "perl died, $error");
            _output(undef, "err", 3, scalar(caller), "@trace") if $trace[0];
        } else {
            _output(undef, "ERR", 3, scalar(caller), "perl died, $error");
            _output(undef, "err", 7, scalar(caller), "@trace") if $trace[0];
        }
        exit(1);
    };

# begin block finished
}



# init cli options used by this module
INIT {
    Mnet::Opts::Cli::define({
        getopt      => 'debug',
        help_tip    => 'set to display extra debug log entries',
        help_text   => '
            note that the --quiet and --silent options override this option
            refer to perldoc Mnet::Log for more information
        ',
    });
    Mnet::Opts::Cli::define({
        getopt      => 'quiet!',
        help_tip    => 'set to suppress terminal standard output',
        help_text   => '
            suppresses Mnet::Log stdout entries, not necessarily other stdout
            use shell redirection if necessary to suppress all script stdout
            note that setting this option overrides the --silent option
            refer to perldoc Mnet::Log for more information
        ',
    });
    Mnet::Opts::Cli::define({
        getopt      => 'silent!',
        help_tip    => 'set to suppress standard output and error',
        help_text   => '
            suppresses all Mnet::Log output, but not necessarily other output
            use shell redirection if necessary to suppress all script output
            note that this option can be overridden by the --quiet option
            refer to perldoc Mnet::Log for more information
        ',
    });
}



sub new {

=head1 $self = Mnet::Log->new(\%opts)

This class method creates a new Mnet::Log object. The opts hash ref argument is
not requried but may be used to override any parsed cli options parsed with the
Mnet::Opts::Cli module.

The returned object may be used to call other documented methods in this module.

The input opts hash ref may contain a log_identifier key which may be set to
a device name or other identifier which will be prepended to all entries made
using the returned Mnet::Log object. A warning will be issued if the identifier
is not a single word.

Refer to the SYNOPSIS section of this perldoc for more information.

=cut

    # read input class and optional opts hash ref
    my $class = shift // croak("missing class arg");
    croak("invalid call to class new") if ref $class;
    my $opts = shift // {};

    # warn if log_indentifier contains non-space characters
    carp("invalid log_identifier $opts->{log_identifier}")
        if defined $opts->{log_identifier}
        and $opts->{log_identifier} !~ /^\S+$/;

    # create object, apply input opts over any cached cli options
    my $self = bless Mnet::Opts::Cli::Cache::get($opts), $class;

    # finished new method
    return $self;
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



sub _output {

# _output($self, $prefix, $severity, $caller, $text)
# purpose: used by other methods in this module to output Mnet::Log entries
# $self: object instance passed from public methods in this module, or undef
# $prefix: set to a keyword used to prefix entry such as dbg, inf, WRN, or ERR
# $severity: set to 7 for debug, 6 for info, 4 for warn, and 5 for error
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
    if (not $Mnet::Log::first) {
        $Mnet::Log::first = 1;
        my $script_name = $0;
        $script_name =~ s/^.*\///;
        my $pid_time = $self->{test} ? "--test run" : "pid $$, ".localtime;
        my $text = "script $script_name started, $pid_time";
        _output($self, "inf", 6, "Mnet::Log", $text);
    }

    # return for debug entries if --debug is not set
    return 1 if $severity > 6 and not $self->{debug};

    # return if --silent is set, unless --quiet is also set
    return 1
        if $self->{silent}
        and (not defined $self->{quiet} or not $self->{quiet});

    # return for non-warning entries if --quiet is set
    return 1 if $severity > 4 and $self->{quiet};

    # update global error flag with first line of first error entry
    $Mnet::Log::errors = (split(/\n/, $text))[0]
        if $severity < 5 and not defined $Mnet::Log::errors;

    # set hh:mm:ss timestamp for entries
    my ($second, $minute, $hour, $mday, $month, $year) = localtime();
    my $timestamp = sprintf("%02d:%02d:%02d", $hour, $minute, $second);

    # note identifier for Mnet::Log entries
    my $identifier = $self->{log_identifier} // "-";

    # otherwise output entry as lines of text for each line of input entry text
    #   inf and dbg entries are output to stderr, otherwise output to stderr
    foreach my $line (split(/\n/, $text)) {
        $line = "$timestamp $prefix $identifier $caller $line";
        if ($severity > 4) {
            syswrite STDOUT, "$line\n";
        } else {
            syswrite STDERR, "$line\n";
        }
    }

    # finished _entry sub
    return 1;
}



sub debug {

=head1 $self->debug($text)

Method call to output a debug entry to stdout with an Mnet::Log prefix of dbg.

=cut

    # call _output function
    my ($self, $text) = (shift, shift);
    return $self->_output("dbg", 7, scalar(caller), $text);
}



sub info {

=head1 $self->info($text)

Method call to output an info entry to stdout with an Mnet::Log prefix of inf.

=cut

    # call _output function
    my ($self, $text) = (shift, shift);
    return $self->_output("inf", 6, scalar(caller), $text);
}



sub warn {

=head1 $self->warn($text)

Method call to output a warn entry to stderr with an Mnet::Log prefix of WRN.

=cut

    # call _output function
    my ($self, $text) = (shift, shift);
    return $self->_output("WRN", 4, scalar(caller), $text);
}



sub fatal {

=head1 $self->fatal($text)

Method to output a fatal entry to stderr with an Mnet::log prefix of DIE.

=cut

    # call _output function
    my ($self, $text) = (shift, shift);
    return $self->_output("DIE", 2, scalar(caller), $text);
}



sub DEBUG {

=head1 DEBUG($text)

Function to output a debug entry to stdout with an Mnet::Log prefix of dbg.

=cut

    # call _output function
    my $text = shift;
    return _output(undef, "dbg", 7, scalar(caller), $text);
}



sub INFO {

=head1 INFO($text)

Function to output an info entry to stdout with an Mnet::Log prefix of inf.

=cut

    # call _output function
    my $text = shift;
    return _output(undef, "inf", 6, scalar(caller), $text);
}



sub WARN {

=head1 INFO($text)

Function to output a warn entry to stderr with an Mnet::Log prefix of WRN.

=cut

    # call _output function
    my $text = shift;
    return _output(undef, "WRN", 4, scalar(caller), $text);
}



sub FATAL {

=head1 FATAL($text)

Function to output a fatal entry to stderr with an Mnet::Log prefix of DIE.

=cut

    # call _output function
    my $text = shift;
    _output(undef, "DIE", 2, scalar(caller), $text);
    exit(1);
}



# output Mnet::Log finished entry at end of script
#   note that $^T, aka $BASETIME, is the unixtime script started running
END {
    if ($INC{"Mnet/Log.pm"}) {
        my $opts = Mnet::Opts::Cli::Cache::get({});
        my $pid_elapsed = ", pid $$, ".(time-$^T+1)." seconds elapsed";
        $pid_elapsed = ", --test finished" if $opts->{test};
        my $errors = "errors";
        $errors = "no errors" if not defined $Mnet::Log::errors;
        INFO("finished with " . $errors . $pid_elapsed);
    }
    exit 1 if defined $Mnet::Log::errors;
}



=head1 SEE ALSO

 Mnet

=cut

# normal end of package
1;

