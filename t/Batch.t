#!/usr/bin/env perl

# purpose: tests Mnet::Batch

# required modules
use warnings;
use strict;
use File::Temp;
use Test::More tests => 3;

#? create .t tests for Mnet::Batch, including opts and tests

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
    Mnet::Batch::fork($cli) or exit;
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

# replay both test files in batch mode
#? fix this test, it is failing and should pass
Test::More::is(`( echo --replay $file1; echo --replay $file2 ) | perl -e '
    $script
' -- --batch /dev/stdin --test 2>&1`, 'sample = 2
', 'replay batch mode');

#? add test fails with --sample app set in batch child and batch parent

# finished
exit;

