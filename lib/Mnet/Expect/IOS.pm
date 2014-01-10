package Mnet::Expect::IOS;

=head1 NAME

Mnet::Expect::IOS - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

Usage examples:

 # open a session to --object-name, similar to Mnet::Expect module
 use Mnet;
 use Mnet::Expect::IOS;
 my $cfg = &object;
 my $session = new Mnet::Expect::IOS({
    'expect-username' => '',
    'expect-password' => 'userpass',
    'expect-enable'   => 'enablepass',
 }) or die "could not connect to ios device";

 # set ios_sh_ver and related data such as ios_model, ios_image, etc.
 $session->show_ver or die "show_ver error";

 # set ios_sh_run and related such as ios_domain
 my $sh_run = $session->show_run or die "show_run error";

 # gathers show int, int switchport, and cdp neigh detail output
 my @ints = $session->show_int;

 # execute an ios ping command from device, extended ping possible
 my ($pct, $avg, $max) = $session->ping("test-ping.local");

 # execute ios copy command, file can be local or network
 $session->copy("nvram:startup-config", "flash:backup", 1) or die;

 # delete a local file
 $session->delete("flash:backup") or die;

 # issue and confirm a timed reload
 $session->reload_in(5) or die;

 # gather stanza config and set all staza related data properties
 my $int_cfg = $session->show_stanza("interface FastEthernet0/0");

 # push new config to ios device, return on error, backout optional
 $session->config_push("conf t\n"."no ip domain lookup\n"."end\n")
    if not $session->command("show run | i no ip domain lookup");

 # cancel a timed reload and confirm
 $session->reload_cancel or die;

 # force a reload now, do not save config, will reattach and confirm
 $session->reload_now("no_write_mem") or die;

 # write config to memory, confirm the write was ok
 $session->write_mem or die;

 # finished, close expect ios session
 $session->close;

Refer also to the stanza_* methods in this documentation for info
on how to check and update interface, access-list, class-map, etc
config stanzas.

=head1 DESCRIPTION

This module can be used to communicate with IOS devices.

This module inherits all of the Mnet::Expect module methods and
properties. Refer to the documentation for that module. Methods
and properties specific to this module are described below.

Other functions exist to implement config changes with the ability to
detect errors and backout the config, to reload the router, execute
pings, etc. Refer to the documentation below for a description of all
fucntions and how to use them.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --ios-config-ignore     set regex for config push errors to ignor
 --ios-detail            enable extra debug detail
 --ios-ints-lan-re       default regex '(atm|multi|pos|serial|tunnel)'
 --ios-ints-wan-re       default regex '(ethernet|token)'
 --ios-no-term-length    set true to skip term len 0 after login
 --ios-version           set at compilation to build number

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and libraries:

=cut

# modules used
use warnings;
use strict;
use Carp;
use Mnet;
use Mnet::Expect;

# setup inheritance of mnet expect methods
our @ISA = qw(Mnet::Expect);

# module initialization, track sessions to properly closer them all at exit
BEGIN {
    our $cfg = &Mnet::config({
        'ios-ints-lan-re'  => '(ethernet|token)',
        'ios-ints-wan-re'  => '(atm|multi|pos|serial|tunnel)',
        'ios-version'      => '+++VERSION+++',
        'ios-tab-strip'    => '    ',
    });
    our $selves = {};
}



sub config_push {

=head2 config_push method

 $result = $session->config_push($implementation, $backout);
 $result = $session->config_push(\@implementation, \@backout);

The config_push method sends the input implemenation argument to the
connected ios device, one line at a time. If there are any errors
during the push of the implementation config then the optional
backout lines are sent to the connected ios device.

For each line of implementation that is sent the output is examined
looking for the percent character used by ios to indicate errors. If
any line results in an error the implementation is stopped and the
lines from the optional backout argument are sent. All lines in the
backout are sent without checking for errors.

Howevere the --ios-config-ignore setting may be used to specify
a regular expression to use as a filter against any expected ios
warnings or errors. This property is cleared when the change method
is finished.

Note that a timeout will cause script errors. The Mnet::Expect
command method can be used to work around an expected timeout.

The implemenation and backout arguments may be specified either as
strings with linefeeds, or as referenced arrays of command lines.
The implementation argument is required, the backout argument is
optional.

The returned result will be 1, 0 or undefined. A value of 1 indicates
the implementation finished without errors. A value of 0 indicates
that there was an error during implementation and that the backout
was sent. A value of undefined indicates there was an error during
implementation, or a timeout, and that no backout input argument was
present, or the backout could not be entered.

The implemenation and backout arguments should assume a start from
an enable prompt, requiring a 'config terminal' command to enter
config mode and an 'end' command to return to the enable prompt.

Note that the ios 'end' command is automatically sent after a failed
implementation before a backout is started.

=cut

    # check that we were called as an instance
    my ($session, $implementation, $backout) = @_;
    &dbg($session, "config_push sub called from " . lc(caller));
    croak "not called as an instance" if not ref $session;

    # check input arguments, move them into array references
    $implementation = [split(/\n/, $implementation)]
        if not ref $implementation and $implementation =~ /\S/;
    croak "config_push implementation arg missing, not a string or array ref"
        if not defined $implementation or ref $implementation ne "ARRAY";
    $backout = [split(/\n/, $backout)]
        if defined $backout and not ref $backout and $backout =~ /\S/;
    croak "config_push backout arg not a string or an array ref"
        if defined $backout and ref $backout ne "ARRAY";

    # check for config ignore setting
    my $cfg_err_ignore = $session->{'ios-config-ignore'};
    $session->dbg("config_push: ios-config-ignore set '$cfg_err_ignore'")
        if $cfg_err_ignore;
    $session->{'ios-config-ignore'} = undef;

    # loop through sending the implementation lines to the device
    $session->inf("config_push implementation push starting");
    foreach my $line (@$implementation) {
        $session->inf("config_push implementation line = $line");

        # enter next command and note any output
        my $output = $session->command($line);

        # continue if there are no ios warnings or errors in output
        next if defined $output and $output !~ /^.*(\%.*)\s*$/m;
        my $error = $1;

        # return if there was a timeout during implementation
        if (not defined $output) {
            $session->log(4, "config_push implementation timeout");
            return undef;
        }

        # log ios error and return if ios-config-ignore is set but not a match
        if ($cfg_err_ignore) {
            my $error_flag = 0;
            foreach my $line (split(/\n/, $output)) {
                next if $line !~ /\%/;
                if ($line =~ /$cfg_err_ignore/i) {
                    $session->inf("config_push ignoring error $line");
                    next;
                }
                $session->log(4, "ios config_push implementation error $line");
                $error_flag = 1;
                last;
            }
            next if not $error_flag;
            return undef if $error_flag and not $backout;

        # log the ios error and return if no backout was set
        } else {
            $session->log(4, "config_push implementation error $error");
            return undef if not $backout;
        }
            
        # push the backout config and return a zero
        $session->inf("config_push backout push starting");
        $session->command("end");
        foreach my $line (@$backout) {
            $session->inf("config_push backout line = $line");
            $session->command($line);
        }
        $session->inf("config_push backout finished");
        return 0;

    # finished looping through the implementation
    }
    $session->inf("config_push implementation finished without errors");

    # config_push method finished
    return 1;
}

 

sub copy {

=head2 copy method

 $result = $session->copy($src, $dst, $verify);

Executes the ios copy command using the regquired source and destination
file specifications. An optional verifiy argument can be used to confirm
that the copy was successful.

Note that the verify argument can be set to '1' or to an md5 checksum.
If the verify arg is set to a value of one then a simplier checksum
verification will be attempted using the ios verify command. If an md5
value is supplied as the verify arg then an ios verify with the /md5
flag will be used to check the destination file. If the /md5 option
is not available on a device then checksum verification will be used
as a fallback.

This method will return a value of true if the copy and optional verify
succeeded. If the copy of the verify fails the result will be undefined.

Note that source and destinations can be specified as filepaths on local
filesystems, such as nvram:startup-config or flash:/path/file or network
filespecs, such as tftp://10.9.8.7/boot/router1.cfg.

The ios device may prompt to erase the destination filesystem as part
of the copy. The script will always answer 'n' (no) to this prompt.

The ios device may prompt to overwrite the destination file, if it
exists. The script will answer yes if no verify argument was supplied.
If a verify argument was supplied then the script will answer yes.

If the verify arg is set a destination file fails verification it will
be deleted.

=cut

    # check that we were called as an instance
    my ($session, $src, $dst, $verify) = @_;
    &dbg($session, "copy called from " . lc(caller));
    croak "not called as an instance" if not ref $session;

    # verify required arguments are present
    croak "copy missing required src argument"
        if not defined $src or $src !~ /\S/;
    croak "copy missing required dst argument"
        if not defined $dst or $dst !~ /\S/;

    # output copy attempt message
    $session->inf("copy attempt $src to $dst no verify") if not $verify;
    $session->inf("copy attempt $src to $dst with verify") if $verify;

    # overwrite files, unless verify is being used
    my $overwrite = "y";
    $overwrite = "n" if $verify;

    # start copy attempt
    my $start_time = time;
    my $copy_out = $session->command("copy $src $dst", undef, {
        '(?i)destination filename \[\S+\]\?' => "\n",
        '(?i)erase .* \[confirm\]' => "n\n",
        '(?i).*over\s?write.* \[confirm\]' => "$overwrite\n",
    });

    # check on how copy finished, return on failure
    my $elapsed_time = time - $start_time;
    if ($copy_out and $copy_out =~ /over\s?write/ and $overwrite eq 'n') {
        $session->inf("copy skipped overwrite of $dst");
    } else {
        if (not $copy_out or $copy_out !~ /(\[ok.*\]|bytes copied)/i) {
            &log(4, "copy failed $src to $dst in $elapsed_time seconds");
            return undef;
        }
        $session->inf("copy complete $src to $dst in $elapsed_time seconds");
    }

    # check if verify arg is not set
    if (not $verify) {
        $session->dbg("copy complete $src to $dst, no verification");

    # attempt md5 verification of dst, if verify is set and not equal to one
    } elsif ($verify ne "1") {
        $session->inf("copy attempting md5 verification of $dst");
        my $verify_out = $session->command("verify /md5 $dst $verify");
        if ($verify_out and $verify_out =~ /invalid input detected/i) {
            $session->inf("copy md5 verify not supported, using checksum");
            $verify = 1;
        } else {
            if (not $verify_out or $verify_out =~ /\%/
                or $verify_out =~ /error/i or $verify_out !~ /verified/i) {
                $session->log(4, "copy md5 verify error, deleting file $dst");
                $session->delete("$dst");
                return undef;
            }
            $session->inf("copy md5 verify succeeded for $dst");
        }
    }

    # attempt checksum verification of destination
    if ($verify and $verify eq "1") {
        $session->inf("copy attempting checksum verification of $dst");
        my $verify_out = $session->command("verify $dst");
        if (not $verify_out or $verify_out =~ /\%/ 
            or ($verify_out =~ /\S/i and $verify_out !~ /verified/i)) {
            $session->log(4, "copy checksum verify error, deleting file $dst");
            $session->delete($dst);
            return undef;
        }
        $session->inf("copy checksum verify succeeded for $dst");
    }
        
    # finished
    return 1;
}



sub delete {

=head2 delete method

 $result = $session->delete($file)

This method will execute the ios delete command for the specified
file. Any confirmation prompts will be answered.

This method will return a value of true if the ios delete command
appears to succeed. A value of true will also be returned if an error
indicating 'no such file' was returned. Any other ios error or timeout
will result in a return result of undefined.

=cut

    # check that we were called as an instance
    my ($session, $file) = @_;
    &dbg($session, "delete called from " . lc(caller));
    croak "not called as an instance" if not ref $session;

    # verify required file argument is present
    croak "copy missing required file argument"
        if not defined $file or $file !~ /\S/;

    # attempt to delete file
    $session->inf("delete starting for file $file");
    my $delete_out = $session->command("delete $file", undef, {
        '(?i)delete filename \[\S+\]\?' => "\n",
        '(?i)delete \S+\? \[confirm\]' => "\n",
    });

    # return on timeout or error
    if (not $delete_out
        or ($delete_out =~ /\%/ and $delete_out !~ /no such file/i)) {
        $session->log(4, "delete error for file $file");
        return undef;
    }

    # finished delete
    $session->inf("delete completed for file $file");
    return 1;
}



sub new {

=head2 new class method

 $session = new Mnet::Expect::IOS(\%args)

Creates a new IOS session object. Default config settings, or settings
in effect, may be changed with the optional hash argument.

The object is created using Mnet::Expect and the config settings
currently in effect. The $session->command and $session->close methods
can be used to address this connection.

The expect-username, expect-password and optional expect-enable config
settings should be used to log into the IOS device. Refer also to the
Mnet::Expect man page for more information.

A value of undefined is returned if the expect session could not be
created and expect session did not terminate with an error.

=cut

    # read optional input args and set up new class instance
    my ($class, $args) = @_;
    &dbg("new sub called from " . lc(caller));
    croak "new method for class only" if ref $class;
    $args = {} if not defined $args;
    croak "invalid ios config args" if ref $args ne "HASH";

    # connect the ios session, or return undefined
    my $session = &Mnet::Expect::new($class, $args);
    return undef if not defined $session;

    # dump new object data
    &dump("new", $session);

    # ensure session is in global list of all sessions
    $Mnet::Expect::IOS::selves->{$session} = $session;

    # attempt to turn off paging in terminal
    $session->command("term length 0") if not $session->{'ios-no-term-length'};

    # finished new
    return $session;
}


sub ping {

=head2 ping method

 $pct = $session->ping($ip)
 ($pct, $avg, $max) = $session->ping($ip, $count, $size, $source)

This method used the cisco ios ping command to test icmp reachability
to a given target ip address.

The success, average and maximum integer values are always returned. 
The success is a percentage rate of responses received. The average
and maximum response times are in milliseconds.

The optional count and size arguments will cause an extended ping
command to be used. This is only available when logged into an enable
mode ios command prompt.

An error will be issued for invalid input arguments. A warning will
be issued if the ping command returns an obvious ios error. Success
will always be a positive integer, but average and maximum may be
undefined.

=cut

    # check that we were called as an instance
    my ($session, $ip, $count, $size, $source) = @_;
    &dbg($session, "ping sub called from " . lc(caller));
    croak "not called as an instance" if not ref $session;

    # verify ip argument is present
    croak "ping missing required ip argument"
        if not defined $ip or $ip !~ /\S/;
    croak "ping count argument not valid"
        if defined $count and ($count !~ /^\d+$/ or $count < 1);
    croak "ping size argument not valid"
        if defined $size and ($size !~ /^\d+$/ or $size > 18024 or $size < 36);
    $size = 100 if defined $count and not defined $size;
    $source = "" if not defined $source;

    # execute simple or extended ping command on router as necessary
    my $ping_out = "";
    if (not $count and not $size and not $source) {
        $session->inf("ping to $ip using default count and size");
        $ping_out = $session->command("ping $ip");
    } else {
        $session->inf("ping to $ip using count $count and size $size, $source");
        $ping_out = $session->command("ping", undef, {
                    '\%'                          => undef,
                    '(?i)protocol.*:\s*'          => "ip\n",
                    '(?i)target ip.*:\s*'         => "$ip\n",
                    '(?i)repeat count.*:\s*'      => "$count\n",
                    '(?i)datagram size.*:\s*'     => "$size\n",
                    '(?i)timeout.*:\s*'           => "\n",
                    '(?i)extended commands.*:\s*' => "y\n",
                    '(?i)source.*:\s*'            => "$source\n",
                    '(?i)type of service.*:\s*'   => "\n",
                    '(?i)set df bit.*:\s*'        => "\n",
                    '(?i)validate reply.*:\s*'    => "\n",
                    '(?i)data pattern.*:\s*'      => "\n",
                    '(?i)loose.*:\s*'             => "\n",
                    '(?i)sweep.*:\s*'             => "\n",
        });
    }

    # output a warning if it looks like we encountered a command error
    $session->log(4, "ios ping output contained an ios error")
        if $ping_out =~ /^\%/m;

    # attempt to parse return values from ping output
    my ($pct, $avg, $max) = (undef, undef, undef);
    $pct = int($1) if $ping_out =~ /success rate is (\d+\.?\d*) percent/i;
    $avg = int($1) if $ping_out =~ /min\/avg\/max = \S+\/(\d+\.?\d*)\/\S+/i;
    $max = int($1) if $ping_out =~ /min\/avg\/max = \S+\/\S+\/(\d+\.?\d*)/i;
    $pct = 0 if not defined $pct;

    # output return values from ping
    my ($d_avg, $d_max) = ($avg, $max);
    $d_avg = "undef" if not defined $avg;
    $d_max = "undef" if not defined $max;
    $session->inf("ping $ip, $pct\% success, avg=$d_avg, max=$d_max");

    # finished ping method
    return $pct if not $count and not $size and not $source;
    return ($pct, $avg, $max)
}



sub reload_cancel {

=head2 reload_cancel method

 $result = $session->reload_cancel;

This method will cancel any scheduled reload on the currently
connected ios device.

A value of true is returned by this method when the reload is
confirmed as canceled.  A log warning is otherwise generated
an undefined value returned.

=cut

    # read session instance
    my $session = shift;
    croak "ios reload_cancel not called as an instance" if not ref $session;

    # initiate immediate reload, we dont' expect a prompt back
    $session->inf("reload_cancel initiating");
    $session->command("reload cancel");

    # pause and deal with logging syncronous banner
    if (not $session->{'expect-replay'}) {
        sleep 5;
        $session->command("");
    }

    # use show reload to verify that reload has been scheduled
    $session->dbg("reload_cancel verification, checking for scheduled reload");
    my $output = $session->command("show reload");
    if ($output !~ /no reload is scheduled/i) {
        $session->log(4, "ios reload_cancel error, could not confirm");
        return undef;
    }

    # finished
    $session->inf("reload_cancel complete");
    return 1;
}



sub reload_in {

=head2 reload_now method

 $result = $session->reload_in($minutes)

This method will initiate a scheduled reload on the currently
connected ios device.

The config will not be saved. The `show reload` command will be
used to confirm that a reload is scheduled.

A value of true is returned by this method when the reload is
confirmed as succeeded.  A log warning is otherwise generated
an undefined value returned.

=cut

    # read session instance and minutes
    my ($session, $minutes) = @_;
    croak "ios reload_in not called as an instance" if not ref $session;
    croak "ios reload_in invalid or missing minutes arg"
        if not $minutes or $minutes !~ /^\d+$/;

    # initiate immediate reload, we dont' expect a prompt back
    $session->inf("reload_in $minutes is being initiated");
    $session->command("reload in $minutes", undef, {
        '(?i)save\?\s+\[\S+\]:\s*'  => "no\n",
        '(?i)\[confirm\]\s*'        => "\n",
    });

    # pause and deal with logging syncronous banner
    if (not $session->{'expect-replay'}) {
        sleep 5;
        $session->command("");
    }

    # use show reload to verify that reload has been scheduled
    $session->dbg("reload_in $minutes, checking for scheduled reload");
    my $output = $session->command("show reload");
    if ($output !~ /reload scheduled in/i or $output =~ /no reload/i) {
        $session->log(4, "ios reload_in $minutes confirmation error\n");
        return undef;
    }

    # finished successfully
    $session->inf("reload_in $minutes confirmed as scheduled");
    return 1;
}



sub reload_now {

=head2 reload_now method

 $result = $session->reload_now($no_write_mem)

This method will reload the currently connected ios device.

Normally the 'write memory' command is issued first. The optional
no_write_mem argument, if set to true, will cause the ios device to
be reloaded without saving the currently running configuration.

It is expected that the reload command will timout without returning
to a command prompt and that the Mnet::Expect session will need to be
re-established to the target device. There is a one minute pause
before attempting to reconnect on the new session. Reconnect attempts
are made repeatedly over a period of 300 seconds.

After the new telnet session login is complete the 'show version'
command will be used and the uptime examined to verify the reload
actually happened.

A value of true is returned by this method when the reload succeeded.
An error is otherwise generated and script execution terminates. 

=cut

    # check that we were called as an instance
    my ($session, $no_write_mem) = @_;
    &dbg($session, "reload sub called from " . lc(caller));
    croak "ios reload_now not called as an instance" if not ref $session;

    # save the running config unless no_write_mem set true
    $session->inf("reload no_write_mem arg flag set") if $no_write_mem;
    $session->write_mem if not $no_write_mem;

    # initiate reload, expect the reload command to timeout returning a prompt
    $session->inf("reload_now command being entered");
    croak "ios reload_now command did not immediately disconnect"
        if defined $session->command("reload", undef, { undef => undef,
        '\[confirm\]' => "\n", '(S|s)ave\? \[yes\/no\]:?' => "no\n" })
        and not $session->{'expect-replay'};

    # mark time or reload then attempt to reconnect after a one minute delay
    my $reload_time = time;
    $session->inf("reload_now delay for one minute reconnection attempts");
    sleep 60 if not $session->{'expect-replay'}; 

    # attempt to repeatedly reconnect for 300 seconds
    $session->inf("reload_now method attempting to reconnect for 300 seconds");
    my ($pct, $start_time) = (0, time);
    while (1) {
        $pct = $session->connect;
        last if $pct;
        last if time > $start_time + 300;
        sleep 30;
    }
	croak "ios reload_now failed to reconnect" if not $pct;
    $session->inf("reload_now method reconnected");

    # calculate minutes since reload and parse show version uptime minutes
    my $reload_minutes = int((time - $reload_time) / 60) + 1;
    $session->dbg("reload_now reload_minutes = $reload_minutes");
    my $sh_ver_out = $session->command("show version");
    croak "ios reload_now show version uptime not consistant with reload"
        if $sh_ver_out !~ /uptime is (\d+) minutes?\s*$/m;
    my $sh_ver_minutes = $1;
    $session->dbg("reload_now show_ver_minutes = $sh_ver_minutes");

    # verify current uptime is consistant with the recent reload
    croak "ios reload_now uptime could not be verified for successful reload"
        if $sh_ver_minutes > $reload_minutes;
    $session->inf("reload_now verified using show version uptime");

    # finished reload method
    return 1;
}



sub show_int {

=head2 show_int method

 @ints = $session->show_int;

Collects show interface, show interface switchport, and show cdp
neighbor detail output from the currently connected ios device.

The output is parsed and a list of interface names is returned,
or an empty list if there was a problem collecting the outputs.
   
This method also parses the outputs and stores the following data
as properties of the session object:

 ios_ints_all   space-sep list of all interfaces from ios_sh_run
 ios_ints_lan   space-sep matching enabled --ios-ints-lan-re
 ios_ints_wan   space-sep matching enabled --ios-ints-wan-re
 ios_sh_cdp     show cdp neighbor detail output from device
 ios_sh_int     show interface output from device
 ios_sh_inv     show inventory output from device
 ios_sh_switch  show interface switchport output from device
 ios_wan_high   fastest enabled wan int bw in kb, from show int
 ios_wan_low    slowest enabled wan int bw in kb, from show int

These are all initialized to null values before being set from parsed
show version output, unless otherwise noted.

Note that this method will call the show_ver method if the session
object ios_sh_ver key is not yet set. The show_run method will be
called is the ios_sh_run session object key is not yet set.

=cut

    # check that we were called as an instance
    my $session = shift;
    &dbg($session, "show_int called from " . lc(caller));
    croak "ios show_int not called as an instance" if not ref $session;

    # initialize return value, as undefined
    my @ints = ();

    # set show ver, if not set already
    $session->show_ver if not $session->{'ios_sh_ver'};

    # set show run, if not set already
    $session->show_run if not $session->{'ios_sh_run'};

    # prepare lists of interfaces - all, lan and wan
    $session->{'ios_ints_all'} = "";
    if ($session->{'ios_sh_run'}) {
        foreach my $line (split(/\n/, $session->{'ios_sh_run'})) {
            next if $line !~ /^interface (\S+)/;
            push @ints, $1;
            $session->{'ios_ints_all'} .= "$1 ";
        }
        $session->{'ios_ints_all'} =~ s/\s$//;
    }
    &dtl("show_int ios_ints_all = $session->{'ios_ints_all'}");

    # set show int from command output
    $session->{'ios_sh_int'} = "";
    my $sh_int = $session->command("show interface");
    $session->{'ios_sh_int'} = $sh_int if $sh_int;

    # set enabled lan/wan ints and high/low wan bandwidth
    $session->{'ios_ints_lan'} = "";
    $session->{'ios_ints_wan'} = "";
    $session->{'ios_wan_high'} = "";
    $session->{'ios_wan_low'} = "";
    if ($sh_int) {
        my $int = "";
        foreach my $line (split(/\n/, $sh_int)) {
            $int = $1 if $line =~ /^(\S+) is/;
            $int = "" if $line =~ /^\S+ is administratively down/i;
            next if not $int;
            next if $line !~ /^\s*mtu\s+\d+\s+bytes,\s+bw\s+(\d+)\s+kbit/i;
            my $bw = $1;
            $session->{'ios_ints_lan'} .= "$int "
                if $int =~ /$session->{'ios-ints-lan-re'}/i;        
            next if $int !~ /$session->{'ios-ints-wan-re'}/i;
            $session->{'ios_ints_wan'} .= "$int ";
            $session->{'ios_wan_high'} = $bw
                if not $session->{'ios_wan_high'}
                or $bw > $session->{'ios_wan_high'};
            $session->{'ios_wan_low'} = $bw
                if not $session->{'ios_wan_low'}
                or $bw < $session->{'ios_wan_low'};
        }
        $session->{'ios_ints_lan'} =~ s/\s$//;
        $session->{'ios_ints_wan'} =~ s/\s$//;
    }
    &dtl("show_int ios_ints_lan = $session->{'ios_ints_lan'}");
    &dtl("show_int ios_ints_wan = $session->{'ios_ints_wan'}");
    &dtl("show_int ios_wan_high = $session->{'ios_wan_high'}");
    &dtl("show_int ios_wan_low = $session->{'ios_wan_low'}");

    # set show inventory from command output
    $session->{'ios_sh_inv'} = "";
    my $sh_inv = $session->command("show inventory");
    $session->{'ios_sh_inv'} = $sh_inv if $sh_inv;

    # set show cdp neighbor detail from command output
    $session->{'ios_sh_cdp'} = "";
    my $sh_cdp = $session->command("show cdp neighbor detail");
    $session->{'ios_sh_cdp'} = $sh_cdp if $sh_cdp;

    # set show interface switchport from command output
    $session->{'ios_sh_switch'} = "";
    my $sh_switch = $session->command("show interface switchport");
    $session->{'ios_sh_switch'} = $sh_switch if $sh_switch;

    # finished show_int method
    return @ints;
}



sub show_run {

=head2 show_run method

 $sh_run = $session->show_run;

Collects show running-config output from the currently connected ios
device.

The output is returned, or an undefined value if there was a problem
collecting the output.
   
This method also parses the output and stores the following data as
properties of the session object:

 ios_domain     ip domain-name from show running-config output
 ios_sh_run     show running-config output

These are all initialized to null values before being set from parsed
show version output, unless otherwise noted.

Note that this method will call the show_ver method if the session
object ios_sh_ver key is not yet set.

=cut

    # check that we were called as an instance
    my $session = shift;
    &dbg($session, "show_run called from " . lc(caller));
    croak "ios show_run not called as an instance" if not ref $session;

    # set show ver, if not set already
    $session->show_ver if not $session->{'ios_sh_ver'};

    # set show run from command output, or return value is undefined
    $session->{'ios_sh_run'} = "";
    my $sh_run = $session->command("show running-config");
    $session->{'ios_sh_run'} = $sh_run if $sh_run;

    # set config register
    $session->{'ios_domain'} = "";
    $session->{'ios_domain'} = $1
        if $sh_run and $sh_run =~ /^\s*ip domain-name (\S+)\s*$/mi;
    &dtl("show_run ios_domain = $session->{'ios_domain'}");

    # finished show_run method
    return $sh_run;
}



sub show_stanza {

=head2 show_stanza method

 $config = $session->show_stanza($match_re);
 $config = $session->show_stanza($match_re, \&match_sub);
 $config = $session->show_stanza($match_re, \&match_sub, \&config_sub);

This method parses show running-config output, returning matching
config and setting data elements in the session object.

A stanza is one or more lines of ios config where the first line is
flush with the left margin and any following lines are indented. 

The input $match_re argument can be a string or a regular expression.
A string will be matched against the beginning of each line in the show
run output up to a space or the end of line.

A input regular expression is bracketed by forward slashes and allows
for more flexible matches. It is recommended to use regular expressions
with text anchored to the start of the line to avoid less predictable
stanza outputs - such as returning a class applied under a policy-map.

The $config output from this function will be all lines matching the
input argument, along with all config indented under those lines. All
double spaces will be changed to single spaces, except that indenting
spaces will be preserved.

Note that the show_run method will be called if ios_sh_run is not
already set. Also note that some of the ios_int_* values below will
be set only if the show_int method was invoked prior.

The optional input \&match_sub code reference can contain tests of
ios_stanza_* and ios_int_* properties to return a value of true or
false. The session object is passed as the only arg to this code
ref. Each stanza in the running-config is evaluated first against
the input $match_re and then against the \&match_sub. Config lines
that match both coditions are then returned. All ios_stanza_* and
ios_int_* properties are cleared after a \&match_sub call.

If one, and only one, stanza was matched by the input argument then
the following session data will be set:

 ios_stanza_config   matching stanza or global config commands      
 ios_stanza_desc     from stanza description command
 ios_stanza_name     set to stanza header line, removes int suffix

If the matching stanza is a single interface then the following
session data will also be set:

 ios_int_cdp         show_int cdp neighbor output for current int
 ios_int_config      matching interface stanza config
 ios_int_desc        from interface descriptiong command
 ios_int_sh          show_int output for current interface
 ios_int_kb          bandwidth from show int or running-config output
 ios_int_lan         true if int-name matches --ios-ints-wan-re
 ios_int_inv         set show inventory output for current int slot    
 ios_int_name        current interface name, ex: Serial1/0.10
 ios_int_ip          primary address from int_config, if present
 ios_int_shut        true if interface is shutdown
 ios_int_switch      show_int switchport output for current int
 ios_int_wan         true if int_name matches --ios-ints-wan-re

Note that ios_int_inv output has relevant show inventory output for
name/pid line pairs for current interface slot concatenated into
single name/pid lines.

All of the above session data elements are initialized to null values
before being set, unless otherwise noted.

The optional \&config_sub code ref is used internally by the stanza_*
methods. Before appending matching stanza configs to this method's
output the config_sub code reference is called with the session object,
the matching config, and the text matched by the input match_re as
arguments. The matching config can be processed and the resulting new
config returned from the config_sub code reference is passed along as
output from this function.

=cut

    # read inputs, check that we were called as an instance
    my ($session, $match_re, $match_sub, $config_sub) = @_;
    &dbg($session, "show_stanza called from " . lc(caller));
    croak "ios show_stanza not called as an instance" if not ref $session;

    # normalize match regular expression input 
    $match_re = "" if not defined $match_re;
    $match_re = '.*' if $match_re eq '';
    $match_re = '/^' . $match_re . '(\s|$)/' if $match_re !~ /^\s*\/.*\/\s*$/;
    $match_re = $1 if $match_re =~ /^\s*\/(.*)\/\s*$/;
    &dbg("show_stanza normalized match = /$match_re/");

    # check on match subroutine input
    croak "ios show_stanza match_sub arg not a code reference"
        if defined $match_sub and ref $match_sub ne "CODE";
    &dtl("show_stanza match_sub set") if defined $match_sub;

    # check on config subroutine input
    croak "ios show_stanza config_sub arg not a code reference"
        if defined $config_sub and ref $config_sub ne "CODE";
    &dtl("show_stanza config_sub set") if defined $config_sub;

    # set show run, if not set already
    $session->show_run if not $session->{'ios_sh_run'};

    # process stanzas using match_sub code ref, build match_sub output config
    my $match_sub_config = "";
    if ($match_sub) {
        &dbg("show_stanza match_sub using match_re '$match_re'");
        foreach my $line (split(/\n/, $session->{'ios_sh_run'})) {
            next if $line !~ /($match_re)/;
            &dbg("show_stanza match_sub '$line' matches /($match_re)/");
            my $stanza_config
                = $session->show_stanza($line, undef, $config_sub);
            if (not &$match_sub($session)) {
                &dbg("show_stanza match_sub evaluated false for '$line'");
                next;
            }
            &dbg("show_stanza match_sub evaluated true for '$line'");
            $match_sub_config .= $stanza_config;
        }
    }

    # initialize session stanza data
    &dtl("show_stanza clearing ios_stanza_* object properties");
    $session->{'ios_stanza_config'} = "";
    $session->{'ios_stanza_desc'} = "";
    $session->{'ios_stanza_name'} = "";

    # initialize session stanza interface data
    &dtl("show_stanza clearing ios_int_* object properties");
    $session->{'ios_int_cdp'} = "";
    $session->{'ios_int_config'} = "";
    $session->{'ios_int_desc'} = "";
    $session->{'ios_int_sh'} = "";
    $session->{'ios_int_kb'} = "";
    $session->{'ios_int_lan'} = "";
    $session->{'ios_int_name'} = "";
    $session->{'ios_int_inv'} = "";
    $session->{'ios_int_ip'} = "";
    $session->{'ios_int_shut'} = "";
    $session->{'ios_int_switch'} = "";
    $session->{'ios_int_wan'} = "";

    # return match_sub_config output 
    if ($match_sub) {
        &dtl("show_stanza match_sub config: $_")
            foreach split(/\n/, $match_sub_config);
        &dbg("show_stanza returning from match_sub");
        return $match_sub_config;
    }

    # loop through show run output lines, track indents and match count
    my ($count, $indent) = (0, "");
    foreach my $line (split(/\n/, $session->{'ios_sh_run'})) {

        # fix descriptions sometimes not indented, remove extra spaces
        $line =~ s/^(description)/ $1/;
        $line =~ s/(\S+)\s\s+/$1 /g;
        $line =~ s/\s+$//;

        # add stanza lines indented under a matching line from above
        if ($indent ne "" and $line =~ /^$indent/) {
            $session->{'ios_stanza_config'} .= "$line\n";

        # add line to output, note stanza indent and update count
        } elsif ($line =~ /$match_re/) {
            $session->{'ios_stanza_config'} .= "$line\n";
            $indent = "$1 " if $line =~ /^(\s*)/;
            &dtl("show_stanza match_re matched something") if not $count;
            $count++;

        # reset indent since we must be done with stanza for matching line
        } else {
            $indent = "";
        }

    # continue looping through show run output lines
    }

    # output details of match_re config
    &dtl("show_stanza match_re config: $_")
        foreach split(/\n/, $session->{'ios_stanza_config'});

    # set matched text from config stanza and input match_re
    my $matched = "";
    $matched = $1 if $session->{'ios_stanza_config'} =~ /($match_re)/;
    chomp $matched;

    # return immediately if we have none of more than one matching line/stanza
    if (not $count or $count > 1) {
        if ($config_sub) {
            &dbg("show_stanza returning config_sub non-single stanza match");
            return &$config_sub($session,
                $session->{'ios_stanza_config'}, $matched);
        }
        &dbg("show_stanza returning non-single stanza match");
        return $session->{'ios_stanza_config'};
    }
        
    # set stanza name from first line of config, remove any interface suffix
    $session->{'ios_stanza_name'} = $1
        if $session->{'ios_stanza_config'} =~ /^\s*(.*)(\n|\r)/;
    $session->{'ios_stanza_name'} =~ s/^(interface\s+\S+)/$1/;
    &dtl("show_stanza ios_stanza_name = $session->{'ios_stanza_name'}");

    # set stanza description from stanza config, if present
    $session->{'ios_stanza_desc'} = $1
        if $session->{'ios_stanza_config'} =~ /^\s*description\s+(.*)/m;
    &dtl("show_stanza ios_stanza_desc = $session->{'ios_stanza_desc'}");

    # return now if stanza is not an interface stanza, or set interface name
    if ($session->{'ios_stanza_name'} !~ /^interface (\S+)/) {
        if ($config_sub) {
            &dbg("show_stanza returning config_sub non-interface match");
            return &$config_sub($session,
                $session->{'ios_stanza_config'}, $matched);
        }
        &dbg("show_stanza returning non-interface match");
        return $session->{'ios_stanza_config'};
    }
    $session->{'ios_int_name'} = $1;
    &dtl("show_stanza ios_int_name = $session->{'ios_int_name'}");

    # set interface config and description from stanza data
    $session->{'ios_int_config'} = $session->{'ios_stanza_config'};
    $session->{'ios_int_desc'} = $session->{'ios_stanza_desc'};
    &dtl("show_stanza ios_int_desc = $session->{'ios_int_desc'}");

    # parse show cdp neigh detail for the current interface
    my ($tmp_cdp_int, $tmp_cdp_detail) = ("", "");
    foreach my $line (split(/\n/, $session->{'ios_sh_cdp'})) {
        $tmp_cdp_detail .= "$line\n";
        $tmp_cdp_int = $1
            if $line =~ /^\s*interface:\s+(\Q$session->{'ios_int_name'}\E),/i;
        next if $line !~ /^\Q----\E/;
        $session->{'ios_int_cdp'} = $tmp_cdp_detail if $tmp_cdp_int;
        ($tmp_cdp_int, $tmp_cdp_detail) = ("", "");
    }
    $session->{'ios_int_cdp'} = $tmp_cdp_detail if $tmp_cdp_int;
    &dtl("show_stanza ios_int_cdp data found") if $session->{'ios_int_cdp'};

    # parse show interface output for the current interface
    my $tmp_sh_int = "";
    foreach my $line (split(/\n/, $session->{'ios_sh_int'})) {
        last if $tmp_sh_int and $line =~ /^\S+\s+is\s+\S+/i;
        next if not $tmp_sh_int
            and $line !~ /^\Q$session->{'ios_int_name'}\E\s+is/i;
        $tmp_sh_int .= "$line\n";
    }
    $session->{'ios_int_sh'} = $tmp_sh_int if $tmp_sh_int;
    &dtl("show_stanza ios_int_sh data found") if $session->{'ios_int_sh'};

    # gather show interface switchport for the current interface
    my ($tmp_sh_switch, $tmp_int_switch) = ("", $session->{'ios_int_name'});
    $tmp_int_switch = "${1}${2}"
        if $session->{'ios_int_name'} =~ /^(\S\S)\D+(\S+)$/;
    foreach my $line (split(/\n/, $session->{'ios_sh_switch'})) {
        last if $tmp_sh_switch and $line =~ /^\s*name:/i;
        next if not $tmp_sh_switch
            and $line !~ /^\s*name: \Q$tmp_int_switch\E\s*$/i;
        $tmp_sh_switch .= "$line\n";
    }
    $session->{'ios_int_switch'} = $tmp_sh_switch if $tmp_sh_switch;
    &dtl("show_stanza ios_int_switch data found")
        if $session->{'ios_int_switch'};

    # set relevant inventory items show inventory command output
    if ($session->{'ios_sh_inv'}
        and $session->{'ios_int_name'} !~ /(loopback|vlan|tunnel)/i
        and $session->{'ios_int_name'} =~ /^\D+(\d+)/) {
        my $slot = $1;
        my $name = "";
        foreach my $line (split(/\n/, $session->{'ios_sh_inv'})) {
            $name = $line if $line =~ /^\s*name/i;
            next if $line !~ /^\s*pid/i;
            my $flag = 0;
            $flag = 1 if $name =~ /^\s*name: "$slot"/i;
            $flag = 1 if $name =~ /^\s*name: "[^"]+\D$slot\D*"/i;
            next if not $flag;
            $session->{'ios_int_inv'} .= "$name, $line\n";
        }
    }

    # set bandwidth from show interface or show running-config output
    $session->{'ios_int_kb'} = $1
        if $session->{'ios_int_sh'} =~ /^\s*mtu \d+ bytes, bw (\d+) kb/mi
        or $session->{'ios_int_config'} =~ /^\s*bandwidth (\d+)/m;
    &dtl("show_stanza ios_int_kb = $session->{'ios_int_kb'}");

    # set primary ip from show running-config for current interface
    $session->{'ios_int_ip'} = $1
        if $session->{'ios_int_config'} =~ /^\s*ip address (\S+)/m;
    &dtl("show_stanza ios_int_ip = $session->{'ios_int_ip'}");

    # set shutdown status for current interface from running-config
    $session->{'ios_int_shut'} = 1
        if $session->{'ios_int_config'} =~ /^\s*shutdown\s*$/m;
    &dtl("show_stanza ios_int_shut = $session->{'ios_int_shut'}");

    # set ios_int_lan if interface name matches --ios-ints-lan-re
    $session->{'ios_int_lan'} = 1
        if $session->{'ios_int_name'} =~ /$session->{'ios-ints-lan-re'}/i;
    &dtl("show_stanza ios_int_lan = $session->{'ios_int_lan'}");

    # set ios_int_wan if interface name matches --ios-ints-wan-re
    $session->{'ios_int_wan'} = 1
        if $session->{'ios_int_name'} =~ /$session->{'ios-ints-wan-re'}/i;
    &dtl("show_stanza ios_int_wan = $session->{'ios_int_wan'}");

    # process matching config through config_sub code, returning output
    if ($config_sub) {
        &dbg("show_stanza returning config_sub interface match");
        return &$config_sub($session,
            $session->{'ios_stanza_config'}, $matched);
    }

    # finished show_stanza method
    &dbg("show_stanza returning interface match");
    return $session->{'ios_stanza_config'};
}



sub show_ver {

=head2 show_ver method

 $sh_ver = $session->show_ver;

Collects show version output from the currently connected ios device.

The output is returned, or an undefined value if there was a problem
collecting the output.
   
This method also parses the output and stores the following data as
properties of the session object:

 ios_cfg_reg    config register from show version, ex: 0x2102
 ios_disk       disk from show version system image file, ex: flash
 ios_dram       dram in megabytes from show version output
 ios_file       name of ios file, from show version system image file
 ios_hostname   hostname from show version uptime line
 ios_image      name of system image file, lowercase, with no .bin
 ios_model      lowercase model from show ver chassis/proc/hardware
 ios_path       path from show version system image file, if present
 ios_uptime     show version uptime in seconds, or 0 if unknown
 ios_sh_ver     show version command output

These are all initialized to null values before being set from parsed
show version output, unless otherwise noted.

=cut

    # check that we were called as an instance
    my $session = shift;
    &dbg($session, "show_ver called from " . lc(caller));
    croak "ios show_ver not called as an instance" if not ref $session;

    # set show version from command output, or return value is undefined
    $session->{'ios_sh_ver'} = "";
    my $sh_ver = $session->command("show version");
    $session->{'ios_sh_ver'} = $sh_ver if $sh_ver;

    # set config register
    $session->{'ios_cfg_reg'} = "";
    $session->{'ios_cfg_reg'} = $1
        if $sh_ver and $sh_ver =~ /^\s*config\S+ register is (.*)\s*$/mi;
    &dtl("show_ver ios_cfg_reg = $session->{'ios_cfg_reg'}");

    # set disk, path, file and image from show version
    $session->{'ios_disk'} = ""; 
    $session->{'ios_path'} = "";
    $session->{'ios_file'} = "";
    $session->{'ios_image'} = "";
    $session->{'ios_file'} = $1
        if $sh_ver and $sh_ver =~ /image file is (\S+)/;
    if (not $session->{'ios_file'}) {
        my $sh_boot = $session->command('show boot');
        $session->{'ios_file'} = $1
            if $sh_boot and $sh_boot =~ /^boot.*:(\S+)/mi;
    }
    $session->{'ios_file'} =~ s/("|'|,\d+|;)//gi;
    $session->{'ios_disk'} = $1 if $session->{'ios_file'} =~ s/^(.+)://;
    $session->{'ios_path'} = $1.$2
        if $session->{'ios_file'} =~ s/^(.+)(\/|\\)//;
    $session->{'ios_image'} = lc($session->{'ios_file'});
    $session->{'ios_image'} =~ s/\.bin$//;
    &dtl("show_ver ios_disk = $session->{'ios_disk'}");
    &dtl("show_ver ios_path = $session->{'ios_path'}");
    &dtl("show_ver ios_file = $session->{'ios_file'}");
    &dtl("show_ver ios_image = $session->{'ios_image'}");

    # set dram mb
    $session->{'ios_dram'} = ""; 
    $session->{'ios_dram'} = int(($1+$2+1023)/1024)
        if $sh_ver and $sh_ver =~ /(\d+)k\/(\d+)k bytes of mem/i;
    &dtl("show_ver ios_dram = $session->{'ios_dram'}");

    # set hostname form show ver
    $session->{'ios_hostname'} = ""; 
    $session->{'ios_hostname'} = $1
        if $sh_ver and $sh_ver =~ /^(\S+)\s+uptime is/m;
    &dtl("show_ver ios_hostname = $session->{'ios_hostname'}");

    # set model from show ver
    $session->{'ios_model'} = ""; 
    if ($sh_ver =~ /^cisco (.+) (chassis|processor|.rev)/mi) {
        $session->{'ios_model'} = lc($1);
        $session->{'ios_model'} =~ s/\s*\(.+\)//;
        $session->{'ios_model'} =~ s/\s*processor//;
    } elsif ($sh_ver =~ /^hardware .* model: (\S+)/mi) {
        $session->{'ios_model'} = lc($1);
    }
    &dtl("show_ver ios_model = $session->{'ios_model'}");

    # set uptime in secods from show ver, or zero if unknown
    $session->{'ios_uptime'} = 0;
    $session->{'ios_uptime'} += $1 * 60
        if $sh_ver and $sh_ver =~ /^\S+ uptime is.*\s(\d+)\s+minute/m;
    $session->{'ios_uptime'} += $1 * 60 * 60
        if $sh_ver and $sh_ver =~ /^\S+ uptime is.*\s(\d+)\s+hour/m;
    $session->{'ios_uptime'} += $1 * 60 * 60 * 24
        if $sh_ver and $sh_ver =~ /^\S+ uptime is.*\s(\d+)\s+day/m;
    $session->{'ios_uptime'} += $1 * 60 * 60 * 24 * 7
        if $sh_ver and $sh_ver =~ /^\S+ uptime is.*\s(\d+)\s+week/m;
    $session->{'ios_uptime'} += $1 * 60 * 60 * 24 * 7 * 52
        if $sh_ver and $sh_ver =~ /^\S+ uptime is.*\s(\d+)\s+year/m;
    &dtl("show_ver ios_uptime = $session->{'ios_uptime'}");

    # finished show_ver method
    return $sh_ver;
}



sub stanza_global {

=head2 stanza_global method

 $config = $session->stanza_global($match_cfg)

This method can be used to update global config commands, checking
for missing or extra commands. Only global config commands that are
not indented will be processed.

The existing global config commands are checked for each line in the
input $match_cfg then the output $config will contain commands to
update the global config.

The $match_cfg argument is required. The $match_cfg arg is used to
specify one or more lines of config that are matched against the
global configs.

The $match_cfg can contain + or - directives to check if commands
are present or need to be removed, respectively. The output $config
will add missing $match_cfg commands to the stanza, and/or no-out
extra commands in the stanza.

Example:

 # new config will be set as follows:
 #      adds snmp-server location test if not already present
 #      no-out any snmp-server commands that may be present
 $new_config .= $session->stanza_global('
    + snmp-server location test
    - snmp-server contact
 ');

=cut

    # read inputs
    my ($session, $match_cfg) = @_;
    &dbg($session, "stanza_global called from " . lc(caller));
    croak "ios stanza_global not called as an instance" if not ref $session;

    # remove match_cfg leading tabs and blank lines
    $match_cfg =~ s/^($session->{'ios-tab-strip'})+//mg;
    $match_cfg =~ s/\n+/\n/g;
    $match_cfg =~ s/^\s*\n//;

    # set show run, if not set already
    $session->show_run if not $session->{'ios_sh_run'};

    # prepare global global config commands
    my $config_global = "";
    foreach my $config_line (split(/\n/, $session->{'ios_sh_run'})) {
        next if $config_line =~ /^(\s|\!)/;
        $config_global .= "$config_line\n";
    }

    # initialize output config
    my $config = "";

    # loop through each line in the input match_cfg
    foreach my $match_line (split(/\n/, $match_cfg)) {
        next if $match_line !~ /\S/ or $match_line =~ /^\s*\#/;

        # handle ios comments
        if ($match_line =~ /^\s*\!/) {
            $config .= "$match_line\n";
            next;
        }

        # set default + directive if there's no directive specified
        $match_line = "+ $match_line" if $match_line !~ /^\s*(\+|\-)/;

        # handle + directive, or default no directive
        if ($match_line =~ s/^(\s*)\+\s*/$1/) {
            $config .= "$match_line\n"
                if &stanza_mismatch($config_global, $match_line, 'single');
            next
        }

        # handle - directive, check lines in config_old for what to no-out
        if ($match_line =~ /^\s*\-/) {
            foreach my $config_line (split(/\n/, $config_global)) {
                next if not &stanza_mismatch(
                    $config_line, $match_line, 'single');
                $config .= "no $config_line\n"
            }
        }

    # finish looping through the input match_cfg
    }

    # reset config_new if there's only comments
    my $comments_only_flag = 1;
    foreach my $line (split(/\n/, $config)) {
        next if $line !~ /\S/ or $line =~ /^\s*\!/;
        $comments_only_flag = 0;
        last;
    }
    $config = "" if $comments_only_flag;

    # output modified config back to show_stanza for matches
    $config = "! global\n$config" if $config and $config !~ /^\s*!/;
    &dbg("stanza_global returning: $_") foreach split(/\n/, $config);

    # finished stanza_global
    return $config;
}



sub stanza_mismatch {

# internal: $mismatch = &stanza_mismatch($config_old, $config_new, $single)
# purpose: compare old and new config, strip extra spaces
# $config_old: current device stanza config being checked
# $config_new: new config to compare to old, may include +/- directives
# $single: flag set true for comparing single $config_new to $config_old
# $mistmatch: set null on extact match, or to hint on first mismatch
# note: + directive (default) checks that the specified line is present
# note: - directive checks that the specified line is not present
# note: new config lines may be plain text or regex patterns 
# note: lines must match in the exact order, except for - directives
# note: new config lines can be regex definitions, enclosed in /.../

    # initialize output mismatch hint, read inputs
    my ($config_old, $config_new, $single) = @_;
    $config_old = "" if not defined $config_old;
    $config_new = "" if not defined $config_new;

    # build list of old config lines, skip blanks/comments, strip extra spaces
    my @old_lines = ();
    foreach my $old_line (split(/\n/, $config_old)) {
        next if $old_line !~ /\S/ or $old_line =~ /^\s*(!|#)/;
        $old_line =~ s/(^\s+|\s+$)//g;
        $old_line =~ s/\s\s+/ /g;
        push @old_lines, $old_line;
    }

    # set first line from old config
    my $old_line = shift @old_lines;

    # loop through new config, look for mismatches
    foreach my $new_line (split(/\n/, $config_new)) {

        # skip blank and comment lines in new config, strip extra spaces
        next if $new_line !~ /\S/ or $new_line =~ /^\s*(!|#)/;
        $new_line =~ s/(^\s+|\s+$)//g;
        $new_line =~ s/\s\s+/ /g;

        # return mismatch for - directive old lines that should not be present
        if ($new_line =~ s/^-\s*(\S.*)\s*$/- $1/) {
            my $match = $1;
            if ($match =~ /^\/(.*)\/\s*$/) {
                return "old config contains '$new_line'"
                    if $config_old =~ /$match/m;
            } else {
                return "old config contains '$new_line'"
                    if $config_old =~ /^\s*\Q$match\E(\s|$)/m;
            }
            $old_line = shift @old_lines;
            next;
        }

        # strip default + directive from new lines, must be in old to match
        $new_line =~ s/^\+\s*//;

        # look for single mode new line match in old config, return results
        if ($single) {
            if ($new_line =~ /^\/(.*)\/\s*$/) {
                return "old config mismatch with new '$new_line'"
                    if $config_old !~ /$new_line/m;
            } else {
                return "old config mismatch with new '$new_line'"
                    if $config_old !~ /^\s*\Q$new_line\E\s*$/m;
            }
            return "";
        }

        # return mismatch if old config ran out while we still have new config
        return "old config not present" if not $config_old;
        return "old config missing '$new_line'" if not defined $old_line;

        # return mismatch if new config line is not matched with next old line
        if ($new_line =~ /^\/(.*)\/\s*$/) {
            return "old config mismatch '$old_line' with new '$new_line'"
                if $old_line !~ /$new_line/;
        } else {
            return "old config mismatch '$old_line' with new '$new_line'"
                if $old_line !~ /^\Q$new_line\E$/;
        }

        # set next line of old config
        $old_line = shift @old_lines;

    # finish looping through new config
    }

    # check if there are any old config lines left, return mismatch
    return "old config extra '$old_line'" if defined $old_line;

    # finished stanza_mismatch method, we did not mismatch so return null
    return "";
}



sub stanza_rebuild {

=head2 stanza_rebuild method

 $config = $session->stanza_rebuild($match_re, $match_cfg)
 $config = $session->stanza_rebuild($match_re, \&match_sub, $match_cfg)

This method can be used to rebuild specified ios config stanzas that
do not already exactly match a specified config. This is intended for
updating access-list or class-map stanzas, where the order is important
and the stanzas cannot be removed and recreated in the config.

If the matching stanza configs do not exactly match the $match_cfg then
the output $config will contain commands to no-out all of the commands
in the stanza and rebuild the stanza with all the new commands from the
$match_cfg.

The $match_re and $match_cfg arguments are required. The $match_re arg
is used to specify the name of the stanza to match. The $match_cfg arg
is used to specify one or more lines of config that are expected to 
match exactly with the $match_re specified stanza.

If the $match_cfg does not match the existing stanza config exactly
then the output $config will contain a command to enter config under
the stanza, no-out all the old config, and rebuild the stanza with new
$match_cfg statements. The command to enter the stanza config will be
be taken using the matching $match_re input.

An optional \&match_sub can be provided as an input arg to examine
session ios_stanza_* and ios_int_* properties for stanzas to refine
which stanzas will match. Refer to the show_stanza method documentation
for more information.

Example:

 # new config will be set as follows if old class-map doesn't match:
 #      class-map match-any xy
 #       no description old
 #       description new
 $new_config .= &stanza_rebuild('ip access-list extended xy', '
    class-map match-any test
     description new
 ');

=cut

    # read inputs, including optional match_sub middle argument
    my ($session, $match_re, $match_sub, $match_cfg) = @_;
    &dbg($session, "stanza_rebuild called from " . lc(caller));
    croak "ios stanza_rebuild not called as an instance" if not ref $session;
    $match_cfg = $match_sub and $match_sub = undef if not defined $match_cfg;
    &dbg("stanza_rebuild match_re = '$match_re'");

    # remove match_cfg leading tabs and blank lines
    $match_cfg =~ s/^($session->{'ios-tab-strip'})+//mg;
    $match_cfg =~ s/\n+/\n/g;
    $match_cfg =~ s/^\s*\n//;

    # create new config, use match_re, match_sub, and config_sub
    my $config = $session->show_stanza($match_re, $match_sub, sub {

        # init modified config, read config_sub arguments for matching stanzas
        my ($config_new, $session, $config_old, $matched) = ("", @_);

        # return no new config if old and new already match
        my $mismatch = &stanza_mismatch($config_old, $match_cfg);
        if (not $mismatch) {
            &dtl("stanza_rebuild returning null for matching stanza");
            return "";
        }

        # prepare to recreate stanza, using match_cfg
        &dbg("stanza_rebuilde mismatch: $mismatch");

        # no-out everything under the existing stanza
        $config_new = "! rebuild $matched\n$matched\n";
        $config_old =~ s/^\s*\Q$matched\E//;
        foreach my $config_line (split(/\n/, $config_old)) {
            next if $config_line =~ /^\s*(#|!)/ or $config_line !~ /\S/;
            next if $config_line !~ s/^(\s*)//;
            $config_new .= "${1}no $config_line\n"
        }

        # rebuild new stanza config
        $match_cfg =~ s/^\s*\Q$matched\E//;
        foreach my $line (split(/\n/, $match_cfg)) {
            next if $line =~ /^\s*(#|-)/ or $line !~ /\S/;
            $line =~ s/^\s*\+\s*//;
            $config_new .= "$line\n"
        }

        # output modified config back to show_stanza for matches
        &dbg("stanza_rebuild returning: $_") foreach split(/\n/, $config_new);
        return $config_new;

    # finished stanza_rebuild new config
    });

    # finished stanza_rebuild
    return $config;
}


    
sub stanza_recreate {

=head2 stanza_recreate method

 $config = $session->stanza_recreate($match_re, $match_cfg)
 $config = $session->stanza_recreate($match_re, \&match_sub, $match_cfg)

This method can be used to recreate specified ios config stanzas that
do not already exactly match a specified config. This is intended for
updating access-list stanzas, where the order is important and the
stanzas can be removed and recreated in the config.

If the matching stanza configs do not exactly match the $match_cfg then
the output $config will contain commands to no-out the stanza and
recreate it from the $match_cfg.

The $match_re and $match_cfg arguments are required. The $match_re arg
is used to specify the name of the stanza to match. The $match_cfg arg
is used to specify one or more lines of config that are expected to 
match exactly with the $match_re specified stanza.

If the $match_cfg does not match the existing stanza config exactly
then the output $config will contain a command to no-out the stanza
and recreate it with the $match_cfg statements. The no-out statement
will be taken using the matching $match_re input.

An optional \&match_sub can be provided as an input arg to examine
session ios_stanza_* properties for stanzas to refine which stanzas
will match. Refer to the show_stanza method documentation for more
information.
 
Examples:

 # new config will be set as follows if access-list is not present
 #      access-list 100 permit ip any any
 $new_cfg .= $session->stanza_recreate('access-list 100', '
    access-list 100 permit ip any any
 ')

 # new config will be set as follows if access-list is not exact match
 #      no access-list 100
 #      access-list 100 permit ip any any
 # otherwise output appended to new config will be null
 $new_cfg .= $session->stanza_recreate('access-list 100', '
    access-list 100 permit ip any any
 ')

 # new config will be set as follows if access-list is not exact match
 #      no ip access-list extended acl
 #      ip access-list extended acl
 #       remark empty access list
 # otherwise output appended to new config will be null
 $new_cfg .= $session->stanza_recreate('ip access-list standard xy', '
    ip access-list standard xy
     remark empty access list
 ')

=cut

    # read inputs, including optional match_sub middle argument
    my ($session, $match_re, $match_sub, $match_cfg) = @_;    
    &dbg($session, "stanza_recreate called from " . lc(caller));
    croak "ios stanza_recreate not called as an instance" if not ref $session;
    $match_cfg = $match_sub and $match_sub = undef if not defined $match_cfg;
    &dbg("stanza_recreate match_re = '$match_re'");

    # remove match_cfg leading tabs and blank lines
    $match_cfg =~ s/^($session->{'ios-tab-strip'})+//mg;
    $match_cfg =~ s/\n+/\n/g;
    $match_cfg =~ s/^\s*\n//;

    # create new config, use match_re, match_sub, and config_sub
    my $config = $session->show_stanza($match_re, $match_sub, sub {

        # init modified config, read config_sub arguments for matching stanzas
        my ($config_new, $session, $config_old, $matched) = ("", @_);

        # return no new config if old and new already match
        my $mismatch = &stanza_mismatch($config_old, $match_cfg);
        if (not $mismatch) {
            &dtl("stanza_recreate returning null for matching stanza");
            return "";
        }

        # prepare to recreate stanza, using match_cfg
        &dbg("stanza_recreate mismatch: $mismatch");
        $config_new = "! recreate $matched\nno $matched\n" if $matched;
        foreach my $line (split(/\n/, $match_cfg)) {
            next if $line =~ /^\s*(#|-)/ or $line !~ /\S/;
            $line =~ s/^\s*\+\s*//;
            $config_new .= "$line\n"
        }

        # output modified config back to show_stanza for matches
        &dbg("stanza_recreate returning: $_") foreach split(/\n/, $config_new);
        return $config_new;

    # finished stanza_recreate new config
    });

    # finished stanza_recreate
    return $config;
}



sub stanza_update {

=head2 stanza_update method

 $config = $session->stanza_update($match_re, $match_cfg)
 $config = $session->stanza_update($match_re, \&match_sub, $match_cfg)

This method can be used to update specified ios config stanzas,
checking for missing or extra commands. This is intended for use in
updating interface and line configs, where the order of commands is
not important.

The matching stanza configs are checked for each line in the input
$match_cfg then the output $config will contain commands to update
the stanza configs.

The $match_re and $match_cfg arguments are required. The $match_re arg
is used to specify the name of the stanza to match. The $match_cfg arg
is used to specify one or more lines of config that are matched
against the stanza configs.

The $match_cfg can contain + or - directives to check if commands
are present or need to be removed, respectively. The output $config
will add missing $match_cfg commands to the stanza, and/or no-out
extra commands in the stanza.

An optional \&match_sub can be provided as an input arg to examine
session ios_stanza_* and ios_int_* properties for stanzas to refine
which stanzas will match. Refer to the show_stanza method documentation
for more information.
 
Example:

 # new config adds input qos if missing, removes output if present
 #      ethernet interfaces only are processed
 $new_config .= &stanza_update('/^interface \S+/', sub {
    my $session = shift;
    return 1 if $session->{'ios_int_name'} =~ /ethernet/i;
    return 0;
 }, '
    + service-policy input qos        
    - service-policy output
 ');

=cut

    # read inputs, including optional match_sub middle argument
    my ($session, $match_re, $match_sub, $match_cfg) = @_;    
    &dbg($session, "stanza_update called from " . lc(caller));
    croak "ios stanza_update not called as an instance" if not ref $session;
    $match_cfg = $match_sub and $match_sub = undef if not defined $match_cfg;
    &dbg("stanza_update match_re = '$match_re'");

    # remove match_cfg leading tabs and blank lines
    $match_cfg =~ s/^($session->{'ios-tab-strip'})+//mg;
    $match_cfg =~ s/\n+/\n/g;
    $match_cfg =~ s/^\s*\n//;

    # create new config, use match_re, match_sub, and config_sub
    my $config = $session->show_stanza($match_re, $match_sub, sub {

        # init modified config, read config_sub arguments for matching stanzas
        my ($config_new, $session, $config_old, $matched) = ("", @_);

        # check each line in match_cfg against stanza config_old, skip comments
        foreach my $match_line (split(/\n/, $match_cfg)) {
            next if $match_line !~ /\S/ or $match_line =~ /^\s*\#/;

            # handle ios comments
            if ($match_line =~ /^\s*\!/) {
                $config_new .= "$match_line\n";
                next;
            }

            # set default + directive if there's no directive specified
            $match_line = "+ $match_line" if $match_line !~ /^\s*(\+|\-)/;

            # handle + directive, or default no directive
            if ($match_line =~ s/^(\s*)\+\s*/$1/) {
                $config_new .= "$match_line\n"
                    if &stanza_mismatch($config_old, $match_line, 'single');
                next
            }

            # handle - directive, check lines in config_old for what to no-out
            if ($match_line =~ /^\s*\-/) {
                foreach my $config_line (split(/\n/, $config_old)) {
                    next if not &stanza_mismatch(
                        $config_line, $match_line, 'single');
                    next if $config_line !~ s/^(\s*)//;
                    $config_new .= "${1}no $config_line\n"
                }
            }

        # finish looping through new match_cfg
        }

        # reset config_new if there's only comments
        my $comments_only_flag = 1;
        foreach my $line (split(/\n/, $config_new)) {
            next if $line !~ /\S/ or $line =~ /^\s*\!/;
            $comments_only_flag = 0;
            last;
        }
        $config_new = "" if $comments_only_flag;

        # output modified config back to show_stanza for matches
        $config_new = "! update $matched\n$matched\n$config_new" if $config_new;
        &dbg("stanza_update returning: $_") foreach split(/\n/, $config_new);
        return $config_new;

    # finished stanza_update new config
    });

    # finished stanza_update
    return $config;
}



sub write_mem {

=head2 write_mem method

 $result = $session->write_mem;

This method will attempt to save the router config to memory.

A value of true is returned by this method when the reload succeeded.
An error is otherwise generated zand script execution terminates. 

=cut

    # check that we are called as an instance
    my $session = shift;
    &dbg($session, "write_mem sub called from " . lc(caller));
    croak "not called as an instance" if not ref $session;

    # save the running config
    $session->inf("write_mem saving running config");
    my $wr_mem = $session->command("write mem", undef, {'\[confirm\]' => "\n"});
    croak "write_mem error saving running config"
        if $wr_mem !~ /\[ok\]\s*$/mi or $wr_mem =~ /error/;
    $session->dbg("write_mem finished saving config");

    # finished write_mem method
    return 1;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, Mnet::Expect

=cut



# normal package return
1;

