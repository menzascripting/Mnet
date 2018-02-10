package Mnet::SNMP;

=head1 NAME

Mnet::SNMP - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

This perl module can be used to query for SNMP values. A Numeric OID
argument is required. A valid object-address must be set in the
configuration. The snmp-community will be prompted for if it is not
already configured.

Usage examples:

 use Mnet;
 use Mnet::SNMP;
 my $cfg = &object({
     'object-address' => 'hub1-rtr',
     'snmp-community' => 'secret',
 });
 my $oid1 = '.1.3.6.1.2.1.1.5.0';
 my $value = &snmp_get($oid1);
 my %table = ();
 my @oids = ('.1.3.6.1.2.1.1.1.0', '.1.3.6.1.2.1.1.5.0');
 &snmp_bulkget(\@oids, \%table);
 my $oid = '.1.3.6.1.2.1.2.2.1';
 my $error = &snmp_bulkwalk($oid, \%table);
 die $error if $error;

=head1 DESCRIPTION

The SNMP query functions in this module require that a numeric OID be
given as an argument - or an array reference for the bulk get function.
The bulk functions are given a table hash reference argument and that
is where the query response values are stored. Also each query function
can be given an optional hash reference argument of config settings to
use for that query.

The optional hash reference configuration settings argument can be used
to supply a different object-address or other relevant parameter for a
specific snmp function call. Normally the object-address configured for
the invoking script is used by the snmp functions.

The user is prompted on the terminal to input an snmp-community when an
snmp query function is called if one is not already set in the
configuration. Once  prompted for, the same snmp-community is used by
other function calls in the same script unless changed with an optional
arg passed to an snmp function call.

The snmp-batch setting can be used to prompt the user once for all
object scripts when running in batch mode. In batch mode different
snmp-community seetings can be specified for any objects in the
batch-list file.

Read table values have been normalized as perl scaler values. SNMP
timeticks have been converted to unix epoch time. The hashes returned
from the bulk query functions use the numeric SNMP OID values as the
key.

Note that the snmp-domain setting can be used to control whether
queuries are executed with the default upd or tcp.

Also note that the default is to connect via ipv4 snmp. If a colon is
detected in the object-address setting then ipv6 will be used, instead.
The Socket6 perl module must be installed for this IPv6 support to
function.

The snmp-record and snmp-replay config settings can be used for
testing. Session activity can be recorded to a file and replayed
back from the file at a later time.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --object-address <addr>   adress that snmp will connect to
 --snmp-batch              input snmp read community once
 --snmp-community <read>   snmp read community
 --snmp-detail             enable for extra snmp debug detail
 --snmp-domain <domain>    default udp, or tcp, udp4, udp6, tcp4, tcp6
 --snmp-record <file>      record snmp session output to a file
 --snmp-replay <file>      replay snmp session output from a file
 --snmp-retries <0+>       integer count of retries, defaults to 2
 --snmp-version            set at compilation to build number
 --snmp-timeout <secs>     integer timeout in seconds, defaults to 2
 --snmp-warn <0|1>         warn on query failures, otherwise debug log

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
use Net::SNMP;

# export module function names
our @ISA = qw( Exporter );
our @EXPORT = qw( snmp_bulkget snmp_bulkwalk snmp_get );

# module initialization
BEGIN {

    # access config and set package defaults
    our $cfg = &Mnet::config({
        'snmp-batch'    => 1,
        'snmp-domain'   => 'udp',
        'snmp-retries'  => 2,
        'snmp-version'  => '+++VERSION+++',
        'snmp-timeout'  => 2,
    });

    # set input for snmp community if batch mode configured
    &Mnet::input("snmp-community", "hide")
        if $cfg->{'batch-list'} and $cfg->{'snmp-batch'}
        and not $cfg->{'snmp-replay'};

    # remove any old snmp-record file
    if ($cfg->{'snmp-record'} and -e $cfg->{'snmp-record'}) {
        &dbg("deleting snmp-record file $cfg->{'snmp-record'}");
        unlink($cfg->{'snmp-record'})
            or croak "snmp-record $cfg->{'snmp-record'} del err $!";
    }

# end of module initialization
}



sub snmp_args {

# internal: (\%args, $log, $session) = &snmp_args(\$function, %args_in)
# purpose: set snmp config args from hash reference and mnet config settings
# \%args_in: optional arguments passed to snmp function from invoking script
# $function: which function call is currently parsing config arguments
# \%args: effective config settings for use in snmp functions
# $log: log prefix string consisting of function and optional object-address
# $session: open snmp session object
# note: snmp session is not opened if snmp-replay arg is set

    # read input arguments
    my ($function, $args_in) = @_;
    $args_in = {} if not defined $args_in;
    croak "snmp_arg function arg missing" if not defined $function;
    croak "snmp_arg config args not a hash ref" if ref $args_in ne "HASH";
    my $args = &config({}, $args_in);

    # log error if snmp-retries not a valid integer
    croak "invalid snmp-retries " . $args->{'snmp-retries'}
        if $args->{'snmp-retries'} !~ /^\d+$/;

    # log error if snmp-timeout not a valid integer
    croak "invalid snmp-timeout " . $args->{'snmp-timeout'}
        if $args->{'snmp-timeout'} !~ /^\d+$/;

    # prompt for snmp community if necessary
    if (not defined $args->{'snmp-community'} and not $args->{'snmp-replay'}) {
        &input('snmp-community', "hide");
        $args->{'snmp-community'} = $Mnet::SNMP::cfg->{'snmp-community'};
    }

    # initialize logging string
    my $log = $function;
    $log .= " to $args->{'object-address'}"
        if $args->{'object-address'} ne $Mnet::SNMP::cfg->{'object-address'};

    # set snmp version based on function name
    my $version = 1;
    $version = 2 if $function =~ /bulk/;

    # set snmp-domain for ipv6 if colon detected in input address, else ipv4
    if ($args->{'snmp-domain'} !~ /(4|6)$/) {
        if ($args->{'object-address'} =~ /:/) {
            $args->{'snmp-domain'} .= "6";
        } else {
            $args->{'snmp-domain'} .= "4";
        }
        &dbg("automatically set snmp-domain to $args->{'snmp-domain'}");
    }

    # return without opening snmp session if snmp-replay is set
    if ($args->{'snmp-replay'}) {
        &dbg("$log snmp-replay set to $args->{'snmp-replay'}");
        return ($args, $log, undef);
    }

    # debug message if we will be recording
    &dbg("$log snmp-record set to $args->{'snmp-record'}")
        if $args->{'snmp-record'};

    # define the new snmp session on standard udp port 161 or error
    my ($session, $error) = Net::SNMP->session(
        -hostname  => $args->{'object-address'},
        -community => $args->{'snmp-community'},
        -domain    => $args->{'snmp-domain'},
        -retries   => $args->{'snmp-retries'},
        -timeout   => $args->{'snmp-timeout'},
        -translate => ['-all' => 0, '-octetstring' => 1,
                      '-opaque' => 1, '-unsigned' => 1],
        -version   => $version,
        -port      => 161
    );
    croak "$log session error $error" if not $session;

    # finished snmp_args function
    return ($args, $log, $session);
}



sub snmp_bulkget {

=head2 snmp_bulkget function

 $error = &snmp_bulkget(\@oids, \%table, \%args)

This function can be used to execute a SNMP version 2c bulk get of a
list of specified object ids from a host.

The input OID array reference should be specified as a list of dotted
decimal notation individual object ids each starting with a period.
The script will terminate with an error if this input is invalid.

On success the input table hash reference will receive a new key for
each found OID in the SNMP MIB after the bulk get, along with
associated values. New keys will be added to the table hash.

The config arguments hash reference argument to use for this call are
optional.

If the SNMP session did not complete successfully the return error
value will have the text of the error message and a warning will be
issued if snmp-warn is set. Otherwise on success the output error
will be undefined.

=cut

    # read input oid and optional config args, count non-repeaters and log
    &dtl("snmp_bulkget sub called from " . lc(caller));
    my ($oids, $table, $args, $log, $session)
        = (shift, shift, &snmp_args("snmp_bulkget", shift));
    my $non_repeaters=@$oids;
    croak "$log no oids specified" if not $non_repeaters;
    croak "$table not a hash ref" if ref $table ne "HASH";
    &dbg("$log preparing for $non_repeaters oids");

    # init bulk oid array, adjust each input oid for bulk get 
    my @bulk_oids=();
    foreach my $oid (@$oids) {
        &dtl("$log preparing for oid $oid");
        if ($oid=~/^(\S+)\.(\d+)\.0$/) {
            my $begin=$1;
            my $digit=$2;
            $digit--;
            push @bulk_oids, "$begin.$digit.0";
        } elsif ($oid=~/^(\S+)\.(\d+)$/) {
            my $begin=$1;
            my $digit=$2;
            $digit--;
            push @bulk_oids, "$begin.$digit";
        } else {
            croak "$log cannot parse digits from oid $oid";
        }
    }
                        
    # initialize query result
    my $result = {};

    # return bulk values for input oids from replay file, if snmp-replay is set
    if ($args->{'snmp-replay'}) {
        &snmp_replay($args->{'snmp-replay'}, "get", $result, @$oids);

    # execute snmp query, since we are not doing an snmp-replay
    } else {
        $result = $session->get_bulk_request(
            -nonrepeaters   => $non_repeaters,
            -maxrepetitions => 0,
            -varbindlist    => \@bulk_oids
        );

        # handle error getting query result
        if (not defined $result) {
            my $error = $session->error if $session->error;
            $error = "unknown snmp error" if not defined $error;
            if ($args->{'snmp-warn'}) {
                carp "$log query error $error";
            } else {
                &dbg("$log query error $error");
            }
            &dbg("$log for $non_repeaters oids = <undef>");
            return $error;
        }

    # result will be set from replay or query
    }

    # handle snmp query result data
    my $count = 0;
    foreach my $oid (keys %$result) {
        $table->{$oid} = $result->{$oid};
        &dtl("$log result $oid = $table->{$oid}");
        &snmp_record($args->{'snmp-record'}, $oid, $table->{$oid})
            if $args->{'snmp-record'};
        $count++;
    }
    &dbg("$log for $non_repeaters oids = $count values");

    # finished snmp_bulkget function
    $session->close if $session;
    return undef;
}



sub snmp_bulkwalk {

=head2 snmp_bulkwalk function

 $error = &snmp_bulkwalk($oid, \%table, \%args)

This function can be used to bulk walk an SNMP agent starting from the
specified object id value using SNMP version 2c.

The input OID argument should be specified in dotted decimal notation
and it should start with a period. The script will terminate with an
error if this input is invalid.

On success the input table hash reference will receive a new key for
each found OID in the SNMP MIB after the bulk get, along with
associated values.

The config arguments hash reference argument to use for this call are
optional.

If the SNMP session did not complete successfully the return error
value will have the text of the error message and a warning will be
issued if snmp-warn is set. Otherwise on success the output error
will be undefined.

=cut

    # read input oid and optional config args
    &dtl("snmp_bulkwalk sub called from " . lc(caller));
    my ($oid, $table, $args, $log, $session)
        = (shift, shift, &snmp_args("snmp_bulkwalk", shift));
    croak "$log call missing oid arg" if not defined $oid;
    croak "$table not a hash ref" if ref $table ne "HASH";
    &dbg("$log preparing for oid $oid");

    # initialize query result
    my $result = {};

    # return bulk values for input oids from replay file, if snmp-replay is set
    if ($args->{'snmp-replay'}) {
        &snmp_replay($args->{'snmp-replay'}, "walk", $result, $oid);

    # execute snmp query, since we are not doing an snmp-replay
    } else {
        $result = $session->get_table(
            -baseoid => $oid
        );

        # handle error getting query result
        if (not defined $result) {
            my $error = $session->error if $session->error;
            $error = "unknown snmp error" if not defined $error;
            if ($args->{'snmp-warn'}) {
                carp "$log query error $error";
            } else {
                &dbg("$log query error $error");
            }
            &dbg("$log oid $oid = <undef>");
            return $error;
        }

    # result will be set from replay or query
    }

    # handle snmp query result data
    my $count = 0;
    foreach my $oid (keys %$result) {
        $table->{$oid} = $result->{$oid};
        &dtl("$log result $oid = $result->{$oid}");
        &snmp_record($args->{'snmp-record'}, $oid, $result->{$oid})
            if $args->{'snmp-record'};
        $count++;
    }
    &dbg("$log oid $oid = $count values");

    # finished snmp_bulkwalk function
    $session->close if $session;
    return undef;
}



sub snmp_get {

=head2 snmp_get function

 $value = &snmp_get($oid, \%args)

This function can be used to query an SNMP agent for the value
associated with a specified MIB OID. SNMP version 1 is used for the
query.

Default config settings can be changed using the optional args hash
reference argument.

The input MIB argument should be specified in dotted decimal notation
and it should start with a period.

The return value will be undefined and a warning issued if there was a
session error and snmp-warn is set. The output will be null if there
was no response to the snmp query. Otherwise the output value will be
the query result.

=cut

    # read input oid and optional config args
    &dtl("snmp_get sub called from " . lc(caller));
    my ($oid, $args, $log, $session)
        = (shift, &snmp_args("snmp_get", shift));
    croak "$log call missing oid arg" if not defined $oid;
    &dbg("$log preparing for oid $oid");

    # initialize snmp query result
    my $result = undef;

    # return value for oid from replay file, if snmp-replay is set
    if ($args->{'snmp-replay'}) {
        $result = {};
        &snmp_replay($args->{'snmp-replay'}, "get", $result, $oid);

    # execute snmp query, since we are not doing an snmp-replay
    } else {
        $result = $session->get_request(
            -varbindlist => [$oid]
        );

    # result will be set from replay or query
    }

    # handle error getting query result
    if (not defined $result) {
        my $error = $session->error if $session->error;
        $error = "unknown snmp error" if not defined $error;
        if ($args->{'snmp-warn'}) {
            carp "$log query error $error";
        } else {
            &dbg("$log query error $error");
        }
        &dbg("$log oid $oid value = <undef>");

    # handle undefined result for specified oid
    } elsif (not defined $result->{$oid}) {
        &dbg("$log oid $oid value = <undef>");

    # log and optionally record snmp value
    } else {
        &dbg("$log oid $oid value = '$result->{$oid}'");
        if ($args->{'snmp-record'}) {
            &snmp_record($args->{'snmp-record'}, $oid, $result->{$oid});
        }
    }

    # finished snmp_get, close session and set return value
    $session->close if defined $session;
    return undef if not defined $result or not defined $result->{$oid};
    return $result->{$oid};
}       



sub snmp_record {

# internal: &snmp_record($file, $oid, $result) if $args->{'snmp-record'}
# purpose: write oid result to snmp record dump file, call if configured
# $file: set to snmp-replay filename, should be in current data directory
# $oid: set to oid values beign stored in snmp replay file
# $result: set to result for snmp oid, may be null

    # read args
    my ($file, $oid, $result) = @_;
    croak "snmp_record file arg missing" if not $file;
    croak "snmp_record oid arg missing" if not $oid;
    &dtl("snmp_record sub called from " . lc(caller));

    # return right away on undefined result
    if (not defined $result) {
        &dtl("snmp_record undefined result for oid $oid");
        return;
    }

    # escape end of line characters in output, must match in &snmp_replay
    $result =~ s/\r/\\EOL-CR\\/g;
    $result =~ s/\n/\\EOL-LF\\/g;

    # save snmp output to expect record file
    open(FILE, ">>$file")
        or croak "snmp_record $file open err $!";
    print FILE "SNMP: $oid = $result\n"
        and &dtl("snmp_record saved $oid = $result");
    CORE::close FILE;

    # finished snmp_record function
    return;
}



sub snmp_replay {

# internal: &snmp_replay($file, $type, \%table, @oids) if $args->{'snmp-replay'}
# purpose: read oid table from snmp record dump file, call if configured
# $file: set to snmp-replay filename, should be in current data directory
# $type: set to keyword get or walk, affects which oids match
# \%table: hash reference that will get oid keyed results from replay file
# @oids: set to one or more oid values for get, bulk get, or bulk walk
# \%table: output hash reference, oid key and result values

    # read args
    my ($file, $type, $table, @oids) = @_;
    croak "snmp_replay file arg missing" if not $file;
    croak "snmp_replay type arg invalid"
        if not $type or $type !~ /^(get|walk)$/;
    croak "snmp_replay table arg invalid"
        if not $table or ref $table ne "HASH";
    croak "snmp_replay oids arg missing" if not $oids[0];
    &dtl("snmp_replay sub called from " . lc(caller));

    # read snmp replay file contents, or die with error
    open(FILE, $file)
        or croak "snmp_replay file $file open err $!";

    # process entire replay file, looking for relevant oids
    while (<FILE>) {

        # fetch next line, strip comments
        my $line = $_;
        &dtl("snmp_replay read line $line");
        $line =~ s/#.+//;

        # parse snmp oid and result, possible null result
        next if $line !~ /^SNMP: (\S+) =(.+)/;
        my ($oid, $result) = ($1, $2);
        $result =~ s/^\s//;

        # check if current oid matches an input oid, or start of oid for walk
        my $output_flag = 0;
        foreach my $input_oid (@oids) {
            next if $type eq 'get' and $input_oid ne $oid;
            next if $type eq 'walk' and $oid !~ /^\Q$input_oid/;
            $output_flag = 1;
            last;
        }

        # skip this oid if it should not be in output result
        next if not $output_flag;

        # restore escaped end of line characters, must match in &snmp_record
        $result =~ s/\\EOL-CR\\/\r/g;
        $result =~ s/\\EOL-LF\\/\n/g;

        # store relevant result in output result for oid with input oid match
        &dtl("snmp_replay returning $oid = $result");
        $table->{$oid} = $result;

    # finished processing oid file
    }

    # close snmp replay file
    CORE::close FILE;

    # finished snmp_replay function
    return;
}



=head1 SNMP

Here is a list of SNMP OID MIB values:

 Standard system:
    system                     .1.3.6.1.2.1.1
    sysDescr                   .1.3.6.1.2.1.1.1.0
    sysObjectID                .1.3.6.1.2.1.1.2.0
    sysUptime                  .1.3.6.1.2.1.1.3.0
    sysContact                 .1.3.6.1.2.1.1.4.0
    sysName                    .1.3.6.1.2.1.1.5.0
    sysLocation                .1.3.6.1.2.1.1.6.0

 Standard ifTable:
    ifTable                    .1.3.6.1.2.1.2.2.1
    ifDescr                    .1.3.6.1.2.1.2.2.1.2
    ifType                     .1.3.6.1.2.1.2.2.1.3
    ifSpeed                    .1.3.6.1.2.1.2.2.1.5
    ifPhysAddress              .1.3.6.1.2.1.2.2.1.6
    ifAdminStatus              .1.3.6.1.2.1.2.2.1.7
    ifOperStatus               .1.3.6.1.2.1.2.2.1.8
    ifLastChange               .1.3.6.1.2.1.2.2.1.9
    ifInOctets                 .1.3.6.1.2.1.2.2.1.10
    ifInUcastPkts              .1.3.6.1.2.1.2.2.1.11
    ifInNUcastPkts             .1.3.6.1.2.1.2.2.1.12
    ifInDiscards               .1.3.6.1.2.1.2.2.1.13
    ifInErrors                 .1.3.6.1.2.1.2.2.1.14
    ifOutOctets                .1.3.6.1.2.1.2.2.1.16
    ifOutUcastPkts             .1.3.6.1.2.1.2.2.1.17
    ifOutNUcastPkts            .1.3.6.1.2.1.2.2.1.18

 Standard ipv4:
    ipAdEntAddr                .1.3.6.1.2.1.4.20.1.1.x.x.x.x            
    ipAdEntIfIndex             .1.3.6.1.2.1.4.20.1.2.x.x.x.x
    ipAdEntNetMask             .1.3.6.1.2.1.4.20.1.3.x.x.x.x

 Standard rfc2233 ifXTable:
    ifName                      .1.3.6.1.2.1.31.1.1.1.1
    ifInMulitcastPkts           .1.3.6.1.2.1.31.1.1.1.2
    ifInBroadcastPkts           .1.3.6.1.2.1.31.1.1.1.3
    ifOutMulticastPkts          .1.3.6.1.2.1.31.1.1.1.4
    ifOutBroadcastPkts          .1.3.6.1.2.1.31.1.1.1.5
    ifHCInOctets                .1.3.6.1.2.1.31.1.1.1.6
    ifHCInUcastPkts             .1.3.6.1.2.1.31.1.1.1.7
    ifHCInMulticastPkts         .1.3.6.1.2.1.31.1.1.1.8
    ifHCInBroadcastPkts         .1.3.6.1.2.1.31.1.1.1.9
    ifHCOutOctets               .1.3.6.1.2.1.31.1.1.1.10
    ifHCOutUcastPkts            .1.3.6.1.2.1.31.1.1.1.11
    ifHCOutMulticastPkts        .1.3.6.1.2.1.31.1.1.1.12
    ifHCOutBroadcastPkts        .1.3.6.1.2.1.31.1.1.1.13
    ifLinkUpDownTrapEnable      .1.3.6.1.2.1.31.1.1.1.14
    ifHighSpeed                 .1.3.6.1.2.1.31.1.1.1.15
    ifPromiscuousMode           .1.3.6.1.2.1.31.1.1.1.16
    ifConnectorPresent          .1.3.6.1.2.1.31.1.1.1.17
    ifAlias                     .1.3.6.1.2.1.31.1.1.1.18
    ifCounterDiscontinuityTime  .1.3.6.1.2.1.31.1.1.1.19

 Foundry:
    snChasSerNum                .1.3.6.1.4.1.1991.1.1.1.1.2
    snSwPortName                .1.3.6.1.4.1.1991.1.1.3.3.1.1.24
    snSwPortIfIndex             .1.3.6.1.4.1.1991.1.1.3.3.1.1.38

 Microsoft:
    hrSystemProcesses           .1.3.6.1.2.1.25.1.6.0
    hrProcessorLoad             .3.1.3.6.1.2.1.25.3.3.1.2.3
    hrMemorySize (KB)           .1.3.6.1.2.1.25.2.2.0
    hrStorageDescr              .1.3.6.1.2.1.25.2.3.1.3 (x:\ label:aaaa)
    hrStorageAllocationUnits    .1.3.6.1.2.1.25.2.3.1.4 (bytes)
    hrStorageSize (alloc units) .1.3.6.1.2.1.25.2.3.1.5
    hrStorageUsed (alloc units) .1.3.6.1.2.1.25.2.3.1.6

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, Mnet::Poll

=cut



# normal package return
1;

