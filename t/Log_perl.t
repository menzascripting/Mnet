#!/usr/bin/env perl

# purpose: tests Mnet::Log perl die and warn handlers

# required modules
use warnings;
use strict;
use Test::More tests => 7;

# check output from perl compile warning for invalid 'foo' command
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log qw( DEBUG INFO WARN FATAL );
    use Mnet::Log::Test;
    foo;
' -- 2>&1`,
'Bareword "foo" not allowed while "strict subs" in use at -e line 6.
Execution of -e aborted due to compilation errors.
', 'perl compile warning');

# check output from perl runtime warning
{
    my $out = `perl -e '
        use warnings;
        use strict;
        use Mnet::Log qw( DEBUG INFO WARN FATAL );
        use Mnet::Log::Test;
        my \$x = 1 + undef;
    ' -- 2>&1`;
    $out =~ s/^(err - main perl warn,  at) .*/$1 .../m;
    $out =~ s/^(err - main perl warn,)\s+(Mnet::Log::__ANON__).*/$1   $2 .../m;
    Test::More::is($out, ' -  - Mnet::Log script -e started
ERR - main perl warn, Use of uninitialized value in addition (+) at -e line 6.
err - main perl warn,  at ...
err - main perl warn,   Mnet::Log::__ANON__ ...
err - main perl warn, $? = 0
 -  - Mnet::Log finished with errors
', 'perl runtime warning');
}

# check output from perl eval warning
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log qw( DEBUG INFO WARN FATAL );
    use Mnet::Log::Test;
    eval { warn "warn eval"; my \$x = 1 + undef; }
' -- 2>&1 | grep -v ^err`, ' -  - Mnet::Log script -e started
ERR - main perl warn, warn eval at -e line 6.
ERR - main perl warn, Use of uninitialized value in addition (+) at -e line 6.
 -  - Mnet::Log finished with errors
', 'perl eval warnings');

# check perl warnings in eval with sig handler trapping warnings
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Test;
    eval { local \$SIG{__WARN__} = sub{}; warn "warn eval" };
' -- 2>&1 | grep -v ^err`, '', 'perl eval sig warn handler');

# check output from perl warn command
{
    my $out = `perl -e '
        use warnings;
        use strict;
        use Mnet::Log qw( DEBUG INFO WARN FATAL );
        use Mnet::Log::Test;
        warn "warn command";
    ' -- 2>&1`;
    $out =~ s/^(err - main perl warn,  at) .*/$1 .../m;
    $out =~ s/^(err - main perl warn,)\s+(Mnet::Log::__ANON__).*/$1   $2 .../m;
    Test::More::is($out, ' -  - Mnet::Log script -e started
ERR - main perl warn, warn command at -e line 6.
err - main perl warn,  at ...
err - main perl warn,   Mnet::Log::__ANON__ ...
err - main perl warn, $? = 0
 -  - Mnet::Log finished with errors
', 'perl warn command');
}

# check output from perl die command
{
    my $out = `perl -e '
        use warnings;
        use strict;
        use Mnet::Log qw( DEBUG INFO WARN FATAL );
        use Mnet::Log::Test;
        die "die command";
    ' -- 2>&1`;
    $out =~ s/^(err - main perl die,  at) .*/$1 .../m;
    $out =~ s/^(err - main perl die,)\s+(Mnet::Log::__ANON__).*/$1   $2 .../m;
    Test::More::is($out, ' -  - Mnet::Log script -e started
ERR - main perl die, die command at -e line 6.
err - main perl die,  at ...
err - main perl die,   Mnet::Log::__ANON__ ...
err - main perl die, $? = 0
 -  - Mnet::Log finished with errors
', 'perl die command');
}

# check output from perl die eval
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Log qw( DEBUG INFO WARN FATAL );
    use Mnet::Log::Test;
    eval { die "die eval" };
    die if "\$@" ne "die eval at -e line 6.\n";
' -- 2>&1`, '', 'perl eval die');

# finished
exit;

