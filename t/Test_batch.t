#!/usr/bin/env perl

# purpose: tests Mnet::Batch

# required modules
use warnings;
use strict;
use File::Temp;
use Test::More tests => 5;

# create multiple temp record/replay/test files
my ($fh1, $file1) = File::Temp::tempfile( UNLINK => 1 );
my ($fh2, $file2) = File::Temp::tempfile( UNLINK => 1 );

# init script used to test with mnet batch module
my $script = '
    use warnings;
    use strict;
    use Mnet::Batch;
    use Mnet::Opts::Cli;
    use Mnet::Test;
    Mnet::Opts::Cli::define({ getopt => "sample=i", recordable  => 1 });
    my $cli = Mnet::Opts::Cli->new;
    $cli = Mnet::Batch::fork($cli) or exit;
    syswrite STDOUT, "sample = $cli->{sample}\n";
';

# record file 1 for batch test
Test::More::is(`perl -e '
    $script
' -- --record $file1 --sample 1 2>&1`, 'sample = 1
', 'test record file 1');

# record file 2 for batch test
Test::More::is(`perl -e '
    $script
' -- --record $file2 --sample 2 2>&1`, 'sample = 2
', 'test record file 2');

# replay both tests passing in batch mode
Test::More::is(`( echo --replay $file1; echo --replay $file2 ) | perl -e '
    $script
' -- --batch /dev/stdin --test 2>&1`, '', 'batch replay passed');

# replay both tests failing in batch mode due to parent arg
Test::More::is(`( echo --replay $file1; echo --replay $file2 ) | perl -e '
    $script
' -- --batch /dev/stdin --test --sample 4 2>&1 | sed "s/ pid .*//"`,
'fork reaped child
fork reaped child
', 'batch exectution with new parent option');

# replay child test failing in batch mode due to child arg
Test::More::is(`( echo --replay $file1 --sample 3 ) | perl -e '
    $script
' -- --batch /dev/stdin --test 2>&1 | sed "s/ pid .*//"`, 'fork reaped child
', 'batch replay child failed');

# finished
exit;

