package Mnet::RRD;

=head1 NAME

Mnet::RRD - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

This perl module can be used by scripts to store numeric data in
round roubin database .rrd files. These .rrd files can be used
to generate graphs and reports.

Usage examples:
 
 # sample value and interface data rrd writes
 use Mnet;
 use Mnet::SNMP;
 use Mnet::RRD;
 my $cfg = &object;
 my $if_table_oid = '.1.3.6.1.2.1.2.2.1';
 my %snmp = ();
 &snmp_bulkwalk($if_table_oid, \%snmp);
 &rrd_interface(\%snmp, "FastEthernet0/0");
 my $cpu = &snmp_get('.1.3.6.1.4.1.9.9.109.1.1.1.1.3.1');
 &rrd_value("cpu", "percent", "gauge", $cpu, 0, 100)

 # sample read of rrd graph png image
 use Mnet;
 use Mnet::RRD;
 my $cfg = &config({
     'data-dir => '/var/mnet'
 });
 my $png = &rrd_png({'object' => 'router1', 'rrd' => 'cpu.val'});

=head1 DESCRIPTION

The functions in this module allow for historical data to be stored
in round robin database files and for this data to be queried. This
module requires that the perl RRDs module is installed, which is
part of the rrdtool distribution.

RRD files store values that are sampled at regular intervals. The
default is to store sampled values in 300 second intervals. Using
this default rrd-step value 36 hours of short term data is stored,
10 days of medium term, and 100 days of long term data.

This module can handle two types of RRD files - one for network
interface data and another for single numeric values. The interface
RRD is meant to be used with SNMP data and stores data relevant for
network monitoring and management. The value RRD can be used to
store any other numeric data, such as CPU, memory or disk activity.

The rrdtool package used by this module is quite flexible and only
a subset of its functionality is used here.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --data-dir <dir>       directory where mnet object data is stored
 --object-name <name>   used to locate object data subdirectory
 --rrd-detail           enable for extra rrd debug details
 --rrd-height <pixels>  height of rrd graphs, default 18
 --rrd-max <1+>         maximum rrd data value, default 10 gigbit
 --rrd-medium <rra>     define rra, default week AVERAGE:0.4:2:1440
 --rrd-long-avg <rra>   define rra, default month AVERAGE:0.6:6:4800
 --rrd-long-max <rra>   define rra, default month MAX:0.6:6:4800
 --rrd-version          set at compilation to build number
 --rrd-short <rra>      define rra, default day MAX:0.2:1:432
 --rrd-step <1+>        input sample interval in seconds, default 300
 --rrd-width <pixels>   width of rrd graphs, default 540

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
use RRDs;

# export module function names
our @ISA = qw( Exporter );
our @EXPORT=qw( rrd_interface rrd_value rrd_png );

# module initialization of default values
BEGIN {
    our $cfg = &Mnet::config({
        'rrd-height'    => 180,
        'rrd-long-avg'  => "AVERAGE:0.6:6:4800",
        'rrd-long-max'  => "MAX:0.6:6:4800",
        'rrd-max'       => 10000000000,
        'rrd-medium'    => "AVERAGE:0.4:2:1440",
        'rrd-version'   => '+++VERSION+++',
        'rrd-short'     => "MAX:0.2:1:432",
        'rrd-step'      => 300,
        'rrd-width'     => 640,
    });
}



sub rrd_interface {

=head2 rrd_interface function

 $file = &rrd_interface(\%snmp, $interface, $step)

This function stores a number of interface counters in a rrd graph file.
The rrd file will be created in the current device data directory and
given the name '<interface>.int.rrd' based on the interface name. The
rrd file will be created if it does not exist.

The returned file value is the normalized interface name, used as the
rrd filename.  Slashes and colons are removed from the interface name.

The referenced snmp hash is normally filled with using bulk walk data
from the snmp ifTable and ifXTable OIDs. The interface argument must
be specified as an instance in the interface table or as an interface
name. The step argument is optional. A default 300 second step value
can ge changed using this argument or the --rrd-step config option.
A heartbeat value is derived from the step value in effect at the time
the rrd is created. If data is not supplied to the graph in double the
step interval an unknown value is stored.  Otherwise the timing of
input data is taken into consideration when data is stored in the rrd
file.

The numerical admin status, the operator status, the current interface
speed, in and out bits per second, in errors and in and out packets per
second values are stored in the rrd graph file.

Several rra sets of data are stored in the graph rrd file. A short term
rra of max data values, a medium term average rra, and both max and
average long term rra sets are stored in the rrd value. These rra data
sets allow for the data in the graph file to be viewed in these several
different ways with varying levels of detail. The step value relates to
these intervals. These rra sets can be changed using the --rrd-short,
--rrd-medium, --rrd-long-avg and --rrd-long-max config settings.

See also the rrdtool and related man pages for more information.

=cut

    # read input args and set defaults
    &dtl("rrd_interface sub called from " . lc(caller));
    my ($snmp, $interface, $step) = @_;
    $step = $Mnet::RRD::cfg->{'rrd-step'} if not defined $step;

    # validate snmp reference is present
    croak "rrd_interface missing snmp arg"
        if not defined $snmp or ref $snmp ne "HASH";

    # validate interface argument
    croak "rrd_interface missing interface argument"
        if not defined $interface or $interface !~ /\S/;

    # validate step argument
    croak "rrd_interface $interface invalid step '$step'"
        if $step !~ /^\d+$/ || $step == 0;

    # return if data directory not configured or log a debug message
    return if not defined $Mnet::RRD::cfg->{'data-dir'};
    &dbg("rrd_interface $interface starting");
    
    # ininitialize interface instance and description variables
    my ($instance, $descr) = ("", "");

    # set description if specified as an integer instance
    if ($interface =~ /^\s*(\d+)\s*$/) {
        $instance = $1;
        if (defined $$snmp{".1.3.6.1.2.1.2.2.1.2.$instance"}) {
            $descr = $$snmp{".1.3.6.1.2.1.2.2.1.2.$instance"};
            &dtl("rrd_interface $interface found descr $descr");
        }

    # set instance if specified as a description
    } else {
        foreach my $oid (keys %$snmp) {
            next if $oid !~ /^\Q.1.3.6.1.2.1.2.2.1.2.\E(\d+)$/;
            $instance = $1;
            if ($$snmp{$oid} =~ /^\Q$interface\E/i) {
                $descr = $$snmp{$oid};
                &dtl("rrd_interface $interface found instance $instance");
                last;
            }
        }
    }

    # return with error if interface instance and description not determined
    if ($instance eq "" or $descr eq "") {
        carp "rrd interface $interface not found";
        return;
    }

    # set interface speed
    my $speed = undef;
    if (defined $$snmp{".1.3.6.1.2.1.31.1.1.1.15.$instance"}) {
        $speed = $$snmp{".1.3.6.1.2.1.31.1.1.1.15.$instance"} * 1000000;
    } elsif (defined $$snmp{".1.3.6.1.2.1.2.2.1.5.$instance"}) {
        $speed = $$snmp{".1.3.6.1.2.1.2.2.1.5.$instance"};
    } else {
        &dbg("rrd_interface $interface unable to read interface speed");
        return;
    }

    # set interface admin status for up and non-up conditions
    my $admin = undef;
    if (defined $$snmp{".1.3.6.1.2.1.2.2.1.7.$instance"}) {
        if ($$snmp{".1.3.6.1.2.1.2.2.1.7.$instance"} =~ /^(1|up)$/i) {
            $admin = $speed;
        } else {
            $admin = 0;
        }   
    }

    # set interface operator status for up and non-up conditions
    my $oper = undef;
    if (defined $$snmp{".1.3.6.1.2.1.2.2.1.8.$instance"}) {
        if ($$snmp{".1.3.6.1.2.1.2.2.1.8.$instance"} =~ /^(1|up)$/i) {
            $oper = $speed;
        } else {
            $oper = 0;
        }
    }

    # set interface bits in 
    my $bits_in = undef;
    if (defined $$snmp{".1.3.6.1.2.1.31.1.1.1.6.$instance"}) {
        $bits_in = $$snmp{".1.3.6.1.2.1.31.1.1.1.6.$instance"} * 8;
    } elsif (defined $$snmp{".1.3.6.1.2.1.2.2.1.10.$instance"}) {
        $bits_in = $$snmp{".1.3.6.1.2.1.2.2.1.10.$instance"} * 8;
    }

    # set interface bits out
    my $bits_out = undef;
    if (defined $$snmp{".1.3.6.1.2.1.31.1.1.1.10.$instance"}) {
        $bits_out = $$snmp{".1.3.6.1.2.1.31.1.1.1.10.$instance"} * 8;
    } elsif (defined $$snmp{".1.3.6.1.2.1.2.2.1.16.$instance"})  {
        $bits_out = $$snmp{".1.3.6.1.2.1.2.2.1.16.$instance"} * 8;
    }

    # set interface errors to errors in
    my $errors = undef;
    if (defined $$snmp{".1.3.6.1.2.1.2.2.1.14.$instance"}) {
        $errors = $$snmp{".1.3.6.1.2.1.2.2.1.14.$instance"};
    }

    # add interface discards in to interface errors
    if (defined $$snmp{".1.3.6.1.2.1.2.2.1.13.$instance"}) {
        $errors += $$snmp{".1.3.6.1.2.1.2.2.1.13.$instance"};
    }

    # add interface errors out to interface errors
    if (defined $$snmp{".1.3.6.1.2.1.2.2.1.19.$instance"}) {
        $errors += $$snmp{".1.3.6.1.2.1.2.2.1.19.$instance"};
    }

    # add interface discards out to interface errors
    if (defined $$snmp{".1.3.6.1.2.1.2.2.1.20.$instance"}) {
        $errors += $$snmp{".1.3.6.1.2.1.2.2.1.20.$instance"};
    }

    # scale errors relative to current speed for graphing
    if (defined $errors) {
        my $factor = 100;
        $factor = $speed / 100 if $speed =~ /^\d+$/;
        $errors = $errors * $factor;
        $errors = $speed if $errors > $speed;
    }

    # set interface packets in
    my $pkts_in = undef;
    if (defined $$snmp{".1.3.6.1.2.1.31.1.1.1.7.$instance"}
        and defined $$snmp{".1.3.6.1.2.1.31.1.1.1.8.$instance"}
        and defined $$snmp{".1.3.6.1.2.1.31.1.1.1.9.$instance"}) {
        $pkts_in = $$snmp{".1.3.6.1.2.1.31.1.1.1.7.$instance"}
            + $$snmp{".1.3.6.1.2.1.31.1.1.1.8.$instance"}
            + $$snmp{".1.3.6.1.2.1.31.1.1.1.9.$instance"};
    } elsif (defined $$snmp{".1.3.6.1.2.1.2.2.1.11.$instance"}
        and defined $$snmp{".1.3.6.1.2.1.2.2.1.12.$instance"}) {
        $pkts_in = $$snmp{".1.3.6.1.2.1.2.2.1.11.$instance"}
            + $$snmp{".1.3.6.1.2.1.2.2.1.12.$instance"};
    }

    # set interface packets out
    my $pkts_out = undef;
    if (defined $$snmp{".1.3.6.1.2.1.31.1.1.1.11.$instance"}
        and defined $$snmp{".1.3.6.1.2.1.31.1.1.1.12.$instance"}
        and defined $$snmp{".1.3.6.1.2.1.31.1.1.1.13.$instance"}) {
        $pkts_out = $$snmp{".1.3.6.1.2.1.31.1.1.1.11.$instance"}
            + $$snmp{".1.3.6.1.2.1.31.1.1.1.12.$instance"}
            + $$snmp{".1.3.6.1.2.1.31.1.1.1.13.$instance"};
    } elsif (defined $$snmp{".1.3.6.1.2.1.2.2.1.17.$instance"}
        and defined $$snmp{".1.3.6.1.2.1.2.2.1.18.$instance"}) {
        $pkts_out = $$snmp{".1.3.6.1.2.1.2.2.1.17.$instance"}
            + $$snmp{".1.3.6.1.2.1.2.2.1.18.$instance"};
    }   

    # at this point the following variables are set:
    # $%snmp, $instance, $descr, $admin, $oper, $speed,
    # $bits_in, $bits_out, $errs_in, $pkts_in, $pkts_out
    &dtl("rrd_interface $interface data gathered for update");

    # set default max to 10gb and heartbeat to two step intervals
    my $max = $Mnet::RRD::cfg->{'rrd-max'};
    my $heartbeat = $step * 2;

    # create rrd specifications for interface data sources
    my @ds = (
        "admin:gauge:${heartbeat}:0:${max}",
        "oper:gauge:${heartbeat}:0:${max}",
        "speed_bps:counter:${heartbeat}:0:${max}",
        "in_bps:counter:${heartbeat}:0:${max}",
        "out_bps:counter:${heartbeat}:0:${max}",
        "in_pps:counter:${heartbeat}:0:${max}",
        "out_pps:counter:${heartbeat}:0:${max}",
        "errors:counter:${heartbeat}:0:${max}",
    );

    # set interface data values for rrd
    my @values = ($oper, $admin, $speed, $bits_in, $bits_out,
        $pkts_in, $pkts_out, $errors);

    # log debug message if illegal characters in description changed
    my $file = $descr;
    $file =~ s/(\\|\/)/-/g;
    $file =~ s/:/_/g;
    &dtl("rrd_interface $interface descr $descr changed to $file")
        if $file ne $descr;
    $file = "$file.int.rrd";

    # call function to update rrd graph and log any errors
    my $err = &rrd_update($file, $step, \@ds, \@values);
    if (defined $err) {
        carp "rrd_interface $descr file $file update error $err";
    } else {
        &dbg("rrd_interface $descr file $file updated");
    }

    # finished rrd_interface function
    return $file;
}



sub rrd_png {

=head2 rrd_png function

 $png = &rrd_png(\%input)

Outputs a rrd graph png for the specified rrd.

The input hash reference must contain the object and rrd keys,
and may contain any combination of the other keys:

 object      name of the object to pull information for
 rrd         file name of the rrd associated with the object
 start       rrd start time, default end-36hours
 cfunction   rrd consolidation function, default MAX
 period      default short, or medium, long-avg, long-max
 height      png height in pixels, default --module-rrd-height
 width       png width in pixels, default --module-rrd-width

Note that interface and value rrd files will be autodetected based
on the named input rrd.

Refer to the rrdtool man pages for information on time ranges and
consolidation functions. If these are not set then the period is
used.

=cut

    # read input hash reference
    my $input = shift;
    croak "rrd_png missing input hash ref arg"
        if not $input or ref $input ne 'HASH';
    &dtl("rrd_png sub called from " . lc(caller));

    # require data-dir directory to be set
    croak "rrd_png requires data-dir directory to be configured"
        if not defined $Mnet::RRD::cfg->{'data-dir'};

    # requires rrd module, return immediately if not present
    eval { require RRDs };
    return undef if $@;

    # verify required object input is present
    my $object = $input->{'object'};
    croak "rrd_png missing input object key" if not defined $object;

    # verify required rrd input is present
    my $rrd = $input->{'rrd'};
    croak "rrd_png missing input rrd key" if not defined $rrd;

    # initialize time range and consolidation function
    my ($start, $cfunction) = (undef, undef);

    # process period, set from default
    my $period = $input->{'period'};
    $period = 'short' if not defined $period;
    ($start, $cfunction) = ("end-36hours", "MAX") if $period =~ /short/;
    ($start, $cfunction) = ("end-10days", "AVERAGE") if $period =~ /medium/;
    ($start, $cfunction) = ("end-100days", "AVERAGE") if $period =~ /long-avg/;
    ($start, $cfunction) = ("end-100days", "MAX") if $period =~ /long-max/;

    # use input time range, if defined
    $start = $input->{'start'} if defined $input->{'start'};

    # use input consolidation function, if defined
    $cfunction = $input->{'cfunction'} if defined $input->{'cfunction'};

    # validate input width, set from default
    my $width = $input->{'width'};
    $width = $Mnet::RRD::cfg->{'rrd-width'} if not defined $width;
    croak "rrd_png invalid input width $width" if $width !~ /^\d+$/;

    # validate input height, set from default
    my $height = $input->{'height'};
    $height = $Mnet::RRD::cfg->{'rrd-height'} if not defined $height;
    croak "rrd_png invalid input height $height" if $height !~ /^\d+$/;

    # set rrd filename using data-dir dir, object and rrd inputs
    my $rrd_file = $Mnet::RRD::cfg->{'data-dir'} . "/$object/$rrd";

    # set initial rrd graph arguments
    my @rrd_args = ();
    push @rrd_args, "--imgformat",  "PNG";
    push @rrd_args, "--height", $height - 63;
    push @rrd_args, "--width", $width - 97;
    push @rrd_args, "--lower-limit", 0;
    push @rrd_args, "--end", "now";
    push @rrd_args, "--start", $start;

    # attempt to retrieve rrd info for file
    my $rrd_info = RRDs::info($rrd_file);
    #&dbg("rrd_png info $_ = $$rrd_info{$_}") foreach sort keys %$rrd_info;

    # initialize upper limit, set from rrd info depending on graph type
    my $upper_limit = undef;

    # setup for interface graph
    if ($rrd_file =~ /([^\/]+)\.int\.rrd$/i) {
        my $name = $1;
        push @rrd_args, "--vertical-label", $name;
        push @rrd_args, "DEF:in_bps=$rrd_file:in_bps:$cfunction";
        push @rrd_args, "AREA:in_bps#00ff00:in bps";
        push @rrd_args, "DEF:out_bps=$rrd_file:out_bps:$cfunction";
        push @rrd_args, "LINE1:out_bps#0000ff:out bps";
        #push @rrd_args, "DEF:in_pps=$rrd_file:in_pps:$cfunction";
        #push @rrd_args, "LINE1:in_pps#ff00ff:in pps";
        #push @rrd_args, "DEF:out_pps=$rrd_file:out_pps:$cfunction";
        #push @rrd_args, "LINE1:out_pps#c08000:out pps";
        push @rrd_args, "DEF:errors=$rrd_file:errors:$cfunction";
        push @rrd_args, "LINE1:errors#ff0000:errors";
        push @rrd_args, "DEF:admin=$rrd_file:admin:$cfunction";
        push @rrd_args, "LINE2:admin#000000:admin";
        push @rrd_args, "DEF:oper=$rrd_file:oper:$cfunction";
        push @rrd_args, "LINE1:oper#ffff00:oper";
        $upper_limit = $rrd_info->{"ds[speed_bps].last_ds"}
            if defined $rrd_info->{"ds[speed_bps].last_ds"}
            and $rrd_info->{"ds[speed_bps].last_ds"} =~ /^\d+$/;

    # setup for single value graph
    } elsif ($rrd_file =~ /([^\/]+)\.val\.rrd$/i) {
        my $name = $1;
        my $ds = "";
        foreach my $key (keys %$rrd_info) {
            $ds = $1 if $key =~ /^ds\[(.+)\]/;
            last if $ds ne "";
        }
        my $last = "u";
        $last = $rrd_info->{"ds[$ds].last_ds"}
            if defined $rrd_info->{"ds[$ds].last_ds"};
        $last = lc($last);
        push @rrd_args, "--vertical-label", $name;
        push @rrd_args, "DEF:$ds=$rrd_file:$ds:$cfunction";
        push @rrd_args, "LINE2:$ds#000000:$ds";
        push @rrd_args, "COMMENT:last\\: $last";
        $upper_limit = $rrd_info->{"ds[$ds].max"}
            if defined $rrd_info->{"ds[$ds].max"};

    # finished graph setup
    }

    # set rigid upper limit, if defined
    push @rrd_args, "--rigid", "--upper-limit", $upper_limit
        if defined $upper_limit;

    # execute rrdtool to make graph and capture output image data
    &dtl("rrd_png rrdtool graph rrd.png @rrd_args");
    my $rrd_output = &RRDs::graphv("", @rrd_args);
    my $rrd_err = &RRDs::error;
    croak "rrd_png error: $rrd_err (rrdtool graph rrd.png @rrd_args)"
        if defined $rrd_err;

    # finished rrd_png function
    &dtl("rrd_png function finishing");
    return $rrd_output->{'image'};
}



sub rrd_value {

=head2 rrd_value function

 $file = &rrd_value($name, $legend, $type, $value, $min, $max, $step)

This function can be used to store rrd graph information for a single
varying value. The named rrd file will be created in the current
data directory with a .val.rrd suffix. The rrd file will be created
if it does not exist.

The supplied name is used as the filename and the .val.rrd extension
is added. The name given to the rrd file should be descriptive, such
as 'system cpu' or 'rate limited bytes'.

The returned file value is the normalized input name, used as the
rrd filename.  Slashes and colons are removed from the input name.

The legend argument must be supplied and should be set to describe
the units being measured in the graph data , such as 'percentage'
or 'bytes per second'. The legend is limited to 19 characters. Any
out of the ordinary characters will be turned into underscores.

Note that the legend is used as the rrd data source name. This
function creates rrd files with one data source only. The name of
the rrd file and the legend stored as the data source name can be
used to automatically title the graph and the data on it.

The type argument must be set to the either the keyword 'gauge' or
'counter'. The gauge type is used to measure an absolute value such
as cpu percentage. The counter value is used to store the changes
in an accumulating counter, such as interface bytes in.

The value argument is required. This needs to be a numeric value or
a null value which is stored as an unknown value.

The minimum, maximum and step values are optional. The default minimum
is zero, the default maximum is 10gb and the default step value is
300 seconds. These parameters, along with name, type and legend, are
used when creating an rrd file. Input values are ignored if they fall
outside the minimum and maximum range. The step value specifies the
interval in seconds that values are expected to be supplied to an
rrd file. The default step value of 300 seconds can be changed using
the --rrd-step config directive. A heartbeat value is derived from
the step value in effect at the time the rrd is created. If data is
not supplied to the graph in double the step interval an unknown
value is stored. Otherwise the timing of input data is taken into
consideration when data is stored in the rrd file.

Several rra sets of data are stored in the graph rrd file. A short
term rra of max data values, a medium term average rra, and both
max and average long term rra sets are stored in the rrd value. These
rra data sets allow for the data in the graph file to be viewed in
these several different ways with varying levels of detail. The step
value relates to these intervals. With the default step value 36 hours
of short term data is stored, 10 days of medium term, and 100 days
of long term data. These rra sets can be changed using the --rrd-short,
--rrd-medium, --rrd-long-avg and --rrd-long-max config settings.

See also the rrdtool and related man pages for more information.

=cut

    # read input arguments and set defaults
    &dtl("rrd_value sub called from " . lc(caller));
    my ($name, $legend, $type, $value, $min, $max, $step) = @_;
    $min = 0 if not defined $min;
    $max=$Mnet::RRD::cfg->{'rrd-max'} if not defined $max;
    $step = $Mnet::RRD::cfg->{'rrd-step'} if not defined $step;

    # validate name argument
    croak "rrd_value missing name argument" if not defined $name;
    croak "rrd_value invalid name argument '$name'"
        if $name !~ /\S/ or $name =~ /[^(\w|\-|\.)]/;

    # validate legend argument
    croak "rrd_value $name missing or invalid legend argument"
        if not defined $legend or $legend !~ /\S/ or $legend =~ /[^\w]/;
    croak "rrd_value $name invalid legend argument '$legend'"
        if $legend !~ /\S/ or $legend =~ /[^\w]/;
    croak "rrd_value $name legend argument '$legend' over 19 characters"
        if length $legend > 19;

    # validate type argument
    croak "rrd_value $name type argument must be gauge or counter"
        if not defined $type or $type ne "gauge" and $type ne "counter";

    # set value to unknown for update if value is a null value
    $value = "U" if not defined $value or $value eq '';

    # validate step, min and max arguments as numeric
    croak "rrd_value $name invalid step argument '$step'"
        if $step !~ /^\d+$/ || $step == 0;
    croak "rrd_value $name invalid min argument '$min'"
        if $min !~ /^-?\d+(\.\d+)?$/;
    croak "rrd_value $name invalid max argument '$max'"
        if $max !~ /^-?\d+(\.\d+)?$/;

    # return if data directory not configured
    if (not defined $Mnet::RRD::cfg->{'data-dir'}) {
        &dbg("rrd_value $name call skipped without data-dir dir defined");
        return;
    } else {
        &dbg("rrd_value $name call starting");
    }

    # create rrd specifications for this single data source graph
    my $heartbeat = $step * 2;
    my @ds = ("${legend}:${type}:${heartbeat}:${min}:${max}");
    my @values = ($value);
    &dtl("rrd_value $name data gathered for update");

    # log debug message if illegal characters in description changed
    my $file = $name;
    &dtl("rrd_value $name changed to $file")
        if $file =~ s/(\\|\/)/-/g or $file =~ s/:/_/g;
    $file = "$file.val.rrd";

    # call function to update rrd graph and log any errors
    my $err = &rrd_update("$file", $step, \@ds, \@values);
    if (defined $err) {
        carp "rrd_value $name $type file $file update error $err";
    } else {
        &dbg("rrd_value $name $type file $file updated value = $value");
    }

    # finished rrd_value function
    return $file;
}



sub rrd_update {

# internal: $err = &rrd_update($file, $step, \@ds, \@values)
# purpose: update specified rrd creating new rrd if necessary
# $file: name of output rrd file in configured data-dir dir
# step: planned update interval frequency in seconds
# \@ds: list of rrd ds spec format "ds-name:gauge|counter:heartbeat:min:max"
# \@values: list of rrd values for data sources, each numeric or undefined
# $err: set undef on success or else set to error text message
# note: ds names should be set as 1-19 characters used for graph legend

    # read input arguments and return error if any are missing
    &dtl("rrd_update sub called from " . lc(caller));
    my ($file, $step, $ds, $values) = @_ or return "rrd_update arg error";

    # return if data directory is not set, or else log debug messages
    return undef if not defined $Mnet::RRD::cfg->{'data-dir'};

    # return with an error if input file name contains illegal characters
    return "rrd_update input $file contains slashes or colons"
        if $file =~ /(\\|\/)/ or $file =~ /:/;

    # create string of updated values from data source entries
    my $update = time . ":";
    foreach my $value (@$values) {
        $value = "U" if not defined $value;
        return "rrd_update invalid value $value for $file update"
            if $value !~/^-?\d+(\.\d+)?$/ and $value ne "U";
        $update.="$value:";
    }
    $update=~s/:$//;

    # retrieve current time, attempt to update rrd and retrieve any error
    &dtl("rrdtool update $file $update");
    &RRDs::update($file, $update);
    my $err = &RRDs::error();
    return $err if not $err or $err !~ /No such file or directory$/;

    # check if update resulted in error and attempt to create new rrd
    &dbg("creating then updating new rrd file $file");

    # format ds specs for rrd creation
    my @create_ds = @$ds;
    foreach my $ds (@create_ds) {
        next if $ds !~ /^([^:]+):(gauge|counter):(.*)$/;
        my ($ds_name, $ds_type, $ds_params) = ($1, uc($2), $3);
        $ds_name =~ s/\s+/_/g; 
        $ds = "DS:${ds_name}:${ds_type}:${ds_params}";
    }

    # intialize rra specs for rrd creation
    my @create_rra = (
        "RRA:" . $Mnet::RRD::cfg->{'rrd-short'},
        "RRA:" . $Mnet::RRD::cfg->{'rrd-medium'},
        "RRA:" . $Mnet::RRD::cfg->{'rrd-long-avg'},
        "RRA:" . $Mnet::RRD::cfg->{'rrd-long-max'},
    );

    # create new rrd file with input ds and rra specs, return on errors
    &dtl("rrdtool create $file --step=$step @create_ds @create_rra");
    &RRDs::create("$file.new", "--step=$step", @create_ds, @create_rra);
    $err = &RRDs::error();
    return $err if $err;

    # rename new rrd file and return on errors
    rename "${file}.new", $file or return "rrd file $file rename error $!";

    # attempt to update rrd and return any error
    &dtl("rrdtool update $file $update") if not $err;
    &RRDs::update($file, $update);
    $err = &RRDs::error();
    return $err if $err;

    # finished rrd_update function
    return undef;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, rrdtool

=cut



# normal package return
1;

