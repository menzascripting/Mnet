package Mnet::Opts::Cli;

=head1 NAME

Mnet::Opts::Cli

=head1 SYNOPSIS

The functions and methods in this module can be used by scripts to define and
parse command line options, as shown in the example below:

 # required to use this module
 use Mnet::Opts::Cli;

 # define --sample cli option
 Mnet::Opts::Cli::define({
     getopt   => 'sample=s',
     help_tip => 'set to input string',
 });

 # call in list context for cli opts object and any extra args
 my ($cli, @extras) = Mnet::Opts::Cli->new();

 # call in scalar context to disallow extra args
 $cli = Mnet::Opts::Cli->new();

 # access parsed cli options using method calls
 my $value = $cli->sample;

Refer to the Mnet::Opts and Mnet::Opts::Cli::Cache modules for more info.

=head1 TESTING

#? finish me, describe --record/replay behaviour

=cut

# required modules, inherits from Mnet::Opts
use warnings;
use strict;
use parent 'Mnet::Opts';
use Carp;
use Getopt::Long;
use Mnet::Dump;
use Mnet::Log::Conditional qw( DEBUG INFO WARN FATAL );
use Mnet::Opts::Cli::Cache;
use Mnet::Opts::Set;
use Storable;



# init global var in begin block for defined cli options
#   defined in begin block to be available for calls from other init blocks
#   these are set by Mnet::Opts::Cli::define() function
BEGIN {
    my $defined = {};
}



# init cli options used by this module
INIT {
    Mnet::Opts::Cli::define({
        getopt      => 'help:s',
        help_tip    => 'display tips, or text for matching options',
    });
}



sub define {

=head1 Mnet::Opts::Cli::define(\%specs)

This function may be used during initialaztion to define cli options which can
be parsed by the Mnet::Opts->cli class method in this module, as in the example
which follows that define a --sample string option:

 use Mnet::Cli::Opts;
 Mnet::Opts::Cli::define({ getopt => 'sample=s' });

A warning results if an option with the same name has already been defined.

The following Getopt::Long option specification types are supported:

 opt    --opt       boolean option, set true if --opt is set
 opt!   --[no]opt   negatable option, returns false if --noopt is set
 opt=i  --opt <i>   required integer, warns if input value is not set
 opt:i  --opt [i]   optional integer, returns null if value not set
 opt=s  --opt <s>   required string, warns if input value is not set
 opt:s  --opt [s]   optional string, returns null if value not set

The following keys in the specs input hash reference argument are supported:

 getopt     - required option name and type, refer to perldoc Getopt::Long
 default    - default value for option, defaults to undefined
 help_tip   - short tip text to show in --help list of available options
 help_text  - longer help text to show in --help for specific options

Refer to perldoc Getopt::Long for more information.

=cut

    # read input option definition specs
    my $specs = shift or croak("missing specs arg");
    croak("invalid specs hash ref") if ref($specs) ne "HASH";

    # check for required getopt key in input specs, note opt name
    croak("missing specs hash getopt key") if not defined $specs->{getopt};
    croak("invalid specs hash getopt value") if $specs->{getopt} !~ /^(\w+)/;
    my $opt = $1;

    # abort if option was already defined
    #   options defined differently in multiple places would cause problems
    croak("option $opt defined by $Mnet::Opts::Cli::defined->{$opt}->{caller}")
        if exists $Mnet::Opts::Cli::defined->{$opt};

    # copy input specs to global var holding defined options
    $Mnet::Opts::Cli::defined->{$opt} = Storable::dclone($specs);

    # set caller for defined option
    $Mnet::Opts::Cli::defined->{$opt}->{caller} = caller;

    # set help_usage for defined option
    #   note that this aborts with an error for unsupported Getopt::Long types
    $Mnet::Opts::Cli::defined->{$opt}->{help_usage}
        = _define_help_usage($Mnet::Opts::Cli::defined->{$opt}->{getopt});

    # finished Mnet::Opts::Cli::define
    return;
}



sub _define_help_usage {

# $help_usage = _define_help_usage($getopt)
# purpose: output help usage syntax given input getopt string
# $getopt: input option specification in Getopt::Long format
# $help_usage: output option usage syntax, used for --help output
# note: aborts with an error for unsupported Getopt::Long specs

    # read input getopt spec string
    my $getopt = shift // croak "missing getopt arg";

    # init output help usage string for supported getopt types
    my $help_usage = undef;
    if ($getopt =~ /^(\w+)$/)   { $help_usage = $1;       }
    if ($getopt =~ /^(\w+)\!$/) { $help_usage = "[no]$1"; }
    if ($getopt =~ /^(\w+)=i$/) { $help_usage = "$1 <i>"; }
    if ($getopt =~ /^(\w+):i$/) { $help_usage = "$1 [i]"; }
    if ($getopt =~ /^(\w+)=s$/) { $help_usage = "$1 <s>"; }
    if ($getopt =~ /^(\w+):s$/) { $help_usage = "$1 [s]"; }

    # abort if unable to determine help usage
    croak("invalid or unsupported specs hash getopt value $getopt")
        if not defined $help_usage;

    # finished _define_help_usage, return help_usage
    return $help_usage;
}


sub new {

=head1 $self = Mnet::Opts::Cli->new()

=head1 S< > or ($self, @extras) = Mnet::Opts::Cli->new()

The class method may be used to retrieve an options object containing defined
options parsed from the command line and an array contining any extra command
line arguments.

If called in list context this method will return an opts object containing
values for defined options parsed from the command line followed by a list of
any other extra arguments that were present on the command line.

 use Mnet::Opts::Cli;
 my ($cli, @extras) = Mnet::Opts::Cli->new();

If called in scalar context a warning will be issued if extra command line
arguments exist.

 use Mnet::Opts::Cli;
 my $cli = Mnet::Opts::Cli->new();

Options are applied in the following order:

 - command line
 - Mnet environment variable
 - Mnet::Opts::Set use pragmas
 - Mnet::Opts::Cli::define default key

Note that warnings are not issued for unknown options that may be set for other
scripts in the Mnet environment variable. Also note that the Mnet environment
variable is not parsed if the --test option is set on the command line.

The perl ARGV array is not modified by this module.

=cut

    # read input class, warn if not called as a class method
    my $class = shift // croak("missing class arg");
    croak("invalid call to class new") if ref $class;

    # returned cached cli options and extra args, if set from prior call
    if (Mnet::Opts::Cli::Cache::get()) {
        my ($opts, @extras) = Mnet::Opts::Cli::Cache::get();
        my $self = bless $opts, $class;
        return wantarray ? ($self, @extras) : $self;
    }

    # configure how command line parsing will work
    Getopt::Long::Configure(qw/
        no_auto_abbrev
        no_getopt_compat
        no_gnu_compat
        no_ignore_case
        pass_through
        prefix=--
    /);

    # note all getopt definitions, set from Mnet::Opt::Cli::define()
    my @definitions = ();
    foreach my $opt (keys %{$Mnet::Opts::Cli::defined}) {
        push @definitions, $Mnet::Opts::Cli::defined->{$opt}->{getopt}
    }

    # parse options set via Mnet::Opts::Set pragma sub-modules
    my $pragma_opts = Mnet::Opts::Set::pragmas();

    # parse options from command line, also note extra args on command line
    #   remove -- as the first extra options, used to stop option parsing
    #   output extra cli arg warning when not called to return extras args
    my ($cli_opts, @extras) = ({}, @ARGV);
    Getopt::Long::GetOptionsFromArray(\@extras, $cli_opts, @definitions);
    shift @extras if defined $extras[0] and $extras[0] eq "--";
    die "invalid extra arguments @extras\n" if $extras[0] and not wantarray;

    #? check for opts applied via replay
    #   remember not only opts, buts also extra args
    #   maybe have it so that new opts/args completely replace old in test data

    # check for Mnet::Test replay data for this module, refer to TESTING pod
    #   set cli cache before calling Mnet::Test, needed to check for --replay
    Mnet::Opts::Cli::Cache::set($cli_opts, @extras);
    my $test_data = Mnet::Test::data();

    # parse options from Mnet environment variable if --test is not set
    #   ignore warnings for env options that might not be defined at the moment
    my $env_opts = {};
    eval {
        local $SIG{__WARN__} = "IGNORE";
        Getopt::Long::GetOptionsFromString($ENV{Mnet}, $env_opts, @definitions);
    } if defined $ENV{Mnet} and not $cli_opts->{test};

    # prepare list to hold log entries, which will be output later
    #   to avoid catch-22 of properly logging opts before log opts are parsed
    my @log_entries = ();

    # apply options in order of precedence, refer to perldoc for this method
    #   note deferred log entry for each option, including log option type
    my $opts = {};
    foreach my $opt (sort keys %{$Mnet::Opts::Cli::defined}) {
        my $opt_src = "def opt";
        if (exists $cli_opts->{$opt}) {
            ($opts->{$opt}, $opt_src) = ($cli_opts->{$opt}, "cli opt");
        } elsif (exists $env_opts->{$opt}) {
            ($opts->{$opt}, $opt_src) = ($env_opts->{$opt}, "env opt");
        } elsif (exists $pragma_opts->{$opt}) {
            ($opts->{$opt}, $opt_src) = ($pragma_opts->{$opt}, "use opt");
        } elsif (exists $Mnet::Opts::Cli::defined->{$opt}->{default}) {
            $opts->{$opt} = $Mnet::Opts::Cli::defined->{$opt}->{default};
        }
        push @log_entries, "$opt_src $opt = ".Mnet::Dump::line($opts->{$opt});
    }

    # update cache after parsing env opts, cli opts, replay opt, and extra args
    Mnet::Opts::Cli::Cache::set($opts, @extras);

    # output --help if set on command line and exit
    #   disable log entries during help by setting --quiet in cli cache
    #   width of longest help_usage string is used to pad help tips column
    #   --help set to null outputs short help tips for all defined options
    #   --help otherwise outputs longer help text for matching defined options
    if (defined $cli_opts->{help}) {
        my $width = 0;
        Mnet::Opts::Cli::Cache::set({ quiet => 1 }, @extras);
        foreach my $opt (sort keys %{$Mnet::Opts::Cli::defined}) {
            my $usage = $Mnet::Opts::Cli::defined->{$opt}->{help_usage};
            $width = length($usage) + 2 if $width < length($usage) + 2;
        }
        syswrite STDOUT, "\nAvailable options:\n\n";
        foreach my $opt (sort keys %{$Mnet::Opts::Cli::defined}) {
            my $defined_opt = $Mnet::Opts::Cli::defined->{$opt};
            my $tip = $defined_opt->{help_tip} // "";
            my $usage = $defined_opt->{help_usage};
            if ($cli_opts->{help} eq "") {
                syswrite STDOUT, sprintf(" --%-${width}s $tip\n", $usage);
            } elsif ($opt =~ /$cli_opts->{help}/) {
                my $text = $defined_opt->{help_text} // "";
                $text =~ s/(^(\n|\s)+|(\n|\s+)$)//g;
                $text =~ s/^\s*/   /mg;
                syswrite STDOUT, " --$usage\n\n   $tip\n\n$text\n\n";
            }
        }
        syswrite STDOUT, "\n";
        exit;
    }

    # disable collection of stdout/stderr if --test is not set
    Mnet::Test::disable() if $INC{"Mnet/Test.pm"} and not $opts->{test};

    # log parsed options
    my $log = Mnet::Log::Conditional->new($opts);
    foreach my $log_entry (@log_entries) {
        if ($log_entry =~ /^def/) {
            $log->debug("new parsed $log_entry");
        } else {
            $log->info("new parsed $log_entry");
        }
    }

    # log any extra arguments
    $log->info("new parsed cli arg (extra) = "._dump($_)) foreach @extras;

    # create new cli opts object using the current class
    my $self = bless $opts, $class;

    # finished new method, return cli opts object and extra args or just object
    return wantarray ? ($self, @extras) : $self;
}



=head1 SEE ALSO

 Mnet

=cut

# normal package return
1;

