package Mnet::Report;

#? write a .t test for this module

=head1 NAME

Mnet::Report

=head1 SYNOPSIS

This module can be used to output rows of report data for one or more tables
in various formats.

Here's an example showing an END block used to report on all fatal errors:

Refer to the documentation below for more information.

=head1 TESTING

This module supports the Mnet::Test test, record, and replay functionality,
outputting report data so it can be included in testing.

=cut

# required modules
use warnings;
use strict;
use Carp;
use Mnet::Dump;
use Mnet::Log::Conditional qw( DEBUG INFO NOTICE WARN FATAL );
use Mnet::Opts::Cli::Cache;

# set autoflush and sig handlers to capture first error if Mnet::Log not loaded
#   autoflush is set so multi-process syswrite lines don't clobber each other
BEGIN {
    $| = 1;
    my $error = undef;
    if (not $INC{'Mnet/Log.pm'}) {
        $SIG{__DIE__} = sub {
            $Mnet::Report::error = "@_" if not defined $Mnet::Report::error;
            die @_;
        };
        $SIG{__WARN__} = sub {
            $Mnet::Report::error = "@_" if not defined $Mnet::Report::error;
            warn @_
        };
    }
}



sub new {

=head1 $self = Mnet::Report->new(\%opts)

A new Mnet::Report object can be created for each required table, as follows:

 my $report = Mnet::Report->new({
    table   => "example",
    output  => "csv:sample.csv",    # also json, sql, and dump files
    columns => [                    # ordered list of column names
        device  => "text",          # eol chars stripped for csv output
        count   => "integer",       # +/- integer numbers
        error   => "error",         # first error, refer to end method
        time    => "time",          # row time in yyyy/mm/dd hh:mm:ss
    ],
 });

Errors are issued for invalid options.

Refer to the documentation for specific output options below for more info.

=cut

    # read input class and optional opts hash ref
    my $class = shift // croak("missing class arg");
    my $opts = shift // {};
    DEBUG("new starting");

    # abort if we were called before batch fork if Mnet::Batch was loaded
    croak("new Mnet::Report objects must be created before Mnet::Batch::fork")
        if $INC{"Mnet/Batch.pm"} and $MNet::Batch::fork_called;

    # init new object
    my $self = {};

    # abort if opts table name key is not set
    croak("missing opts input table key") if not $opts->{table};
    croak("invalid table name $opts->{table}") if $opts->{table} =~ /["\r\n]/;
    DEBUG("new opts table = $opts->{table}");
    $self->{table} = $opts->{table};

    # abort if opts columns array ref is not set
    #   copy column names and types into new object data
    #   croak for invalid column types and error type if Mnet::Log not loaded
    croak("missing opts input columns key") if not $opts->{columns};
    croak("invalid opts input columns key") if ref $opts->{columns} ne "ARRAY";
    croak("missing opts input column data") if not scalar(@{$opts->{columns}});
    $self->{columns} = {};
    $self->{columns_order} = [];
    while (@{$opts->{columns}}) {
        my $column = shift @{$opts->{columns}} // croak("missing column name");
        my $type = shift @{$opts->{columns}} // croak("missing column type");
        croak("invalid column name $column") if $column =~ /["\r\n]/;
        DEBUG("new opts column $column ($type)");
        $self->{columns}->{$column} = $type;
        push @{$self->{columns_order}}, $column;
        if ($type !~ /^(error|integer|string|time)$/) {
            croak("column type $type is invalid");
        }
    }

    # set output option in new object
    if ($opts->{output}) {
        if ($opts->{output} !~ /^(test|(csv|dump|json|sql):.+)$/) {
            croak("invalid output option $opts->{output}")
        }
        DEBUG("new opts output = $opts->{output}");
        $self->{output} = $opts->{output};
    }

    # initialize array ref to hold row data
    $self->{rows} = [];

    # bless new object
    bless $self, $class;

    # call _output method if Mnet::Batch module has been loaded
    #   parent process will output heading rows before Mnet::Batch::fork called
    $self->_output if $INC{"Mnet/Batch.pm"};

    # finished new method, return Mnet::Report object
    DEBUG("new finished, returning $self");
    return $self;
}



sub end {

=head1 $self->end(\%data)

This method can be used in an END block to ensure a row is output if there
were any prior errors that may have terminated the script before the errors
had a chance to be reported, as in the example below:

 # declare report object as a global
 use Mnet::Report;
 our $report = Mnet::Report->new({
    table   => "example",
    output  => "json:file.json",
    columns => [ field => "text", error = "error", ttl => "integer" ],
 });

 # declare report data as a global
 our $data = { field => "sample" };
 if `ping host` !~ /ttl=(\d+)/ or die "ping error";
 $data->{ttl} = $1;
 $report->row($data);

 # call end method using global report object and data
 END { $main::report->end($main::data) }

The end method call in the END above will be triggered only if the ping error
causes the script to die. Otherwise the row method is called and the end method
is skipped becuase there were no prior errors that were unreported.

=cut

    # read inputs and call row methdo if errors have been detected
    my $self = shift // croak("missing self arg");
    my $data = shift // croak("missing self arg");
    if ($INC{'Mnet/Log.pm'} and Mnet::Log::error() or $Mnet::Report::error) {
        $self->row($data) if not $self->{error_reported};
    }
    return;
}



sub row {

=head1 $self->row(\%data)

This method will add a row of specified data to the current report table
object, as in the following example:

 $self->row({
    device  => $string,
    sample  => $integer,
 })

Note that an error is issued if any input columns are not defined for the
current object or invalid data is submitted.

=cut

    # read input object
    my $self = shift // croak("missing self arg");
    my $data = shift // croak("missing data arg");
    DEBUG("row starting for table $self->{table}");

    # init hash ref to hold output row data
    my $row = {};

    # loop through all columns in the current object
    foreach my $column (sort keys %{$self->{columns}}) {
        my ($type, $value) = ($self->{columns}->{$column}, $data->{$column});

        # set error column type to current Mnet::Log::Error value
        #   use Mnet::Log::error if that module is loaded
        if ($type eq "error") {
            $row->{$column} = $Mnet::Report::error;
            $row->{$column} = Mnet::Log::error() if $INC{'Mnet/Log.pm'};
            chomp($row->{$column}) if defined $row->{$column};
            croak("invalid error column $column") if exists $data->{$column};
            $self->{error_reported} = 1;

        # set integer column type, croak on bad integer
        } elsif ($type eq "integer") {
            if (defined $value) {
                $value =~ s/(^\s+|\s+$)//;
                if ($value =~ /^(\+|\-)?\d+$/) {
                    $row->{$column} = $value;
                } else {
                    croak("invalid integer column $column value $value");
                }
            }

        # set string column type
        } elsif ($type eq "string" and defined $value) {
            $row->{$column} = $value;

        # set time column types to yyyy/mm/dd hh:mm:ss
        } elsif ($type eq "time") {
            my ($second, $minute, $hour, $date, $month, $year) = localtime;
            $month++; $year += 1900;
            my @fields = ($year, $month, $date, $hour, $minute, $second);
            $row->{$column} = sprintf("%04s/%02s/%02s %02s:%02s:%02s", @fields);
            croak("invalid time column $column") if exists $data->{$column};

        # abort on unknown column type
        } else {
            die "invalid column type $type";
        }

    # continue loop through columns in the currect object
    }

    # croak if any input data columns were not declared for current object
    foreach my $column (sort keys %$data) {
        next if exists $self->{columns}->{$column};
        croak("column $column was not defined for table $self->{table}");
    }

    # output row data
    DEBUG("row calling _outout method");
    $self->_output($row);

    # finished row method
    DEBUG("row finished for table $self->{table}");
    return;
}



sub _output {

# $self->_output($row)
# purpose: call the correct output subroutine
# \%row: row data, or undef for init call from new method w/Mnet::Batch loaded

    # read inputs
    my $self = shift // croak("missing self arg");
    my $row = shift;
    DEBUG("_output starting");

    # handle --test output
    my $cli = Mnet::Opts::Cli::Cache::get({});
    if ($cli->{test}) {
        DEBUG("_output calling _output_test for table $self->{table}");
        $self->_output_test($row);

    # note that no output option was set
    } elsif (not defined $self->{output}) {
        DEBUG("_output not set for table $self->{table}");

    # handle csv output
    } elsif ($self->{output} =~ /^csv:/) {
        DEBUG("_output calling _output_csv for table $self->{table}");
        $self->_output_csv($row);

    # handle dump output
    } elsif ($self->{output} =~ /^dump:/) {
        DEBUG("_output calling _output_dump for table $self->{table}");
        $self->_output_dump($row);

    # handle json output
    } elsif ($self->{output} =~ /^json:/) {
        DEBUG("_output calling _output_json for table $self->{table}");
        $self->_output_json($row);

    # handle sql output
    } elsif ($self->{output} =~ /^sql:/) {
        DEBUG("_output calling _output_sql for table $self->{table}");
        $self->_output_sql($row);

    # error on invalid output option
    } else {
        FATAL("table $self->{table} invalid output option $self->{output}");
    }

    # finished _output method
    DEBUG("_output finished");
    return;
}



sub _output_csv {

=head1 output csv file

The csv output option can be used to create csv files.

Note that text column eol characters are replaced with spaces in csv outputs.

Scripts that create multiple Mnet::Report objects with the output option set
to csv need to ensure that the filenames are different, otherwise that single
will be created with possibly different columns mixed together and missing
heading rows.

All csv output fields are double quoted, and double quote are escaped with an
extra double quote.

=cut

    # read input object
    my $self = shift // croak("missing self arg");
    my $row = shift;
    DEBUG("_output_csv starting");

    # note output csv filename
    die "unable to parse csv filename" if $self->{output} !~ /^csv:(.+)/;
    my $file = $1;

    # declare sub to quote and escape csv value
    #   eol chars removed so concurrent batch outputs don't intermix
    #   double quotes are escaped with an extra double quote
    #   value is prefixed and suffixed with double quotes
    sub _output_csv_escaped {
        my $value = shift // "";
        $value =~ s/(\r|\n)/ /g;
        $value =~ s/"/""/g;
        $value = '"'.$value.'"';
        return $value;
    }

    # determine if headings row is needed
    #   headings are needed if current script is not a batch script
    #   headings are needed for parent process of batch executions
    my $headings_needed = 0;
    if (not $INC{"Mnet/Batch.pm"} or not $MNet::Batch::fork_called) {
        $headings_needed = 1;
    }

    # attempt to open csv file for output
    #   open to create anew if headings are needed, perhaps batch parent
    #   otherwise open to append, perhaps batch children outputting rows
    my $fh = undef;
    if ($headings_needed) {
        open($fh, ">", $file) or FATAL("unable to open $file, $!");
    } else {
        open($fh, ">>", $file) or FATAL("unable to open $file, $!");
    }

    # output heading row, if needed
    if ($headings_needed) {
        my @headings = ();
        foreach my $column (@{$self->{columns_order}}) {
            push @headings, _output_csv_escaped($column);
        }
        syswrite $fh, join(",", @headings) . "\n";
    }

    # output data row, if defined
    #   this will be undefined when called from new method
    if (defined $row) {
        my @data = ();
        foreach my $column (@{$self->{columns_order}}) {
            push @data, _output_csv_escaped($row->{$column});
        }
        syswrite $fh,, join(",", @data) . "\n";
    }

    # close output csv file
    close $fh;

    # finished _output_csv method
    DEBUG("_output_csv finished");
    return;
}



sub _output_dump {

=head1 output dump

The dump output option writes one row per line in Data::Dumper format prefixed
by the table name as the variable name.

This dump output can be read back into a perl script as follows:

 use Data::Dumper;
 while (<STDIN>) {
    my ($line, $var) = ($_, undef);
    my $table = $1 if $line =~ s/^\$(\S+)/\$var/ or die;
    eval "$line";
    print Dumper($var);
 }

Note that dump output is appended to the specified file, so the perl unlink
command can be used to remove these files prior to each Mnet::Report new call,
if desired. This means it is ok for multiple Mnet::Report objects to write
data to the same file. Use 'dump:/dev/stdout' to output to the terminal.

=cut

    # read input object
    my $self = shift // croak("missing self arg");
    my $row = shift // return;
    DEBUG("_output_dump starting");

    # note output dump filename
    die "unable to parse dump filename" if $self->{output} !~ /^dump:(.+)/;
    my $file = $1;

    # attempt to open dump file for appending
    open(my $fh, ">>", $file) or FATAL("unable to open $file, $!");

    # output data row
    #   this will be undefined if called from new method
    if (defined $row) {
        my $dump = Mnet::Dump::line($row);
        syswrite $fh, "\$$self->{table} = $dump;\n";
    }

    # finished _output_dump method
    DEBUG("_output_dump finished");
    return;
}



sub _output_json {

=head1 output json

The dump output option writes one row per line in json format prefixed by the
table name as the variable name.

This json output can be read back into a perl script as follows:

 use JSON;
 use Data::Dumper;
 while (<STDIN>) {
    my ($line, $var) = ($_, undef);
    my $table = $1 if $line =~ s/^(\S+) = // or die;
    $var = decode_json($line);
    print Dumper($var);
 }

Note that json output is appended to the specified file, so the perl unlink
command can be used to remove these files prior to each Mnet::Report new call,
if desired. This means it is ok for multiple Mnet::Report objects to write
data to the same file. Use 'dump:/dev/stdout' to output to the terminal.

=cut

    # read input object
    my $self = shift // croak("missing self arg");
    my $row = shift // return;
    DEBUG("_output_json starting");

    # abort with an error if JSON module is not available
    croak("Mnet::Report json output requires perl JSON module is installed")
        if not $INC{'JSON.pm'} and not eval("require JSON; 1");

    # note output json filename
    die "unable to parse json filename" if $self->{output} !~ /^json:(.+)/;
    my $file = $1;

    # attempt to open dump file for appending
    open(my $fh, ">>", $file) or FATAL("unable to open $file, $!");

    # output data row
    #   this will be undefined if called from new method
    if (defined $row) {
        my $json = encode_json($row);
        syswrite $fh, "$self->{table} = $json;\n";
    }

    # finished _output_json method
    DEBUG("_output_json finished");
    return;
}



sub _output_sql {

=head1 output sql

The dump output option writes one row perl line as sql insert statements.

Note that sql output is appended to the specified file, so the perl unlink
command can be used to remove this file prior to the Mnet::Report new call,
if desired. This means it is ok for multiple Mnet::Report objects to write
data to the same file. Use 'dump:/dev/stdout' to output to the terminal.

=cut

    # read input object
    my $self = shift // croak("missing self arg");
    my $row = shift // return;
    DEBUG("_output_sql starting");

    # note output sql filename
    die "unable to parse sql filename" if $self->{output} !~ /^sql:(.+)/;
    my $file = $1;

    # attempt to open sql file for appending
    open(my $fh, ">>", $file) or FATAL("unable to open $file, $!");

    # output data row
    #   this will be undefined if called from new method
    #   double quote column names to handle unusual column names
    #   escape multiline outputs which concurrent batch procs can clobber
    if (defined $row) {
        my @sql_columns = ();
        my @sql_values = ();
        foreach my $column (@{$self->{columns_order}}) {
            push @sql_columns, '"' . $column . '"';
            my $value = $row->{$column} // "";
            $value =~ s/'/''/g;
            $value =~ s/\r/'+CHAR(10)+'/g;
            $value =~ s/\n/'+CHAR(13)+'/g;
            push @sql_values, "'" . $value . "'";
        }
        my $sql = "INSERT INTO \"$self->{table}\" ";
        $sql .= "(" . join(",", @sql_columns) . ") ";
        $sql .= "VALUES (" . join(",", @sql_values) . ");";
        syswrite $fh, "$sql\n";
    }

    # finished _output_sql method
    DEBUG("_output_sql finished");
    return;
}



sub _output_test {

=head1 output test

Normal Mnet::Report output is overriden when the Mnet::Test module is loaded
and the --test cli option is present. Normal file output is suppressed and
instead test report output is sent to stdout.

The test output option may also be set maually.

=cut

    # read input object
    my $self = shift // croak("missing self arg");
    my $row = shift;
    DEBUG("_output_test starting");

    # determine width of widest column, for formatting
    my $width = 0;
    foreach my $column (@{$self->{columns_order}}) {
        $width = length($column) if length($column) > $width;
    }

    # output data row to Mnet::Log
    #   row will be undefined if called from new method
    if (defined $row and $INC{"Mnet/Log.pm"}) {
        my $prefix = "row output table $self->{table}";
        INFO("$prefix {");
        foreach my $column (@{$self->{columns_order}}) {
            my $value = Mnet::Dump::line($row->{$column});
            INFO(sprintf("$prefix    %-${width}s => $value", $column));
        }
        INFO("$prefix }");

    # otherwise output data row to standard output
    #   row will be undefined if called from new method
    } elsif (defined $row) {
        syswrite STDOUT, "Mnet::Report row output table $self->{table} = {\n";
        foreach my $column (@{$self->{columns_order}}) {
            my $value = Mnet::Dump::line($row->{$column});
            syswrite STDOUT, sprintf("  %-${width}s => $value\n", $column);
        }
        syswrite STDOUT, "}\n";
    }

    # finished _output_test method
    DEBUG("_output_test finished");
    return;
}



=head1 SEE ALSO

 Mnet
 Mnet::Test

=cut

# normal package return
1;

