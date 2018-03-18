#!/usr/bin/env perl

# purpose: tests Mnet::Log::Conditional

# required modules
use warnings;
use strict;
use Test::More tests => 4;

# check output from Mnet::Log::Conditional functions without Mnet::Log loaded
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log::Conditional qw( DEBUG INFO NOTICE WARN FATAL );
    use Mnet::Log::Test;
    use Mnet::Opts::Set::Debug;
    DEBUG("debug");
    INFO("info");
    NOTICE("notice");
    WARN("warn");
    FATAL("fatal");
' -- 2>&1`, 'warn
fatal
', 'function calls without Mnet::Log');

# check output from Mnet::Log::Conditional functions with Mnet::Log loaded
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Conditional qw( DEBUG INFO NOTICE WARN FATAL );
    use Mnet::Log::Test;
    use Mnet::Opts::Set::Debug;
    DEBUG("debug");
    INFO("info");
    NOTICE("notice");
    WARN("warn");
    FATAL("fatal");
' -- 2>&1 | grep -v "^dbg - Mnet::Version"`, ' -  - Mnet::Log script -e started
dbg - main debug
inf - main info
 -  - main notice
WRN - main warn
DIE - main fatal
 -  - Mnet::Log finished with errors
', 'function calls with Mnet::Log');

# check output from Mnet::Log::Conditional methods without Mnet::Log loaded
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log::Conditional;
    use Mnet::Log::Test;
    use Mnet::Opts::Set::Debug;
    Mnet::Log::Conditional->new->debug("debug");
    Mnet::Log::Conditional->new->info("info");
    Mnet::Log::Conditional->new->notice("notice");
    Mnet::Log::Conditional->new->warn("warn");
    Mnet::Log::Conditional->new->fatal("fatal");
' -- 2>&1`, 'warn
fatal
', 'method calls without Mnet::Log');

# check output from Mnet::Log::Conditional methods with Mnet::Log loaded
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Conditional;
    use Mnet::Log::Test;
    use Mnet::Opts::Set::Debug;
    Mnet::Log::Conditional->new->debug("debug");
    Mnet::Log::Conditional->new->info("info");
    Mnet::Log::Conditional->new->notice("notice");
    Mnet::Log::Conditional->new->warn("warn");
    Mnet::Log::Conditional->new->fatal("fatal");
' -- 2>&1 | grep -v "^dbg - Mnet::Version"`, ' -  - Mnet::Log script -e started
dbg - main debug
inf - main info
 -  - main notice
WRN - main warn
DIE - main fatal
 -  - Mnet::Log finished with errors
', 'method calls with Mnet::Log');

# finished
exit;

