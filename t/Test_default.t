#!/usr/bin/env perl

# purpose: tests Mnet::Test with Mnet::Opts::Cli --default option

# required modules
use warnings;
use strict;
use File::Temp;
use Test::More tests => 4;

# create temp record/replay/test file
my ($fh, $file) = File::Temp::tempfile( UNLINK => 1 );

# init script used to test --default option
my $script = '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    use Mnet::Test;
    Mnet::Opts::Cli::define({
        getopt      => "sample=i",
        default     => 1,
        recordable  => 1,
    });
    my ($cli, @extras) = Mnet::Opts::Cli->new;
    syswrite STDOUT, "sample = $cli->{sample}\n";
    syswrite STDOUT, "extras = @extras\n" if @extras;
';

# save record file with sample and extra cli opts
Test::More::is(`perl -e '$script' -- --record $file --sample 2 extra 2>&1`,
'sample = 2
extras = extra
', 'test record with sample opt and extra cli arg');

# test replay file with sample and extra cli opts
Test::More::is(`perl -e '$script' -- --replay $file 2>&1`,
'sample = 2
extras = extra
', 'test replay with sample opt and extra arg');

# test replay file with --default sample opts
Test::More::is(`perl -e '$script' -- --replay $file --default sample 2>&1`,
'sample = 1
extras = extra
', 'test replay with default sample cli opt');

# test replay file with --default extra cli args
Test::More::is(`perl -e '$script' -- --replay $file --default 2>&1`,
'sample = 2
', 'test replay with default extra cli args');

# finished
exit;

