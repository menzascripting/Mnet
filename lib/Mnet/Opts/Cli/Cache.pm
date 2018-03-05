package Mnet::Opts::Cli::Cache;

=head1 NAME

Mnet::Opts::Cli::Cache

=head1 SYNOPSIS

This module can be used to access command line options that may be in effect,
depending on if the Mnet::Opts::Cli module new method was used to parse them.

The following is a typical usage example, showing a subroutine that allows for
an Mnet::Opts object to be created using an input opts hash reference which is
overaid onto any cached cli options that may have already been parsed by the
running script:

 # requried to use this module
 use Mnet::Opts::Cli::Cache;

 # sample sub with an input opts arg overlaid onto cached cli options
 sub example {
    my $opts = Mnet::Opts::Cli::Cache::get(shift // {});
 }

Refer to the Mnet::Opts::Cli and Mnet::Opts modules for more info.

=cut

# required modules
#   importing symbols from Mnet::Log::Conditional causes compile errors,
#       apparently because Mnet::Log::Conditional uses this module,
#       it causes a catch-22 for imports to work before Exporter runs,
#       workaround is call with path, example: Mnet::Log::Conditional::INFO()
use warnings;
use strict;
use Carp;
use Mnet::Log::Conditional;
use Mnet::Opts::Set;
use Storable;



# init global vars used for cached cli opt hash ref and extra cli args list
#   opts is undefined until Mnet::Opts::Cli::Cache::set() is called
INIT {
    my $opts = undef;
    my @extras = ();
}



sub set {

# Mnet::Opts::Cli::Cache::set(\%opts, @extras)
# purpose: called from Mnet::Opts::Cli->new to cache cli opts and extra args
# \%opts: Mnet::Opts::Cli object parsed by Mnet::Opts::Cli->new
# @extras: extra cli arguments parsed by Mnet::Opts::Cli->new
# note: this is meant to be called from Mnet::Opts::Cli only

    # set global cache variables with input opts object and extra args
    #   output debug if unexpectantly called other than from Mnet::Opts::Cli
    my ($opts, @extras) = (shift, @_);
    $Mnet::Opts::Cli::Cache::opts = $opts;
    $Mnet::Opts::Cli::Cache::extras = @extras;
    Mnet::Log::Conditional::DEBUG("set called from ".caller)
        if caller ne "Mnet::Opts::Cli";
    return;
}



sub get {

=head1 \%opts = Mnet::Opts::Cli::Cache::get(\%input);

=head1 S< > or (\%opts, @extras) = Mnet::Opts::Cli::Cache::get(\%input);

This function can be used to retrieve a hash reference of parsed cli options
and a list of extra cli arguments. An optional input hash reference can be
used to specify options that will override any cached cli opts.

Note that the returned hash reference of cached cli options will be empty if
the Mnet::Opts::Cli->new method was not called yet by the running script and
no input hash reference was supplied. This can be used to tell if a script is
using Mnet::Opts::Cli for command line option parsing.

Also note that this function can be called in list context to return a hash ref
of cached cli options and extra arguments paresed from the commmand line, or in
scalar context to return cached cli options only.

Refer to the SYNOPSIS section of this perldoc for usage examples and more info.

=cut

    # return clone of cached cli options and extra cli args
    #   return undef if Mnet::Opts::Cli was not used for cli option parsing
    #   retrieve either cached cli opts or pragma opts if cli opts not parsed
    #   overlay input options on top of parsed cli/prgama opts before returning
    my $input = shift;
    return undef if not $input and not $Mnet::Opts::Cli::Cache::opts;
    my $opts = Storable::dclone(
        $Mnet::Opts::Cli::Cache::opts // Mnet::Opts::Set::pragmas()
    );
    $opts->{$_} = $input->{$_} foreach keys %$input;
    my @extras = @Mnet::Opts::Cli::Cache::extras;
    return wantarray ? ($opts, @extras) : $opts
}



=head1 SEE ALSO

 Mnet
 Mnet::Log::Conditional
 Mnet::Opts::Set

=cut

# normal package return
1;

