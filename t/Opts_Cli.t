#!/usr/bin/env perl

# purpose: tests Mnet::Opts::Cli

# required modules
use warnings;
use strict;
use Test::More tests => 9;

# check --version
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli->new;
' -- --version 2>&1 | grep -e Mnet -e 'exec path' | head -n 2 | wc -l`, '2
', 'display --version');

# check --help
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli->new;
' -- --help 2>&1 | grep -e Mnet -e '^ *--'`, 'Mnet options:
 --default [s]   reset recordable options or extra args
 --help [s]      display tips, or text for matching options
 --version       display version and system information
', 'display --help');

# parse cli opt and check that ARGV doesn't change
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli::define({ getopt => "sample=s" });
    my \$cli = Mnet::Opts::Cli->new;
    print \$cli->{sample} ."\n";
    print \$cli->sample ."\n";
    print "\@ARGV\n";
' -- --sample test 2>&1`, 'test
test
--sample test
', 'parse cli opt without changing ARGV');

# parse cli opt and extras and check that ARGV doesn't change
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli::define({ getopt => "sample=s" });
    my (\$cli, \@extras) = Mnet::Opts::Cli->new;
    print \$cli->{sample} ."\n";
    print \$cli->sample ."\n";
    print "\@extras\n";
    print "\@ARGV\n";
' -- --sample test extra1 extra2 2>&1`, 'test
test
extra1 extra2
--sample test extra1 extra2
', 'parse cli opt and extras without changing ARGV');

# check for error when reading invalid extra args
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli::define({ getopt => "sample=s" });
    my \$cli = Mnet::Opts::Cli->new;
' -- --sample test extra1 extra2 2>&1`, 'invalid extra args extra1 extra2
', 'invalid extra args');

# check for error when reading bad cli opt
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    my \$cli = Mnet::Opts::Cli->new;
' -- --sample test 2>&1`, 'invalid extra args --sample test
', 'invalid cli opt');

# check --default option for undef default
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli::define({ getopt => "sample=s" });
    warn "sample" if defined Mnet::Opts::Cli->new->sample;
' -- --sample test --default sample 2>&1`, '', 'undef --default');

# check --default option for defined default
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli::define({ getopt => "sample=s", default => "default" });
    warn "sample" if Mnet::Opts::Cli->new->sample ne "default";
' -- --sample test --default sample 2>&1`, '', 'defined --default');

# check logging of options
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    Mnet::Opts::Cli::define({ getopt => "sample=s" });
    Mnet::Opts::Cli->new;
' -- --sample test 2>&1`, ' -  - Mnet::Log script -e started
inf - Mnet::Opts::Cli new parsed opt cli sample = "test"
 -  - Mnet::Log finished with no errors
', 'invalid cli opt');

# finished
exit;

