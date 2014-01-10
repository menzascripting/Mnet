package Mnet::Model;

=head1 NAME

Mnet::Model - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

Usage example:

 use Mnet;
 use Mnet::Model;
 my $cfg = &config({
     'db-name' => 'mnet.db',
     'data-dir => '/var/mnet'
 });
 my $logs = &log_query({'object' => 'router1'});
 my $alerts = &alert_query({'object' => 'router1', 'sev' => '6'});
 my $objects = &object_query({'object' => 'router*'});
 my $object = &object_info({'object' => 'router1'});
    
Refer to the documentation for each function below on valid input
options and output elements.

=head1 DESCRIPTION

This module is used to retrieve data from an db-name database and/or
and data-dir directory.

The data returned from each function can be used by other scripts.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --data-dir </path/dir>     specify directory for object information
 --db-name <database>       database to connect to, default not set
 --model-detail             enable for extra expect debug detail
 --model-version            set at compilation to build number

=cut

# modules used
use warnings;
use strict;
use Carp;
use Exporter;
use Mnet;
use Time::Local;

# export module function names
our @ISA = qw( Exporter );
our @EXPORT=qw(
    alert_query file_data log_query object_info object_query
);


# module initialization
BEGIN {

    # initialze default config settings
    our $cfg = &Mnet::config({
        'model-version'     => '+++VERSION+++',
    });

# end of module initialization
}



sub alert_query {

=head2 alert_query function

 \@output = &alert_query(\%input)

Outputs a list of alert entries matching input specifications.

The input hash reference may contain any combination of the following
keys that will be used to return matching alerts:

 object      supports wildcard asterisk and question mark
 script      supports wildcard asterisk and question mark
 sev         maximum severity 1-7 to return, default 5
 text        supports wildcard asterisk and question mark
 info        search on info field, which is "sev ?: text"
 limit       integer for maximum rows to return
 page        paging with limit, positive int, default 1

The array reference output will contain zero or more rows resulting
from the input alert query. Each element in this output array is a
hash reference containing the following keys from the alert database:

 time        unix timestamp alert was generated
 object      object name associated with alert
 script      script name associated with alert
 sev         severity of alert, from 1-7
 text        text associated with alert
 expire      unxi timestamp alert will expire
 dtime       display timestamp, mmm-dd hh:mm
 info        defined as combination "sev ?: text"
 age         age of alert, in minutes
 color_age   hex rgb value
 color_sev   hex rgb value

=cut 

    # read input hash reference
    my $input = shift;
    croak "alert_query missing input hash ref arg"
        if not $input or ref $input ne 'HASH';
    &dtl("alert_query sub called from " . lc(caller));

    # initialize output array reference
    my $output = [];

    # parse inputs to make ready for sql
    my $object = &parse_wildcard($input->{'object'});
    my $script = &parse_wildcard($input->{'script'});

    # set default severity, and verify if input
    my $sev = $input->{'sev'};
    $sev = 5 if not defined $sev;
    if ($sev !~ /^\d+$/) {
        carp "alert_query reset invalid input sev $sev to sev=5";
        $sev = 5;
    }

    # parse text and info fields
    my $text =  &parse_wildcard($input->{'text'});
    my $info = &parse_wildcard($input->{'info'});

    # validate limit is numeric, if set in input
    my $limit = $input->{'limit'};
    if (defined $limit and $limit !~ /^\d+$/) {
        carp "alert_query reset invalid input limit $limit to 1024";
        $limit = 1024;
    }

    # validate input page number to display, set to 1 if not defined
    my $page = $input->{'page'};
    $page = 1 if not defined $page;
    if (defined $page and $page !~ /^\d+$/) {
        carp "alert_query reset invalid input page $page to 1";
        $page = 1;
    }
    
    # prepare sql command and parameters, use security level
    my $sql_cmd = "select _time, _object, _script, _sev, _text, _expire ";
    $sql_cmd .= "from _alert where _sev <= ?";
    my @sql_params = ($sev);

    # add object clause, if object is set
    if (defined $object and $object ne '') {
        $sql_cmd .= " and _object like ? escape '!'";
        push @sql_params, "\%$object\%";
    }

    # add script clause, if script is set
    if (defined $script and $script ne '') {
        $sql_cmd .= " and _script like ? escape '!'";
        push @sql_params, "\%$script\%";
    }

    # add info clause, if info is set
    if (defined $info and $info ne "") {
        $sql_cmd .= " and (' sev ' || _sev || ': ' ";
        $sql_cmd .= "|| _text) like ? escape '!'";
        push @sql_params, "\%$info\%";
    }

    # sort order for resulting alerts
    $sql_cmd .= " order by _sev asc, _time desc, _object asc, _text asc";

    # add limit clause, if limit is set
    if (defined $limit and $limit ne '' and $limit ne '0') {
        my $page_offset = ($page - 1) * $limit;
        $sql_cmd .= " limit $limit offset $page_offset";
    }

    # debug output of sql command
    &dtl("alert_query sql $sql_cmd (@sql_params)");

    # open database connection and execute query
    &dtl("alert_query opening database connection");
    my ($mnet_dbh, $err_dbh) = &database();
    croak "database_error $err_dbh" if defined $err_dbh;
    $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };

    # attempt to read alert data from database
    &dtl("alert_query reading alert data from database");
    my $db_alerts = $mnet_dbh->selectall_arrayref($sql_cmd, {}, @sql_params);

    # loop through alerts returned from database and add to output list
    foreach my $db_alert (@$db_alerts) {

        # read fields for current alert
        my ($time, $object, $script, $sev, $text, $expire) = @$db_alert;

        # create shortened alert time and prepare for timelocal call
        my $dtime = lc(localtime($time));
        $dtime = "$1 $2 $3" if $dtime =~ /(\S+)\s+(\d+)\s+(\d+:\d+)/;
        $dtime = "$1 0$2 $3" if $dtime =~ /(\S+)\s(\d)\s+(\d+:\d+)/;

        # calculate the age, in minutes, of current alert
        my $age = int((time - $time) / 60);

        # prepare info output field
        my $info = "sev $sev: $text";

        # set age color based on age of alert
        my $color_age = &color_age($age);

        # set severity color based on alert severity
        my $color_sev = &color_severity($sev);

        # add current alert info to output array ref
        push @{$output}, {
            'color_age' => $color_age,
            'color_sev' => $color_sev,
            'dtime'     => $dtime,
            'expire'    => $expire,
            'info'      => $info,
            'object'    => $object,
            'script'    => $script,
            'sev'       => $sev,
            'text'      => $text,
            'time'      => $time,
        };

    # continue looping through alerts returned from database
    }

    # finished alert_query function
    &dtl("alert_query function finishing");
    return $output;
}



sub color_age {

# internal: $color = &color_age($age)
# purpose: output rgb hex color for input age in minutes

    # read input severity
    my $age = shift;

    # set age color based on age of alert
    my $color = 'ff0000';                    # age < 5 minutes, red
    $color = 'ffa500' if $age > 6;           # age < 21 minutes, orange
    $color = 'ffff00' if $age > 21;          # age < 91 minutes, yellow
    $color = 'faafbe' if $age > 90;          # age < 4 hours, pink     
    $color = 'e3e4fa' if $age > 4 * 60;      # age < 3 days, lavender
    $color = 'ffffff' if $age > 3 * 60 * 24; # age > 3 days, white

    # finished color_age function
    return $color;
}



sub color_severity {

# internal: $color = &color_severity($sev)
# purpose: output rgb hex color for input severity

    # read input severity
    my $sev = shift;

    # assign output rgb hex value
    my $color = 'ffffff';           # sev 7+6, white
    $color = 'e3e4fa' if $sev < 6;  # sev 5, lavender
    $color = 'faafbe' if $sev < 5;  # sev 4, pink
    $color = 'ffff00' if $sev < 4;  # sev 3, yellow
    $color = 'ffa500' if $sev < 3;  # sev 2, orange
    $color = 'ff0000' if $sev < 2;  # sev 1+0, red

    # finished color_severity function
    return $color;
}



sub file_data {

=head2 file_data function

 $data = &file_data(\%input)

Outputs data contained in specified object file.

The input hash reference must contain the object and file keys,
and may contain any combination of the other keys:

 object      name of the object to pull information for
 file        file name to query data for

The data-dir directory must be set.

=cut

    # read input hash reference
    my $input = shift;
    croak "file_data missing input hash ref arg"
        if not $input or ref $input ne 'HASH';
    &dtl("file_data sub called from " . lc(caller));

    # require data-dir directory to be set
    croak "file_data requires data-dir directory to be configured"
        if not defined $Mnet::Model::cfg->{'data-dir'};

    # verify required object input is present
    my $object = $input->{'object'};
    croak "file_data missing input object key" if not defined $object;

    # verify required rrd input is present
    my $file = $input->{'file'};
    croak "file_data missing input file key" if not defined $file;

    # initialize output data
    my $data = undef;

    # finish me
    $file = "$Mnet::Model::cfg->{'data-dir'}/$object/$file";
    if (open(my $fh, $file)) {
        $data .= $_ while <$fh>;
        close $fh;
    } else {
        carp "file_data unable to open $file: $!";
    }

    # finished log_query function
    &dtl("file_data function finishing");
    return $data;
}



sub log_query {

=head2 log_query function

 \@output = &log_query(\%input)

Outputs a list of log entries matching input specifications.

The input hash reference may contain any combination of the following
keys that will be used to return for matching alerts:

 time        search back, unix time or flexible mm-dd-yyyy hh:mm:ss
 object      supports wildcard asterisk and question mark
 script      supports wildcard asterisk and question mark
 type        log type such as log, dbg, bug, wrn, err, etc
 sev         integer maximum severity 1-7 to return
 text        supports wildcard asterisk and question mark
 pid         integer process id
 info        search on info field, which is "sev ?: text"
 order       sort order, asc or desc, default asc
 limit       integer for maximum rows to return
 page        integer page number, given limit

The array reference output will contain zero or more rows resulting
from the input alert query. Each element in this output array is a
hash reference containing the following keys from the alert database:

 time        time alert was generated, yyyy-mm-dd hh:mm:ss
 object      object name associated with alert
 script      script name associated with alert
 type        log type such as log, dbg, bug, wrn, err, etc
 sev         severity of alert, from 1-7
 text        text associated with alert
 pid         process id of script that created log entry
 info        defined as combination "sev ?: text"
 color_sev   hex rgb value

=cut

    # read input hash reference
    my $input = shift;
    croak "log_query missing input hash ref arg"
        if not $input or ref $input ne 'HASH';
    &dtl("log_query sub called from " . lc(caller));

    # initialize output array reference
    my $output = [];

    # parse input time for query
    my $time = &parse_time($input->{'time'});

    # parse more inputs
    my $object = &parse_wildcard($input->{'object'});
    my $script = &parse_wildcard($input->{'script'});
    my $type = &parse_wildcard($input->{'type'});

    # set default severity, and verify if input
    my $sev = $input->{'sev'};
    $sev = 5 if not defined $sev;
    if ($sev !~ /^\d+$/) {
        carp "log_query reset invalid input sev $sev to 5";
        $sev = 5;
    }

    # parse more input fields
    my $text =  &parse_wildcard($input->{'text'});
    my $pid = $input->{'pid'};
    my $info = &parse_wildcard($input->{'info'});

    # set default sort order, and verify if input
    my $order = $input->{'order'};
    $order = "asc" if not defined $order;
    if ($order !~ /^(asc|desc)$/) {
        carp "log_query reset invalid input order $order to asc";
        $order = 'asc';
    }

    # validate limit is numeric, if set in input
    my $limit = $input->{'limit'};
    if (defined $limit and $limit !~ /^\d+$/) {
        carp "log_query reset invalid input limit $limit to 1024";
        $limit = 1024;
    }

    # validate input page number to display, set to 1 if not defined
    my $page = $input->{'page'};
    $page = 1 if not defined $page;
    if (defined $page and $page !~ /^\d+$/) {
        carp "log_query reset invalid input page $page to 1";
        $page = 1;
    }

    # prepare sql command and parameters, use security level
    my $sql_cmd = "select _time, _object, _script, _type, _sev, _text, _pid ";
    $sql_cmd .= "from _log where _sev <= ?";
    my @sql_params = ($sev);

    # add c_time clause, if date was parsed from filter
    if (defined $time and $time ne '') {
        $sql_cmd .= " and _time<=?";
        push @sql_params, $time;
    }   

    # add object clause, if object is not null
    if (defined $object and $object ne '') {
        $sql_cmd .= " and _object like ? escape '!'";
        push @sql_params, "\%$object\%";
    }

    # add script clause, if cgi script is set
    if (defined $script and $script ne '') {
        $sql_cmd .= " and _script like ? escape '!'";
        push @sql_params, "\%$script\%";
    }

    # add script clause, if cgi script is set
    if (defined $type and $type ne '') {
        $sql_cmd .= " and _type like ? escape '!'";
        push @sql_params, "\%$type\%";
    }

    # add info clause, if cgi info is set
    if (defined $info and $info ne '') {
        $sql_cmd .= " and (' sev ' || _sev || ': ' || _text ";
        $sql_cmd .= "|| ' ' || _pid) like ? escape '!'";
        push @sql_params, "\%$info\%";
    }

    # sort order for results
    $sql_cmd .= " order by _time $order";

    # paging for log entries, if limit set
    if (defined $limit and $limit ne '' and $limit ne '0') {
        my $page_offset = ($page - 1) * $limit;
        $sql_cmd .= " limit $limit offset $page_offset";
    }

    # open database connection and execute query
    my ($mnet_dbh, $err_dbh) = &database();
    croak "database_error $err_dbh" if defined $err_dbh;
    $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };
    my $db_logs = $mnet_dbh->selectall_arrayref($sql_cmd, {}, @sql_params);

    # loop through log entries returned from database and add to html table
    foreach my $db_log (@$db_logs) {

        # read fields for current log entry
        my ($time, $object, $script, $type, $sev, $text, $pid) = @$db_log;

        # create shortened alert time and prepare for timelocal call
        my $dtime = lc(localtime($time));
        $dtime = "$1 $2 $3" if $dtime =~ /(\S+)\s+(\d+)\s+(\d+:\d+)/;
        $dtime = "$1 0$2 $3" if $dtime =~ /(\S+)\s(\d)\s+(\d+:\d+)/;

        # prepare info output field
        my $info = "sev $sev: $text";

        # set severity color based on log entry severity
        my $color_sev = &color_severity($sev);

        # add current alert info to output array ref
        push @{$output}, {
            'color_sev' => $color_sev,
            'dtime'     => $dtime,
            'info'      => $info,
            'object'    => $object,
            'pid'       => $pid,
            'script'    => $script,
            'sev'       => $sev,
            'text'      => $text,
            'time'      => $time,
            'type'      => $type,
        };

    # continue looping through log entries returned from database
    }

    # finished log_query function
    &dtl("log_query function finishing");
    return $output;
}



sub object_info {

=head2 object_info function

 (\%output) = &object_info(\%input)

Retrieves information on the specified input object.

The input hash reference must contain the following:

 object         required object name

The output hash reference will contain the following elements:

 dir            mnet data directory for this object
 files          array ref of files in the object data directory
 object         input object name
 persist        hash ref, keys are script names
     script1    persistant data hash ref associated with script
     script2    ... additional script persistant data
 poll           poll data hash reference, if available
 report         array ref of report hash elements

Refer to perldoc Mnet::Poll for documentation on the contents of
the poll hash reference.

Refer to perldoc Mnet::Report for documentation on the contents of
the reports hash reference.

=cut

    # read input hash reference
    my $input = shift;
    croak "object_info missing input hash ref arg"
        if not $input or ref $input ne 'HASH';
    &dtl("object_info sub called from " . lc(caller));

    # read input object name
    my $object = $input->{'object'};
    croak "object_info object arg missing"
        if not defined $object or $object !~ /\S/;

    # initialize output hash reference
    my $output = {};

    # set object name in output
    $output->{'object'} = $object;

    # set object directory in output, if data-dir is set
    my $object_dir = undef;
    if (defined $Mnet::Model::cfg->{'data-dir'}) {
        $object_dir = "$Mnet::Model::cfg->{'data-dir'}/$object";
        $output->{'dir'} = $object_dir;
    }
    
    # read files from data directory, or output an error
    &dtl("object_info reading object dir $object_dir");
    $output->{'files'} = ();
    if (defined $object_dir and opendir(DIR, $object_dir)) {
        foreach my $file (readdir DIR) {
            next if $file =~ /^\./;
            &dtl("object_info found file $file in object dir");
            push @{$output->{'files'}}, $file;
        }
        close DIR;
    } elsif (defined $object_dir) {
        &dtl("object_info could not read object dir $object_dir, $!");
    } else {
        &dtl("object_info mnet-dir for $object-dir not set");
    }

    # open database connection
    &dtl("object_info opening database connection");
    my ($mnet_dbh, $err_dbh) = (undef, undef);
    ($mnet_dbh, $err_dbh) = &database()
        if defined $Mnet::Model::cfg->{'db-name'};
    croak "database_error $err_dbh" if defined $err_dbh;
    $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };

    # attempt to read poll data into output hash
    &dtl("object_info reading poll data from database");
    $output->{'poll'} = undef;
    if (defined $mnet_dbh) {
        my $sql_poll_read = 'select _data from _poll where _object = ?';
        my $db_poll_read = $mnet_dbh->selectall_arrayref(
            $sql_poll_read, {}, $object);
        if (defined $db_poll_read) {
            &dtl("object_info found poll data in database");
            my $poll_data = $$db_poll_read[0];
            my $poll_dump = $$poll_data[0];
            my $VAR1;
            $VAR1 = eval $poll_dump;
            $output->{'poll'} = $VAR1;
        } else {
            &dtl("object_info did not find poll data in database");
        }
    } else {
        &dtl("object_info poll data db-name not set");
    }

    # attempt ot read persist data from database
    &dtl("object_info attempting to read persist data from database");
    $output->{'persist'} = undef;
    if (defined $mnet_dbh) {
        my $sql_persist_read = "select _script, _data from _persist ";
        $sql_persist_read .= "where _object = ?";
        my $db_persist_read = $mnet_dbh->selectall_arrayref(
            $sql_persist_read, {}, $object);
        foreach my $db_persist_row (@$db_persist_read) {
            my $persist_script = $$db_persist_row[0];
            &dtl("object_info found script $persist_script persist data");
            my $persist_dump = $$db_persist_row[1];
            my $VAR1;
            $VAR1 = eval $persist_dump;
            $output->{'persist'}->{$persist_script} = $VAR1;
        }
        &dtl("object_info did not find any persist data")
            if not $output->{'persist'};
    } else {
        &dtl("object_info persist data db-name not set");
    }

    # attempt to read report data into output hash
    &dtl("object_info reading report data from database");
    $output->{'report'} = &Mnet::Report::report_query_object($object);

    # finished object_info function
    &dtl("object_info function finishing");
    return $output;
}



sub object_query {

=head2 object_query function

 \@output = &object_query(\%input)

Outputs a list of objects matching input specifications.

The input hash reference may contain any combination of the following
keys that will be used to return for matching objects:

 object      supports wildcard asterisk and question mark
 sev         max severity to return or keyword "all", default 7
 info        search on info field, which is "sev ?: text"
 limit       integer for maximum rows to return
 page        integer page number, given limit

Note that objects are returned from the alerts table unless the
severity is set to keyword all and data-dir is set in the config. In
this case a list of devices is returned from the data-dir directory.

The array reference output will contain zero or more rows resulting
from the input alert query. Each element in this output array is a
hash reference containing the following keys from the alert database:

 object      object name associated with alert
 sev         severity of worst alert, from 1-7
 text        text associated with alert
 info        defined as combination "sev ?: text"
 color_sev   hex rgb value

=cut

    # read input hash reference
    my $input = shift;
    croak "alert_query missing input hash ref arg"
        if not $input or ref $input ne 'HASH';
    &dtl("object_query sub called from " . lc(caller));

    # initialize output array reference
    my $output = [];

    # parse object input
    my $object = &parse_wildcard($input->{'object'});

    # set default severity, and verify if input
    my $sev = $input->{'sev'};
    $sev = 7 if not defined $sev;
    if ($sev !~ /^(all|\d+)$/) {
        carp "alert_query reset invalid input sev $sev to sev=5";
        $sev = 7;
    }

    # parse text and info fields
    my $text =  &parse_wildcard($input->{'text'});
    my $info = &parse_wildcard($input->{'info'});

    # validate limit is numeric, if set in input
    my $limit = $input->{'limit'};
    if (defined $limit and $limit !~ /^\d+$/) {
        carp "object_query reset invalid input limit $limit to 1024";
        $limit = 1024;
    }

    # validate input page number to display, set to 1 if not defined
    my $page = $input->{'page'};
    $page = 1 if not defined $page;
    if (defined $page and $page !~ /^\d+$/) {
        carp "log_query reset invalid input page $page to 1";
        $page = 1;
    }

    # handle severty set all with data-dir directory
    if (defined $sev and $sev eq 'all'
        and defined $Mnet::Model::cfg->{'data-dir'}
        and opendir(my $dh, $Mnet::Model::cfg->{'data-dir'})) {
            my $count = 1;
            foreach my $dir (sort readdir $dh) {
                next if !-d "$Mnet::Model::cfg->{'data-dir'}/$dir";
                next if $dir =~ /^\./;
                if (defined $input->{'object'}) {
                    my $obj_re = $input->{'object'};
                    $obj_re =~ s/\*/.+/g;
                    $obj_re =~ s/\?/./g;
                    next if $dir !~ /$obj_re/i;
                }
                $count++;
                if ($page and $limit) {
                    next if $count < ($page - 1) * $limit;
                    last if $count > $page * $limit;
                }
                push @{$output}, {
                    'object'    => $dir,
                    'sev'       => '',
                    'text'      => 'alert status not shown for sev all',
                    'info'      => "alert status not shown for sev all",
                    'color_sev' => &color_severity(7),
                };
            }
            close $dh;
            &dtl("object_query function finishing");
            return $output;
    }

    # prep sql to query rows with object, alert count, worst sev and worst alert
    my @sql_params = ();
    my $sql_cmd = "select * from (";
    $sql_cmd .= "select _object as obj, count(*) as cnt, min(_sev) as worst,";
    $sql_cmd .= "( select _text from _alert where _object = _a._object";
    $sql_cmd .= "  and _sev = (select min(_sev) from _alert";
    $sql_cmd .= "  where _object = _a._object) limit 1";
    $sql_cmd .= ") as txt from _alert as _a group by _object order by _object"; 
    $sql_cmd .= ") as _o where ";

    # add object clause, if object is not null
    if (defined $object and $object ne '') {
        $sql_cmd .= " obj like ? escape '!' and ";
        push @sql_params, "\%$object\%";
    }

    # add info clause, if cgi info is set
    if (defined $info and $info ne '') {
        $sql_cmd .= " ((cnt || ' alert(s), sev '";
        $sql_cmd .= "|| worst || ': ' || txt) like ? escape '!') and ";
        push @sql_params, "\%$info\%";
    }

    # remove last and from sql
    $sql_cmd =~ s/where\s*$//g;
    $sql_cmd =~ s/and\s*$//g;

    # add limit clause, if limit is set
    if ($limit) {
        my $page_offset = ($page - 1) * $limit;
        $sql_cmd .= " limit $limit offset $page_offset";
    }

    # open database connection and execute query
    my ($mnet_dbh, $err_dbh) = &database();
    croak "database_error $err_dbh" if defined $err_dbh;
    $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };
    my $db_objs = $mnet_dbh->selectall_arrayref($sql_cmd, {}, @sql_params);

    # loop through object entries returned from database and add to html table
    foreach my $db_obj (@$db_objs) {

        # read fields for current object entry
        my ($object, $count, $worst, $text) = @$db_obj;

        # skip if worst alert is greater than input severity
        next if $worst > $sev;

        # build output text
        my $info = "";
        if ($count == 0) {
            $info = "unable to read alerts";
        } else {
            $info = "$count alert(s), sev $worst: $text";
        }

        # add current alert info to output array ref
        push @{$output}, {
            'object'    => $object,
            'sev'       => $worst,
            'text'      => $text,
            'info'      => $info,
            'color_sev' => &color_severity($worst),
        };

    # continue looping through object entries returned from database
    }

    # finished object_query function
    &dtl("object_query function finishing");
    return $output;
}



sub parse_time {

# internal: $out = &parse_time($in)
# purpose: parse input date to prep for sql

    # read input field
    my $in = shift;
    return undef if not defined $in or $in !~ /\S/;

    # return if time already in unix format
    return $in if $in =~ /^\d{10}$/;    

    # initialize using current time, set 4 digit year
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
    my $current_mon = $mon;
    $year = 1900 + $year;

    # parse clock time from input
    ($hour, $min, $sec) = (23, 59, 59);
    ($hour, $min, $sec) = ($1, $2, $3) if $in =~ s/(\d+):(\d+):(\d+)//;
    ($hour, $min, $sec) = ($1, $2, 59) if $in =~ s/(\d+):(\d+)//;

    # prepare for date parsing, changing slashes to dashes
    $in =~ s/(\\|\/)/-/g;

    # pasrse numeric date with year at beginning
    if ($in =~ /(^|\s)(\d\d\d\d)-(\d\d?)-(\d\d?)(\s|$)/) {
        ($year, $mon, $mday) = ($2, $3-1, $4);

    # parse numeric date with year at the end
    } elsif ($in =~ /(^|\s)(\d\d?)-(\d\d?)-(\d\d\d?\d?)(\s|$)/) {
        ($mon, $mday, $year) = ($2-1, $3, $4);

    # parse numeric date with month and day
    } elsif ($in =~ /(^|\s)(\d\d?)-(\d\d?)(\s|$)/) {
        ($mon, $mday) = ($2-1, $3);

    # parse date with month abbreviation
    } elsif ($in =~ s/(^|\s)(\D\D\D)(\s+|-)(\d\d?)(\s|$)//) {
        ($mon, $mday) = (lc($2), $4);

        # convert month to numeric value
        my %months = qw/jan 0 feb 1 mar 2 apr 3 may 4 jun 5
            jul 6 aug 7 sep 8 oct 9 nov 10 dec 11/;
        $mon = $months{$mon} if defined $months{$mon};

        # rollback to last year if month is later in the year
        $year = $year -1 if $mon > $current_mon;

        # set year from input, if present
        $year = $2 if $in =~ /(^|\s)(\d\d\d\d)(\s|$)/;

    # finished parsing date
    }

    # calculate output unix time
    my $out = timelocal($sec, $min, $hour, $mday, $mon, $year);

    # finished parse_time
    return $out;
}



sub parse_wildcard {

# internal: $out = &parse_wildcard($in)
# purpose: parse input wildcards to prep for sql

    # read input field
    my $in = shift;
    return undef if not defined $in;

    # initialize output and fix field wildcards and escapes for sql
    my $out = $in;
    $out =~ s/(!|_|\%)/!$1/g;
    $out =~ s/\?/_/g;
    $out =~ s/__/?/g;
    $out =~ s/\*/%/g;
    $out =~ s/\%\%/*/g;

    # finished parse_wildcard
    return $out;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, Mnet::Poll, Mnet::Report

=cut



# normal package return
1;

