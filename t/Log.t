#!/usr/bin/env perl

# required modules
use warnings;
use strict;
use Test::More tests => 1;

# sample test
Test::More::is(`perl -e 'use warnings; use strict; use Mnet::Log::Test;
    use Mnet::Log qw( DEBUG INFO WARN FATAL );
    INFO("test");
' -- 2>&1`, ' -  - Mnet::Log script -e started
inf - main test
 -  - Mnet::Log finished with no errors
', 'sample test');

# finished
exit;

