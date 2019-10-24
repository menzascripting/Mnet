
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
' -- --debug-error /dev/stdout 2>&1 | head -n 7`, ' -  - Mnet::Log -e started
inf - Mnet::Opts::Cli new parsed opt cli debug-error = "/dev/stdout"
WRN - main error
 -  - Mnet::Log creating --debug-error /dev/stdout
 -  - Mnet::Log finished with errors
 -  - Mnet::Log -e started
dbg - Mnet::Version -e = ?
', 'debug default disabled');

# finished
exit;

