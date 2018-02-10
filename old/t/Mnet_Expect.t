# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Expect_telnet.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; } or die "perl File::Temp module not found";
eval { require Net::Telnet; } or die "perl File::Temp module not found";
eval { require Expect; };
&plan(skip_all => "perl Expect module not installed") if $@;

# Insert your test code below, refer to Test::More man page

# init testing command and output vars
my ($cmd, $out);

# port that we can use for telnet test
my $telnet_port = "2323";

# output netstat showing status of telnet server
my $telnet_test = "if [ -n \"`netstat -an | grep $telnet_port`\" ]; then ";
$telnet_test .= "echo server confirmed listening on port $telnet_port; else ";
$telnet_test .= "echo server NOT LISTENING on port $telnet_port; fi ";

# setup perl test telnet client code
my $perl_test_telnet = '
    perl -e \'
        use warnings;
        use strict;
        use Mnet;
        use Mnet::Expect;
        my $cfg = &object;
        &log(5, "(starting) ".$cfg->{"command"}." =~ ".$cfg->{"output"});
        my $telnet = new Mnet::Expect({"expect-detail" => 1})
            or die "failed to open expect session";
        my $output = $telnet->command($cfg->{"command"});
        $telnet->close("exit");
        my $regex = $cfg->{"output"};
        if ($output =~ /\Q$regex\E/i) {
            &log(5, "(ok) ".$cfg->{"command"}." =~ ".$cfg->{"output"});
        } else {
            &log(4, "(not ok) ".$cfg->{"command"}." =~ ".$cfg->{"output"});
        }
    \' - \\
';

# setup perl test telnet server code
my $perl_test_server = '
    # sockstat command is freebsd specific, perhaps use netstat instead
    #if [ -n "`sockstat | grep \'*:2323\' | awk \'{ print $3 }\'`" ]; then
    #    kill `sockstat | grep \'*:2323\' | awk \'{ print $3 }\'`;
    #fi
    perl -e \'
        use warnings;
        use strict;
        use Socket;
        my ($prompt_username, $valid_username) = ("Username: ", "testuser");
        my ($prompt_password, $valid_password) = ("Password: ", "testpass");
        my ($enable_mode, $valid_enable) = (0, "testenable");
        my $prompt = "telnet ";
        # $prompt = "telnet>";
        # $prompt = "telnet#";
        # $prompt = "telnet(config)#";
        # $prompt = "telnet (enable)";
        # $prompt = "rp/0/rp0/cpu0:telnet#";
        my $EOL = "\015\012";
        my $port = shift || 2345;
        my $proto = getprotobyname("tcp");
        die "invalid port $port" if not $port or $port !~ /^(\d+)$/;
        my $login_flag = shift;
        $login_flag = 1 if not defined $login_flag;
        socket(Server, PF_INET, SOCK_STREAM, $proto)
            or die "socket: $!";
        setsockopt(Server, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
            or die "setsockopt: $!";
        bind(Server, sockaddr_in($port, INADDR_ANY))
            or die "bind: $!";
        listen(Server,SOMAXCONN)
            or die "listen: $!";
        print "telnet server pid $$ on port $port started\n";
        my $paddr = accept(Client,Server);
        while ($login_flag) {
            syswrite(Client, $EOL);
            syswrite(Client, $prompt_username);
            my $input_username = &input;
            syswrite(Client, $prompt_password);
            my $input_password = &input;
            last if $input_username eq $valid_username
                and $input_password eq $valid_password;
            syswrite(Client, $EOL."Login error".$EOL);
        }
        syswrite(Client, $EOL."Greetings!".$EOL.$EOL);
        while (1) {
            syswrite(Client, $prompt);
            if ($prompt eq "telnet") {
                syswrite(Client, "> ") if not $enable_mode;
                syswrite(Client, "# ") if $enable_mode;
            }
            my $input = &input;
            next if $input !~ /\S/;
            if ($input eq "enable") {
                syswrite(Client, "Enable password: ");
                my $input_enable = &input;
                if ($input_enable eq $valid_enable) {
                    $enable_mode = 1;
                } else {
                    syswrite(Client, "Authorization failed".$EOL);
                }
                syswrite(Client, $EOL);
                next;
            }
            if ($input eq "dump") {
                my $ouput = "";
                for (my $loop = 1; $loop < 1000; $loop++) {
                    syswrite(Client, "line $loop".$EOL);
                }
            }
            last if $input eq "exit";
            syswrite(Client, "input = $input".$EOL.$EOL);
        }
        close Client;
        print "telnet server pid $$ on port $port exiting\n";
        sub input {
            my $count = 0;
            while (1) {
                local $/ = "\r";
                my $input = <Client>;
                if (not defined $input) {
                    $count++;
                    sleep 1;
                    die "$0 $$: server on port $port died\n" if $count > 30;
                    next;
                }
                $input =~ s/^\s*(.+)\s*$/$1/;
                $input =~ s/(\n|\r)$//g;
                syswrite (Client, $EOL);
                return $input;
            }
        }
    \' \\
';

# test telnet getting connect error, use Net::Telnet
my $timeout_ip = "255.255.255.254";
$cmd = "$perl_test_telnet --object-name $timeout_ip ";
$cmd .= "--expect-username user --command cmd --output out --expect-detail ";
$cmd .= "--expect-password pass --expect-enable enablepass ";
$cmd .= "--expect-command 0 --expect-telnet-timeout 2 --expect-retries 0 ";
$out = &output("$cmd --log-stdout --log-level 7");
ok($out =~ /\Qconfig setting expect-username = user\E/,
    'expect1 config expect-username');
ok($out =~ /\Qconfig setting expect-password = ****\E/,
    'expect1 config expect-password');
ok($out =~ /\Qconfig setting expect-enable = ****\E/,
    'expect1 config expect-enable');
ok($out =~ /\Qconfig setting expect-telnet-timeout = 2\E/,
    'expect1 config expect-timeout');
ok($out =~ /\Q(starting) cmd =~ out\E/,
    'expect1 config command and output');
ok($out =~ /\Qconfig setting expect-detail = 1\E/,
    'expect1 config expect-detail');
ok($out =~ /\Qexpect Net::Telnet to $timeout_ip port 23 initiating\Q/,
    'expect1 session initiating');
ok($out =~ /die 0 \S+ main failed to open expect session/mi,
    'expect1 session timeout');

# create temporary telnet record/replay file
my $fh_telnet = File::Temp->new() or die "unable to open telnet file";
print $fh_telnet '';
close $fh_telnet;
my $file_telnet = $fh_telnet->filename;

# test basic telnet login to test server, use Net::Telnet, record the session
system("( $perl_test_server $telnet_port ) &");
sleep 2;
system($telnet_test);
$cmd = "$perl_test_telnet ";
$cmd .="--object-name 127.0.0.1 --expect-port-telnet $telnet_port ";
$cmd .= "--expect-username testuser --expect-password testpass ";
$cmd .= "--command show --output 'input = show' --expect-detail ";
$cmd .= "--expect-command 0 --expect-telnet-timeout 2 --expect-retries 0 ";
$out = &output("$cmd --log-stdout --log-level 7 --expect-record $file_telnet");
ok($out =~ /setting expect-port-telnet = $telnet_port$/m,
    'expect2 set telnet port');
ok($out =~ /expect creating expect-record \Q$file_telnet\E\s*$/m,
    'exspect2 recording session');
ok($out =~ /expect Net::Telnet session init/m, 'expect2 telnet session init');
ok($out =~ /expect connected to Net::Telnet/m,'expect2 telnet session connect');
ok($out =~ /expect waiting for first prompt$/m, 'expect2 telnet await login');
ok($out =~ /expect | Username:/m, 'expect2 logged first prompt');
ok($out =~ /expect sending username$/m, 'expect2 telnet username');
ok($out =~ /expect | testuser/m, 'expect2 logged username');
ok($out =~ /expect sending password$/m, 'expect2 telnet password');
ok($out =~ /expect read returned \d+ chars$/m, 'expect2 telnet read chars');
ok($out =~ /expect password accepted$/m, 'expect2 telnet password accepted');
ok($out =~ /expect current prompt 'telnet' found$/m, 'expect2 telnet prompt');
ok($out =~ /expect password accepted$/m, 'expect2 telnet login complete');
ok($out =~ /expect command 'show' timeout \d+s/m,'expect2 telnet show command');
ok($out =~ /expect command 'show' returned \d+ chars$/m,
    'expect2 telnet show returned output');
ok($out =~ /expect expect-record saved 'show' output/m,
    'expect2 recorded show output');
ok($out =~ /expect close sub called from main$/m, 'expect2 telnet closing');
ok($out =~ /expect close sending exit command$/m, 'expect2 telnet exit');
ok($out =~ /expect close session complete$/m, 'expect2 telnet complete');
ok($out =~ /\(ok\) show =~ input = show$/m, 'expect2 telnet show output');
ok($out !~ /^\S+ (0|1|2|3|4)/, 'expect2 telnet no warnings');

# test replay of recorded session
$cmd = "$perl_test_telnet ";
$cmd .="--object-name 127.0.0.1 --expect-port-telnet $telnet_port ";
$cmd .= "--expect-username testuser --expect-password testpass ";
$cmd .= "--command show --output 'input = show' --expect-detail ";
$cmd .= "--expect-command 0 --expect-telnet-timeout 2 --expect-retries 0 ";
$out = &output("$cmd --log-stdout --log-level 7 --expect-replay $file_telnet");
ok($out =~ /expect reading expect-replay \Q$file_telnet\E\s*/m,
    'expect3 read expect-replay file');
ok($out =~ /expect command 'show' returned \d+ chars$/m,
    'expect3 show returned replay output');
ok($out !~ /^\S+ (0|1|2|3|4)/, 'expect3 telnet no warnings');

# another test telnet login to test server, use telnet system command
system("( $perl_test_server $telnet_port ) &");
sleep 2;
system($telnet_test);
$cmd = "$perl_test_telnet --object-name test ";
$cmd.= "--object-address 127.0.0.1 --expect-port-telnet $telnet_port ";
$cmd.= "--expect-username testuser --expect-password testpass ";
$cmd.= "--command dump --output 'line 999' --expect-detail ";
$cmd.= "--expect-enable testenable ";
$cmd.= "--expect-timeout-login 2 --expect-retries 0 ";
$out = &output("$cmd --log-stdout --log-level 7");
ok($out =~ /expect command telnet spawned/m, 'expect4 telnet spawned');
ok($out =~ /expect first prompt/m,'expect4 telnet connected');
ok($out =~ /expect sending enable command$/m, 'expect4 telnet await enable');
ok($out =~ /expect sending enable password$/m, 'expect4 telnet send enable');
ok($out =~ /expect enable password accepted/m,
    'expect4 telnet enable accepted');
ok($out =~ /expect command 'dump' timeout \d+s$/m,
    'expect4 telnet dump command');
ok($out =~ /expect command 'dump' returned \d+ chars$/m,
    'expect4 telnet dump returned');
ok($out =~ /\(ok\) dump =~ line 999$/m, 'expect4 telnet dump output');
ok($out !~ /^\S+ (0|1|2|3|4)/, 'expect4 telnet no errors');

# test telnet login without username or password prompts, use Net::Telnet
system("( $perl_test_server $telnet_port 0 ) &");
sleep 2;
system($telnet_test);
$cmd = "$perl_test_telnet ";
$cmd.= "--object-name 127.0.0.1 --expect-port-telnet $telnet_port ";
$cmd.= "--expect-username '' --expect-password '' --expect-command 0 ";
$cmd.= "--expect-retries 0 --expect-timeout-login 2 ";
$cmd.= "--command show --output 'input = show' --expect-detail ";
$out = &output("$cmd --log-stdout --log-level 7");
ok($out =~ /config setting expect-username =\s*$/m, 'expect5 no username');
ok($out =~ /config setting expect-password =\s*$/m, 'expect5 no password');
ok($out =~ /expect connected to Net::Telnet/m, 'expect5 session connected');
ok($out !~ /expect waiting for login prompt$/m,
    'expect5 session login skipped');
ok($out =~ /expect close session complete$/m, 'expect5 session complete');
ok($out =~ /\(ok\) show =~ input = show$/m, 'expect5 session show output');
ok($out !~ /^\S+ (0|1|2|3|4)/, 'expect5 session no warnings');

# finished
&done_testing;
exit;

sub output {
    # purpose: command output with optional debug
    my $command = shift or die;
    my $output = `( $command ) 2>&1`;
    print "\n\n$command\n\n$output\n\n"
        if "@ARGV" =~ /(^|\s)(-d|--?debug)(\s|$)/;
    return $output;
}

