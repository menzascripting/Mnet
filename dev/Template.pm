#? update package name
package Mnet::Template;

=head1 NAME

#? update pod name section
Mnet::Template - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

#? Usage examples:

 #!/usr/bin/perl
 use Mnet;
 use Mnet::Template;
 my $cfg = &object;
 my $template = new Mnet::Template;
 my $example1 = $telnet->sample("example");
 my $example2 = new Mnet::Template({
     'object-address'  => 'hub1-rtr',
 });

=head1 DESCRIPTION

#? This perl module can be used...

=head1 CONFIGURATION

#? Alphabetical list of all config settings supported by this module:

 --template-default	    default sample setting
 --template-detail      extra debug logging, default disabled
 --template-version     set at compilation to build number

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and libraries:

=cut

#? modules used
use warnings;
use strict;
use Carp;
use Exporter;
use Mnet;

#? export module function names
our @ISA = qw( Exporter );
our @EXPORT = qw( internal sample );

#? module initialization, set module defaults
BEGIN {
    our $cfg = &Mnet::config({
        'template-version'  => '+++VERSION+++',
        'template-default'  => 1,
    });
}



sub internal {

#? sample internal function
# internal: $output = &internal($input)
# purpose: sample internal function

    # read input
    my $input = shift;

    # processing
    my $output = $input;

    # finished
    return $output;
}



sub sample {

=head2 sample method

 $output = $session->sample($input)

#? This is a method that can be used...

=cut

    # read input
    my $input = shift;
    &dbg($self, "sample sub called from " . lc(caller));
    &bug("not called as an instance") if not ref $self;
    
    # processing
    my $output = $input;
   
    # finished
    return $output;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

#? update main Mnet pod section with this module name
Mnet

=cut



# normal package return
1;

