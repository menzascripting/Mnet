package Mnet::Test;

=head1 NAME

Mnet::Test

=cut

# required modules
use warnings;
use strict;
use Data::Dumper;
use Mnet::Log::Conditional qw( DEBUG INFO WARN FATAL );
use Mnet::Opts::Cli::Cache;



# begin block to initialize capture of stdout and stderr
BEGIN {

    # init global scalar variable to accumulate stdout+stderr outputs
    my $outputs = "";

    # declare tie contructor used to capture stdout/stderr handles
    sub TIEHANDLE {
        my ($class, $code) = (shift, shift);
        return bless({ CODE => $code }, $class);
    }

    # declare tie method triggered for print to handles
    sub PRINT {
        my $self = shift;
        &{$self->{CODE}}(@_);
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

    # use tie to capture stderr to global test outputs var
    open(my $stderr_fh, ">&STDERR");
    tie(*STDERR => 'Mnet::Test' , sub {
        syswrite $stderr_fh, "@_";
        $Mnet::Test::outputs .= "@_";
    });

    # use tie to capture stdout to global test outputs var
    open(my $stdout_fh, ">&STDOUT");
    tie(*STDOUT => 'Mnet::Test' , sub {
        syswrite $stdout_fh, "@_";
        $Mnet::Test::outputs .= "@_";
    });

# finished begin block
}



# init global var to hold record/replay/test data and cli opt for this module
INIT {
    my $data = undef;
    Mnet::Opts::Cli::define({
        getopt      => 'record:s',
        help_tip    => 'record test data to file',
        help_text   => '
            files recorded can be replayed using the --replay option
            set null to save using the filename set by the --replay option
            data is saved with a .new suffix, then renamed after writing
            refer to perldoc Mnet::Test for more information
        ',
    });
    Mnet::Opts::Cli::define({
        getopt      => 'replay=s',
        help_tip    => 'run with test data from file',
        help_text   => '
            execute script using replay file created with the --record option
            refer to perldoc Mnet::Test for more information
        ',
    });
    Mnet::Opts::Cli::define({
        getopt      => 'test',
        help_tip    => 'diff script output with --replay output',
        help_text   => '
            use to compare current script output to recorded --replay output
            refer to perldoc Mnet::Test for more information
        ',
    });
}



#? finish me, setup record, replay, and diff test outputs
#   export time and localtime functions, with test times
#   remember to add SYNOPSIS perldoc section
#       mention TESTING section in perldoc of modules that use Mnet::Test

sub data {

=head1 \%data = Mnet::Test::data();

#? document me

=cut

    # note the calling module name
    my $caller = caller;
    $caller = "main" if $caller eq "-e";

    # init global test data var, if not yet defined
    #   init to an empty hash ref, or from file if --replay cli opt is set
    if (not defined $Mnet::Test::data) {
        $Mnet::Test::data = {};
        my $opts = Mnet::Opts::Cli::Cache::get({});
        _replay($opts->{replay}) if defined $opts->{replay};
    }

    # init hash ref for caller if it doesn't yet exist
    $Mnet::Test::data->{$caller} = {}
        if not exists $Mnet::Test::data->{$caller};

    # finished Mnet::Test::data function, return hash ref for calling module
    return $Mnet::Test::data->{$caller};
}



sub disable {

# Mnet::Test::disable()
# purpose: used by Mnet::Opts::Cli to disable the collection of stdout/stderr
# note: called by Mnet::Opts::Cli if --test is not set, to avoid out of memory

    # disable tied stdout/stderr handles
    untie(*STDOUT);
    untie(*STDERR);
}



sub _record {

# _record()
# purpose: save Mnet::Test::data global hash ref data to --record file
# note: this is called from this module's end block, if --record is set

    # note cached cli options
    my $opts = Mnet::Opts::Cli::Cache::get({});

    # warn if --record cli option was set but test data was never accessed
    WARN("never needed to save test data for --record $opts->{record}")
        if not defined $Mnet::Test::data;

    # prepare to dump test data
    my $dumper = Data::Dumper->new([$Mnet::Test::data]);
    $dumper->Sortkeys(1);
    my $dump = $dumper->Dump;

    # replace default Data::Dumper var name with something more descriptive
    #   this will help discourage bypassing this module to access these files
    $dump =~ s/^\$VAR1/Mnet::Test::data/g;

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

# _replay()
# purpose: read Mnet::Test::data global hash ref data from --replay file
# note: this is called from Mnet::Test::data() if --replay is set

    # note cached cli options
    my $opts = Mnet::Opts::Cli::Cache::get({});

    # read dump of test data from replay file, abort on errors
    my $dump = "";
    open(my $fh, "<", $opts->{replay})
        or FATAL("error opening --replay $opts->{replay}, $!");
    $dump .= $_ while <$fh>;
    close $fh;

    # log dump of test data that we just read
    if ($opts->{debug}) {
        DEBUG("_replay: $_") foreach split(/\n/, $dump);
    }

    # restore variable name before eval of Data::Dumper file data
    $dump =~ s/^Mnet::Test::data/\$data/;

    # eval replay dump data, warn on eval syntax problems
    my $data = undef;
    eval {
        local $SIG{__WARN__} = sub { WARN("@_") };
        $data = eval $dump;
    };
    $Mnet::Test::data = $data;

    # abort if --replay test data hash ref eval failed
    FATAL("eval Mnet::Test::data failed for --replay $opts->{replay}")
        if ref $Mnet::Test::data ne "HASH";

    # finished _replay function
    return;
}



# end block executed when script exits
END {

    # note cached cli options
    my $opts = Mnet::Opts::Cli::Cache::get({});

    # save test data to file if --record cli option was set
    _record() if defined $opts->{record};

# finished end block
}



=head1 SEE ALSO

 Mnet

=cut

# normal end of package
1;

