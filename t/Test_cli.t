#!/usr/bin/env perl

# purpose: tests Mnet::Test with Mnet::Opts::Cli module

# required modules
use warnings;
use strict;
use File::Temp;
use Test::More tests => 3;

# create temp record/replay/test file
my ($fh, $file) = File::Temp::tempfile( UNLINK => 1 );

# init script used to test mnet cli opt and extra arg
my $script = '
    use warnings;
    use strict;
    use Mnet::Opts::Cli;
    use Mnet::Test;
    Mnet::Opts::Cli::define({
        getopt      => "sample=i",
        default     => 1,
        recordable  => 1,
    });
    my ($cli, @extras) = Mnet::Opts::Cli->new;
    syswrite STDOUT, "sample = $cli->{sample}\n";
    syswrite STDOUT, "extras = @extras\n" if @extras;
';

# save record file using Mnet::Opts::Cli
Test::More::is(`( perl -e '
    $script
' -- --record $file --sample 2 extra; cat $file | sed "s/^ *//" ) 2>&1`,
"sample = 2
extras = extra
\$Mnet::Test::data = {
'Mnet::Opts::Cli' => {
'extras' => [
'extra'
],
'opts' => {
'sample' => 2
}
},
'Mnet::Test' => {
'outputs' => 'sample = 2
extras = extra
'
}
};
", 'test record with mnet cli opt and extra arg');

# test replay file using Mnet::Opts::Cli
Test::More::is(`perl -e '
    $script
' -- --replay $file --test 2>&1 | sed "s/tmp\\/.*/tmp\\/file/"`,
"sample = 2
extras = extra

-------------------------------------------------------------------------------
diff --test --replay /tmp/file
-------------------------------------------------------------------------------

Test output is identical.

", 'test replay with mnet cli opt and extra arg');


# test replay file using Mnet::Opts::Cli
Test::More::is(`perl -e '
    $script
' -- --replay $file --test --sample 3 arg 2>&1 | sed "s/tmp\\/.*/tmp\\/file/"`,
"sample = 3
extras = arg

-------------------------------------------------------------------------------
diff --test --replay /tmp/file
-------------------------------------------------------------------------------

@@ -1,2 +1,2 @@
-sample = 3
+sample = 2
-extras = arg
+extras = extra

", 'test replay with overridden cli opt and extra arg');

# finished
exit;

