#!/usr/bin/env perl

# purpose: tests Mnet::Log quiet

# required modules
use warnings;
use strict;
use Test::More tests => 6;

# check functions with Mnet::Opts::Set::Quiet pragma option
Test::More::is(`perl -e 'use warnings; use strict; use Mnet::Log::Test;
    use Mnet::Log qw( DEBUG INFO WARN FATAL );
    use Mnet::Opts::Set::Debug;
    use Mnet::Opts::Set::Quiet;
    DEBUG("debug");
    INFO("info");
    WARN("warn");
    FATAL("fatal");
' -- 2>&1`, 'WRN - main warn
DIE - main fatal
', 'functions with quiet pragma option');

# check methods with Mnet::Opts::Set::Quiet pragma option
Test::More::is(`perl -e 'use warnings; use strict; use Mnet::Log::Test;
    use Mnet::Log;
    use Mnet::Opts::Set::Debug;
    use Mnet::Opts::Set::Quiet;
    Mnet::Log->new->debug("debug");
    Mnet::Log->new->info("info");
    Mnet::Log->new->warn("warn");
    Mnet::Log->new->fatal("fatal");
' -- 2>&1`, 'WRN - main warn
DIE - main fatal
', 'methods with quiet pragma option');

# check methods with Mnet::Log->new object quiet option
Test::More::is(`perl -e 'use warnings; use strict; use Mnet::Log::Test;
    use Mnet::Log;
    use Mnet::Opts::Set::Debug;
    Mnet::Log->new({ quiet => 1})->debug("debug");
    Mnet::Log->new({ quiet => 1})->info("info");
    Mnet::Log->new({ quiet => 1})->warn("warn");
    Mnet::Log->new({ quiet => 1})->fatal("fatal");
' -- 2>&1`, 'WRN - main warn
DIE - main fatal
', 'quiet object option');

# check functions with --quiet cli option
Test::More::is(`perl -e 'use warnings; use strict; use Mnet::Log::Test;
    use Mnet::Log qw( DEBUG INFO WARN FATAL );
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli->new;
    DEBUG("debug");
    INFO("info");
    WARN("warn");
    FATAL("fatal");
' -- --quiet 2>&1`, 'WRN - main warn
DIE - main fatal
', 'quiet cli option');

# check perl warnings and die with quiet pragma and silent
#   error output from quiet overrides any conflicting silent setting
Test::More::is(`perl -e 'use warnings; use strict; use Mnet::Log::Test;
    use Mnet::Log;
    use Mnet::Opts::Set::Quiet;
    use Mnet::Opts::Set::Silent;
    eval { warn "warn eval" };
    warn "warn command";
    die "die command";
' -- 2>&1 | grep -v ^err`, 'ERR - main perl warn, warn eval at -e line 5.
ERR - main perl warn, warn command at -e line 6.
ERR - main perl die, die command at -e line 7.
', 'quiet perl warnings and die');

# check stdout and stderr with --quiet cli option
#   only Mnet::Log entries are affected by quiet
#   quiet other script output using /dev/null redirect
Test::More::is(`perl -e 'use warnings; use strict; use Mnet::Log::Test;
    use Mnet::Log;
    print STDOUT "stdout\n";
    print STDERR "stderr\n";
' -- --quiet 2>&1`, 'stdout
stderr
', 'quiet stdout and stderr');

# finished
exit;

