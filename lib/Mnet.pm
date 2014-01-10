package Mnet;

=head1 NAME
 
Mnet - network automation scripting module
 
=head1 VERSION

+++VERSION+++

=cut

BEGIN {
    our $VERSION = '+++VERSION+++';
}

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

This perl module can be used to create network monitoring and
automation scripts.

The functions made available by this module allow for reading config
settings and writing log entries. An optional database connection can
be used to store log entries, track alerts, and handle other script
data. In addition the invoking script can be run in a batch mode where
multiple instances are forked to handle a list of target network
objects. Other related modules exist to provide additional
functionality.

Usage examples:

 # sample1.pl --object-name test --object-address 127.0.0.1
 # nb: the object function call reads all config settings
 #     command line settings are set in the cfg object
 use Mnet;
 my $cfg = &object;
 &log(7, "loopback") if $cfg->{'object-address'} eq "127.0.0.1";

 # sample3.pl --batch-hosts --batch-list /etc/hosts
 # nb: object call forks multiple instances to process hosts
 #     object-name and object-address set in cfg from hosts file
 #     log-stdout set as default enabled at cfg object call
 #     sterr prompts for object-input value set from stdin
 use Mnet;
 my $cfg = &object({ 'log-stdout' => '1'});
 &input("object-input");
 &alert(5, "local") if $cfg->{'object-name'} =~ /\.local$/;

 # sample3.pl --object-name test --db-name mnet
 # nb: uses persist hash references to examine and update data
 #     from one instance of object script execution to the next
 use Mnet;
 my $cfg = &object;
 my ($persist_old, $persist_new) = &persist;
 $persist_new->{counter} = $persist_old->{counter} + 1;
 &log("old counter value = " . $persist_old->{counter});
 &log("new counter value = " . $persist_new->{counter});

 # sample4.pm
 # nb: creates new module with its own default config setting
 #     input value is prompted for once in sample3-batch mode
 #     when not in batch mode test function prompts for input
 package sample4;
 use Mnet;
 BEGIN {
     our $cfg = &config({'sample4-opt' => 'default'});
     &Mnet::input("sample4-input")
        if defined $cfg->{'sample4-batch'};
 }
 sub test {
     &input("sample4-input")
         if not defined $sample4::cfg->{'object-name'};
     return if $sample4::cfg->{'object-name'} !~ /-rtr$/;
     &log(6, "the name of this object ends in '-rtr'");
 }
 1;

The following sections describe the basic operation of this module,
batch mode, the optional database connection, configuration parsing
and using this module to create other modules.

=head1 DESCRIPTION

This perl module can be used to create network monitoring and
automation scripts.

Scripts using this module will require one call, and one call only,
to the object function. This call will return a hash reference to
all config settings. Normally the object call is made early in the
script.

When running a script using this module it is required that either
an object-name name or object-address config setting be supplied. The
script will end with an error at the object call if one of these
settings are not present. The object name will used as an address
if an address is not set, and vice-versa.

In batch mode a list of objects can be passed to the script. In
batch mode a parent process will handle feeding the list of objects
to one or more child processes. This fork occurs at the object
function call. This means that the same script can handle one
object configured via the command line, or a list of objects from
a file.

Normally the config hash reference returned by the object function
call is used for reading config settings only. Default config
settings for the script can be suplied as an argument to the
object function. New config settings for use by the script can be
referenced as necessary. Naming collisions with module config
settings and changing config settings used by other modules can
cause problems and should be avoided.

The input function can be used to prompt a user for a config
setting value on the terminal.

The alert and log functions output unbuffered formatted lines with
timestamps and the current object name to the terminal and/or a
configured database connection.

A configured data-dir directory will result in a subdirectory
being created for each object that is processed. Scripts may store
data files in these object subdirectories. After an object function
call the object subdirectory is automatically created and becomes
the current working directory.

The database function allows for an invoking script to access
database tables directly, to store data specific to the script
or to query data written by other scripts. Log and alert data from
this module can be examined that way.

It is not necessary to use the database function in a script to
make use of the database. If a properly configured database is
set using the db-name config setting then this module, and others
that make use of the database, will automatically make use of the
db-name specified database. This module can store log and alert
information in a database.

=head1 CONFIGURATION

List of all config settings supported by this module:

 --object-address <addr>  specify address, defaults to object-name
 --object-name <name>     specify name, defaults to object-address

 --data-dir </path/dir>   specify object data subdirectories location

 --log-detail-all         enable for extra debug detail for everything
 --log-diff               zero stdout log times, no summary, for diffs
 --log-filter             default '^(?i)\S+-(enable|md5|pass|secret)'
 --log-level <0-7>        default sev 6, controls logging except stderr
 --log-long               enable to force object in log file output
 --log-quiet              suppresses inf, dbg, dtl log to stdout and db
 --log-silent             disables mnet logging and signal handlers
 --log-stderr             default 1 meg debug stderr output on errors
 --log-stdout             default enabled stdout entries of log-level
 --log-summary            output summary of wrn, err, and sev 0-4 logs

 --conf-auth <file>       allows auth settings to be secured
 --conf-etc <file>        default /usr/local/etc/Mnet.conf file
 --conf-file <file>       file containing config settings to apply
 --conf-noinput           set for batch jobs, die on stdin input call

 --batch-list <file>      config line per object for batch mode 
 --batch-hosts            batch file will be in hosts file format
 --batch-procs <count>    defaults to one batch mode child process
 --batch-repeat <secs>    batch or object interval, default disabled
 --batch-parse            if set then parse batch file and exit

 --db-name <database>     database name to connect to, default not set
 --db-clean               set to cleanup expired db entries on exit
 --db-expire <days>       days to remove old data, default 100
 --db-dbi <driver>        database dbi driver, default uses sqlite
 --db-host <host>         address for db connection, default 127.0.0.1
 --db-pass <pass>         password for db connection, default null
 --db-port <port>         tcp port used for db connection, default 5432
 --db-user <user>         username for db connect, default null
 --db-persist             clear to suppress persist data read and write

 --ment-detail            enable for extra mnet module debug detail
 --mnet-script <name>     set at compilation to calling script name
 --mnet-version           set at compilation to module release number

List of hidden config settings used by this module:

 _mnet-object-flag        set in object sub, errors on second call
 _mnet-caller             log entry caller output, default script-name

Note that if log-stderr is set non-zero and data-dir is set then if a
script die or warn statement error condition is encounters an .err
file will be written in the object-name data directory. This file
will be named using the mnet-script configuration setting.

=head1 BATCH MODE

The batch-list config setting enables batch mode processing in a
script. Each line in the specified batch file must contain config
settings for one object. An object-name or object-address setting
is required. Other config settings for each object may be used as
desired or necessary.

Note that the batch-list file will be looked for in the current
directory, or in the data-dir directory if one is defined. An
absolute path may be used to point to a batch file, if desired.

This means that global settings, those common to all objects in
a batch file, may be placed on the command line or in a file
specified by the conf-file setting. Config settings specific to
an object can be placed in the batch-list file on the same line
as the defined object. Anything on a line after a hash character
is considered a comment and ignored.

When a script is started with the batch-list setting defined a
process fork occurs at the first object function call. A parent
process reads the contents of the batch-list file and starts one
or more child processes. The parent process passes all config
settings in effect, including those from the next batch file line,
to the new child process. The child continues running from the
object function call with one object defined.

The parent process continues running and forking new children
until all object lines in the batch file have been processed by
child instances of the script. By default only one child process
at a time is allowed to execute. The batch-procs config setting
may be changed to allow more child processes to run concurrently.
The batch mode parent process will wait for a child process to
complete before forking another.

The batch-host config setting can be used to specify that the
configured batch-list file is in standard hosts file format, with
an ip address, some whitepace and a hostname. The first word
on a line is taken as the object-address and the second word is
taken as the object-name name. All other text is ignored. The
localhost entry is skipped.

The batch-parse config setting can be used to syntax check the
configured batch-list file and immediately report any parsing
errors without processing anything.

The batch-repeat setting can be used to repeatedly process the
the objects in the batch file, starting the list again when
finished. This can be used for monitoring applications. The
number of seconds specified will be used as a delay to ensure
the list is not started over too soon.

The batch-repeat setting can be used without an batch-list file
being configured when an object-name has been defined. This will
enable batch mode processing of the configured object-name, with
repeated execution of the script forking from the object call
at regular intervals.

=head1 DATABASE CONNECTIVITY

This module has a database function that returns a handle to a
database connection. The DBI perl module is required and should
be consulted for additional information on how to make use of
the returned handle.

This function does not need to be called to store logs, alerts or
object persistant data in a database. A specified db-name config
setting will automatically allow these builtin functions to use
a database.

The db-dbi config setting defaults to SQLite. Change to Pg
for postgresql. Other DBD modules may work, but have not been
tested. The default db-host, port, username and password
settings work for current user to access a local database.

Note that for SQLite that the db-name specifies the file that the
database will use. This can include a path. If it does not then
the database file will be created in the data-dir directory if
one was configured. Otherwise the database file will be created
in the current directory. 

The database function can be used to get a handle for the named
database to read tables, such as the alert and log tables, or to
create a new table. It would not be advisable to modify data that
was created by other scripts or modules.
 
The db-clean setting controls the deletion of old data when
a script exits. When running in batch mode this cleaning occurs
when the parent process exits, or at the end of the batch file if
batch-repeat is configured. During a database clean all tables are
examined for an _expired column. If the unix time in the _expired
column is greater than the current time that record is deleted.

To force a clean of expired entries enter the following command:

 perl -e 'use Mnet; &config;' - \
    --db-name <database> --db-clean \

The db-expire config setting is used to set the number of days
that database entries, such as log entries, should expire. In this
module the alert table entries use different default expiration
times. Refer to the alert function for more information.

Database tables created in a user script will need old entries
removed as desired. This module will not clean tables create by a 
user script.

=head1 CONFIGURATION PARSING

Config option values cannot include spaces, unless they are single
or double quoted. Nested quotes are ok, but escapes are not
recognized.

A config option with no value will be stored with a default value
of a numberic one. Quoted line breaks in an input config value
will be converted to spaces.

The conf-file option can be used to reference a file storing any
number of config settings for a script. Multiple conf-file files
can be specified, they are processed in the order encountered.

The conf-auth option can be used to reference a file stored with
restricted permissions used to store sensitive config settings such
as passwords. Specified conf-auth files are otherwise handles like
conf-file files.

Config settings are applied in the following order:

 - mnet module begin block defaults
 - other module begin block config defaults
 - from conf-etc config file
 - from the MNET environment variable
 - config or object functions in code
 - command line arguments, see note below
 - current line from specified batch-list file
 - config function settings during execution

The last application of a config setting will be the setting in
effect for script execution.

The input function may be used to in a script to prompt user terminal
input for config settings required for script operation. The user will
be prompted for settings defined with the input function if these
settings are not otherwise configured when the script is executed.

Note on comand line arguments: If a single dash by itself is present
on the command line then this module will process only command line
arguments after this dash.

=head1 OTHER MODULES

The basic functions in this module handle the parsing of config
settings, batch mode processing, logging, database connectivity
and alerts. This module comes with other modules to handle
common usage situations, such as telnet and snmp connectivity
and rrd graphs. Other modules that leverage the functionality in
this module can be created as necessary.

New modules can have access to all config settings by use of a
config function call in the begin block of the new module. The
output hash reference from this call should be declared as a
global module variable using the 'our' declaration. Default
config settings for the new module can be passed as a referenced
hash to the config functon call. The input function in a module
begin block may also be used to query the terminal user for
passwords or other user input required by a module for proper
prompting of user input values when running in batch mode.

Note that all config settings for a module should follow the
naming convention 'module-setting' with the name of the module
used as a prefix. This will help avoid config setting namespace
collisions.

The referenced hash of config settings can be used to read or
modify any config settings. It would not be a good practice to
modify config settings used outside a module. Doing this could
cause problems.

The bug function in this module should be used to report program
errors.  This insures errors are logged properly along with a trace
sent to standard error.

Note that in the begin block of the new module that an object will
not yet be configured and that functions such as log and alert
that require an object will not cause a bug error if they are
called in a begin block.

Also note that a module may be used by a script running in batch
mode. This means that multiple process instances may be forked
and running concurrently. To avoid problems data should be kept
separate for each object, using a hidden config value, a file
in a data-dir directory, or a table in the database. Hidden
config values start with an underscore character as a convention.

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and modules:

=cut

# modules used
use strict;
use warnings;
use 5.008008;
use Carp;
use Data::Dumper;
use Exporter;
use File::Path;
use POSIX ":sys_wait_h";
use Time::HiRes qw ( time );

# export module function names and set version number
our @ISA = qw( Exporter );
our @EXPORT = qw(
    alert config database dbg dtl dump inf input log object persist
);

# module initialization
BEGIN {

    # set script start time
    our $start_time = time;

    # initialize process id, parent id and child counter for batch mode
    our ($pid, $ppid) = (0, 0);
    our $child_count = 0;

    # initialize dummy batch list for batch-repeat without batch-list
    our $batch_object = "";

    # initialize counter and list to hold user terminal input prompts
    our $input_count = 0;
    our %inputs = ();

    # initialize config settings and config defaults
    our $cfg = {};
    our $cfg_defaults = {
        'conf-etc'      => '/usr/local/etc/Mnet.conf',
        'log-filter'    => '(?i)\S+-(enable|md5|pass|secret)',
        'batch-procs'   => 1,
        'db-expire'     => 100,
        'db-dbi'        => 'SQLite',
        'db-host'       => '127.0.0.1',
        'db-pass'       => '',
        'db-port'       => 5432,
        'db-user'       => '',
        'log-level'     => 6,
        'log-stderr'    => 1,
        'log-stdout'    => 1,
        'log-summary'   => 1,
        'mnet-version'  => '+++VERSION+++',
    };

    # set script name, strip perl keyword, args, path and spaces
    $cfg_defaults->{'mnet-script'} = $0;
    $cfg_defaults->{'mnet-script'} =~ s/^\s*perl:?\s*//i;
    $cfg_defaults->{'mnet-script'} =~ s/^(\S+).*/$1/;
    $cfg_defaults->{'mnet-script'} =~ s/^.*(\/|\\)(\S+)/$2/;
    $cfg_defaults->{'mnet-script'} =~ s/\s+/_/;
    $cfg_defaults->{'mnet-script'} = 'perl-e'
        if $cfg_defaults->{'mnet-script'} eq "-e";

    # initialize flags to track script start and version logging
    our ($start_logged, $versions_logged) = (0, 0);

    # set starting config to config defaults
    foreach my $option (keys %$cfg_defaults) {
        $cfg->{$option} = $cfg_defaults->{$option};
    }

    # initialize tracking of current alerts
    our %new_alerts = ();

    # initialize global database connection handle and prepared queries
    our $mdbh;
    our ($db_log_new, $db_log_clean)
        = (undef, undef);
    our ($db_alert_clear, $db_alert_new, $db_alert_update)
        = (undef, undef, undef);
    our ($db_persist_new, $db_persist_update)
        = (undef, undef);

    # initialize log error debug output and mnet exit warnign and error flag
    our ($log_stderr, $error, $error_last) = ('', 0, '');

    # initialize log summary output
    our $log_summary = "";

    # initialize persistant object data
    our $persist_old = {};
    our $persist_new = {};

    # trap interrupt signal, to exit normally
    our $sig_int = 0;
    our $sig_int_old = $SIG{INT};
    $SIG{INT} = sub {
        $Mnet::error = 1;
        $Mnet::error_last = "caught interrupt signal";
        $Mnet::sig_int = 1;
        &Mnet::log(0, "wrn", "caught interrupt signal");
        &$sig_int_old if $sig_int_old;
        exit 1;
    };

    # trap terminate signal, to exit normally
    our $sig_term = 0;
    my $sig_term_old = $SIG{TERM};
    $SIG{TERM} = sub {
        $Mnet::error = 1;
        $Mnet::error_last = "caught terminate signal";
        $Mnet::sig_term = 1;
        &Mnet::log(0, "wrn", "caught terminate signal");
        &$sig_term_old if $sig_term_old;
    };

    # trap perl warnings for logging
    my $sig_warn_old = $SIG{__WARN__};
    $SIG{__WARN__} = sub {
        my ($error_text, $caller) = ("@_", lc(caller));
        $Mnet::error = 1;
        $caller = lc(caller(1)) if $caller eq "carp";
        $Mnet::error_last = "$caller $error_text";
        &Mnet::log(0, "wrn", $error_text, $caller);
        foreach my $line (split(/\n/, Carp::longmess)) {
            next if $line !~ /\S/;
            &Mnet::log(7, "wrn", $line, $caller);
        }
        &$sig_warn_old if $sig_warn_old;
    };

    # trap perl die for logging
    my $sig_die_old = $SIG{__DIE__};
    $SIG{__DIE__} = sub {
        my ($error_text, $caller) = ("@_", lc(caller));
        $Mnet::error = 1;
        $caller = lc(caller(1)) if $caller eq "carp";
        $Mnet::error_last = "$caller $error_text";
        &Mnet::log(0, "die", $error_text, $caller);
        foreach my $line (split(/\n/, Carp::longmess)) {
            next if $line !~ /\S/;
            &Mnet::log(7, "die", $line, $caller);
        }
        &$sig_die_old if $sig_die_old;
        exit 1;
    };

# end of module initialization
}



sub alert {

=head2 alert function

 &alert($sev, $text, $expires)

Alerts can be used to show object availability, interface problems,
abnormal utilization, etc. An alert is different than a log entry
in that, with a db-name configured, alerts persist and are tracked
across multiple polls of an object.

If a db-name is configured then current alerts for each object are
stored in a table and log entries are made as alerts appear and
disappear. The data set includes the time the alert first appeared.
The alert disappears when an object returns polling data and a
matching alert (sev and text) is not present.

The optional expires argument can specify the number of minutes
until an orphaned alert, for an object not being polled anymore,
is automatically removed from the database. If not specified an
alert will be set to expire in severity + 1 days.

The script will terminate with an error if the alert function is
called before the object function is invoked.

=cut

    # check object initialization and function arguments
    &dbg("alert sub called from " . lc(caller));
    croak "invalid alert call before object call" if not $Mnet::pid;
    my ($sev, $text, $expire) = @_;

    # validate input args and remove extra whitespace from text
    $sev = 0 if not defined $sev or $sev !~ /^\d$/ or $sev > 7;
    $text = "unspecified alert" if not defined $text;
    $text =~ s/(^\s+|\s+$)//g;
    $text =~ s/(\s\s+|\r?\n)/ /g;
    $expire = ($sev + 1) * 1440 if not defined $expire or $expire !~ /^\d+$/;

    # update current poll alert hash with new alert
    $Mnet::new_alerts{"$sev $text"} = $expire;

    # finished alert function
    return;
}



sub alert_update {

# internal: &alert_update()
# purpose: update alert database and make alert and clear entries

    # finished right away if not running as a specific object
    &dbg("alert_update sub called from " . lc(caller));
    return if not defined $Mnet::cfg->{'object-name'};

    # mark current alert time
    my $atime = int(time);

    # log all alerts and return if database is not being used
    if (not defined $Mnet::mdbh) {
        foreach my $new_alert (sort keys %Mnet::new_alerts) {
            my ($sev, $text) = (0, "unknown");
            ($sev, $text) = ($1, $2) if $new_alert =~ /^(\d)\s(.+)/;
            &log($sev, 'alr', $text);
        }
        return;
    }

    # obtain list of alerts for this object and script from database
    my $db_alerts = $Mnet::mdbh->selectall_arrayref(
        "select _sev, _text from _alert where _object=? and _script=?", {},
        $Mnet::cfg->{'object-name'}, $Mnet::cfg->{'mnet-script'});

    # loop through alerts from database looking for cleared and updated alerts
    foreach my $db_alert (@$db_alerts) {
        my ($sev, $text) = @$db_alert;

        # clear alerts in database no longer in current list
        if (not defined $Mnet::new_alerts{"$sev $text"}) {
            $Mnet::db_alert_clear->execute($Mnet::cfg->{'object-name'},
                $Mnet::cfg->{'mnet-script'}, $sev, $text);
            &log($sev, 'clr', $text);

        # update expired time of current alerts in database and log to terminal
        } elsif ($Mnet::new_alerts{"$sev $text"}) {
            my $expire = $Mnet::new_alerts{"$sev $text"};
            my $etime = int(time + $expire * 60);
            $Mnet::db_alert_update->execute($etime, $Mnet::cfg->{'object-name'},
                $Mnet::cfg->{'mnet-script'}, $sev, $text);
            $Mnet::new_alerts{"$sev $text"} = undef;
            &log($sev, 'no_db:alr', $text);
        }

    # continue looping through database alerts
    }

    # loop through remaining new alerts adding them to database
    foreach my $new_alert (keys %Mnet::new_alerts) {

        # skip new alerts flagged as already in database
        next if not defined $Mnet::new_alerts{$new_alert};

        # parse alert data and add new record to database
        my ($sev, $text) = (0, "unknown");        
        ($sev, $text) = ($1, $2) if $new_alert =~ /^(\d)\s(.+)/;
        my $expire = $Mnet::new_alerts{$new_alert};
        my $etime = int($atime + $expire * 60);
        $Mnet::db_alert_new->execute($atime, $Mnet::cfg->{'object-name'},
            $Mnet::cfg->{'mnet-script'}, $sev, $text, $etime);
        &log($sev, 'alr', $text);    

    # continue loop to add remaining alerts to database
    }

    # finished rotate alerts function
    return;
}



sub batch {

# internal: &batch()
# purpose: implement batch mode parent process controlling child processes
# note: called from the object function when batch-list is configured

    # log batch mode and current config settings
    &dbg("batch sub called from " . lc(caller));
    &inf("batch mode initiated");

    # error if batch-repeat value not valid
    croak "batch-repeat <seconds> not a valid integer"
        if defined $Mnet::cfg->{'batch-repeat'}
        and $Mnet::cfg->{'batch-repeat'} !~ /^\d+$/;

    # log batch repeat, if configured
    &inf("batch repeat set to $Mnet::cfg->{'batch-repeat'} seconds")
        if $Mnet::cfg->{'batch-repeat'};

    # error if batch-procs value not valid
    croak "batch-procs <count> not valid"
        if $Mnet::cfg->{'batch-procs'} !~ /^\d+$/
        and $Mnet::cfg->{'batch-procs'} < 1;

    # set flag for parse check pass through
    my $parse_check = 1 if $Mnet::cfg->{'batch-parse'};

    # start an endless loop in case batch-repeat is configured
    while (1) {

        # read batch file, set batch line counter and start time
        my @batch_items = &batch_file;
        my ($batch_item, $batch_line, $time_start) = ("", 0, time);

        # loop until all items in batch list are processed
        while (1) {

            # fork another child as necessary
            if (@batch_items
                and $Mnet::child_count < $Mnet::cfg->{'batch-procs'}) {
                $batch_item = shift @batch_items;
                $batch_line++;
                &batch_fork;
            }

            # configure child, exiting on errors or returning to main script
            if ($Mnet::ppid) {
                my $err = &config_line($batch_item, undef, "no-globals");
                croak "batch-list line $batch_line $err" if $err;
                exit if $parse_check;
                return;
            }

            # exit batch loop if all batch lines processed and children exited
            last if not @batch_items and not $Mnet::child_count;

        # continue loop to process all batch list items
        }

        # exit if batch-parse is configured
        if ($parse_check and $Mnet::cfg->{'batch-parse'}) {
            &inf("batch-list batch-parse complete");
            exit;

        # reset parse check flag and restart loop for processing
        } elsif ($parse_check) {
            $parse_check = 0;
            next;
        }

        # clean database, if connection is open
        &database_clean() if defined $Mnet::mdbh;

        # calclulate elapsed time then log and exit if batch-repeat not set
        my $time_elapsed = time - $time_start;
        $time_elapsed = 0 if $Mnet::cfg->{'log-diff'};
        $time_elapsed = sprintf("in %.3f seconds", $time_elapsed);
        &inf("batch-list finished processing $batch_line items $time_elapsed")
            if not $Mnet::cfg->{'batch-repeat'};
        last if not $Mnet::cfg->{'batch-repeat'};

        # calculate sleep time between batch-repeat lops, log progress, sleep
        my $time_sleep = int($Mnet::cfg->{'batch-repeat'} - (time-$time_start));
        $time_sleep = 2 if $time_sleep < 2;
        &inf("batch-list $batch_line items processed $time_elapsed, "
            . "sleeping $time_sleep");
        sleep $time_sleep;

    # continue endless batch-repeat loop
    }

    # finished batch function
    exit;
}



sub batch_file {

# internal: @batch_items = &batch_file
# purpose: read configured batch-list line items into array 
# note: this function is called from the batch function
# note: lines are reformatted if the batch-hosts setting is configured
# note: script will exit with error if batch-hosts encounters problems

    # exit if batch-list config option is not defined
    &dbg("batch_file sub called from " . lc(caller));
    croak "batch_file internal error" if not defined $Mnet::cfg->{'batch-list'};

    # reset batch list
    my @batch_items = ();

    # if batch-repeat set without batch-list return batch object set earlier
    if ($Mnet::batch_object ne "") {
        &dbg("batch_file using current object-name only in batch list");
        return $Mnet::batch_object;
    }

    # attempt to open configured batch-list and read contents
    croak "unable to open batch-list $Mnet::cfg->{'batch-list'}, $!"
        if not open (my $fh, "<$Mnet::cfg->{'batch-list'}");
    croak "unable to read from batch-list $Mnet::cfg->{'batch-list'}"
        if not @batch_items = <$fh>;
    close $fh;

    # reformat batch-list lines if batch-hosts is configured
    if ($Mnet::cfg->{'batch-hosts'}) {
        my @new_batch_items = ();
        my $line_count = 0;
        foreach my $batch_item (@batch_items) {
            $line_count++;
            $batch_item =~ s/#.*$//;
            next if $batch_item !~ /\S/;
            next if $batch_item =~ /^\s*(\S+)\s+localhost/i;
            croak "batch-list batch-hosts line $line_count error"
                if $batch_item !~ /^\s*(\S+)\s+(\S+)/;
            $batch_item = "--object-address $1 --object-name $2\n";
            &dtl("batch_file batch-hosts batch_item $batch_item");
            push @new_batch_items, $batch_item;
        }
        @batch_items = @new_batch_items;
    }

    # log batch file read success and line count
    my $line_count = @batch_items;
    &inf("read $line_count line batch-list $Mnet::cfg->{'batch-list'}");

    # finished batch_file function
    return @batch_items;
}



sub batch_fork {

# internal: &batch_fork
# purpose: fork a batch child process and set handler for zombies
# note: this function is called from the batch function

    # set handler for reaping dead children
    &dbg("batch_fork sub called from " . lc(caller));
    $SIG{CHLD} = \&batch_reaper;

    # attempt to fork child or return error
    my $pid = fork();

    # handle failure to fork
    if (not defined $pid) {
        carp "batch_fork failed to fork child $!";
        sleep 10;
        return;
    }

    # parent process returns
    if ($pid) {
        $Mnet::child_count++;
        return;
    }

    # set script start time for batch child
    $Mnet::start_time = time;

    # set database handle to not be destroyed at exit and clone for child
    if (defined $Mnet::mdbh) {
        $Mnet::mdbh->{InactiveDestroy} = 1;
        undef $Mnet::mdbh;
        &database_mnet();
    }

    # log debug entry for new children
    my $pid_out = $$;
    $pid_out = "0" if $Mnet::cfg->{'log-diff'};
    &dbg("batch_fork child pid $pid_out forked");


    # set pid and parent pid for child process
    $Mnet::ppid = $Mnet::pid;
    $Mnet::pid = $$;

    # finished batch_fork function
    return;
}



sub batch_reaper {

# internal: $SIG{CHLD} = \&batch_reaper
# purpose: signal handler to properly wait on forked child processes
# note: this handler function is set in the batch_fork function

    # handle reaping children, as per perlipc man page
    &dbg("batch_reaper sub called from " . lc(caller));
    while ((my $child = waitpid(-1, &POSIX::WNOHANG)) > 0) {
        $Mnet::child_count--;
        $child = 0 if $Mnet::cfg->{'log-diff'};
        &dbg("batch_reaper child pid $child status $?");
    }
    $SIG{CHLD} = \&batch_reaper;

    # finished batch_reaper function
    return;
}



sub config {

=head2 config function

 \%cfg = &config(\%defaults, \%settings)

This function can be used to retrieve a reference to all config
settings. A referenced hash of default config settings to be merged
into the current configuration may optionally be provided. 

Note that supplied config default settings will not overwrite any
currently defined config settings.

This function would typically be used in modules directly related
to this module allowing default config settings for that module to
be defined.

If the optional settings hash reference is defined then the returned
cfg will be a new copy of the working config settings with the added
settings applied.

Refer to the configuration section of this documentation for more
information.

=cut

    # read function arguments
    &dtl("config sub called from " . lc(caller));
    my ($defaults, $settings) = @_;
    $defaults = {} if not defined $defaults;
    croak "config function defaults arg not a hash reference"
        if ref $defaults ne "HASH";
    croak "config function settings arg not a hash reference"
        if defined $settings and ref $settings ne "HASH";

    # remove first args, up to first dashed arg
    my @temp_args = ();
    my $dash_flag = 0;
    if ("@ARGV" =~ /(^|\s)-(\s|$)/) {
        foreach my $arg (@ARGV) {
            push @temp_args, $arg if $dash_flag;
            $dash_flag = 1 if $arg eq '-';
        }
    } else {
        @temp_args = @ARGV;
    }

    # build quoted command line from passed arguments
    my $cmd_args = "";
    foreach my $arg (@temp_args) {
        if ($arg =~ /^-/) {
            $cmd_args .= "$arg ";
        } elsif ($arg !~ /(^-|')/) {
            $cmd_args .= "'$arg' ";
        } elsif ($arg !~ /(^-|")/) {
            $cmd_args .= "\"$arg\" ";
        }
    }

    # reset all config settings in proper order
    &config_file('conf-etc')
        if defined $Mnet::cfg->{'conf-etc'} and -e $Mnet::cfg->{'conf-etc'};
    &config_line($ENV{'MNET'}, "MNET environment");
    &config_line($cmd_args, "command line");

    # apply default config settings that are not yet defined
    foreach my $option (keys %$defaults) {
        $Mnet::cfg_defaults->{$option} = $defaults->{$option};
        $Mnet::cfg->{$option} = $defaults->{$option};
    }

    # reapply command line arguments
    &config_line($cmd_args, "command line");

    # log script start, if not yet already done
    if (not $Mnet::start_logged) {
        $Mnet::start_logged = time;
        my $date_stamp = lc(localtime);
        $date_stamp = lc(localtime(0)) if 1 or $Mnet::cfg->{'log-diff'};
        &dbg("script $Mnet::cfg->{'mnet-script'} starting $date_stamp");
    }

    # set object-address, or object-name, if the other is not defined
    $Mnet::cfg->{'object-name'} = $Mnet::cfg->{'object-address'}
        if defined $Mnet::cfg->{'object-address'}
        and not defined $Mnet::cfg->{'object-name'};
    $Mnet::cfg->{'object-address'} = $Mnet::cfg->{'object-name'}
        if defined $Mnet::cfg->{'object-name'}
        and not defined $Mnet::cfg->{'object-address'};

    # return temporary copy of config with added settings applied
    if (defined $settings) {
        my $cfg = { %$Mnet::cfg };
        foreach my $option (keys %$settings) {
            $cfg->{$option} = $settings->{$option};
        }
        return $cfg;
    }

    # finished config function, return config reference
    return $Mnet::cfg;
}



sub config_file {

# internal: &config_file($option)
# purpose: parse the formatted file in the specified config option
# note: this function used to parse the conf-file and conf-auth files
# note: the script terminates if there is an error parsing the file 
# note: command line config options are refreshed after each file parse

    # initialize function argument and attempt to open specified file
    &dtl("config_file sub called from " . lc(caller));
    my $option = shift;
    croak "config_file function option arg not defined" if not defined $option;
    if (not defined $Mnet::cfg->{$option}) {
        &dbg("config_file called for unset option $option");
        return;
    }

    my $fh = undef;
    my $file = $Mnet::cfg->{$option};
    &dtl("config_file attempting to open $option file $file");
    croak "$option '$file' $!" if not open ($fh, $file);

    # loop through lines in file, returning on config parsing errors
    my $line_count=0;
    while (<$fh>) {
        my $line=$_;
        $line_count++;
        $line =~ s/#.*//;
        &config_line($line, "$option error: '$file' line $line_count");
    }
    close $fh;

    # finished config_file function
    &dtl("config_file finished reading $option file $file");
    return;
}



sub config_filter {

# internal: $filtered = &config_filter($option)
# purpose: return config value after filtering passwords, etc.
# $option: config setting name to process through filter

    my $option = shift;
    my $filtered = '(undef)';
    $filtered = $Mnet::cfg->{$option} if defined $Mnet::cfg->{$option};
    $filtered = '****' if $option =~ /^$Mnet::cfg->{'log-filter'}/
        and $Mnet::cfg->{$option} ne "0" and $Mnet::cfg->{$option} ne "1"
        and  $Mnet::cfg->{$option} ne "";
    return $filtered;
}



sub config_line {

# internal: $error = &config_line($input, $die, $no_globals)
# purpose: parse $input config line and return any $error messages
# $input: line of config to parse
# $die: set to descriptive text if script should die on parsing errors
# $no_globals: set true to skip *-global options in batch-list
# $error: undef if parsed without errors, or else set to error text
# note: script will terminate with error only if $die is defined
# note: this function is used to parse config files, command args, etc
# note: options without a value will be given a default value of one
# note: any line breaks in $input will be replaced with single spaces
 
    # read arguments and strip input eol, lead/trail spaces and comments
    my ($input, $die, $no_globals) = @_;
    return undef if not defined $input;
    $input =~ s/(\r|\n)+/ /g if 0;
    $input =~ s/(^\s*|#.|\s*$)//g;

    # strip leading dash
    $input =~ s/^-\s+//s;

    # loop to process config settings on input line
    while ($input =~ /\S/) {

        # set config option name from next word or return error
        if ($input !~ s/^\s*-+(\S+)\s*//) {
            my $line_summary=substr($input =~ s/(\S+).*/$1/, 0, 20);
            croak "$die parsing near $1" if defined $die;
            return "parse error near '$1'";
        }
        my $option = $1;

        # output error and skip global options if no globals flag set
        if ($no_globals and $option =~ /^(\S+)-global$/) {
            return "$option not valid in batch-list";
        }

        # set option value to next word, quoted string, or default
        if ($input =~ /^-+\S+/) {
            $Mnet::cfg->{$option} = 1;  # default if next word is an option
        } elsif ($input =~ s/^"([^"]*)"// or $input =~ s/^'([^']*)'//) {
            $Mnet::cfg->{$option} = $1;  # quoted values
        } elsif ($input =~ s/^(\S+)//) {
            $Mnet::cfg->{$option} = $1;  # next word
        } else {
            $Mnet::cfg->{$option} = 1;  # default
        }

        # process specified conf-file settings as they appear
        &config_file('conf-file')
            if $option eq 'conf-file' and defined $Mnet::cfg->{$option};

        # process specified conf-auth settings as they appear
        &config_file('conf-auth')
            if $option eq 'conf-auth' and defined $Mnet::cfg->{'conf-auth'};

    # finish loop to process line options then return
    }

    # finished config_line function
    return undef;
}



sub config_log {

# internal: &config_log
# purpose: output debug log entries for non-default config settings

    # log module name and version numbers
    &version_log;

    # output set config options
    foreach my $option (sort keys %$Mnet::cfg) {
        next if $option =~ /^_/ or defined $Mnet::cfg_defaults->{$option}
            and $Mnet::cfg_defaults->{$option} eq $Mnet::cfg->{$option};
        &dbg("config setting $option = " . &config_filter($option));
    }

    # output default config options 
    foreach my $option (sort keys %$Mnet::cfg) {
        next if $option =~ /^_/ or not defined $Mnet::cfg_defaults->{$option}
            or $Mnet::cfg_defaults->{$option} ne $Mnet::cfg->{$option};
        &dtl("config default $option = " . &config_filter($option));
    }

    # finished config_log function
    return;
}



sub create_dir {

# internal: &create_dir($dir)
# purpose: creates and changes into specified directory or exit with error

    # read input directory
    my $dir = shift;

    # create directory if not present, exit on errors
    if (!-d $dir) {
        &dbg("creating missing data-dir dir $dir");
        eval { mkpath($dir) };
        croak "error creating data-dir dir $dir $@" if $@;
        croak "error verifing creation of data-dir dir $dir" if !-d $dir;
    }

    # attempt to change into specified directory
    croak "error chdir into data-dir dir $dir $!" if not chdir $dir;

    # finished create_dir function
    return;
}



sub database {

=head2 database function

 ($dbh, $error) = &database(\@tables, $db_name)

This function can be used to obtain a handle to the database object
defined by the db-name and other db config options. This function
is only needed if a script or module is working with its own tables
or wants to directly view or manipulate existing data. It is not
advisable to manipulate data maintained by another codebase.

The optional database argument will override the configured db-name
name, if it is supplied. Other db-name options, such as db-host,
will still be in effect.

If there was an error then the output database handle will be an
undefined value and the output error text will be set.

Refer to the perldoc DBI text for information on how to use the
returned database handle.  The DBI and appropriate DBD perl modules
need to be installed for this database function to work.

This function takes an optional array reference. If specified this
array reference will be filled with a list of tables currently in
the database. This can be used to check for tables that need to be
initialized.

Also note that, to avoid the potential for problems, this function
should only be used after an object call so that a child processes
have already forked, this also means not in a module begin block.
Otherwise there could be problems with prepared queries being
duplicated between parent and child processes.

Refer to the database section of this document for more information.

=cut

    # read optional table list reference, validate and initialize
    &dbg("database sub called from " . lc(caller));
    my ($process_tables, $tables, $db_name) = (undef, @_);
    $process_tables = 1 if defined $tables and ref $tables eq 'ARRAY';
    $tables = [] if not defined $tables;
    croak "database function tables arg not an array ref"
        if ref $tables ne "ARRAY";

    # use database name argument
    if (defined $db_name) {
        &dbg("database name $db_name being used instead of db-name setting");

    # return undefined database handle and error if db-name not configured
    } elsif (not defined $Mnet::cfg->{'db-name'}
        or $Mnet::cfg->{'db-name'} !~ /\S/) {
        return (undef, "db-name not set in configuration settings");

    # use db-name if no optional database name argument was supplied
    } else {
        $db_name = $Mnet::cfg->{'db-name'};
        if ($Mnet::cfg->{'db-dbi'} eq 'SQLite'
            and $db_name !~ /\// and defined $Mnet::cfg->{'data-dir'}
            and $Mnet::cfg->{'data-dir'} =~ /\S/) {
            $db_name = "$Mnet::cfg->{'data-dir'}/$Mnet::cfg->{'db-name'}";
            &dbg("database name set to $db_name for sqlite");
        }

    }

    # initialize output database handle
    my $dbh = undef;

    # create handle for database connection, return on errors
    my $connect = "dbi:$Mnet::cfg->{'db-dbi'}:";
    $connect .= "dbname=$db_name;";
    $connect .= "host=$Mnet::cfg->{'db-host'};";
    $connect .= "port=$Mnet::cfg->{'db-port'}";
    my $eval_result = eval {
        require DBI;
        $dbh = DBI->connect($connect,
            $Mnet::cfg->{'db-user'}, $Mnet::cfg->{'db-pass'}, 
            { RaiseError => 0, PrintError => 0, AutoCommit => 1 }
        );
    };
    if (not $eval_result) {
        my $dbi_err = "unknwon";
        $dbi_err = $DBI::errstr if $DBI::errstr;
        return (undef, "error while opening database (dbi $dbi_err)");
    }
    return (undef, "undefined database handle returned") if not defined $dbh;
    return (undef, $@) if $@;

    # set up handling of future database errors using error log
    $dbh->{HandleError} = sub {
        my $text = shift;
        croak "database error $text";
    };

    # obtain referenced list of table names in named database, return on errors
    if ($process_tables) {
        my $db_tables = $dbh->table_info('%', '%', '%', "TABLE");
        return (undef, $dbh->errstr) if $dbh->err;
        foreach my $table (@{$db_tables->fetchall_arrayref([2])}) {
            push @$tables, @$table;
        }
    }

    # finished database function
    &dbg("database connection successfully opened");
    return ($dbh, undef);
}



sub database_clean {

# internal: &database_clean()
# purpose: expire old alert and log table entries then close database

    # return if db-name not set, in a batch child, or db clean set as zero
    &dbg("database_clean sub called from " . lc(caller));
    if (not $Mnet::cfg->{'db-name'} or $Mnet::ppid
        or not $Mnet::cfg->{'db-clean'}) {
        &dbg("database_clean skipped at this time");
        return;
    }

    # open database handle, if not already defined
    &database_mnet if not defined $Mnet::mdbh;

    # obtain list of table names in database
    my $db_tables = $Mnet::mdbh->table_info('%', '%', '%', "TABLE");
    croak "database_clean table query error $Mnet::mdbh->errstr"
         if $Mnet::mdbh->err;

    # process each table, skip tables not named with underscore prefix
    foreach my $table_ref (@{$db_tables->fetchall_arrayref([2])}) {
        my $table = "@$table_ref";
        next if $table !~ /^_/;

        &dtl("database_clean deleting expired $table table entries");
        my $sql_expire = "delete from $table where _expire <= ?";
        my $db_expire = $Mnet::mdbh->prepare($sql_expire);
        $db_expire->execute(time);
        my $rows = 0;
        $rows = $db_expire->rows if $db_expire->rows;
        &dtl("database_clean deleted $rows expired rows from $table table");

    # finished processing tables
    }

    # finished database_clean function
    &dbg("database_clean sub finished");
    return;
}



sub database_mnet {

# internal: &database_mnet()
# purpose: used by the object function to open database and create tables

    # exit with a bug message if db-name not configured
    croak "db-name not specified for database function call"
        if not defined $Mnet::cfg->{'db-name'};

    # create empty list of tables
    my @tables = ();
    
    # attempt to connect to database, get table list, output errors
    my $err = undef;
    ($Mnet::mdbh, $err) = &database(\@tables);
    croak "database open error $err" if defined $err;

    # create alert table if not present
    if (" @tables " !~ /\s+_alert\s/) {
        &log(7, "no_db:dbg", "database_mnet creating missing _alert table");
        my $sql = "create table _alert ( ";
        $sql .= "_time int, ";
        $sql .= "_expire int, ";
        $sql .= "_object varchar, ";
        $sql .= "_script varchar, ";
        $sql .= "_sev smallint, ";
        $sql .= "_text varchar ); ";
        $sql .= "create index _alert_idx1 on _alert (_expire); ";
        $sql .= "create index _alert_idx2 on _alert (_sev, _object); ";
        $sql .= "create index _alert_idx3 on _alert (_object, _script); ";
        $Mnet::mdbh->do($sql);
    }

    # prepare query for new alert entries
    &log(7, "no_db:dtl", "database_mnet preparing alert insert query");
    my $sql_alert_new = "insert into _alert ";
    $sql_alert_new .= "(_time, _object, _script, _sev, _text, _expire) ";
    $sql_alert_new .= "values (?, ?, ?, ?, ?, ?)";
    $Mnet::db_alert_new =  $Mnet::mdbh->prepare($sql_alert_new);

    # prepare query to update alert entries
    &log(7, "no_db:dtl", "database_mnet preparing alert update query");
    my $sql_alert_update = "update _alert set _expire=? where _object=? ";
    $sql_alert_update .= "and _script=? and _sev=? and _text=?";
    $Mnet::db_alert_update = $Mnet::mdbh->prepare($sql_alert_update);

    # prepare query to clear alert entries
    &log(7, "no_db:dtl", "database_mnet preparing alert delete query");
    my $sql_alert_clear = "delete from _alert where _object=? ";
    $sql_alert_clear .= "and _script=? and _sev=? and _text=?";
    $Mnet::db_alert_clear = $Mnet::mdbh->prepare($sql_alert_clear);

    # create log table if not present
    if (" @tables " !~ /\s+_log\s/) {
        &log(7, "no_db:dbg", "database_mnet creating missing _log table");
        my $sql = "create table _log ( ";
        $sql .= "_time int, ";
        $sql .= "_expire int, ";
        $sql .= "_object varchar, ";
        $sql .= "_script varchar, ";
        $sql .= "_sev smallint, ";
        $sql .= "_text varchar, ";
        $sql .= "_type varchar, ";
        $sql .= "_pid int ); ";
        $sql .= "create index _log_idx1 on _log (_expire); ";
        $sql .= "create index _log_idx2 on _log (_time, _sev); ";
        $sql .= "create index _log_idx3 on _log (_object, _time, _sev); ";
        $Mnet::mdbh->do($sql);
    }

    # prepare query for log inserts
    &log(7, "no_db:dtl", "database_mnet preparing log insert query");
    my $sql_log_new = "insert into _log ";
    $sql_log_new .= "(_time, _expire, _object, _script,";
    $sql_log_new .= "  _type, _sev, _text, _pid) ";
    $sql_log_new .= "values (?, ?, ?, ?, ?, ?, ?, ?)";
    $Mnet::db_log_new = $Mnet::mdbh->prepare($sql_log_new);

    # create persist table if not present
    if (" @tables " !~ /\s+_persist\s/) {
        &log(7, "no_db:dbg", "database_mnet creating missing _persist table");
        my $sql = "create table _persist ( ";
        $sql .= "_expire int, ";
        $sql .= "_object varchar, ";
        $sql .= "_script varchar, ";
        $sql .= "_data text ); ";
        $sql .= "create index _persist_idx1 on _alert (_expire);";
        $sql .= "create index _persist_idx2 on _alert (_object, _script);";
        $Mnet::mdbh->do($sql);
    }

    # finished database function
    return $Mnet::mdbh;
}



sub dbg {

=head2 dbg function or method

 &dbg($text)
 $self->dbg($text)

This function will log the debug text with a severity of seven.

=cut

    # log debug text then return
    my ($self, $text) = @_;
    $text = $self if defined $self and not ref $self;
    $text = 'unspecified dbg text' if not defined $text;
    if (ref $self) {
        &log($self, 7, "dbg", $text, lc(caller));
    } else {
        &log(7, "dbg", $text, lc(caller));
    }
    return;
}



sub dtl {

=head2 dtl function or method

 &dtl($text, $sev)
 $self->dtl($text, $sev)

This function will log extra detail debug text with a severity of
seven if the callers <caller>-detail coniguration option is set,
where caller is the name of the module or keyword 'main' for the
main script.

Note that the log-detail-all config setting will enable all extra
detail messages from all modules and the main script.

The severity argument is optional and can be used to log detail
messages with something beside a debug severity of seven.

=cut

    # log detail debug text then return
    my ($self, $text, $sev) = @_;
    $text = $self if defined $self and not ref $self;
    $text = 'unspecified dtl text' if not defined $text;
    $sev = 7 if not defined $sev or $sev !~ /^[0..7]$/;
    if (ref $self) {
        &log($self, $sev, "dtl", $text, lc(caller));
    } else {
        &log($sev, "dtl", $text, lc(caller));
    }
    return;

}



sub dump {

=head2 dump function

 &dump($title, $variable)

This function will output a dump of the input variable as a series
of detail debug log entries.

The default log-filter setting will be used to recogize password
related settings and not show those passwords in the output.

=cut

    # read inputs, error if title is missing
    my ($title, $variable) = @_;
    croak "dump call missing title arg" if not $title;

    # return if caller detail is not set
    my $caller = lc(caller);
    $caller =~ s/^\S+:://;
    return if not $Mnet::cfg->{'log-detail-all'}
        and not $Mnet::cfg->{"${caller}-detail"};

    # output dump, filter passwords
    my $filtered = $Mnet::cfg->{'log-filter'};
    foreach my $line (split(/\n/, Dumper($variable))) {
        $line =~ s/^(\s*)'($filtered\S*)' => '.+'/$1'$2' => '****'/s;
        &log(7, 'dtl', "dump $title: $line", lc(caller));
    }

    # finished dump function
    return;
}



sub inf {

=head2 inf function or method

 &inf($text)
 $self->inf($text)

This function will log the info text with a severity of six.

=cut

    # log info text then return
    my ($self, $text) = @_;
    $text = $self if defined $self and not ref $self;
    $text = 'unspecified inf text' if not defined $text;
    if (ref $self) {
        $self->log(6, "inf", $text, lc(caller));
    } else {
        &log(6, "inf", $text, lc(caller));
    }
    return;
}



sub input {

=head2 input function or method

 $input = &input($option, $hide, $noverify, $noset)
 $input = &input({}, $option, $hide, $noverify, $noset)
 $input = $self->input($option, $hide, $noverify, $noset)

This function requires the option argument specifying the config
setting that will store the input value. An optional hide flag
is used to determine if user input echo should be disabled.

The return value will normally be the value input by the user, or
the already configured option value. The return value could be
undefined otherwise.

The optional noverify flag is used when the hide flag is also set
to suppress input verification re-entry and leave the option in
the global config unchanged. This is useful for entry of rsa
token passcodes that change every time.

This function will die with an error if the conf-noinput option is
set true. This can be used in batch jobs to prevent an indefinate
wait for terminal input.

An input call before an object function call will queue until the
first object initialization. This allows batch mode input. Prompts
for input are made in the order that they are defined. After the
first object call this function prompts terminal standard error.

=cut

    # initialize function arguments and return if option already defined
    my $self = shift if defined $_[0] and ref $_[0];
    my ($option, $hide, $noverify) = @_;
    croak "input call missing option arg" if not defined $option;

    # if called before object initialization then set as input option and return
    if (not $Mnet::pid) {
        my $count = sprintf("%03d", $Mnet::input_count);
        $Mnet::inputs{"$count $option"} = $hide;    
        $Mnet::input_count++;
        return undef;
    }

    # die if called with conf-noinput in effect
    croak "input call while conf-noinput in effect"
        if $Mnet::cfg->{'conf-noinput'};

    # remove sort counter from name of config option to input
    $option =~ s/^\d+\s+//;

    # skip option input if set in config or zeroed out
    if (defined $Mnet::cfg->{$option} and $Mnet::cfg->{$option} ne "1") {
        &dbg("suppress $option input, use config value");
        return $Mnet::cfg->{$option};
    }

    # check if input associated with a batch mode switch and skip if not set
    my $prefix = $1 if $option =~ /^(\S+)-/;
    if (defined $prefix and not defined $Mnet::cfg->{'object-name'}
        and defined $Mnet::cfg->{$prefix."-batch"}
        and not $Mnet::cfg->{$prefix."-batch"}) {
        &dbg("skip $option input, no ${prefix}-batch set");
        return undef;
    }

    # set current object name, or batch indicator, for prompts
    my $object = &prepend_object($self, '');
    $object = $Mnet::cfg->{'object-name'} . " "
        if not defined $object or $object !~ /\S/
        and defined $Mnet::cfg->{'object-name'};
    $object = "batch-list "
        if not defined $object or $object !~ /\S/;

    # output log message
    &dbg("input $object $option from terminal");

    # initialize input variables, echo suppression and verification loop
    my ($input1, $input2) = ("", "");
    system("/bin/stty -echo 2>&1") if $hide;
    while (1) {

        # first prompt to terminal for input using read command
        syswrite STDERR, "Enter ${object}$option: ";
        $input1 = <STDIN>;
        $input1 = "" if not defined $input1;
        chomp $input1;
        syswrite STDERR, "\n" if $hide;

        # second prompt to verify input, repeat loop if not verified
        if ($hide and not $noverify) {
            syswrite STDERR, "Verify ${object}$option: ";
            $input2 = <STDIN>;
            $input2 = "" if not defined $input2;
            chomp $input2;
            syswrite STDERR, "\n" if $hide;
            if ($input1 ne $input2) {
                syswrite STDERR, "Verification error...!\n";
                next;
            }        
        }

        # break out of verification loop since everything is ok
        last;

    # continue input loop verification loop
    }

    # restore echo, set specified config option
    system("/bin/stty echo 2>&1") if $hide;
    $Mnet::cfg->{$option} = $input1 if not $noverify;

    # finished input function
    return $input1;
}



sub log {

=head2 log function or method

 &log([$sev,] [$type,] $text [,$caller [,$object [,$script]]])
 $self->log([$sev,] [$type,] $text [,$caller [,$object [,$script]]])

The log function is used to process log entries. Log entries are 
processed if they match the configured log-level level. Log entries
are sent to standard output if the log-stdout config option is
enabled. They are sent to the database if db-name is set.

All log entries are processed for the log-stderr output. No matter
what the log-level setting is all log entries will be sent to the
the terminal standard error output if log-stderr is configured.

The script will terminate with an error if the log function is
called before the object function is invoked.

If a severity argument is not specified a default severity of 5 will
be used for the entry. If a type argument is not specified a default
type of 'log' will be used.

If the type argument is set to 'dtl' then the *-detail flag will be
honored for the calling module or script. This means the log message
will not be output to stdout or the database unless the appropriate
detail setting is enabled.

The log function will always return a value of undefined.

=cut

    # init defaults and arguments
    my ($self, $sev, $type, $text) = (undef, 5, 'log', 'unspecified log text');
    my $caller = lc(caller);
    my $script = $Mnet::cfg->{'mnet-script'};
    my $object = $Mnet::cfg->{'object-name'};
    $self = shift if defined $_[0] and ref $_[0];
    $sev = shift if defined $_[0] and $_[0] =~ /^[0-8]$/;
    $type = shift if defined $_[1];
    $text = shift if defined $_[0];
    $caller = lc(shift) if defined $_[0];
    $object = shift if defined $_[0];
    $script = shift if defined $_[0];
    $caller =~ s/^Mnet:.*://i;

    # override caller for log entry, if set in config
    $caller = $Mnet::cfg->{'_mnet-caller'}
        if $Mnet::cfg->{'_mnet-caller'};

    # return if error logging disabled and severity doesn't match
    return undef if not $Mnet::cfg->{'log-stderr'}
        and $sev > $Mnet::cfg->{'log-level'};

    # set no_db for no loggin to database if flag set in log type field
    my $no_db = 0;
    $no_db = 1 if $type =~ s/^no_db://i;

    # remove whitespace, prepend object-address, format time, set terminal text
    $text =~ s/(^\s+|\s+$)//g;
    $text =~ s/(\s\s+|\r?\n\r?|\r)/ /g if $sev < 7;
    my $log_text = &prepend_object($self, $text);
    if ($sev > 5 or $type =~ /^(die|wrn)$/i) {
        $log_text = "$caller $log_text" if $caller and $type !~ /^(alr|clr)/i;
    }
    my $stime = $1 if localtime =~ /(\d\d:\d\d:\d\d)/
        or croak "time parse error";
    if (defined $Mnet::cfg->{'batch-list'} or $Mnet::cfg->{'log-long'}) {
        if (defined $object) {
            $log_text = "$object: $log_text";
        } else {
            $log_text = ": $log_text";
        }
    }
    $type = uc($type) if $sev < 5 and $type ne 'clear';
    $log_text = "$type $sev $stime $log_text";

    # accumulate log error debug text if configured and truncate if too much
    if ($Mnet::cfg->{'log-stderr'}) {
        $Mnet::log_stderr .= "$log_text\n";
        if (length($Mnet::log_stderr)
            > $Mnet::cfg->{'log-stderr'} * 1024 * 1024) {
            my $delim = '... log-stderr debug output truncated ...';
            my $cut = int($Mnet::cfg->{'log-stderr'} * 1024 * 1024 / 3) + 1;
            $Mnet::log_stderr = substr($Mnet::log_stderr, 0, $cut)
                . "\n-$delim-\n" . substr($Mnet::log_stderr, -$cut);
            $Mnet::log_stderr =~ s/([^\n]+)\n(\Q-$delim-\E)/$2/;
            $Mnet::log_stderr =~ s/(\Q-$delim-\E)\n([^\n]+)/$1/;
            $Mnet::log_stderr =~ s/\Q-$delim-\E/$delim/;
        }
    }

    # accumulate log summary, if configured
    if ($Mnet::cfg->{'log-summary'} and $sev < 5) {
        $Mnet::log_summary .= "$log_text\n";
    }

    # return if log-silent is set
    return undef if $Mnet::cfg->{'log-silent'};

    # return if severity not a match against configured log-level level
    return undef if $sev > $Mnet::cfg->{'log-level'};

    # return if log-quiet set and not a regular log entry
    return undef if $type =~ /^(inf|dbg|dtl)$/ and $Mnet::cfg->{'log-quiet'};

    # return for detailed debug type if caller, or all, detail not configured
    return undef if $type eq "dtl" and not $Mnet::cfg->{'log-detail-all'}
        and not $Mnet::cfg->{"${caller}-detail"};

    # rewrite log text with time zeroed out if log-diff configured
    $log_text =~ s/^(\S+ \d) \d\d:\d\d:\d\d /$1 00:00:00 /
        if $Mnet::cfg->{'log-diff'};

    # output log entry to standard output per configuration
    syswrite STDOUT, "$log_text\n" if $Mnet::cfg->{'log-stdout'};

    # set expire timestamp for log database entry
    my $expire = int(time + $Mnet::cfg->{'db-expire'} * 86400);

    # output log entry to database if db handle is configured, with pid
    my $time = sprintf "%.6f", time;
    $object = '' if not defined $object;
    $Mnet::db_log_new->execute($time, $expire,
        $object, $script, $type, $sev, $text, $$)
        if $Mnet::mdbh and not $no_db;

    # finished log function
    return undef;
}



sub object {

=head2 object function

 \%cfg = &object(\%defaults)

The object function is used to start processing a configured
object, or the next object in batch mode. The script will exit if
all object processing is complete in batch mode or if no
object-name name or object-address is defined.

A reference to the config setting hash is returned from this
function. This reference can be used in the invoking script to view
and modify config settings tracked by this module.

If the batch-list config option is set then this function call
starts batch mode operation where the necessary child processes are
forked. In batch mode each child processes inherits config settings
from a line in the batch file. In the invoking script the forking
happens at the object function call and all children inherit the
state of the script before the fork. Modules that are not thread
safe should be invoked after the forking object call.

=cut

    # read function arguments
    &dbg("object sub called from " . lc(caller));
    my $defaults = shift;

    # ensure one object call per script, initialize config settings
    croak "multiple object calls" if $Mnet::cfg->{'_mnet-object-flag'};
    foreach my $option (keys %$Mnet::cfg_defaults) {
        $Mnet::cfg->{$option} = $Mnet::cfg_defaults->{$option}
            if not defined $Mnet::cfg->{$option};
    }
    $Mnet::cfg->{'_mnet-object-flag'} = 1;
    &config($defaults);

    # set current pid, enabling exported functions after config processed
    $Mnet::pid = $$;

    # create and cd into data-dir dir, if configured
    if ($Mnet::cfg->{'data-dir'}) {
        &dbg("check data-dir dir $Mnet::cfg->{'data-dir'}");
        &create_dir($Mnet::cfg->{'data-dir'});
    }

    # attempt to open a database connection, if configured
    &database_mnet() if defined $Mnet::cfg->{'db-name'};

    # error if no object or batch file specified
    croak "object-name, object-address or batch-list not specified"
        if not defined $Mnet::cfg->{'object-name'}
        and not defined $Mnet::cfg->{'object-address'}
        and not defined $Mnet::cfg->{'batch-list'};

    # error if both object and batch file are specified
    croak "object-name and batch-list cannot both be specified"
        if defined $Mnet::cfg->{'object-name'}
        and defined $Mnet::cfg->{'batch-list'};

    # set dummy batch-list for object-name if batch-repeat set and no batch-list
    if ($Mnet::cfg->{'batch-repeat'}
        and not defined $Mnet::cfg->{'batch-list'}) {
        &dbg("setting batch-list for object-name with batch-repeat");
        $Mnet::batch_object = "--object-name $Mnet::cfg->{'object-name'} ";
        $Mnet::batch_object
            .= "--object-address $Mnet::cfg->{'object-address'}";
        $Mnet::cfg->{'batch-list'} = "($Mnet::cfg->{'object-name'})";
        delete $Mnet::cfg->{'object-name'};
        delete $Mnet::cfg->{'object-address'};
    }

    # in batch mode output config settings, handle inputs and start parent fork
    if ($Mnet::cfg->{'batch-list'}) {
        &config_log;
        foreach my $option (sort keys %Mnet::inputs) {
            &input($option, $Mnet::inputs{$option});
        }
        &batch if $Mnet::cfg->{'batch-list'} and not $Mnet::ppid;
    }

    # set object address from object name if not defined
    $Mnet::cfg->{'object-address'} = $Mnet::cfg->{'object-name'}
        if defined $Mnet::cfg->{'object-name'}
        and not defined $Mnet::cfg->{'object-address'};

    # set object name from object address if not defined
    $Mnet::cfg->{'object-name'} = $Mnet::cfg->{'object-address'}
        if defined $Mnet::cfg->{'object-address'}
        and not defined $Mnet::cfg->{'object-name'};

    # create and cd into object-name subdirectory, if data-dir was specified
    if ($Mnet::cfg->{'data-dir'}) {
        &dbg("check for object subdirectory in $Mnet::cfg->{'data-dir'}");
        &create_dir($Mnet::cfg->{'object-name'});
    }

    # output config setting debug log entries
    &config_log;

    # process input items if not in batch mode
    if (not $Mnet::cfg->{'batch-list'}) {
        foreach my $option (sort keys %Mnet::inputs) {
            &input($option, $Mnet::inputs{$option});
        }
    }

    # output log message that object has been initiated
    my $pid_out = $$;
    $pid_out = "0" if $Mnet::cfg->{'log-diff'};
    &inf("object $Mnet::cfg->{'object-name'} initiated, pid $pid_out")
        if $Mnet::cfg->{'object-name'};

    # finished object function, return config
    return $Mnet::cfg;
}



sub persist {

=head2 persist function

 (\%persist_old, \%persist_new) = &persist($subkey)

This function will return hash references to the persist data from
the prior instance of script execution for this object, and data
that will be saved after current script execution.

The persist hash references returned may optionally be used to
access data from a prior instance of script execution for an object
and to update that data during the current script execution. These
hashes will initially be empty and data is only saved at exit when
the db-name config option is set. The persist_old hash will be set
with data from the last script execution for the current object and
the persist_new hash is intialized as empty and needs to be filled
with data that will be saved at script exit.

The subkey argument is optional. If a subkey is supplied then the
hash references will point to a subset of the script object data
using the key $subkey prefixed with an underscore character. This
can be used by modules that need to store persistant data, in order
to avoid namespace collisions.

Note that old persistant data is read from the database during the
object call in the main script. Modules should not use this function
to retrieve a reference to the persist old data during their begin
block, as that reference will be overwritten when when the old data
is read during the object call.

=cut

    # read optional input subkey
    my $subkey = shift;

    # retrieve persistant data for object from database
    &persist_read;

    # set hash references to old and new persist data
    &dbg("persist function setting old and new hash references");
    my $persist_old = $Mnet::persist_old;
    my $persist_new = $Mnet::persist_new;

    # set hash references to subkey, if defined
    if (defined $subkey) {
        &dbg("persist function setting hash references to subkey _$subkey");
        $Mnet::persist_old->{"_$subkey"} = {}
            if not exists $Mnet::persist_old->{"_$subkey"};
        $persist_old = $Mnet::persist_old->{"_$subkey"};
        $Mnet::persist_new->{"_$subkey"} = {}
            if not exists $Mnet::persist_new->{"_$subkey"};
        $persist_new = $Mnet::persist_new->{"_$subkey"};
    }

    # finished persist function
    return ($persist_old, $persist_new);
}



sub persist_read {

# internal: &persist_read
# note: read persistant data for current object

    # return if db-persist is clear or mnet database is not open
    if (defined $Mnet::cfg->{'db-persist'}
        and not $Mnet::cfg->{'db-persist'}) {
        &dbg("db-persist set false to suppress reading persist data");
        return;
    } elsif (not $Mnet::mdbh) {
        &dbg("no db-name specified for reading persist data");
        return;
    }

    # attempt ot read persist data from database
    &dbg("attempting to read persist data");
    my $sql_persist_read = "select _data from _persist ";
    $sql_persist_read .= "where _object = ? and _script = ?";
    my $db_persist_read = $Mnet::mdbh->selectall_arrayref($sql_persist_read,
        {}, $Mnet::cfg->{'object-name'}, $Mnet::cfg->{'mnet-script'});

    # return if no persist data found
    if (not @$db_persist_read) {
        &dbg("no persist data found");
        return;
    }

    # restore persist data from database
    my $persist_data = $$db_persist_read[0];
    my $persist_dump = $$persist_data[0];
    my $VAR1;
    $VAR1 = eval $persist_dump;
    $Mnet::persist_old = $VAR1;

    # output perist dump data in debug
    foreach my $line (split(/\n/, $persist_dump)) {
        &dbg("persist_old: $line");
    }

    # debug log after persist data was restored
    &dbg("read persist data with " . length($persist_dump) . " bytes");

    # finished persist_read function
    return;
}



sub persist_write {

# internal: &persist_write
# note: write persistant data for current object

    # create dump of new persist data, or return if no persist data exists
    my $persist_dump = "";
    if (defined $Mnet::persist_old and %$Mnet::persist_old
        or defined $Mnet::persist_new and %$Mnet::persist_new) {
        &dbg("preparing new persist hash data");
        $persist_dump = Dumper($Mnet::persist_new);
    } else {
        &dbg("no new persist data to update");
        return;
    }

    # output perist dump data in debug
    foreach my $line (split(/\n/, $persist_dump)) {
        &dbg("persist_new: $line");
    }

    # return if db-persist is clear or mnet database is not open
    if (defined $Mnet::cfg->{'db-persist'}
        and not $Mnet::cfg->{'db-persist'}) {
        &dbg("db-persist set false to suppress writing persist data");
        return;
    } elsif (not $Mnet::mdbh) {
        &dbg("no db-name specified for writing persist data");
        return;
    }

    # set ten day expire time for saved persist data
    my $expire_time = int(time + $Mnet::cfg->{'db-expire'} * 86400);
    
    # prepare query to update persist entries
    my $sql_persist_update = "update _persist set _data=?, _expire=? ";
    $sql_persist_update .= "where _object=? and _script=?";
    my $db_persist_update = $Mnet::mdbh->prepare($sql_persist_update);

    # update persist data entry
    &dbg("updating persist data with " . length($persist_dump) . " bytes");
    my $result = $db_persist_update->execute($persist_dump, $expire_time,
        $Mnet::cfg->{'object-name'}, $Mnet::cfg->{'mnet-script'});

    # update was successful
    if (defined $result and $result eq "1") {
        &dbg("persist data updated");

    # or else create new persist data entry
    } else {

        # we will need to attempt to create a new persist entry
        &dbg("attempting to create new persist data entry");

        # prepare query for new persist entry
        my $sql_persist_new = "insert into _persist ";
        $sql_persist_new .= "(_data, _expire, _object, _script) ";
        $sql_persist_new .= "values (?, ?, ?, ?)";
        &dbg("sql: $sql_persist_new");
        my $db_persist_new =  $Mnet::mdbh->prepare($sql_persist_new);

        # execute new persist entry query, warn with error on fail
        my $result = $db_persist_new->execute($persist_dump, $expire_time,
            $Mnet::cfg->{'object-name'}, $Mnet::cfg->{'mnet-script'});

        # output results of persist data creation attempt
        if (defined $result and $result eq "1") {
            &dbg("new persist data entry created");
        } else {
            my $err = "unknown error";
            $err = $Mnet::mdbh->errstr if $Mnet::mdbh->errstr;
            carp "unable to write persist data, $err";
        }
    }
            
    # finished persist_write function
    return;
}



sub prepend_object {

# internal: $output = &prepend_object($text)
# internal: $output = $self->prepend_object($text)
# $text = text to optionally have object-address prepended
# $output = output text with optional object-address prepended
# note: object-address will be taken from mnet cfg then self

    my ($self, $text) = @_;
    $text = $self if not defined $text and defined $self and not ref $self;
    $text = '' if not defined $text;
    my $output = $text;
    if (defined $self and ref $self) {
        if (not defined $Mnet::cfg->{'object-address'}) {
            $output = "(no-object) $text";
        } elsif (defined $self->{'object-address'}
            and $self->{'object-address'} ne $Mnet::cfg->{'object-address'}) {
            $output = "to " . $self->{'object-address'} . " $text"
        }
    }
    return $output;
}



sub version_log {

# internal: &version_log
# purpose: used to output version info for script and modules
# note: global versions_logged flag used to indicate completion

    # log module name and version numbers
    return if $Mnet::versions_logged;
    foreach my $option (sort keys %$Mnet::cfg) {
        next if $option !~ /^(\S+)-version$/;
        &dbg("module $1 version $Mnet::cfg->{$option}");
    }
    $Mnet::versions_logged = 1;
    return;
}



# module end tasks
END {

    # re-enable term output, in case it is disabled
    system("/bin/stty echo 2>&1");

    # disable signal handlers
    local $SIG{INT} = 'IGNORE';
    local $SIG{TERM} = 'IGNORE';

    # log call to mnet end block, and error status
    &Mnet::dbg("module end code block called from " . lc(caller));
    &Mnet::dbg("end code block mnet error = $Mnet::error");

    # log version numbers if necessary
    &Mnet::version_log;

    # log batch repeat, if configured
    &Mnet::inf("batch mode exiting")
        if $Mnet::cfg->{'batch-list'} and not $Mnet::ppid;

    # update persistant object data
    &Mnet::persist_write;

    # alert in database for normal poll with a child in batch repeat mode
    if ($Mnet::cfg->{'batch-repeat'} and not $Mnet::error
        and $Mnet::ppid and not $Mnet::sig_int and not $Mnet::sig_term) {
        &Mnet::alert(7, "mnet batch repeat script normal poll, ".lc(localtime));
    }

    # process alerts
    &Mnet::alert_update();

    # clean database if not a batch child process
    &Mnet::database_clean if $Mnet::cfg->{'db-name'} and not $Mnet::ppid;

    # set elapsed time and exit status message
    my $elapsed = time - $Mnet::start_time;
    $elapsed = 0 if $Mnet::cfg->{'log-diff'};
    my $exit = sprintf("%.3f seconds elapsed", $elapsed);
    if ($Mnet::sig_int) {
        $exit = "script $Mnet::cfg->{'mnet-script'} interrupt sig exit, $exit";
    } elsif ($Mnet::sig_term) {
        $exit = "script $Mnet::cfg->{'mnet-script'} terminate sig exit, $exit";
    } elsif ($Mnet::error) {
        $exit = "script $Mnet::cfg->{'mnet-script'} error exit, $exit";
    } else {
        $exit = "script $Mnet::cfg->{'mnet-script'} clean exit, $exit";
    }

    # remove log summary if running with log-diff set
    $Mnet::log_summary = "" if $Mnet::cfg->{'log-diff'};

    # if mnet error is set then output debug logs to stderr
    if ($Mnet::error and $Mnet::cfg->{'log-stderr'}) {

        # add config settings to debug
        foreach my $option (sort keys %$Mnet::cfg) {
            my $value = &config_filter($option);
            &Mnet::dbg("config at exit $option = $value");
        }

        # create error debug output
        &Mnet::dbg("creating log-stderr debug output");
        $Mnet::log_stderr =~ s/creating( log-stderr debug output)$/finished$1/;
        &Mnet::inf("sending log-stderr debug output to terminal stderr")
            if not $Mnet::cfg->{'log-silent'};
        &Mnet::inf("saving error log output to $Mnet::cfg->{'mnet-script'}.err")
            if $Mnet::cfg->{'data-dir'};
        &Mnet::inf($exit);

        # output error debug logs to stderr if not running silent
        if (not $Mnet::cfg->{'log-silent'}) {
            syswrite STDOUT, "\n$Mnet::log_summary\n" if $Mnet::log_summary;
            syswrite STDERR, "*" x 79 . "\n";
            syswrite STDERR, "$Mnet::log_stderr\n";
            syswrite STDERR, "$Mnet::log_summary\n" if $Mnet::log_summary;
        }

        # output error debug logs to script file if data-dir dir is set
        if ($Mnet::cfg->{'data-dir'}) {
            if (open(my $fh, ">$Mnet::cfg->{'mnet-script'}.err")) {
                syswrite $fh, "$Mnet::log_stderr\n";
                syswrite $fh, "$Mnet::log_summary\n" if $Mnet::log_summary;
                close $fh;
            }
        }

    # handle end of script output with no mnet error nor log-stderr set
    } else {
        &Mnet::inf($exit);
        syswrite STDOUT, "\n$Mnet::log_summary\n" if $Mnet::log_summary;

    # finished handling end of script output
    }

    # disconnect from database if not a batch child process
    $Mnet::mdbh->disconnect if defined $Mnet::mdbh and not $Mnet::ppid;

# finished end block
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.

Mnet is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/

=head1 AUTHOR

The Mnet perl module has been created and is maintained by Mike Menza.
Mike can be reached via email at mikemenza@menzascripting.com or
mmenza@cpan.org.

Send an email to mnet-announce+subscribe@googlegroups.com to receive
update, problem, and security announcements for the Mnet network perl
scripting module.

Visit http://menzascripting.com to download the latest release of
the Mnet network automation scripting perl module or access the latest
documentation.

=head1 SEE ALSO

Mnet::Cygwin, Mnet::FAQ, Mnet::Support, Mnet::Tutorial

Mnet::Expect, Mnet::IP, Mnet::Model, Mnet::HPNA,
Mnet::Ping, Mnet::Poll, Mnet::Poll::Cisco, Mnet::Report,
Mnet::RRD, Mnet::Silent, Mnet::SNMP

Mnet::script::Mnet-config-backup, Mnet::script::Mnet-config-push,
Mnet::script::Mnet-poll-objects, Mnet::script::Mnet-web-mojo

=cut



# normal package return
1;

