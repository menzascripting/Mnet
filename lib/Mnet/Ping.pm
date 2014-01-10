package Mnet::Ping;

=head1 NAME

Mnet::Ping - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

This perl module can be used to test connectivity using ICMP echo
request queries.

Usage examples:

 use Mnet::Ping;
 $ENV{'PATH'} .= ':/sbin';
 my $value = &ping({
     'object-address' => 'hub1-rtr',
 });

=head1 DESCRIPTION

The Ping function in this module requires that an object-address is
configured or given as an argument. The ping function sends one or
more ICMP echo request packets to the object address. The ping
function returns a value of true if there was an ICMP echo reply
from the object, or a value of false if there was no reply.

By default, this module requires the Net::Ping::External module and
uses icmp echo request and reply packets. The ping-type setting can
be changed  to icmp, tcp or udp. Setting icmp requires root access.

Refer to the Net::Ping documentation for more details.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --object-address <addr>  address that ping will connect to
 --ping-detail            enable for extra ping debug detail
 --ping-replay            replay ping output as successful
 --ping-retries <0+>      integer count of retries, defaults to 4
 --ping-version           set at compilation to build number
 --ping-timeout <secs>    integer timeout in seconds, defaults to 2
 --ping-type <type>       default external, or set icmp, tcp or udp

Note that a ping-type of external will use icmp without requiring
root privileges. However the ping executable needs to be in the path.

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and libraries:

=cut

# modules used
use warnings;
use strict;
use Carp;
use Exporter;
use Mnet;
use Net::Ping;

# export module function names
our @ISA = qw( Exporter );
our @EXPORT = qw( ping );

# module initialization
BEGIN {

    # access config and set package defaults
    our $cfg = &Mnet::config({
        'ping-retries'  => 4,
        'ping-version'  => '+++VERSION+++',
        'ping-timeout'  => 2,
        'ping-type'     => 'external',
    });

# end of module initialization
}



sub ping {

=head2 ping function

 $success = &ping(\%args)

This function can be used to send an ICMP echo request packet to the
configured object-address. A value of true is returned if an echo
reply is received, a value of false otherwise.

Default config settings can be changed using the optional args hash
reference argument.

=cut

    # read input oid and optional config args
    &dtl("ping sub called from " . lc(caller));
    my $args = shift;
    $args = {} if not defined $args;
    croak "ping function args argument not a hash ref" if ref $args ne "HASH";
    my $cfg = &config({}, $args);

    # log error if ping-retries not a valid integer
    croak "ping invalid ping-retries " . $cfg->{'ping-retries'}
        if $cfg->{'ping-retries'} !~ /^\d+$/;

    # log error if ping-timeout not a valid integer
    croak "ping invalid ping-timeout " . $cfg->{'ping-timeout'}
        if $cfg->{'ping-timeout'} !~ /^\d+$/;

    # log error if ping-type is not valid
    croak "ping invalid ping-type " . $cfg->{'ping-type'}
        if $cfg->{'ping-type'} !~ /^(external|icmp|tcp|udp)$/;

    # log error if object-address is not configured
    croak "ping missing object-address "
        if not defined $cfg->{'object-address'};

    # return success if ping-replay is configured
    if ($cfg->{'ping-replay'}) {
        &dtl("ping replay in effect, returning success");
        &dbg("ping attempt to $cfg->{'object-address'} replied");
        return 1;
    }

    # create icmp object
    my $ping = Net::Ping->new($cfg->{'ping-type'});

    # execute ping attempts, up to count specified by retry value
    for (my $loop = 1; $loop < $cfg->{'ping-retries'}; $loop++) {
        my $attempt = "attempt $loop of $cfg->{'ping-retries'}";
        &dtl("ping $cfg->{'ping-type'} to $cfg->{'object-address'} $attempt");
        if ($ping->ping($cfg->{'object-address'}, $cfg->{'ping-timeout'})) {
            &dbg("ping attempt to $cfg->{'object-address'} replied");
            return 1;
        } else {
            &dtl("ping attempt to $cfg->{'object-address'} timed out");
        }
    }

    # ping function finished
    &dbg("ping attempt to $cfg->{'object-address'} timed out");
    return 0;
}       



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, Net::Ping

=cut



# normal package return
1;

