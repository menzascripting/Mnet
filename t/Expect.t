#!/usr/bin/env perl

# purpose: tests Mnet::Expect functionality

# required modules
use warnings;
use strict;
use Test::More tests => 2;

# check basic Mnet::Expect functionality
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Expect;
    use Mnet::Log qw/DEBUG/;
    use Mnet::Log::Test;
    DEBUG("test");
    my \$expect = Mnet::Expect->new({ spawn => "echo x-test", debug => 1 });
    \$expect->expect->expect(1, "-re", ".-test");
    \$expect->close;
' -- 2>&1 | grep -v pid | grep -v HASH`, ' -  - Mnet::Log script -e started
dbg - Mnet::Expect new starting
dbg - Mnet::Expect new opts debug = 1
dbg - Mnet::Expect new opts spawn = "echo x-test"
dbg - Mnet::Expect spawn starting
dbg - Mnet::Expect spawn finished, returning 1
dbg - Mnet::Expect log txt: x-test
dbg - Mnet::Expect log hex:  0d 0a
dbg - Mnet::Expect close starting
dbg - Mnet::Expect close calling hard_close
dbg - Mnet::Expect close returning, hard_close confirmed
 -  - Mnet::Log finished with no errors
', 'new, expect, log, and close');

# check Mnet::Expect spawn error
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Expect;
    use Mnet::Log;
    use Mnet::Log::Test;
    my \$expect = Mnet::Expect->new({ spawn => "uydfhkksl" });
    die "spawn_error undef" if not defined \$Mnet::Expect::spawn_error;
    die "expect defined" if defined \$expect;
    die "spawn error\\n";
' -- 2>&1 | grep -v ^err`, ' -  - Mnet::Log script -e started
ERR - main perl die, spawn error
 -  - Mnet::Log finished with errors
', 'spawn error');

# finished
exit;

