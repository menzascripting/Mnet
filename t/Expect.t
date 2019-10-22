
# purpose: tests Mnet::Expect functionality

# required modules
#   Expect required in Mnet::Expect modules, best to find our here if missing
use warnings;
use strict;
use Expect;
use Test::More tests => 2;

# use current perl for tests
my $perl = $^X;

# check basic Mnet::Expect functionality
#   some cpan testers needed `grep -v log hex` to pass, must've closed first
Test::More::is(`echo; $perl -e '
    use warnings;
    use strict;
    use Mnet::Expect;
    use Mnet::Log qw( DEBUG );
    use Mnet::Log::Test;
    DEBUG("test");
    my \$expect = Mnet::Expect->new({
        debug => 1,
        spawn => "echo x-test",
    });
    die "expect undef" if not defined \$expect;
    \$expect->expect->expect(1, "-re", ".-test");
    \$expect->close;
' -- 2>&1 |grep -v pid |grep -v HASH |grep -v 'Mnet::Expect log hex: 0d 0a'`, '
 -  - Mnet::Log script -e started
dbg - Mnet::Expect new starting
dbg - Mnet::Expect new opts debug = 1
dbg - Mnet::Expect new opts spawn = "echo x-test"
dbg - Mnet::Expect new opts winsize = "99999x999"
dbg - Mnet::Expect new calling spawn
dbg - Mnet::Expect spawn starting
dbg - Mnet::Expect spawn arg: echo
dbg - Mnet::Expect spawn arg: x-test
dbg - Mnet::Expect spawn finished, returning true
dbg - Mnet::Expect log txt: x-test
dbg - Mnet::Expect close starting
dbg - Mnet::Expect close calling hard_close
dbg - Mnet::Expect close finished, hard_close confirmed
 -  - Mnet::Log finished with no errors
', 'new, expect, log, and close');

# check Mnet::Expect spawn error
Test::More::is(`echo; $perl -e '
    use warnings;
    use strict;
    use Mnet::Expect;
    use Mnet::Log;
    use Mnet::Log::Test;
    my \$expect = Mnet::Expect->new({ spawn => "uydfhkksl" });
' -- 2>&1 | sed 's/spawn error.*/spawn error/'`, '
 -  - Mnet::Log script -e started
DIE - Mnet::Expect spawn error
 -  - Mnet::Log finished with errors
', 'spawn error');

# finished
exit;

