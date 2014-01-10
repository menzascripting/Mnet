package Mnet::Report;

=head1 NAME

Mnet::Report - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

This perl module can be used for scripts that need to output data to
be collected for a report. A line of report data is output when the
script is run with the log-quiet command line setting.

Usage example:

 # sample.pl --batch-list list --db-name data.db \
 #           --data-dir data --report-csv
 use Mnet;
 use Mnet::Report;
 my $cfg = &object;
 &report("compliant", 1) if $cfg->{'object-name'} =~ /-rtr\d$/;

=head1 DESCRIPTION

The report function in this module is used to store label and value
pairs. The output will start with an object label if an object-name is
defined. The output line will end with the error label if the mnet
module trapped any warnings or die calls.

It is intended that report script will be run in batch-list mode,
also having and db-name database, data-dir directory and report-csv
option set. In this case the batch children will save report data to
the database and the batch parent will output this data to a web ready
csv file named after the script in the data-dir directory. The batch
parent will also clean old report entries from the database for the
current script.

If log-quiet is also used with a batch parent and db-name then the
csv file contents will be sent to standard output.

Note that double quotes are escaped in the csv file output using an
extra double quote character. All linefeeds are removed from saved
data values.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --report-csv           enable for batch csv output, requires db-name
 --report-detail        extra debug logging, default disabled
 --report-inf           default inf log for report data if not db-name
 --report-version       set at compilation to build number
 --report-script        script name for report_aggregate function
 --data-dir <dir>       use with report-csv to write script report csv
 --db-name <database>   database name for report data, default not set
 --db-clean <days>      when report entries will expire and be removed
 --log-quiet            use with report-csv for csv to standard output

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and libraries:

=cut

# modules used
use warnings;
use strict;
use Carp;
use Data::Dumper;
use Exporter;
use Mnet;

# export module function names
our @ISA = qw( Exporter );
our @EXPORT = qw( report report_query_object report_query_script );

# module initialization
BEGIN {

    # read config
    our $cfg = &Mnet::config({
        'report-version'   => '+++VERSION+++',
    });
        
    # initialize report data
    our $data = {};

    # initialize database handle, prepared report queries and time
    our $dbh = undef;
    our $db_report_new = undef;
    our $db_report_upd = undef;
    our $db_time = time;

# finished module initialization
}



sub report {

=head2 report function

 &report($label, $value);
 &report($label, $value, $subitem);
 &report(\%data, $mask_re);
 &report(\%data, $mask_re, $subitem);

This function can be used by scripts to set one or more label and value
pairs in the report data. A single label and value pair can be given as
input values, or a hash reference can be used to set multiple values at
at once. An optional mask regular expression can be used with a hash 
reference to act as a filter, skipping all labels that do not match.

An object-name must be set or this function will exit with an error.

Note that any undefined labels or labels with undefined values will be
skipped and not stored with the report data. Key names not containing
a non-space character will be skipped.

Also note that labels and values will be cleaned to remove end of line
and extra whitespace characters.

=cut

    # set input args, may contain label, value or hash ref, mask and subitem
    &dtl("sub called from " . lc(caller));
    my ($arg1, $arg2, $subitem) = @_;

    # initialize data hash ref and data mask
    my $data = {};
    my $mask_re = undef;

    # handle undefined fisr arg, or data and optional mask, or data and value
    if (not defined $arg1) {
        carp "undefined label or data";
        return;
    } elsif (ref $arg1 eq "HASH") {
        ($data, $mask_re) = ($arg1, $arg2);
    } else {
        $data->{$arg1} = $arg2;
    }

    # error if mnet object not defined
    croak "report function called without object-name set"
        if not defined $Mnet::Report::cfg->{'object-name'};

    # set subitem null if not defined
    $subitem = '' if not defined $subitem;
    croak "subitem $subitem contains invalid spaces" if $subitem =~ /\s/;

    # output message with mask regular expression, if defined
    &dtl("mask $mask_re in effect") if defined $mask_re;

    # cleaning expressions, chars to remove and replace with underscores
    my $clean_remove = '(^\s+|"|\'|,|=|\n|\r|\s$)';
    my $clean_under = '\s+';

    # loop through all defined regular data label values
    foreach my $label (keys %$data) {

        # skip invalid labels
        if (not defined $label) {
            &dbg("undefined label");
            next;
        } elsif (ref $label) {
            &dbg("invalid label");
            next;
        } elsif ($label !~ /\S/) {
            &dbg("empty label");
            next;
        }

        # skip undefined or invalid value 
        my $value = $data->{$label};
        if (not defined $value) {
            &dtl("undefined value for $label");
            next;
        } elsif (ref $value) {
            &dtl("invalid value for $label");
            next;
        }

        # set aside orignal label, remove eol, whitespace, equal sign, compare
        my $original = $label;
        $label =~ s/\s\s+/ /g;
        $label =~ s/(\n|\r)/ /g;
        $label =~ s/(^\s|\s$)//g;
        $label =~ s/=/_/g;
        &dtl("cleaned $label from $original")
            if $label ne $original;

        # skip label, or output message, depending on regular expression mask
        if (defined $mask_re) {
            if ($label !~ /$mask_re/) {
                &dtl("mask filtered $label");
                next;
            }
            &dtl("mask matched $label");
        }

        # handle storing report value if db-name is configured
        if ($Mnet::Report::cfg->{'db-name'}) {

            # init report database for this script run, if not already set
            if (not defined $Mnet::Report::dbh) {

                # create report table, if not present
                my $tables = [];
                my $db_err = "";
                &dbg("connecting to db-name");
                ($Mnet::Report::dbh, $db_err) = &database($tables);
                croak "database handle undefined" if not $Mnet::Report::dbh;
                croak "database error: $db_err" if $db_err;
                if (" @$tables " !~ /\s_report\s/) {
                    &dbg("creating missing _report table");
                    my $sql = "create table _report ( ";
                    $sql .= "_time int, ";
                    $sql .= "_expire int, ";
                    $sql .= "_script varchar, ";
                    $sql .= "_object varchar, ";
                    $sql .= "_subitem varchar, ";
                    $sql .= "_label varchar, ";
                    $sql .= "_value varchar); ";
                    $sql .= "create index _report_idx1";
                    $sql .= " on _report (_expire); ";
                    $sql .= "create index _report_idx2";
                    $sql .= " on _report (_script, _label, _value); ";
                    $sql .= "create index _report_idx3";
                    $sql .= " on _report (_object, _subitem);";
                    $Mnet::Report::dbh->do($sql);
                }

                # prepare query to update report row
                my $sql_report_upd = "update _report ";
                $sql_report_upd .= "set _time=?, _expire=?, _value=? where ";
                $sql_report_upd .= "_script=? and _object=? ";
                $sql_report_upd .= "and _subitem=? and _label=?";
                $Mnet::Report::db_report_upd
                    = $Mnet::Report::dbh->prepare($sql_report_upd);
                croak "database report_upd error: " . $Mnet::Report::dbh->errstr
                    if $Mnet::Report::dbh->errstr;

                # prepare query to insert new report row
                my $sql_report_new = "insert into _report (_time, ";
                $sql_report_new .= "_expire, _script, _object, ";
                $sql_report_new .= "_subitem, _label, _value) ";
                $sql_report_new .= "values (?, ?, ?, ?, ?, ?, ?)";
                $Mnet::Report::db_report_new
                    = $Mnet::Report::dbh->prepare($sql_report_new);
                croak "database report_new error: " . $Mnet::Report::dbh->errstr
                    if $Mnet::Report::dbh->errstr;

            # finished initializing database for report items
            }

            # set expire time for new entries
            my $expire = int($Mnet::Report::db_time
                + $Mnet::Report::cfg->{'db-expire'} * 86400);

            # attempt to update report value
            $Mnet::Report::db_report_upd->execute(
                $Mnet::Report::db_time,
                $expire,
                $value,
                $Mnet::Report::cfg->{'mnet-script'},
                $Mnet::Report::cfg->{'object-name'},
                $subitem,
                $label,
            );

            # insert new report value, if update didn't work
            $Mnet::Report::db_report_new->execute(
                $Mnet::Report::db_time,
                $expire,
                $Mnet::Report::cfg->{'mnet-script'},
                $Mnet::Report::cfg->{'object-name'},
                $subitem,
                $label,
                $value,
            ) if not $Mnet::Report::db_report_upd->rows;

            # die if unable to insert new report value
            croak "database insert error: " . $Mnet::Report::dbh->errstr
                if $Mnet::Report::dbh->errstr;

        # finished handling db-name 
        }

        # remove eol and extra whitespace from value
        $value =~ s/\s\s+/ /g;
        $value =~ s/(\n|\r)/ /g;
        $value =~ s/(^\s|\s$)//g;

        # set specified label in output report data hash
        $Mnet::Report::data->{$subitem}->{$label} = $value;
        my $report_log = "label $label = $value";
        $report_log = "subitem $subitem label $label = $value" if $subitem;
        if ($Mnet::Report::cfg->{'report-inf'}
            or not $Mnet::Report::cfg->{'db-name'}) {
            &inf($report_log);
        } else {
            &dbg($report_log);
        }

    # finish looping through all defined data label values
    }

    # finished report function
    return;
}



sub report_aggregate {

=head2 report_aggregate function

 &report_aggregate;

This function is used to read rows of report module output data that
are piped to standard input, aggregate that data, and output it in csv
format.

This function is intended to be called in the following fashion:

 ./script.pl --log-quiet --batch-list list \
    | perl -e 'use Mnet::Report; &Mnet::Report::report_aggregate' - \
    --log-quiet --data-dir /home/mnet/data/ --report-script script.pl

In this way this function is used to convert the reporting data
to csv format from from a script for a batch list of devices.

Note that the output csv report can be saved to a file in the
data-dir directory with report-csv set in the script. This will
allow the web viewer to present the csv file.

=cut

    # initialize lines of input data, list of unique labels and sorted headings
    my @lines = ();
    my %labels = ();
    my @headings = ();

    # read all lines of input into memory and track all labels used as we go
    while (<STDIN>) {
        my $line = $_;
        chomp $line;
        push @lines, $line;
        &dtl("read line $line");
    }

    # create list of all labels in all lines
    &dtl("looking for all labels");
    foreach my $line (@lines) {
        my $current_line = $line;
        while ($current_line =~ s/^\s*([^=]+)="//) {
            $labels{$1} = 1;
            &dtl("found label $1");
            $current_line =~ s/""//g;
            $current_line =~ s/^.*?"\s//;
        }
    }

    # arrange labels in order for heading row
    push @headings, "object";
    foreach my $label (sort keys %labels) {
        next if $label =~ /^(object|error)$/;
        push @headings, $label;
    }
    push @headings, "error";

    # prepare csv heading row
    my $heading_row = "";
    foreach my $heading (@headings) {
        $heading_row .= "\"$heading\", ";
    }
    $heading_row =~ s/,\s*$//;

    # output csv heading row if log-quiet set
    if ($Mnet::Report::cfg->{'log-quiet'}) {
        syswrite STDOUT, "$heading_row\n";
    }

    # output csv heading row if data-dir and report-csv are set
    my $csv_file = "";
    if ($Mnet::Report::cfg->{'data-dir'}
        and $Mnet::Report::cfg->{'report-script'}) {
        $csv_file = $Mnet::Report::cfg->{'data-dir'} . "/";
        $csv_file .= $Mnet::Report::cfg->{'report-script'} . ".csv";
        open (FILE, ">$csv_file.new");
        syswrite FILE, "$heading_row\n";
    }

    # use carriage returns to escape double quotes, since they were cleaned
    my $escape = "\n";

    # loop to output csv data
    foreach my $line (@lines) {
        my $current_line = $line;
        $current_line =~ s/""/$escape/g;
        my $data_row = "";
        foreach my $heading (@headings) {
            my $value = "";
            $value = $2 if $current_line =~ /(^|\s)\Q$heading\E="((.|\n)*?)"/m;
            $value =~ s/$escape/""/g;
            $data_row .= "\"$value\", ";
        }
        $data_row =~ s/,\s*$//;

        # output csv data row if log-quiet set
        if ($Mnet::Report::cfg->{'log-quiet'}) {
            syswrite STDOUT, "$data_row\n";
        }

        # output csv data row if csv file is set
        if ($csv_file) {
            syswrite FILE, "$data_row\n";
        }

    # finished csv output loop
    }

    # close output csv file
    if ($csv_file) {
        close FILE;
        rename "$csv_file.new", $csv_file
            or carp "report_query_script unable to rename $csv_file, $!";
    }

    # finished
    return;
}



sub report_query_object {

=head2 report_query_object

 \@output = &report_query_object($object)

Outputs rows of report data for the specified object.

Each element in the output data array is a hash reference containing
the following keys:

 time        unix timestamp of report entry
 dtime       display timestamp, mmm-dd hh:mm
 script      name of script that generated report entry
 object      name of the object associated with report entry
 subitem     subitem asocciated with report entry
 label       label of report entry
 value       value of report entry

Note that the db-name config option must be specified for this query
to work.

=cut

    # read the input object name
    my $object = shift;
    croak "report_query_object missing input object arg" if not defined $object;
    &dtl("report_query_object sub called from " . lc(caller));

    # initialize output
    my $output = [];

    # prepare query to retrieve object reports
    my $sql_cmd = "select _time, _script, _object, _subitem, _label, _value ";
    $sql_cmd .= "from _report where _object = ? ";
    $sql_cmd .= "order by _script, _subitem, _label";

    # open database connection and execute query
    &dtl("report_query_object opening database connection");
    my ($mnet_dbh, $err_dbh) = &database();
    croak "database_error $err_dbh" if defined $err_dbh;
    $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };
    my $db_reports = $mnet_dbh->selectall_arrayref($sql_cmd, {}, $object);

    # loop through report entries returned from database and add to output list
    foreach my $db_report (@$db_reports) {

        # read fields for current log entry
        my ($time, $script, $object, $subitem, $label, $value) = @$db_report;

        # create shortened alert time and prepare for timelocal call
        my $dtime = lc(localtime($time));
        $dtime = "$1 $2 $3" if $dtime =~ /(\S+)\s+(\d+)\s+(\d+:\d+)/;
        $dtime = "$1 0$2 $3" if $dtime =~ /(\S+)\s(\d)\s+(\d+:\d+)/;

        # add current report entry to output array ref
        push @{$output}, {
            'time'      => $time,
            'dtime'     => $dtime,
            'script'    => $script,
            'object'    => $object,
            'subitem'   => $subitem,
            'label'     => $label,
            'value'     => $value,
        };

    # continue looping through log entries returned from database
    }

    # finished report_query_object function
    &dtl("report_query_object function finishing");
    return $output;
}



sub report_query_script {

=head2 report_query_script

 \@output = &report_query_script
 \@output = &report_query_script($script)
 \@output = &report_query_script($script, $label, $order, $page, $limit)

Outputs rows of report data for the specified script and label. Will
output a list of all scripts if no script argument is specified. Will
output a list of labels if script but not label is specified.

When an input script argument is specified then each element element
in the output data array is a hash reference containing the following
keys:

 time        unix timestamp of report entry
 script      name of script that generated report entry
 object      name of the object associated with report entry
 subitem     subitem asocciated with report entry
 label       label of report entry
 value       value of report entry

The optional sort and order arguments will cause the output rows to be
sorted based on the matching label values, the label being sorted named
as the sort argument. The order argument can be the keyword asc or desc.
The default is an ascending sort on the object name.

The optional page and limit arguments can be used to split the output
into pages.

Note that if the input script argument is not specified then the
output array reference will be a list of all script names from the
report database.

Note that the db-name config option must be specified for this query
to work.

=cut

    # read the optional input script name
    my ($script, $label, $order, $page, $limit) = @_;
    &dtl("report_query_script sub called from " . lc(caller));

    # initialize output
    my $output = [];

    # return list of scripts, if script not specified
    if (not defined $script or $script !~ /\S/) {
        &dtl("report_query_script returning list of scripts");

        # retrieve list of scripts from report database table
        my $sql_cmd = "select distinct _script from _report order by _script";
        &dtl("report_query_object_script opening script database connection");
        my ($mnet_dbh, $err_dbh) = &database();
        croak "database_error $err_dbh" if defined $err_dbh;
        $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };
        $output = $mnet_dbh->selectcol_arrayref($sql_cmd);

        # return list of scripts
        return $output;

    # return list of labels, if script but not label is specified
    } elsif (not defined $label or $label !~ /\S/) {

        # retrieve list of scripts from report database table
        my $sql_cmd = "select distinct _label from _report ";
        $sql_cmd .= "where _script=? order by _label";
        &dtl("report_query_object_script opening label database connection");
        my ($mnet_dbh, $err_dbh) = &database();
        croak "database_error $err_dbh" if defined $err_dbh;
        $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };
        $output = $mnet_dbh->selectcol_arrayref($sql_cmd, {}, $script);

        # return list of labels
        return $output;

    # finshed returning script or label list
    }

    # prepare to get report entries for specified script and label
    &dtl("report_query_script returning $script $label entries");

    # validate limit is numeric, if set in input
    if (defined $limit and $limit !~ /^\d+$/) {
        carp "report_query_script reset invalid input limit $limit to 1024";
        $limit = 1024;
    }

    # validate input page number to display, set to 1 if not defined
    $page = 1 if not defined $page;
    if (defined $page and $page !~ /^\d+$/) {
        carp "report_query_script  reset invalid input page $page to 1";
        $page = 1;
    }

    # prepare query to retrieve object reports
    my $sql_cmd = "select _time, _script, _object, _subitem, _label, _value ";
    $sql_cmd .= "from _report where _script=? and _label=? ";
    if (not $order) {
        $sql_cmd .= "order by _value desc ";
    } elsif ($order eq 'object') {
        $sql_cmd .= "order by _object asc, _subitem asc ";
    } else {
        $sql_cmd .= "order by _value asc ";
    }

    # add limit clause, if limit is set
    if (defined $limit and $limit ne '' and $limit ne '0') {
        my $page_offset = ($page - 1) * $limit;
        $sql_cmd .= " limit $limit offset $page_offset";
    }

    # open database connection and execute query
    &dtl("report_query_object opening database connection");
    my ($mnet_dbh, $err_dbh) = &database();
    croak "database_error $err_dbh" if defined $err_dbh;
    $mnet_dbh->{HandleError} = sub { &dbg("database error " . shift); };
    my $db_reports
        = $mnet_dbh->selectall_arrayref($sql_cmd, {}, $script, $label);

    # loop through report entries returned from database and add to output list
    foreach my $db_report (@$db_reports) {

        # read fields for current report entry
        my ($time, $script, $object, $subitem, $label, $value) = @$db_report;

        # create shortened alert time and prepare for timelocal call
        my $dtime = lc(localtime($time));
        $dtime = "$1 $2 $3" if $dtime =~ /(\S+)\s+(\d+)\s+(\d+:\d+)/;
        $dtime = "$1 0$2 $3" if $dtime =~ /(\S+)\s(\d)\s+(\d+:\d+)/;

        # add current report entry to output array ref
        push @{$output}, {
            'time'      => $time,
            'dtime'     => $dtime,
            'script'    => $script,
            'object'    => $object,
            'subitem'   => $subitem,
            'label'     => $label,
            'value'     => $value,
        };

    # continue looping through log entries returned from database
    }

    # finished report_query_script function
    &dtl("report_query_script function finishing");
    return $output;
}



# module end tasks
END {

    # if not a bacth parent then output error status for report
    if ($Mnet::ppid) {
        &report("error", $Mnet::error) if $Mnet::error;
        &report("error", $Mnet::error_last) if $Mnet::error_last;
        &report("error", "") if not $Mnet::error and not $Mnet::error_last;
    }

    # output report-csv if batch parent and database was configured
    if ($Mnet::Report::cfg->{'report-csv'} and $Mnet::Report::cfg->{'db-name'}
        and $Mnet::Report::cfg->{'batch-list'} and not $Mnet::ppid) {
        &Mnet::dbg("end block processing for batch parent report-csv file");

        # note name of running script
        my $script = $Mnet::Report::cfg->{'mnet-script'};

        # open database connection
        my ($dbh, $db_err) = &Mnet::database;
        croak "database handle undefined" if not $dbh;
        croak "database error: $db_err" if $db_err;

        # delete anything before this report was started
        &Mnet::dbg("deleting old rows from db-name _report table");
        my $sql_del = "delete from _report where _script=? and _time<?";
        my $db_time = $Mnet::Report::db_time;
        my $rows_del = $dbh->do($sql_del, undef, $script, $db_time);
        &Mnet::dbg("deleted $rows_del old rows");

        # prepare query to retrieve report entries for current script
        my $sql_qry = "select _time, _script, _object, _subitem, _label, ";
        $sql_qry .= "_value from _report where _script=? ";
        $sql_qry .= "order by _object asc, _subitem asc ";
        &Mnet::dbg("querying current report rows from db-name");
        my $db_reports = $dbh->selectall_arrayref($sql_qry, {}, $script);

        # create sorted array of headings from labels, using hash of labels
        my @headings = ();
        my %labels = ();
        &Mnet::dbg("looking for report headings");
        foreach my $db_report (@$db_reports) {
            my $label = (@$db_report)[4];
            &Mnet::dtl("found report heading $label") if not $labels{$label};
            $labels{$label} = 1;
        }
        push @headings, "object";
        push @headings, "subitem";
        foreach my $label (sort keys %labels) {
            next if $label =~ /^(object|subitem|error)$/;
            push @headings, $label;
        }
        push @headings, "error";

        # prepare csv heading row
        my $heading_row = "";
        $heading_row .= "\"$_\", " foreach @headings;
        $heading_row =~ s/,\s*$//;

        # output csv heading row if log-quiet set
        syswrite STDOUT, "$heading_row\n" if $Mnet::Report::cfg->{'log-quiet'};

        # output csv heading row if data-dir and report-csv are set
        my $csv_file = "";
        if ($Mnet::Report::cfg->{'data-dir'}
            and $Mnet::Report::cfg->{'report-csv'}) {
            $csv_file = $Mnet::Report::cfg->{'mnet-script'} . ".csv";
            &Mnet::inf("saving data to $csv_file");
            $csv_file = $Mnet::Report::cfg->{'data-dir'} . "/" . $csv_file;
            open (FILE, ">$csv_file.new");
            syswrite FILE, "$heading_row\n";
        }

        # track object_subitem combinations, and row data for each
        my $object_subitem = undef;
        my %row_data = ();

        # loop through report entries returned from database query
        foreach my $entry (@$db_reports) {

            # read fields for current report entry
            my ($time, $script, $object, $subitem, $label, $value) = @$entry;
            $object = "" if not defined $object;
            $subitem = "" if not defined $subitem;
            $label = "" if not defined $label;
            $value = "" if not defined $value;

            # init first object_subitem
            if (not defined $object_subitem) {
                $object_subitem = "$object $subitem";
                $row_data{$label} = $value;
                next;

            # note new label data to current object_subitem
            } elsif ($object_subitem eq "$object $subitem") {
                $row_data{$label} = $value;
                next;
            }

            # prepare row of csv output
            my ($old_object, $old_subitem) = ($1, $2)
                if $object_subitem =~ /^(.+)\s(.*)$/;
            my $csv_row = "\"$old_object\", \"$old_subitem\", ";
            foreach my $heading (@headings) {
                next if $heading =~ /^(object|subitem)$/;
                my $value = "";
                $value = $row_data{$heading} if defined $row_data{$heading};
                $value =~ s/"/""/g;
                $csv_row .= "\"$value\", ";
            }
            $csv_row =~ s/,\s$//;

            # output row of csv data to stdout if log-quiet is set
            syswrite STDOUT, "$csv_row\n" if $Mnet::Report::cfg->{'log-quiet'};

            # output row of csv data to csv report-csv, if set as csv_file
            syswrite FILE, "$csv_row\n" if $csv_file;

            # prepare for next object_subitem
            $object_subitem = "$object $subitem";
            %row_data = ();
            $row_data{$label} = $value;

        # finish looping through report entries
        }

        # prepare row of csv output
        my ($old_object, $old_subitem) = ($1, $2)
            if $object_subitem =~ /^(.+)\s(.*)$/;
        my $csv_row = "\"$old_object\", \"$old_subitem\", ";
        foreach my $heading (@headings) {
            next if $heading =~ /^(object|subitem)$/;
            my $value = "";
            $value = $row_data{$heading} if defined $row_data{$heading};
            $value =~ s/"/""/g;
            $csv_row .= "\"$value\", ";
        }
        $csv_row =~ s/,\s$//;

        # output row of csv data to stdout if log-quiet is set
        syswrite STDOUT, "$csv_row\n" if $Mnet::Report::cfg->{'log-quiet'};

        # output row of csv data to csv report-csv, if set as csv_file
        syswrite FILE, "$csv_row\n" if $csv_file;

        # close output csv file
        if ($csv_file) {
            close FILE;
            rename "$csv_file.new", $csv_file
                or carp "report end block unable to rename $csv_file, $!";
        }

    # handle batch child where batch parent will report to std out
    } elsif ($Mnet::Report::cfg->{'report-csv'}
        and $Mnet::Report::cfg->{'db-name'}
        and $Mnet::Report::cfg->{'batch-list'} and $Mnet::ppid) {

        # debug message
        &Mnet::dbg("skipping end block processing for batch child");

    # output data and error info if running log-quiet, for report_aggregate
    } elsif ($Mnet::Report::cfg->{'log-quiet'}) {
        &Mnet::dbg("end block processing for log-quiet");

        # output a data row for each subitem in current data set
        foreach my $subitem (sort keys %$Mnet::Report::data) {

            # init report output object and subitem
            my $report_output = "";
            $report_output .= "object=\"$Mnet::Report::cfg->{'object-name'}\" "
                if $Mnet::Report::cfg->{'object-name'};
            $report_output .= "subitem=\"$subitem\" " if $subitem =~ /\S/;

            # loop through all labels associated with current data row
            foreach my $label (sort keys %{$Mnet::Report::data->{$subitem}}) {
                next if $label =~ /^(object|error)$/;
                my $value = $Mnet::Report::data->{$subitem}->{$label};
                $value =~ s/"/""/g;
                $report_output .= "$label=\"$value\" ";
            }

            # output current row to terminal
            $report_output =~ s/\s$//;
            syswrite STDOUT, "$report_output\n";
            &Mnet::dbg("data output: $report_output");

        # finish looping through report subitem rows
        }

    # finished log-quiet report data output
    }

# finished module end tasks
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet, Mnet::Model

=cut



# normal package return
1;

