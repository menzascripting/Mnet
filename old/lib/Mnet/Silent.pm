package Silent;

=head1 NAME

Mnet::Silent - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

Usage examples:

 use Mnet;
 use Mnet::Silent;
 print "no logging\n";
 die "no handlers\n";

=head1 DESCRIPTION

This module sets the log-silent config option during compile time
to disable all mnet module logging and all mnet module signal
handlers.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --log-silent           set during compilation of this module
 --silent-version       set at compilation to build number 

=cut

# modules used
use warnings;
use strict;
use Carp;
use Mnet;

# module initialization
BEGIN {
    my $cfg = &Mnet::config({
        'log-silent'       => 1,
        'silent-version'   => '+++VERSION+++',
    });
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet

=cut



#normal package return;
1;
