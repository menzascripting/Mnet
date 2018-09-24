#!/usr/bin/env perl

# purpose: tests Mnet::Dump

# required modules
use warnings;
use strict;
use Test::More tests => 1;

# check output from Mnet::Dump line function
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Dump;
    print Mnet::Dump::line(undef) . "\n";
    print Mnet::Dump::line(1) . "\n";
    print Mnet::Dump::line("test") . "\n";
    print Mnet::Dump::line([ 1, 2 ]) . "\n";
    print Mnet::Dump::line({ 1 => 2 }) . "\n";
' -- 2>&1`, 'undef
1
"test"
[1,2]
{"1" => 2}
', 'line function');

# finished
exit;

