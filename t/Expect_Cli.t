#!/usr/bin/env perl

# purpose: tests Mnet::Expect::Cli functionality

# required modules
use warnings;
use strict;
use Test::More tests => 9;
use Mnet::Expect::Cli;

# init perl code used for new login tests
#   for debug uncomment the use Mnet::Opts::Set::Debug line below
my $perl_new_login = "chmod 700 \$CLI; echo; perl -e '" . '
    use warnings;
    use strict;
    use Mnet::Expect::Cli;
    # use Mnet::Log; use Mnet::Opts::Set::Debug;
    my $opts = { spawn => $ENV{CLI}, timeout => 2, failed_re => "fail" };
    $opts->{username} = "user" if "@ARGV" =~ /user/;
    $opts->{password} = "pass" if "@ARGV" =~ /pass/;
    $opts->{prompt_re} = undef if "@ARGV" =~ /no_prompt_re/;
    my $expect = Mnet::Expect::Cli->new($opts);
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

# new login skipped pre-login banner fail text
#   this goes with Mnet::Expect::Cli to-do on failed_re matching banner text
#   ideally we could enable this test, refer to _login to-do note for more info
#Test::More::is(`export CLI=\$(mktemp); echo '
#    echo \"banner start\"; echo \"not failed\"; echo \"banner end\"
#    echo -n \"username: \"; read INPUT
#    echo -n \"password: \"; read INPUT
#    echo -n \"prompt% \"; read INPUT
#    echo -n \"prompt% \"; read INPUT
#' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
#prompt = (^|\r|\n)prompt% \r?$
#', 'new login skipped pre-login banner fail text');

# new login skipped post-login banner fail text
#   this goes with Mnet::Expect::Cli to-do on failed_re matching banner text
#   ideally we could enable this test, refer to _login to-do note for more info
#Test::More::is(`export CLI=\$(mktemp); echo '
#    echo -n \"username: \"; read INPUT
#    echo -n \"password: \"; read INPUT
#    echo \"banner start\"; echo \"not failed\"; echo \"banner end\"
#    echo -n \"prompt% \"; read INPUT
#    echo -n \"prompt% \"; read INPUT
#' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
#prompt = (^|\r|\n)prompt% \r?$
#', 'new login skipped post-login banner fail text');

# new login username not needed
#   this goes with Mnet::Expect::Cli to-do on failed_re matching banner text
#   ideally we could enable this test, refer to _login to-do note for more info
#Test::More::is(`export CLI=\$(mktemp); echo '
#    echo -n \"password: \"; read INPUT
#    echo -n \"prompt% \"; read INPUT
#    echo -n \"prompt% \"; read INPUT
#' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
#prompt = (^|\r|\n)prompt% \r?$
#', 'new login username not needed');

# new login username and password not needed
#   this goes with Mnet::Expect::Cli to-do on failed_re matching banner text
#   ideally we could enable this test, refer to _login to-do note for more info
#Test::More::is(`export CLI=\$(mktemp); echo '
#    echo -n \"password: \"; read INPUT
#    echo -n \"prompt% \"; read INPUT
#    echo -n \"prompt% \"; read INPUT
#' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
#prompt = (^|\r|\n)prompt% \r?$
#', 'new login username and passowrd not needed');

# finished
exit;

