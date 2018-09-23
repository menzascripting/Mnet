#!/usr/bin/env perl

# purpose: tests Mnet::Opts::Cli precendence of options

# required modules
use warnings;
use strict;
use Test::More tests => 4;

# check default, using --quiet as our test option since it has a pragma
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    my \$cli = Mnet::Opts::Cli->new;
    warn "quiet" if defined \$cli->quiet;
' -- 2>&1`, ' -  - Mnet::Log script -e started
 -  - Mnet::Log finished with no errors
', 'default option value');

# check that pragma setting overrides default
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    use Mnet::Opts::Set::Quiet;
    my \$cli = Mnet::Opts::Cli->new;
    warn "quiet" if not \$cli->quiet;
' -- 2>&1`, '', 'Mnet::Opts::Set pragma');

# check that Mnet env var overrides pragma setting
Test::More::is(`export Mnet="--noquiet"; echo; perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    use Mnet::Opts::Set::Quiet;
    my \$cli = Mnet::Opts::Cli->new;
    warn "quiet" if \$cli->quiet;
' -- 2>&1`, '
 -  - Mnet::Log script -e started
inf - Mnet::Opts::Cli new parsed opt env quiet = 0
 -  - Mnet::Log finished with no errors
', 'Mnet enviroment variable');


# check that Mnet env var overrides pragma setting
Test::More::is(`export Mnet="--noquiet"; perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    use Mnet::Opts::Set::Quiet;
    my \$cli = Mnet::Opts::Cli->new;
    warn "quiet" if not \$cli->quiet;
' -- --quiet 2>&1`, '', 'command line');

# finished
exit;

