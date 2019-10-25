
# purpose: tests Mnet::Log --debug-error

# required modules
use warnings;
use strict;
use Test::More tests => 1;

# use current perl for tests
my $perl = $^X;

# check that --debug-error works after a warning
Test::More::is(`$perl -e '
    use warnings;
    use strict;
    use Mnet::Log qw( WARN );
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    my \$cli = Mnet::Opts::Cli->new;
    WARN("error");
' -- --debug-error /dev/stdout 2>&1 | grep -A 3 DEBUG | grep -v DEBUG`, '
 -  - Mnet::Log -e started
dbg - Mnet::Version -e = ?
'."\n", 'debug default disabled');

# finished
exit;

