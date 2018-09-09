#!/usr/bin/env perl

# purpose: tests Mnet::Expect::Cli functionality

# required modules
use warnings;
use strict;
use Test::More tests => 8;
use Mnet::Expect::Cli;


#
# check new and login methods
#

# init perl code used for new login tests
my $perl_new_login = "chmod 700 \$CLI; echo; perl -e '" . '
    use warnings;
    use strict;
    use Mnet::Expect::Cli;
    use Mnet::Log::Test;
    # use Mnet::Log; use Mnet::Opts::Set::Debug;
    my $opts = { spawn => $ENV{CLI}, timeout => 1 };
    $opts->{username} = "user" if "@ARGV" =~ /user/;
    $opts->{password} = "pass" if "@ARGV" =~ /pass/;
    my $expect = Mnet::Expect::Cli->new($opts) or die "$Mnet::Expect::error\n";
    syswrite STDOUT, "prompt = ".$expect->prompt_re."\n";
    $expect->close;
' . "'";

# check new login with username, password, prompt$
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"User: \"; read INPUT
    echo -n \"Password: \"; read INPUT
    echo -n \"prompt\$ \"; read INPUT
    echo -n \"prompt\$ \"; read INPUT
' >\$CLI; $perl_new_login -- user pass 2>&1; rm \$CLI`, '
prompt = (\r|\n)\Qprompt$ \E$
', 'new login with user, password, prompt $');

# check new login with username, no password, prompt%
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"username: \"; read INPUT
    echo -n \"prompt% \"; read INPUT
    echo -n \"prompt% \"; read INPUT
' >\$CLI; $perl_new_login -- user 2>&1; rm \$CLI`, '
prompt = (\r|\n)\Qprompt% \E$
', 'new login with username, no password, prompt%');

# check new login with passcode, no username, prompt#
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"passcode: \"; read INPUT
    echo -n \"prompt# \"; read INPUT
    echo -n \"prompt# \"; read INPUT
' >\$CLI; $perl_new_login -- pass 2>&1; rm \$CLI`, '
prompt = (\r|\n)\Qprompt# \E$
', 'new login with passcode, no username, prompt#');

# new login with no username, no password and prompt:
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"prompt: \"; read INPUT
    echo -n \"prompt: \"; read INPUT
' >\$CLI; $perl_new_login 2>&1; rm \$CLI`, '
prompt = (\r|\n)\Qprompt: \E$
', 'new login with no username, no password, prompt:');

# new login with prompt> having no trailing spaces
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"prompt>\"; read INPUT
    echo -n \"prompt>\"; read INPUT
' >\$CLI; $perl_new_login 2>&1; rm \$CLI`, '
prompt = (\r|\n)\Qprompt>\E$
', 'new login prompt> without trailing space');

# new login refused before username prompt
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"refused\"; read INPUT
' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
login failed_re matched "refused"
', 'new login refused before username prompt');

# new login failed after login prompt
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"login: \"; read INPUT
    echo -n \"failed\"; read INPUT
' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
login failed_re matched "fail"
', 'new login failed after login prompt');

# new login failed after password prompt
Test::More::is(`export CLI=\$(mktemp); echo '
    echo -n \"username: \"; read INPUT
    echo -n \"password: \"; read INPUT
    echo -n \"denied\"; read INPUT
' >\$CLI; $perl_new_login user pass 2>&1; rm \$CLI`, '
login failed_re matched "denied"
', 'new login denied after password prompt');

#? finish me, add tests with extra prompt and fail text in bad places



#? finish me, check other Mnet::Expect::Cli functions, like command method, etc



# finished
exit;

