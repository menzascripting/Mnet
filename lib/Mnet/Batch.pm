package Mnet::Batch;

=head1 NAME

Mnet::Batch;

=head1 SYNOPSIS

This module can be used in a script to concurrently process a --batch list of
command option lines.

For example, you might run a script sequentially, like this:

 script.pl --sample 1
 script.pl --sample 2a
 script.pl --sample ...

This module allows you to process a list of option command lines, like this:

 echo '
     --sample 1
     --sample 2a
     --sample ...
 ' | script.pl --batch /dev/stdin

In the above example the script accepts a --batch list of command option lines
and forks a child worker process for each line in the list. The --batch list
option can be set to a file, a named pipe, or /dev/stdin as above.

The --batch list lines are processes one at a time unless linux /proc/stat is
detected, in which case list command lines are processes concurrently as fast
as possible without overutilizing the cpu.

Below is a sample script supporting the Mnet::Batch --batch option, as used in
the examples above:

 # usually combined with Mnet::Opts::Cli
 use Mnet::Batch;
 use Mnet::Opts::Cli;

 # define --sample cli option
 Mnet::Opts::Cli::define({
     getopt   => "sample=s",
     help_tip => "set to input string",
 });

 # usually cli options are read before calling Mnet::Batch::fork()
 my $cli = Mnet::Opts::Cli->new;

 # fork child worker processes and exit when parent is finished
 #   returns opts for worker processes and true for parent process
 $cli = Mnet::Batch::fork($cli) or exit;

 # code below runs for batch workers and non-batch executions
 print "sample = $cli->{sample}\n";

Note that a script using the Mnet::Batch module will exit with an error if the
Mnet::Opts::Cli new method was used to parse the command line and the --batch
option is set and Mnet::Batch::fork function was never called.

Refer also to the documentation for the Mnet::Batch::fork function for more
information.

=cut

# required modules
use warnings;
use strict;
use Carp;
use Mnet::Log::Conditional qw( DEBUG INFO WARN FATAL NOTICE );
use Mnet::Opts::Cli::Cache;
use Mnet::Opts::Set;
use POSIX;
use Time::HiRes;



# init global variables and cli options for this module
#   $fork_called used by end block to warn if Mnet::Batch::fork was not called
#   $fork_called also used by Mnet::Report to print csv heading row corrently
INIT {
    my $fork_called = undef;
    Mnet::Opts::Cli::define({
        getopt      => 'batch=s',
        help_tip    => 'process command lines from file',
        help_text   => '
            use --batch to process a list of command lines from specified file
            batch list may be read from standard input by specifying /dev/stdin
            for a dir try: find /dir -name *.test | sed "s/^/--replay /" | ...
            children are --silent, warnings are issued for child exit errors
            refer also to perldoc Mnet::Batch for more information
        ',
    }) if $INC{"Mnet/Opts/Cli.pm"};
}



sub fork {

=head1 \%child_opts = Mnet::Batch::fork(\%opts)

=head1 S< > or ($child_opts, @child_extras) = Mnet::Batch::fork(\%opts)

The Mnet::Batch::fork function requires an input options hash ref containing at
least a batch setting key.

The returned child opts hash ref will contain settings from the input opts hash
overlaid with options from the current batch command options line. Extra args
from batch command option lines are also returned if called in list context.

The returned child opts hash ref will be undefined for the batch parent process
when the parent process is finished.

 my ($cli, @extras) = Mnet::Opts::Cli->new;
 ($cli, @extras) = Mnet::Batch::fork($cli);
 exit if not defined $cli;

Also note that this function can be called by scripts that are not using the
Mnet::Opts::Cli module to parse command line options. In this case the returned
child_opts value will be a scalar containing the input batch line, as in the
following example:

 ( echo "line = 1"; echo "line = 2" ) | perl -e '
     use Mnet::Batch
     my $line = Mnet::Batch::fork({ batch => "/dev/stdin" }) // exit;
     die "child should have line set" if $line !~ /^line =/
 '

Refer also to the SYNOPSIS section of this perldoc for more information.

=cut

    # read input opts hash ref arg
    my $opts = shift // croak("missing opts arg");

    # set global fork_called var true for end block warnings
    #   end block warns if --batch opt is set and Mnet::Batch::fork not called
    $Mnet::Batch::fork_called = 1;

    # return input options if --batch option is not set
    if (not $opts->{batch}) {
        DEBUG("fork returning undef, batch option not set");
        return $opts;
    }

    # disable Mnet::Test outputs for batch parent
    #   we don't want to worry about batch parent polluting child outputs
    #   we enable Mnet::Test output capture for children after fork
    Mnet::Test::disable() if $INC{"Mnet/Test.pm"};

    # abort with error if --record set to filename for all batch children
    #   this would result in all children trying to save to the same file
    FATAL("invalid non-null --record with --batch on parent command line")
        if defined $opts->{record} and $opts->{record} ne "";

    # abort with error if --record set the same for all batch children
    #   to be safe, so all children don't write to same file with null --record
    FATAL("invalid --replay with --batch on parent command line")
        if defined $opts->{replay};

    # read lines of --batch list file
    my @batch_lines = ();
    open(my $fh, "<", $opts->{batch}) or FATAL("fork batch $opts->{batch}, $!");
    while (<$fh>) {
        chomp(my $line = $_);
        $line =~ s/^\s*#.*//g;
        next if $line !~ /\S/;
        push @batch_lines, $line;
    }
    close $fh;

    # output count of batch lines read
    NOTICE("fork read ".scalar(@batch_lines)." lines from $opts->{batch}");

    # use hash ref to note the batch line associated with each forked child pid
    #   used in child sig handler to output batch line for reaped child pid
    my $pid_batch_lines = {};

    # init hash ref used to track when it is ok to fork, refer to _fork_ok()
    my $fork_data = { child_count => 0, child_min => 1, idle_target => 10 };

    # prepare signal handler to properly wait on forked child processes
    #   otherwise these would remain in process table as zombies
    #   warn when reaped children exited with an error
    $SIG{CHLD} = sub {
        while ((my $child = waitpid(-1, &POSIX::WNOHANG)) > 0) {
            $fork_data->{child_count}--;
            my ($error, $sig, $dump) = ($? >> 8, $? & 127, $? & 128);
            my $exit_status = "exit $error, sig $sig, dump $dump";
            $exit_status .= ", $0 $pid_batch_lines->{$child}";
            if ($error or $sig or $dump) {
                WARN("fork reaped child pid $child, $exit_status");
            } else {
                NOTICE("fork reaped child pid $child, $exit_status");
            }
        }
    };

    # loop through batch lines, forking a child worker process for each line
    foreach my $batch_line (@batch_lines) {

        # wait until it is safe to fork another child
        #   refer to _fork_ok() function for more info
        while (1) { last if _fork_ok($fork_data); }

        # fork returns child pid to parent proc, 0 to child, "undef" on failure
        my $pid = fork();

        # handle failure to fork
        if (not defined $pid) {
            warn "fork failed forking child, $!";
            sleep 10;

        # child process returns to continue execution, return forked child opts
        #   children load Mnet::Opts::Set::Silent, quiet/silent opts still work
        #   Mnet::Log::batch_fork resets script start time for forked child
        #   Mnet::Opts::Cli::batch_fork parses cli opts and batch child opts
        #   what is returned depends on context Mnet::Batch::fork() was called
        #       batch_line is returned if script doesn't use Mnet::Opts::Cli
        #       otherwise returns child opts and extras depending on context
        } elsif ($pid == 0) {
            Mnet::Opts::Set::enable("silent");
            DEBUG("fork child forked, pid $$");
            Mnet::Log::batch_fork() if $INC{"Mnet/Log.pm"};
            Mnet::Test::enable() if $INC{"Mnet/Test.pm"};
            if (not $INC{"Mnet/Opts/Cli.pm"}) {
                return $batch_line;
            } elsif (wantarray) {
                my ($child_opts, @child_extras)
                    = Mnet::Opts::Cli::batch_fork($batch_line);
                return ($child_opts, @child_extras);
            } else {
                my $child_opts = Mnet::Opts::Cli::batch_fork($batch_line);
                return $child_opts;
            }
        }

        # output pid of child that we just forked
        #   parent process tracks batch line for each child pid
        #   parent process increments count of child workers
        NOTICE("fork forked child pid $pid, $0 $batch_line");
        $pid_batch_lines->{$pid} = $batch_line;
        $fork_data->{child_count}++;

    # continue loop to process batch list with forked child workers
    }

    # wait for remaining child processes to finish, log how many are waiting
    my $wait_count = $fork_data->{child_count} + 1;
    while ($fork_data->{child_count}) {
        if ($fork_data->{child_count} < $wait_count) {
            $wait_count = $fork_data->{child_count};
            NOTICE("fork waiting on $wait_count child processes");
        }
        sleep 1;
    }

    # output that parent finished processing batch list, along with idle info
    my $fork_info = "processed ".scalar(@batch_lines)." children";
    if ($fork_data->{cpu_count}) {
        $fork_info .= ", max $fork_data->{stat_max} concurrent";
        if ($fork_data->{stat_idle_c} and $fork_data->{stat_idle_s}) {
            my $avg = int($fork_data->{stat_idle_s}/$fork_data->{stat_idle_c});
            $fork_info .= ", average $avg\% idle cpu";
        }
    }
    NOTICE("fork $fork_info");

    # finished Mnet::Batch::fork() function, return undef for parent
    DEBUG("fork parent finished");
    return undef;
}



sub _fork_ok {

# $ok = _fork_ok(\%fork_data)
# purpose: return true if it is ok to fork another child process
# \%fork_data: caller should init child_count=>0, child_min=>1, idle_target=>10
# $ok: set true if ok to fork, otherwise wait in a loop until it is ok

    # read input fork_data hash, the following keys may be used:
    #   child_count => set to count of currently running forked children
    #   child_max   => absolute upper child limit, calculated from cpu_count
    #   child_min   => set from caller may be adjusted for /proc/stat idle cpu
    #   cpu_count   => set from /proc/stat, indicates /proc/stat is available
    #   idle_target => set from caller to percent cpu utilization to leave idle
    #   last_idle   => set to count of idle ticks from last /proc/stat sample
    #   last_ticks  => set to total cpu ticks from last /proc/stat sample
    #   last_time   => set to unix time that /proc/stat was last sampled
    #   stat_idle_c => count of idle cpu samples, used to get average idle cpu
    #   stat_idle_s => sum of idle cpu samples, used to get average idle cpu
    #   stat_max    => highest number of concurrent children during execution
    my $fork_data = shift // croak("missing fork_data arg");

    # init cpu_count from /proc/stat the first time we are called
    #   this will be used later to adjust child_min based on idle cpu
    #   cpu_count is set undef if /proc/stat is not available
    #   child_max is set based on count of cpu cores
    if (not exists $fork_data->{cpu_count}) {
        $fork_data->{cpu_count} = undef;
        if (open(my $fh, "<", "/proc/stat")) {
            while (<$fh>) {
                $fork_data->{cpu_count}++ if $_ =~ /^cpu\d+/;
            }
            close $fh;
            $fork_data->{child_max} = $fork_data->{cpu_count} * 64;
            my $cpu_cores = "detected $fork_data->{cpu_count} cpu cores";
            my $child_max = "child max $fork_data->{child_max}";
            my $idle_target = "idle cpu target $fork_data->{idle_target}\%";
            NOTICE("fork $cpu_cores, setting $child_max and $idle_target");
        }
    }

    # check idle cpu and adjust child_min if /proc/stat was accessible
    _fork_ok_idle($fork_data) if $fork_data->{cpu_count};

    # maintain stat of greatest number of max children concurrently running
    $fork_data->{stat_max} = $fork_data->{child_min}
        if not defined $fork_data->{stat_max}
        or $fork_data->{child_min} > $fork_data->{stat_max};

    # return true if count of current child is less than maximum children
    return 1 if $fork_data->{child_count} < $fork_data->{child_min};

    # sleep a minimal amount or time
    #   this gives other procs a chance to run
    Time::HiRes::usleep(1);

    # finished _fork_ok, return false
    #   we're not ready to fork another child yet
    return undef;
}



sub _fork_ok_idle {

# _fork_ok_idle(\%fork_data)
# purpose: adjust child_min in fork_data hash ref based on cpu utilization
# \%fork_data: refer to the _fork_ok() function for more information

    # read input fork_data hash
    my $fork_data = shift // croak("missing fork_data arg");

    # return if three seconds hasn't gone by since last cpu utilization check
    return if $fork_data->{last_time} and $fork_data->{last_time} + 3 > time;

    # read first line of /proc/stat, with overall cpu utilization
    #   /proc/stat counts cpu ticks, typically 1/100 of a second but can vary
    open(my $fh, "<", "/proc/stat") or FATAL("error opening /proc/stat, $!");
    my $cpu_stats = <$fh>;
    close $fh;

    # note current idle and total cpu ticks, typically 1/100 sec but can vary
    FATAL("error parsing /proc/stat, $cpu_stats")
        if $cpu_stats !~ /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;
    my ($cpu_idle, $cpu_ticks) = ($4, $1 + $2 + $3 + $4);

    # note last idle and total cpu ticks, from prior sample
    #   we end up returning our first time trhough when these are not yet set
    my $last_idle = $fork_data->{last_idle};
    my $last_ticks = $fork_data->{last_ticks};

    # set data for the next call to this sub
    $fork_data->{last_idle}  = $cpu_idle;
    $fork_data->{last_ticks} = $cpu_ticks;
    $fork_data->{last_time}  = time;

    # return on our first time through when prior cpu stats are not yet set
    return if not $last_idle or not $last_ticks;

    # calculate cpu idle percentage during last sample time
    #   divide idle ticks by total ticks then multiple by 100
    #   abort if no new total cpu ticks, to avoid a divide by zero error
    FATAL("error processing /proc/stat") if not $cpu_ticks - $last_ticks;
    my $pct_idle = ($cpu_idle - $last_idle) / ($cpu_ticks - $last_ticks) * 100;
    $fork_data->{stat_idle_s} += $pct_idle;
    $fork_data->{stat_idle_c}++;

    # compute the percentage of cpu idle and available for more batch children
    my $pct_avail = $pct_idle - $fork_data->{idle_target};

    # compute cpu utilization percentage used by each child process
    my $pct_child = (100 - $pct_idle) / $fork_data->{child_count};

    # adjust child_min using percentage of available idle cpu utilization
    #   increase child_min if we have extra idle cpu, otherwise decrease
    #   adjustments are based on the estimated cpu used per child
    $fork_data->{child_min} += int($pct_avail/$pct_child);

    # ensure that child_min is more than one and less than a max per cpu core
    my $limit = $fork_data->{cpu_count} * $fork_data->{child_max};
    $fork_data->{child_min} = $limit if $fork_data->{child_min} > $limit;
    $fork_data->{child_min} = 1 if $fork_data->{child_min} < 1;

    # finished _fork_ok_idle
    return;
}



# issue a warning if --batch set on cli and Mnet::Batch::fork sub never called
END {
    my $opts = Mnet::Opts::Cli::Cache::get({});
    FATAL("cli --batch was set and Mnet::Batch::fork() was never called")
        if $opts->{batch} and not $Mnet::Batch::fork_called;
}


=head1 SEE ALSO

 Mnet
 Mnet::Opts::Cli
 Mnet::Opts::Set

=cut

# normal end of package
1;

