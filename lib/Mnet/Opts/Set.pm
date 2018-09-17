package Mnet::Opts::Set;

=head1 NAME

Mnet::Opts::Set

=head1 SYNOPSIS

This module can be used to check what Mnet::Opts::Set pragma sub-modules are
currently loaded.

Scripts should not need to use or call this module. Normally scripts would use
the Mnet::Opts and Mnet::Opts::Cli modules, which handle checking the status of
Mnet::Opts::Set pragma sub-modules.

=cut

# required modules
use warnings;
use strict;
use Carp;



sub enable {

# Mnet::Opts::Set::enable($pragma)
# purpose: use this function to dynamically load the specified pragma option
# $pragma: progma option to enable, such as silent, quiet, etc.

    my $pragma = shift // croak("missing pragma arg");
    my $path = $INC{"Mnet/Opts/Set.pm"};
    $path =~ s/(Mnet\/Opts\/Set)\.pm$/$1\//;
    $path .= ucfirst($pragma) . ".pm";
    $INC{"Mnet/Opts/Set/".ucfirst($pragma).".pm"} = $path;
    return;
}



sub pragmas {

=head1 $opts = Mnet::Opts::Set::pragmas()

This function returns a hash containing true values for any Mnet::Opts::Set
pragma sub-modules that have been loaded with the perl 'use' command.

Refer to the SEE ALSO section of this perldoc for a list of these sub-modules.

=cut

    # return opts hash with values set for used Mnet::Opts::Set sub-modules
    my $opts = {};
    foreach my $module (keys %INC) {
        next if $module !~ /^Mnet\/Opts\/Set\/(\S+)\.pm$/;
        $opts->{lc($1)} = 1;
    }
    return $opts;
}



=head1 SEE ALSO

 Mnet
 Mnet::Opts::Cli
 Mnet::Opts::Cli::Cache
 Mnet::Opts::Set::Debug
 Mnet::Opts::Set::Quiet
 Mnet::Opts::Set::Silent

=cut

# normal package return
1;

