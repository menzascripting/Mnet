package Mnet::Test;

=head1 NAME

Mnet::Test

=head1 SYNOPSIS

This module can record script inputs and outputs to a file, then replay the
file inputs at a later time and test that outputs are still the same.

Other Mnet modules are designed to detect and make use of Mnet::Test, if it is
being used by the current script. For example, the Mnet::Log start, finish, and
debug entries are not saved with stdout, and Mnet::Opts::Cli allows for command
line options and arguments to be recorded and replayed with Mnet::Test files.

Refer to the perldoc TESTING sections in other Mnet modules for an explanation
of how each module supports Mnet::Test record, replay, and test options.

Refer to the TESTING section below for more about how this module works.

=head1 TESTING

This module captures all stdout and stderr output from an executing script and
can --record, --replay, and --test for changes in output.

When --test is used the exit status of the script will reflect whether output
matched what is in the specified --replay file.

Mnet modules with Mnet::Test support will contain a TESTING pod section with a
description of how that module interacts with the --record and --replay options
in this module.

Scripts that use these modules may not need to do anything else to benefit from
Mnet::Test support. At its most basic a script using this module can create a
test data file with the --record option which will contain all the stdout and
stderr output from the script. The --replay and --test options can be used to
execute the script again and alert the user to any change in output.

Note that the stdout and stderr variables that can be imported from this module
can be used for output that should not be captured by the Mnet::Test module.

Also note that the Mnet::Test::time function can be used to return repeatable
sequences of outputs from the perl time command during --test execution.

Scripts or modules that need to save additional data to --record test data
files can call the Mnet::Test::data function to get a referenced hash key that
can be used to store data for the current script or module. The --record option
will save this data to a file at the end of script execution, and the --replay
command can load that data back from the file into the Mnet::Test::data hash.

Scripts that do not use Mnet::Opts::Cli to parse command line options can pass
the replay file as an argument to the Mnet::Test::data function and call the
Mnet::Test::done function at the end of script execution.

=cut

# required modules
#   perl 5.10 may be requried for tie to capture stdout and stderr
use warnings;
use strict;
use 5.010;
use Carp;
use Data::Dumper;
use Exporter qw(import);
use Mnet::Log::Conditional qw( DEBUG INFO WARN FATAL NOTICE );
use Mnet::Opts::Cli::Cache;

# modules required for diff output
BEGIN { push @INC, "$1/Depends" if $INC{"Mnet/Test.pm"} =~ /(.+)Test\.pm$/; }
use Algorithm::Diff;
use Text::Diff;

# export function names
our @EXPORT_OK = qw( $stderr $stdout );



# begin block to initialize capture of stdout and stderr
BEGIN {

    # original stderr and stdout for bypassing output captured by Mnet::Test
    open(our $stderr, ">&STDERR");
    open(our $stdout, ">&STDOUT");

    # init global scalar variable to accumulate other stdout+stderr outputs
    our ($outputs, $disabled) = ("", undef);

    # declare tie contructor used to capture stdout/stderr handles
    sub TIEHANDLE {
        my ($class, $fh) = (shift, shift);
        return bless({ fh => $fh }, $class);
    }

    # declare tie method triggered for print to handles
    sub PRINT {
        my $self = shift;
        &{$self->{fh}}(@_);
        return 1;
    }

    # declare tie method triggered for printf to handles
    sub PRINTF {
        my $self = shift;
        return $self->PRINT(sprintf(@_));
    }

    # declare tie method triggered for write to handles
    sub WRITE {
        my $self = shift;
        my ($buffer, $length ,$offset) = (shift, shift, shift // 0);
        return $self->PRINT(substr($buffer, $offset, $length));
        return 1;
    }

    # create copied of stderr and stdout to be used for output from tie subs
    open(my $stderr_fh, ">&STDERR");
    open(my $stdout_fh, ">&STDOUT");

    # declare sub used to enable capture of stderr and stdout using tie command
    sub enable_tie {
        tie(*STDERR => 'Mnet::Test' , sub {
            $Mnet::Test::outputs .= "@_" if not $disabled;
            return
                if $INC{"Mnet/Opts/Set/Silent.pm"}
                and not $INC{"Mnet/Opts/Set/Quiet.pm"};
            syswrite $stderr_fh, "@_";
        });
        tie(*STDOUT => 'Mnet::Test' , sub {
            $Mnet::Test::outputs .= "@_" if not $disabled;
            return if $INC{"Mnet/Opts/Set/Quiet.pm"};
            return if $INC{"Mnet/Opts/Set/Silent.pm"};
            syswrite $stdout_fh, "@_";
        });
    }

    # use tie to capture stderr and stdout to global test outputs variable
    Mnet::Test::enable_tie();

    # declare sub used from Mnet::Expect to temporarily untie filehandles
    sub disable_tie {
        untie *STDERR;
        untie *STDOUT;
    }

# finished begin block
}



# init global variables and cli options used by this module
#   Mnet::Test::data hash ref holds record/replay/test data, undef until used
#   Mnet::Test::time used for test unixtime, refer to Mnet::Test::time function
INIT {
    our ($data, $time) = (undef, 0);
    Mnet::Opts::Cli::define({
        getopt      => 'record:s',
        help_tip    => 'record test data to file',
        help_text   => '
            files recorded can be replayed using the --replay option
            set null to save using the filename set by the --replay option
            data is saved with a .new suffix, then renamed after writing
            this option works from the command line only
            refer to perldoc Mnet::Test for more info
        ',
    }) if $INC{"Mnet/Opts/Cli.pm"};
    Mnet::Opts::Cli::define({
        getopt      => 'replay=s',
        help_tip    => 'execute with test data from file',
        help_text   => '
            execute script using replay file created with the --record option
            this option works from the command line only
            refer to perldoc Mnet::Test for more info
        ',
    }) if $INC{"Mnet/Opts/Cli.pm"};
    Mnet::Opts::Cli::define({
        getopt      => 'test',
        help_tip    => 'diff script output with --replay output',
        help_text   => '
            use to compare current script output to recorded --replay output
            this option works from the command line only
            refer to perldoc Mnet::Test for more info
        ',
    }) if $INC{"Mnet/Opts/Cli.pm"};
}



sub data {

=head1 \%data = Mnet::Test::data(\%opts);

This function returns a hash reference containing record/replay test data for
the calling module or the main script. It is up to the calling module or main
script to manage its own record/replay data.

The opts hash ref argument is optional, and may be used to specify a replay
file. Otherwise the --replay option will be checked if the Mnet::Opts::Cli
is used to parse command line options.

Note that care must be taken to use the hash reference returned from this
function properly. You want to save data in the returned hash reference, not
accidently create a new hash reference. For example:

 ok:    my $data = Mnet::Test::data();
        $data->{sub_hash}->{key} = $value;

 ok:    my $data = Mnet::Test::data();
        my $sub_hash = \%{$data->{sub_hash}};
        $sub_hash->{key} = $value;

 ok:    my $sub_hash = \%{Mnet::Test::data()->{sub_hash}};
        $sub_hash->{key} = $value;

 bad:   Mnet::Test::data()->{sub_hash}->{key} = $value;

 bad:   my $data = Mnet::Test::data();
        my $sub_hash = $data->{sub_hash};
        $sub_hash->{key} = $value;

Refer to the TESTING section of this document for more information on how
modules or scripts should use this function for record/replay test data.

=cut

    # read opts hash ref arg, or set via cached cli opts
    my $opts = Mnet::Opts::Cli::Cache::get(shift // {});

    # check for force flag, allowed from Mnet::Opts::Cli only
    my $force = shift;
    croak("invalid force option") if $force and caller ne "Mnet::Opts::Cli";

    # note the calling module name
    my $caller = caller;
    $caller = "main" if $caller eq "-e";

    # init global test data var, if not yet defined
    #   init to an empty hash ref, or from file if --replay cli opt is set
    #   force replay data reload if called with force flag from Mnet::Opts::Cli
    if (not defined $Mnet::Test::data or $force) {
        $Mnet::Test::data = {};
        _replay($opts);
    }

    # init hash ref for caller if it doesn't yet exist
    $Mnet::Test::data->{$caller} = {}
        if not exists $Mnet::Test::data->{$caller};

    # finished Mnet::Test::data function, return hash ref for calling module
    return $Mnet::Test::data->{$caller};
}



sub _diff {

# $diff = _diff(\%opts)
# purpose: dump test data to a file, returns if record option is not defined
# \%opts: looks for record hash ref key, uses replay filename if set null
# $diff: diff output in string format, or undef if no replay data to diff

    # read opts hash ref arg, or set via cached cli opts
    my $opts = Mnet::Opts::Cli::Cache::get(shift // {});

    # return if test or replay options are not set
    return undef if not defined $opts->{test};
    return undef if not defined $opts->{replay};

    # abort if there's no replay test data outputs
    my $test_data = data($opts);
    FATAL("undefined --replay test data") if not defined $test_data->{outputs};
    FATAL("undefined current test data") if not defined $Mnet::Test::outputs;

    # init diff output, use Text::Diff if available
    my $diff = "";
    if ($Mnet::Test::outputs ne $test_data->{outputs}) {
        $diff = "Test output is different, need Text::Diff to show more.\n";
        $diff = Text::Diff::diff(\$Mnet::Test::outputs, \$test_data->{outputs})
            if $INC{"Text/Diff.pm"};
    }

    # output detected differences, unless running in --batch mode
    if (not $opts->{batch}) {
        syswrite $Mnet::Test::stdout, "\n" . "-" x 79 . "\n";
        syswrite $Mnet::Test::stdout, "diff --test --replay $opts->{replay}";
        syswrite $Mnet::Test::stdout, "\n" . "-" x 79 . "\n\n";
        if ($diff) {
            syswrite $Mnet::Test::stdout, $diff;
        } else {
            syswrite $Mnet::Test::stdout, "Test output is identical.\n";
        }
        syswrite $Mnet::Test::stdout, "\n";

    # output error for test diff in --batch mode
    } elsif ($diff) {
        FATAL("batch mode test output is different");
    }

    # finished _diff function
    return $diff;
}



sub disable {

# Mnet::Test::disable()
# purpose: used by Mnet::Opts::Cli to disable the accumulation of stdout/err
# note: called by Mnet::Opts::Cli if --test or --record are not set

    # disable accumulation of captured output
    $Mnet::Test::disabled = 1;
}



sub enable {

# Mnet::Test::enable()
# purpose: used by Mnet::Batch to enable batch child accumulation of stdout/err
# note: called by Mnet::Batch for children before calling Mnet::Opts::Cli->new

    # enable accumulation of captured output
    $Mnet::Test::disabled = 0;
}



sub done {

=head1 $diff = Mnet::Test::done(\%opts)

This function does one or two things, depending on the how the record, replay,
and test options are set.

If the replay and test options are set a diff of test output will be returned,
or a value of undefined if there was no test replay data.

If the record option is set then the Mnet::Test data captured from the current
script execution will be saved to the specified record file.

This function is called automatically at script exit using the record, replay,
and test options parsed from a prior Mnet::Opts::Cli->new call. You do not
need to call this function unless you are not using Mnet::Opts::Cli to parse
command line options or if you want to examine your own test diff data.

Refer to the TESTING section of this document for more information.

=cut

    # read opts hash ref arg, or set via cached cli opts
    my $opts = Mnet::Opts::Cli::Cache::get(shift // {});

    # disable any further capture of stdout/stderr
    disable();

    # diff replay output if replay and test options are set true
    my $diff = _diff($opts);

    # record to file, if ncessary
    #   record if set to a specified file
    #   record if test option is not also set
    #   record if there's a test diff
    if (defined $opts->{record}) {
        if ($opts->{record} ne "") {
            _record($opts);
        } elsif (not $opts->{test}) {
            _record($opts);
        } elsif ($diff) {
            _record($opts);
        }
    }

    # finished done function, return diff output
    return $diff;
}



sub _record {

# _record(\%opts)
# purpose: dump test data to a file, returns if record option is not defined
# \%opts: looks for record hash ref key, uses replay filename if set null

    # read opts hash ref arg, or set via cached cli opts
    my $opts = Mnet::Opts::Cli::Cache::get(shift // {});

    # return if record option is not set
    return if not defined $opts->{record};

    # add current captured input to data before recording to file
    $Mnet::Test::data->{"Mnet::Test"}->{outputs} = $Mnet::Test::outputs;

    # prepare to dump test data
    my $dumper = Data::Dumper->new([$Mnet::Test::data]);
    $dumper->Sortkeys(1);
    my $dump = $dumper->Dump;

    # replace default Data::Dumper var name with something more descriptive
    #   this will help discourage bypassing this module to access these files
    $dump =~ s/^\$VAR1/\$Mnet::Test::data/g;

    # log dump of test data that we are going to save
    if ($opts->{debug}) {
        DEBUG("_record: $_") foreach split(/\n/, $dump);
    }

    # update --replay file if --record is set null
    my $record_file = $opts->{record};
    $record_file = $opts->{replay} if $record_file eq "";
    FATAL("null --record set without --replay file")
        if not defined $record_file or $record_file eq "";

    # read dump of test data from replay file, abort on errors
    open(my $fh, ">", $record_file)
        or FATAL("error opening --record $record_file, $!");
    print $fh $dump;
    close $fh;

    # finished _record function
    return;
}



sub _replay {

# _replay(\%opts)
# purpose: read Mnet::Test::data global hash ref data from replay file
# \%opts: hash ref with replay file key, or undef to use Mnet::Opts::Cli::Cache
# note: this is called from Mnet::Test::data()

    # read opts hash ref arg, or set via cached cli opts
    my $opts = Mnet::Opts::Cli::Cache::get(shift // {});

    # return if replay option is not set
    return if not defined $opts->{replay};

    # create log object using current options
    my $log = Mnet::Log::Conditional->new($opts);

    # read dump of test data from replay file, abort on errors
    my $dump = "";
    open(my $fh, "<", $opts->{replay})
        or $log->fatal("error opening --replay $opts->{replay}, $!");
    $dump .= $_ while <$fh>;
    close $fh;

    # log dump of test data that we just read
    if ($opts->{debug}) {
        $log->debug("replay: $_") foreach split(/\n/, $dump);
    }

    # restore variable name before eval of Data::Dumper file data
    $dump =~ s/^\$Mnet::Test::data/\$data/;

    # eval replay dump data, warn on eval syntax problems
    my $data = undef;
    eval {
        local $SIG{__WARN__} = sub { $log->warn("@_") };
        $data = eval $dump;
    };
    $Mnet::Test::data = $data;

    # abort if replay test data hash ref eval failed
    $log->fatal("eval Mnet::Test::data failed for replay file $opts->{replay}")
        if ref $Mnet::Test::data ne "HASH";

    # finished replay function
    return;
}



sub time {

=head1 $unixtime = Mnet::Test::time($incrememt)

=head1 S< > $unixtime = Mnet::Test::time(\%opts, $increment)

This function can be used by project scripts to get repeatable unixtime output
during executions with the record, replay, or test options set, and real time
from the perl time command otherwise.

An optional incrememnt value can be specified in seconds, and defauls to the
returned time being incremented by one second for each call to this function.

This function can be called with an opts hash ref, which can have record and
replay keys set to indicate test output is needed. Otherwise these options
are expected to be set via the Mnet::Opts::Cli module.

=cut

    # read input args, increment might be only arg, opts defaults to cached cli
    my ($opts, $increment) = (shift, shift);
    ($increment, $opts) = ($opts, Mnet::Opts::Cli::Cache::get({}))
        if not ref $opts;

    # default to a one second increment for each call
    $increment = 1 if not $increment;

    # init output unixtime to real time
    my $unixtime = time;

    # set output incremented test time if record, replay or test opt is set
    if (defined $opts->{record} or $opts->{replay} or $opts->{test}) {
        $unixtime = $Mnet::Test::time += $increment;
    }

    # finished Mnet::Test::time function, return unixtime
    return $unixtime;
}



# process record and test cli options, unless Mnet::Log has been loaded
#   called from Mnet::Log end block if loaded, after last log line output
#   --test diff undef if --replay --test diff was not attempted
#   --test diff is null for no diff, exit clean even if output had errors
#   --test diff is non-null for failed diff, exit with a failed status
END {
    if (not $INC{"Mnet/Log.pm"}) {
        my $diff = Mnet::Test::done();
        exit 0 if defined $diff;
        exit 1 if $diff;
    }
}



=head1 SEE ALSO

 Mnet
 Mnet::Log::Conditional
 Mnet::Opts::Cli
 Mnet::Opts::Cli::Cache

=cut

# normal end of package
1;

