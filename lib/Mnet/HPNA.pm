package Mnet::HPNA;

=head1 NAME

Mnet::HPNA - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

Usage examples:

 # sample hpna script
 # also showing custom user input interface value
 use Mnet;
 use Mnet::Expect;
 use Mnet::HPNA;
 my $cfg = &object({
    'hpna-suicide' => 30
 });
 &hpna_arg('object-name', '$tc_device_hostname$');
 &hpna_arg('object-address', '$tc_device_ip$');
 &hpna_arg('expect-username', '$tc_device_username$');
 &hpna_arg('expect-password', '$tc_device_password$');
 &hpna_arg('expect-enable', '$tc_device_enable_password$');
 &hpna_arg('input-int', '$user_input_interface$');
 my $expect = new Mnet::Expect or die;
 my $out = $expect->command("show interface $cfg->{'input-int'}");
 $expect->close("exit");


=head1 DESCRIPTION

This module can be used to handle input arguments from HPNA,
formerly known as Opsware, in a portable way. Scripts using the
hpna_arg method can read config settings set from HPNA variable
substitution, falling back to normal Mnet config setting methods.

When HPNA variable substitution is detected the hpna_arg call
will also disable the Mnet perl module input function. A script
suicide timer will also be enabled if the hpna-suicide config
option is set.

Refer to the hpna_arg documentation below for more details.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --hpna-detail         extra debug logging, default disabled
 --hpna-version        set at compilation to build number
 --hpna-suicide <1+>   suicide timer in minutes, default disabled

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
our @EXPORT = qw( hpna_arg );

# module initialization, set module defaults and suicide timer activated flag
BEGIN {
    our $cfg = &Mnet::config({
        'hpna-version' => '+++VERSION+++',
    });
    our $suicide_timer_active = 0;
}



sub hpna_arg {

=head2 hpna_arg method

 $value = &hpna_arg($mnet_arg, $hpna_arg)

This is a method that can be used to set mnet configuration settings
from hpna variable subsititutions.

The ouptut $value will be set from the HPNA variable substitution,
or to undefined if no variable substitution occured.

Here is how this method should be called:

 &hpna_arg('object-address', '$tc_device_ip$');

When running under HPNA variable subsitution will occur for the
$tc_device_ip$ string. This function will see that and assign the
HPNA substituted value to the specified mnet config setting.

This aids in the portability of scripts. A call using this method in
the main script will use the normal command line config settings
inputs as handled by the Mnet perl library when not running under
HPNA.

This function will do a couple of other things if it detects that
HPNA variable substitution has occured. It will set the conf-noinput
config setting. This will cause any call to the &Mnet::input fucntion
to die with an error. This is good, since HPNA doesn't allow for
prompted standard input to a script - the script would hang.

This function also can optionally enable an hpna-suicide timer
when it detects that variable substitution has occurred. By default
this option is disabled. The --hpna-suicide config setting can
be set to a number of minutes. If set, the script will die in that
number of minutes. HPNA can be configured to terminate a script
after so many minutes. When HPNA terminates a script the output
from the script is lost. If a script terminates itself with
the hpna-suicide config setting its output will not be lost.

=cut

    # read and validate inputs
    my ($mnet_arg, $hpna_arg) = @_;
    &dtl("hpna_arg sub called from " . lc(caller));
    croak "hpna_arg missing hpna_arg arg" if not defined $hpna_arg;
    croak "hpna_arg missing mnet_arg arg" if not defined $mnet_arg;

    # start hpna processing, if we detect that we are running in hpna
    if ($hpna_arg !~ /^\$\S+\$$/) {

        # set mnet arg from hpna substitution variable
        $Mnet::HPNA::cfg->{$mnet_arg} = $hpna_arg;
        &dbg("config setting $mnet_arg set = "
            . &Mnet::config_filter($mnet_arg));
        $Mnet::HPNA::cfg->{'conf-noinput'} = 1;

        # set hpna suicide timer, if configured and not set yet
        if ($Mnet::HPNA::cfg->{'hpna-suicide'}
            and not $Mnet::HPNA::suicide_timer_active) {
            &dbg("suicide timer being "
                . "set to $Mnet::HPNA::cfg->{'hpna-suicide'} minutes");
            local $SIG{ALRM} = sub {
                croak "hpna preventive suicide timer triggered";
            };
            alarm $Mnet::HPNA::cfg * 60;
            $Mnet::HPNA::suicide_timer_active = 1;
        }

        # return hpna input substituted value
        return $hpna_arg;

    # finished hpna processing
    }

    # finished hpna_arg method, return no hpna substituted value
    return undef;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet

=cut



# normal package return
1;

