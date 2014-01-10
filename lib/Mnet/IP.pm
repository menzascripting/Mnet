package Mnet::IP;

=head1 NAME

Mnet::IP - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

Usage examples, showing IPv4 addresses only:

 use Mnet::IP;
 $mask = &ipv4_cidr2mask("23");                  # mask = 255.255.254.0
 $host = &ip_fqdn2host("test.domain.local");     # host = test
 $cidr = &ipv4_hex2cidr("0xfffffc00");           # cidr = 22
 $mask = &ipv4_hex2mask("0xfffffc00");           # mask = 255.255.252.0
 $ip = &ip_host2ip("test.domain.local");         # ip = 10.10.1.1
 $fqdn = &ip_ip2fqdn("10.10.1.1");               # fqdn = test.local
 $neigh = &ipv4_ip2neighbor("10.1.1.6");         # neigh = 10.1.1.5
 $net = &ip_ip2net("10.9.8.7", "255.255.0.0");   # net = 10.9.0.0
 $cidr = &ipv4_mask2cidr("255.255.255.224");     # cidr = 27
 $wcard = &ipv4_mask2wildcard("255.255.255.0");  # wcard = 0.0.0.255
 $ok = &ip_valid_cidr("24");                     # ok = 1
 $ok = &ipv4_valid_hex("0xffffff00");            # ok = 1
 $ok = &ip_valid("1.2.3.4");                     # ok = 1

=head1 DESCRIPTION

The IP module contains functions for working with both IPv4 and IPv6
addressing information.

Note that the functions in this module will log a debug message with
the results of their operations.

Also note that input validation occurs for each function, and bad
input arguments will result in a bug being logged and stopping script
execution. The validation functions can be used to check that data is
valid before calling the other functions.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --ip-detail        enable for extra ip module debug detail 
 --ip-version       set at compilation to build number

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

# export module function names
our @ISA = qw( Exporter );
our @EXPORT = qw( ipv4_cidr2mask ip_fqdn2host ipv4_hex2cidr ipv4_hex2mask
    ip_host2ip ip_ip2fqdn ipv4_ip2neighbor ip_ip2net ipv4_mask2cidr
    ipv4_mask2wildcard ip_valid_cidr ipv4_valid_hex ip_valid
);

# module initialization
BEGIN {
    our $cfg = &Mnet::config({
        'ip-version'    => '+++VERSION+++',
    });
}



sub ipv4_cidr2mask {

=head2 ipv4_cidr2mask function

 $mask = &ipv4_cidr2mask($cidr)

This method can be used to convert a cidr value between 0 and 32 to
a dotted decimal network mask.

=cut

    # validate input cidr and convert to output dotted decimal mask 
    my $cidr = shift;
    croak "ipv4_cidr2mask cidr arg invalid"
        if not &ip_valid_cidr($cidr, "255.255.255.255");
    my ($mask_start, $mask_mid, $mask_end) = ("", "", "");
    if ($cidr < 9) {
        $mask_end = ".0.0.0";
    }
    if ($cidr > 24) {
        ($mask_start, $mask_end) = ("255.255.255.", "");
        $cidr -= 24;
    }
    if ($cidr>16) {
        ($mask_start, $mask_end) = ("255.255.", ".0");
        $cidr -= 16;
    }
    if ($cidr > 8) {
        ($mask_start, $mask_end) = ("255.", ".0.0");
        $cidr -= 8;
    }
    $mask_mid = 256 - ( 2** (8 - $cidr) );
    my $mask = $mask_start . $mask_mid . $mask_end;
    &dtl("ip4v_cidr2mask for input cidr $cidr is mask $mask");
    return $mask;
}



sub ip_fqdn2host {

=head2 ip_fqdn2host function

 $host = &ip_fqdn2host($fqdn)
 ($host, $domain) = &ip_fqdn2host($fqdn)

This function can be used to extract the host, and optionally also
the domain, from a fully qualified domain name.

Null values will be returned for the host or domain name if they
cannot be parsed from the input argument.

=cut

    # read input fully qualified domain name, parse inot host and domain
    my ($host, $domain, $fqdn) = ("", "", shift);
    croak "ip_fqdn2host undefined fqdn arg" if not defined $fqdn;
    if ($fqdn =~ /^\./) {
        $domain = $fqdn;
        $domain =~ s/^\.+//;
    } else {
        $host = $fqdn;
        $host =~ s/^([^\.]+).*$/$1/;
        if ($fqdn ne $host) {
            $domain = $fqdn;
            $domain =~ s/^\Q$host\E\.//;
        }
    }
    &dtl("ip_fqdn2host fqdn '$fqdn' is host '$host' domain '$domain'");
    return ($host, $domain);
}



sub ipv4_hex2cidr {

=head2 ipv4_hex2cidr function

 $cidr = &ipv4_hex2cidr($hex)

This function converts a hex network mask in 0xhhhhhhhh format into
a cidr value between 0 and 32.

=cut

    # validate hex input and convert to cidr value
    my $hex = shift;
    croak "ipv4_hex2cidr hex arg invalid" if not &ipv4_valid_hex($hex);
    my $mask = &ipv4_hex2mask($hex);
    my $cidr = &ipv4_mask2cidr($mask);
    &dtl("ip4v_hex2cidr for input hex $hex is cidr $cidr");
    return $cidr;
}



sub ipv4_hex2mask {

=head2 ipv4_hex2mask function

 $mask = &ipv4_hex2mask($hex)

This function converts an IPv4 hex network mask in 0xhhhhhhhh format into
a dotted decimal IPv4 network mask.

=cut

    # validate hex input and convert to dotted decimal mask
    my $hex = shift;
    croak "ipv4_hex2mask hex arg invalid" if not &ipv4_valid_hex($hex);
    croak "ipv4_hex2mask internal error for input value $hex"
        if $hex !~ /^0x(\S\S)(\S\S)(\S\S)(\S\S)$/i;
    my ($o1, $o2, $o3, $o4) = (hex($1), hex($2), hex($3), hex($4));
    my $mask = "$o1.$o2.$o3.$o4";
    &dtl("ip4v_hex2mask for input hex $hex is mask $mask");
    return $mask;
}



sub ip_host2ip {

=head2 ip_host2ip function

 $ip = &ip_host2ip($host)

This function will attempt to use the local system name resolver to
convert the given host address to an IP address.

A null value will be returned if an IP address cannot be found.

Note that this may return IPv4 or IPv6 addresses depending on name
name resolution from the local system.

=cut

    # read input hostname and attempt to resolve to an ip address
    my ($ip, $host) = ("", shift);
    if (defined $host) {
        my @data = gethostbyname($host);
        if (@data and defined $data[2] and $data[2] eq "2"
            and defined $data[3] and $data[3] eq "4" and defined $data[4]) {
            $ip = join(".", unpack("C4",$data[4]))
        }
    }
    &dtl("ip_host2ip for host $host returnd ip '$ip'");
    return $ip;
}



sub ip_ip2fqdn {

=head2 ip_ip2fqdn function

 $fqdn = &ip_ip2fqdn($ip)

This method can be used to lookup the fully qualified domain name of
the given input IP address. The local operating system will be used
to resolve the address to a name.

A null value will be returned if unable to resolve the name.

=cut

    # initialze output neighbor ip, validate input ip, convert using last octet
    my $ip = shift;
    croak "ip_ip2fqdn ip arg invalid" if not &ip_valid($ip);
    my $fqdn = gethostbyaddr(pack('C4', split(/\./, $ip)), 2);
    $fqdn = "" if not defined $fqdn;
    &dtl("ip_ip2fqdn for ip $ip is fqdn $fqdn");
    return $fqdn;
}



sub ipv4_ip2neighbor {

=head2 ipv4_ip2neighbor function

 $net = &ipv4_ip2neighbor($ip)

This method can be used to calculate the neighbor ip address of a
given input ip address argument on a /30 subnet.

=cut

    # initialze output neighbor ip, validate input ip, convert using last octet
    my ($neighbor, $ip) = (undef, shift);
    croak "ipv4_ip2neighbor ip arg invalid" if not &ip_valid($ip);
    my $temp = $ip;
    my $octet = $2 if $temp =~ s/^(\d+\.\d+\.\d+\.)(\d+)$/$1/;
    $neighbor = $temp . ($octet + 1) if $octet % 4 == 1;
    $neighbor = $temp . ($octet - 1) if $octet % 4 == 2;
    &dtl("ip4v_ip2neighbor for ip $ip is neighbor $neighbor");
    return $neighbor;
}



sub ip_ip2net {

=head2 ip_ip2net function

 $net = &ip_ip2net($ip, $mask)

This method can be used to extract the network address of an ip, given
the ip address and dotted decimal network mask.

=cut

    # initialze output net ip, validate input ip and mask, convert using bits
    my ($net, $ip, $mask) = (undef, @_);
    croak "ip_ip2net ip arg invalid" if not &ip_valid($ip);
    croak "ip_ip2net mask arg invalid" if not &ip_valid($mask);
    $ip = unpack("N", pack("C4", split(/\./, $ip)));
    $mask = unpack("N", pack("C4", split(/\./, $mask)));
    $net = join(".", unpack("C4", pack("N", ($ip & $mask))));
    &dtl("ip_ip2net converted $ip / $mask to $net");
    return $net;
}



sub ipv4_mask2cidr {

=head2 ipv4_mask2cidr function

 $cidr = &ipv4_mask2cidr($mask)

This method can be used to convert a dotted decimal IPv4 network mask
to a cidr network mask value between 0 and 32.

=cut

    # initialize output cidr, read and validate input mask, and convert
    my ($cidr, $mask) = (0, shift);
    croak "ipv4_mask2cidr mask arg invalid" if not &ip_valid($mask);
    my $temp = $mask;
    $temp =~ s/^0\.0\.0\.0$//;
    $cidr = 24 if $temp =~ s/^255\.255\.255\.(\d+)$/$1/;
    $cidr = 16 if $temp =~ s/^255\.255\.(\d+)\.0$/$1/;
    $cidr = 8 if $temp =~ s/^255\.(\d+)\.0\.0$/$1/;
    $cidr += 8 if $temp =~ s/^255$//;
    $cidr += 7 if $temp =~ s/^254$//;
    $cidr += 6 if $temp =~ s/^252$//;
    $cidr += 5 if $temp =~ s/^248$//;
    $cidr += 4 if $temp =~ s/^240$//;
    $cidr += 3 if $temp =~ s/^224$//;
    $cidr += 2 if $temp =~ s/^192$//;
    $cidr += 1 if $temp =~ s/^128$//;
    &dtl("ipv4_mask2cidr converted mask $mask to cidr $cidr");
    return $cidr;
}



sub ipv4_mask2wildcard {

=head2 ipv4_mask2wildcard function

 $wildcard = &ipv4_mask2wildcard($mask)

This method can be used to convert a dotted decimal IPv4 network mask
to a cisco IPv4 access list wildcard mask.

This same function can be called again with a widlcard as the input
argument to convert back to a normal dotted decimal mask.

=cut

    # initialize output wildcard, read and validate input mask, and convert
    my ($wildcard, $mask) = ("", shift);
    croak "ipv4_mask2cidr mask arg invalid" if not &ip_valid($mask);
    foreach my $octet (split(/\./, $mask)) {
        $wildcard .= 255 - $octet . ".";
    }
    $wildcard =~ s/\.$//;
    &dtl("ipv4_mask2wildcard converted $mask to $wildcard");
    return $wildcard;
}



sub ip_valid {

=head2 ip_valid function

 $ok = &ip_valid($ip)

This function can be used to check that a dotted decimal IP address
is valid. A value of true will be returned if the address is valid, a
value of false will be return otherwise.

=cut

    # read input ip, parse, return false if not valid, return true otherwise
    my $ip = shift;
    $ip = "undef" if not defined $ip;
    my ($oct1, $oct2, $oct3, $oct4) = (256, 256, 256, 256);
    ($oct1, $oct2, $oct3, $oct4) = ($1, $2, $3, $4)
        if $ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
    if ($oct1 > 255 or $oct2 > 255 or $oct3 > 255 or $oct4 > 255) {
        &dtl("ip_valid determined $ip is invalid");
        return 0;
    }
    &dtl("ip_valid determined $ip is valid");
    return 1;
}



sub ip_valid_cidr {

=head2 ip_valid_cidr function

 $ok = &ip_valid_cidr($cidr, $ip)

This function can be used to check that a cidr IP address mask is
valid. A cidr address mask should be a whole integer between 0 and 32
for an IPv4 address and 0 and 128 for an IPv6 address.

The IP address argument is optional for this function. If given then
the address will be analyzed to determine whether the given cidr
should be in the IPv4 range or IPv6.

A value of true will be returned if the address is valid, a value of
false will be return otherwise.

=cut

    # read inputs, return false if not valid, return true otherwise
    my ($cidr, $ip) = @_;
    $cidr = "undef" if not defined $cidr;
    if (not defined $cidr or $cidr !~ /^\d+$/
        or $cidr > 128 or defined $ip and $ip =~ /\./ and $cidr > 32) {
        &dtl("ip_valid_cidr determined $cidr is invalid");
        return 0;
    }
    my $temp = "";
    $temp = "for ip $ip" if defined $ip;
    &dtl("ip_valid_cidr determined $cidr is valid $temp");
    return 1;
}



sub ipv4_valid_hex {

=head2 ipv4_valid_hex function

 $ok = &ipv4_valid_hex($hex)

This function can be used to check that a hex IPv4 network mask is
valid. A value of true will be returned if the hex mask is valid, a
value of false will be return otherwise.

It is expected that IP hex network masks will be in the format
0xhhhhhhhh where each digit is a valid hex character from 0-F. Hex
values in this function are not case sensitive.

=cut

    # read input hex mask, return false if not valid, return true otherwise
    my $hex = shift;
    $hex = "undef" if not defined $hex;
    if ($hex !~ /^0x[0-9a-f]{8}$/i) {
        &dtl("ipv4_valid_hex determined $hex is invalid");
        return 0;
    }
    &dtl("ipv4_valid_hex determined $hex is valid");
    return 1;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet

=cut



# normal package return
1;

