
# purpose: tests Mnet::Expect::Cli functionality

# required modules
#   Expect required in Mnet::Expect modules, best to find our here if missing
use warnings;
use strict;
use Expect;
use Test::More tests => 9;

# use current perl for tests
my $perl = $^X;

# comment on failed_re, applies to Mnet::Expect::Cli and subclasses like Ios
#   there was a problem when failed_re hit on text appearing in login banners
#       example: failed_re /refused/, banner "unauthorized access refused"
#   default failed_re changed to undef to avoid problem with default setting
#       undef works with any login banner, but has to timeout on failures
#       faster if failed_re can pick up 'connection refused", for example
#       users responsible for setting in their network, as noted in perldocs
#   refer to notes/ideas/tests in git commit 65d08eb, lib/Mnet/Expect/Cli.pm

# init perl code used for new login tests
#   for debug uncomment the use Mnet::Opts::Set::Debug line below
my $perl_new_login = "chmod 700 \$CLI; echo; $perl -e '" . '
    use warnings;
    use strict;
    use Mnet::Expect::Cli;
    # use Mnet::Log; use Mnet::Opts::Set::Debug;
    my $opts = { spawn => $ENV{CLI}, timeout => 2, failed_re => "fail" };
    $opts->{username} = "user" if "@ARGV" =~ /user/;
    $opts->{password} = "pass" if "@ARGV" =~ /pass/;
    $opts->{prompt_re} = undef if "@ARGV" =~ /no_prompt_re/;
    my $expect = Mnet::Expect::Cli->new($opts) or die "expect undef";
    syswrite STDOUT, "prompt = ".$expect->prompt_re."\n" if $expect->prompt_re;
    $expect->close;
' . "'";

# check new login with username, password, prompt$
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"User: \"; read INPUT
    echo -n \"Password: \"; read INPUT
    echo -n \"prompt\$ \"; read INPUT
    echo -n \"prompt\$ \"; read INPUT
' >\$CLI; $perl_new_login -- user pass 2>&1; rm \$CLI`, '
prompt = (^|\r|\n)prompt\$ \r?$
', 'new login with user, password, prompt $');

# check new login with username, no password, prompt%
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"username: \"; read INPUT
    echo -n \"prompt% \"; read INPUT
    echo -n \"prompt% \"; read INPUT
' >\$CLI; $perl_new_login -- user 2>&1; rm \$CLI`, '
prompt = (^|\r|\n)prompt% \r?$
', 'new login with username, no password, prompt%');

# check new login with passcode, no username, prompt#
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"passcode: \"; read INPUT
    echo -n \"prompt# \"; read INPUT
    echo -n \"prompt# \"; read INPUT
' >\$CLI; $perl_new_login -- pass 2>&1; rm \$CLI`, '
prompt = (^|\r|\n)prompt# \r?$
', 'new login with passcode, no username, prompt#');

# new login with no username, no password and prompt:
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"prompt: \"; read INPUT
    echo -n \"prompt: \"; read INPUT
' >\$CLI; $perl_new_login 2>&1; rm \$CLI`, '
prompt = (^|\r|\n)prompt: \r?$
', 'new login with no username, no password, prompt:');

# new login prompt match with extra prompt text
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"prompt:\"'"'"'\\n'"'"'\"prompt>\"; read INPUT
    echo -n \"prompt>\"; read INPUT
    echo -n \"prompt>\"; read INPUT
    echo -n \"prompt>\"; read INPUT
' >\$CLI; $perl_new_login 2>&1; rm \$CLI`, '
prompt = (^|\r|\n)prompt>\r?$
', 'new login with extra prompt, no trailing spaces prompt>');

# new login failed before username prompt
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"fail\"; read INPUT
' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
DIE - Mnet::Expect::Cli login failed_re matched "fail"
', 'new login failed before username prompt');

# new login failed after login prompt
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"login: \"; read INPUT
    echo -n \"fail\"; read INPUT
' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
DIE - Mnet::Expect::Cli login failed_re matched "fail"
', 'new login failed after login prompt');

# new login failed after password prompt
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"username: \"; read INPUT
    echo -n \"password: \"; read INPUT
    echo -n \"fail\"; read INPUT
' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
DIE - Mnet::Expect::Cli login failed_re matched "fail"
', 'new login failed after password prompt');

# new login with no user, password, or prompt
Test::More::is(`export CLI=\$(mktemp); echo '
' >\$CLI; $perl_new_login no_prompt_re 2>&1; rm \$CLI`, '
', 'new login with no user, password, or prompt');

# finished
exit;

