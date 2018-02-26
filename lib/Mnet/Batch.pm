package Mnet::Batch;

=head1 NAME

Mnet::Batch;

=head1 SYNOPSIS

#? finish me

=cut

#? do we want/need a --watchdog? how might parent and child have different?

# required modules
use warnings;
use strict;
use Mnet::Log::Conditional qw( DEBUG INFO NOTICE WARN FATAL );
use Mnet::Opts::Cli;
use Mnet::Opts::Cli::Cache;
use Mnet::Opts::Set;
use POSIX;



# init global variables and cli options for this module
INIT {
    our $child_count = 0;
    Mnet::Opts::Cli::define({
        getopt      => 'batch=s',
        help_tip    => 'process command lines from file',
        help_text   => '
            use --batch to process a list of command lines from specified file
            batch list may be read from standard input by specifying /dev/stdin
            for a dir try: find /dir -name *.test | sed "s/^/--replay /" | ...
            children are silent by default, override with --quiet or --nosilent
            #? finish me, mention concurency, limitations, caveats, etc
            refer to perldoc Mnet::Batch for more information.
        ',
    });
}



sub fork {

=head1 $parent = Mnet::Batch::fork(\%opts)

#? document me
#   returns parent set undef if no --batch, false for child, true for parent

=cut

    # read opts hash ref arg, or set parsed cli options
    my $opts = shift // Mnet::Opts::Cli->new;

    # return undef for no --batch option set
    if (not $opts->{batch}) {
        DEBUG("fork returning undef, batch option not set");
        return undef;
    }

    # read lines of --batch list file
    my @batch_lines = ();
    open(my $fh, "<", $opts->{batch}) or FATAL("fork batch $opts->{batch}, $!");
    push @batch_lines, $_ while <$fh>;
    chomp(@batch_lines);
    close $fh;

    # output count of batch lines read
    NOTICE("fork read ".scalar(@batch_lines)." lines from $opts->{batch}");

    # prepare signal handler to properly wait on forked child processes
    #   otherwise these would remain in process table as zombies
    $SIG{CHLD} = sub {
        while ((my $child = waitpid(-1, &POSIX::WNOHANG)) > 0) {
            $Mnet::Batch::child_count--;
            my ($exit, $sig, $dump) = ($? >> 8, $? & 127, $? & 128);
            my $exit_status = "exit $exit, sig $sig, dump $dump";
            NOTICE("fork reaped child pid $child, $exit_status");
        }
    };

    # loop through batch lines, forking a child worker process for each line
    foreach my $batch_line (@batch_lines) {

        #? need some way to rate limit batch forking
        #   target 10% idle, maybe a better/common way besides /proc cpu?

        # fork returns child pid to parent proc, 0 to child, "undef" on failure
        my $pid = fork();

        # handle failure to fork
        if (not defined $pid) {
            warn "fork failed forking child, $!";
            sleep 10;

        # child process returns to continue execution, return false for child
        #   children load Mnet::Opts::Set::Silent, change with --quiet or --nosilent
        } elsif ($pid == 0) {
            #? how will we fix Mnet::Log script start time for children?
            Mnet::Opts::Set::enable("silent");
            DEBUG("fork child forked, pid $$");
            Mnet::Test::enable() if $INC{"Mnet/Test.pm"};
            Mnet::Opts::Cli::batch($batch_line);
            DEBUG("fork child returning false");
            return 0;
        }

        # output pid of child that we just forked
        NOTICE("fork forked child pid $pid, $batch_line");

        # parent process increments count of child workers
        $Mnet::Batch::child_count++;

    # continue loop to fork child workers
    }

    # wait for remaining child processes to finish, log how many are waiting
    my $wait_count = $Mnet::Batch::child_count + 1;
    while ($Mnet::Batch::child_count) {
        if ($Mnet::Batch::child_count < $wait_count) {
            $wait_count = $Mnet::Batch::child_count;
            NOTICE("fork waiting on $wait_count child processes");
        }
        sleep 1;
    }

    # output that parent finished processing batch list, along with rate
    NOTICE("fork processed ".scalar(@batch_lines)." batch children");

    # finished Mnet::Batch::fork() function, return true for parent
    DEBUG("fork parent returning true");
    return 1;
}



=head1 SEE ALSO

 Mnet
 Mnet::Log::Conditional
 Mnet::Opts::Cli
 Mnet::Opts::Cli::Cache

=cut

# normal end of package
1;

