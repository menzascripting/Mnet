#!/usr/bin/env perl

# purpose: tests Mnet::Test

# required modules
use warnings;
use strict;
use File::Temp;
use Test::More tests => 3;

# create temp record/replay/test file
my ($fh, $file) = File::Temp::tempfile( UNLINK => 1 );

# save record file without using Mnet::Opts::Cli
Test::More::is(`( perl -e '
    use warnings;
    use strict;
    use Mnet::Test;
    my \$opts = { record => shift };
    syswrite STDOUT, "stdout1\nstdout2\n";
    syswrite STDERR, "stderr1\nstderr2\n";
    my \$data = Mnet::Test::data(\$opts);
    \$data->{key} = "value";
    Mnet::Test::done(\$opts);
' -- $file >/dev/null 2>/dev/null; cat $file | sed "s/^ *//" ) 2>&1`,
"\$Mnet::Test::data = {
'Mnet::Test' => {
'outputs' => 'stdout1
stdout2
stderr1
stderr2
'
},
'main' => {
'key' => 'value'
}
};
", 'test record, no mnet cli');

# diff from test replay of record file without using Mnet::Opts::Cli
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Test;
    my \$opts = { replay => shift, test => 1 };
    syswrite STDOUT, "stdout1\nstdout3\n";
    syswrite STDERR, "stderr1\nstderr3\n";
    my \$data = Mnet::Test::data(\$opts);
    warn if \$data->{key} ne "value";
    Mnet::Test::done(\$opts);
' -- $file 2>&1 | sed "s/tmp.*/tmp\\/file/"`, 'stdout1
stdout3
stderr1
stderr3

-------------------------------------------------------------------------------
diff --test --replay /tmp/file
-------------------------------------------------------------------------------

@@ -1,4 +1,4 @@
 stdout1
-stdout3
+stdout2
 stderr1
-stderr3
+stderr2

', 'test diff replay, no mnet cli');

# check outputs using Mnet::Test::stdout and Mnet::Test::stderr file handles
Test::More::is(`perl -e '
    use warnings;
    use strict;
    use Mnet::Test qw( \$stdout \$stderr );
    syswrite \$stdout, "Mnet::Test::stdout\n";
    syswrite \$stderr, "Mnet::Test::stderr\n";
    my \$opts = { replay => shift, test => 1 };
    syswrite STDOUT, "stdout1\nstdout2\n";
    syswrite STDERR, "stderr1\nstderr2\n";
    my \$data = Mnet::Test::data(\$opts);
    warn if \$data->{key} ne "value";
    Mnet::Test::done(\$opts);
' -- $file 2>&1 | sed "s/tmp.*/tmp\\/file/"`, 'Mnet::Test::stdout
Mnet::Test::stderr
stdout1
stdout2
stderr1
stderr2

-------------------------------------------------------------------------------
diff --test --replay /tmp/file
-------------------------------------------------------------------------------

Test output is identical.

', 'test no diff replay using exported stdout and stderr, no mnet cli');

# finished
exit;

