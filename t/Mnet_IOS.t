# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mnet_IOS.t'

# use standard modules, clear mnet environment
use strict;
use warnings;
use Test::More;
delete $ENV{'MNET'};

# test for some modules
eval { require File::Temp; };
&plan(skip_all => "perl File::Temp module not installed") if $@;

# requires mnet silent module
eval { require Mnet::Silent; };
&plan(skip_all => "perl Mnet::Silent module not installed") if $@;

# Insert your test code below, refer to Test::More man page

# function used to test module with expect-replay input
sub test_ios {
    my ($code, $record, $newfile) = @_;
    $record =~ s/^\s*\n//;
    my $fh = File::Temp->new() or die "unable to open temp file $!";
    foreach my $line (split(/\n/, $record)) {
        $line =~ s/^\s\s\s\s//;
        print $fh "$line\n";
    }
    close $fh;
    my $filename = $fh->filename;
    my $args = "--object-name router1 --object-address 172.26.240.98 ";
    $args .= "--expect-username cisco --expect-password ciscou ";
    $args .= "--expect-enable ciscoe --ios-detail ";
    $args .= "--log-level 7 "; # uncomment this for debug details
    if ($newfile) {
        $args .= "--expect-record $newfile ";
    } else {
        $args .= "--expect-replay $filename ";
    }
    my $output = &output("perl -e '$code' - $args 2>&1");
    return $output;
}

# function used for command output with optional debug
sub output {
    my $command = shift or die;
    my $output = `( $command ) 2>&1`;
    print "\n\n$command\n\n$output\n\n"
        if "@ARGV" =~ /(^|\s)(-d|--?debug)(\s|$)/;
    return $output;
}

# initialize command arguments and command output
my ($cmd_arg, $cmd_out) = ("", "");

# test a successful push
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->config_push("conf t\n"."ip domain-lookup\n"."end\n") or die;
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:conf t
    ----:::: expect data ::::----
    Enter configuration commands, one per line.  End with CNTL/Z.
    ----:::: expect data ::::----
    COMMAND:ip domain-lookup
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:end
    ----:::: expect data ::::----

    ----:::: expect data ::::----
');
ok($cmd_out =~ /config_push implementation line = ip domain-lookup/,
    'ios config_push1 command sent');
ok($cmd_out =~ /config_push implementation finished without errors/,
    'ios config_push1 finished');
ok($cmd_out =~ /mnet script \S+ clean exit/,
    'ios config_push1 clean exit');

# test a ios-config-ignore error, failed push, and successful backout
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->{"ios-config-ignore"} = "unknown command or computer name";
    $ios->config_push("gorped\n"."show gorped", "show clock") or die;
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:gorped
    ----:::: expect data ::::----
    Translating "gorped"

    Translating "gorped"
    % Unknown command or computer name, or unable to find computer address
    ----:::: expect data ::::----
    COMMAND:show gorped
    ----:::: expect data ::::----
    show gorped
          ^
    % Invalid input detected at "^" marker.
    ----:::: expect data ::::----
    COMMAND:end
    ----:::: expect data ::::----
    Translating "end"

    Translating "end"
    % Unknown command or computer name, or unable to find computer address
    ----:::: expect data ::::----
    COMMAND:show clock
    ----:::: expect data ::::----
    *08:47:22.862 UTC Fri Mar 5 1993
    ----:::: expect data ::::----
');
ok($cmd_out =~ /config_push implementation line = gorped/,
    'ios config_push2 command1 sent');
ok($cmd_out =~ /config_push ignoring error \% Unknown command or computer name/,
    'ios config_push2 command1 error ignored');
ok($cmd_out =~ /config_push implementation line = show gorped/,
    'ios config_push2 command2 sent');
ok($cmd_out =~ /config_push implementation error \% Invalid input detected/,
    'ios config_push2 command2 error detected');
ok($cmd_out =~ /config_push backout push starting/,
    'ios config_push2 backout starting');
ok($cmd_out =~ /config_push backout line = show clock/,
    'ios config_push2 backout command sent');
ok($cmd_out =~ /config_push backout finished/,
    'ios config_push2 backout finished');
ok($cmd_out =~ /^die 0 \S+ main died/mi,
    'ios config_push2 exited with error');

# test ios ping method
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    &log("ping1 = " . $ios->ping("172.26.240.98"));
    &log("ping2 = " . $ios->ping("127.0.0.2"));
    my ($s, $a, $m) = $ios->ping("172.26.240.98", 10, 200, "FastEthernet0/0");
    &log("ping3 = $s, $a, $m");
    ($s, $a, $m) = $ios->ping("127.0.0.2", 2, 200, "FastEthernet0/0");
    &log("ping4 = $s, $a, $m");
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:ping 172.26.240.98
    ----:::: expect data ::::----
    Type escape sequence to abort.
    Sending 5, 100-byte ICMP Echos to 172.26.240.98, timeout is 2 seconds:
    !!!!!
    Success rate is 100 percent (5/5), round-trip min/avg/max = 1/1/1 ms
    ----:::: expect data ::::----
    COMMAND:ping 127.0.0.2
    ----:::: expect data ::::----
    Type escape sequence to abort.
    Sending 5, 100-byte ICMP Echos to 127.0.0.2, timeout is 2 seconds:
    .....
    Success rate is 0 percent (0/5)
    ----:::: expect data ::::----
    COMMAND:ping
    ----:::: expect data ::::----
    pingProtocol [ip]: ipTarget IP address: 172.26.240.98Repeat count [5]: 10Datagra                                                               m size [100]: 200Timeout in seconds [2]: Extended commands [n]: ySource address                                                                or interface: FastEthernet0/0Type of service [0]: Set DF bit in IP header? [no]:                                                                Validate reply data? [no]: Data pattern [0xABCD]: Loose, Strict, Record, Timest                                                               amp, Verbose[none]: Sweep range of sizes [n]: 
    Type escape sequence to abort.
    Sending 10, 200-byte ICMP Echos to 172.26.240.98, timeout is 2 seconds:Packet se                                                               nt with a source address of 172.26.240.98 
    !!!!!!!!!!
    Success rate is 100 percent (10/10), round-trip min/avg/max = 1/1/4 ms
    ----:::: expect data ::::----
    COMMAND:ping
    ----:::: expect data ::::----
    pingProtocol [ip]: ipTarget IP address: 127.0.0.2Repeat count [5]: 2Datagram siz                                                               e [100]: 200Timeout in seconds [2]: Extended commands [n]: ySource address or in                                                               terface: FastEthernet0/0Type of service [0]: Set DF bit in IP header? [no]: Vali                                                               date reply data? [no]: Data pattern [0xABCD]: Loose, Strict, Record, Timestamp,                                                                Verbose[none]: Sweep range of sizes [n]: 
    Type escape sequence to abort.
    Sending 2, 200-byte ICMP Echos to 127.0.0.2, timeout is 2 seconds:Packet sent wi                                                               th a source address of 172.26.240.98 
    ..
    Success rate is 0 percent (0/2)
    ----:::: expect data ::::----
');
ok($cmd_out =~ /ping1 = 100/, 'ios ping1 passed, 100%');
ok($cmd_out =~ /ping2 = 0/, 'ios ping2 passed, 0%');
ok($cmd_out =~ /ping3 = 100, 1, 4/, 'ios ping3 passed, 100%, avg=1, max=4');
ok($cmd_out =~ /ping4 = 0,\s+,\s*$/m, 'ios ping4 passed, 0%, no avg or max');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios ping clean exit');

# test ios write mem success
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->write_mem;
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:write mem
    ----:::: expect data ::::----
    Warning: Attempting to overwrite an NVRAM configuration previously written
    by a different version of the system image.
    Overwrite the previous NVRAM configuration?[confirm]
    Building configuration...
    [OK]
    ----:::: expect data ::::----
');
ok($cmd_out =~ /write_mem saving running config/m, 'ios write_mem1 starting');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios write_mem1 clean exit');

# test ios write mem not ok
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->write_mem;
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:write mem
    ----:::: expect data ::::----
    Warning: Attempting to overwrite an NVRAM configuration previously written
    by a different version of the system image.
    Overwrite the previous NVRAM configuration?[confirm]
    Building configuration...
    ----:::: expect data ::::----
');
ok($cmd_out =~ /write_mem saving running config/m, 'ios write_mem2 starting');
ok($cmd_out =~ /^die 0 \S+ ios write_mem error saving running config/mi,
    'ios write_mem2 detected error');
ok($cmd_out =~ /mnet script \S+ error exit/, 'ios write_mem2 error exit');

# test reload_in success
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->reload_in(10);
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:reload in 10
    ----:::: expect data ::::----
    Reload scheduled in 10 minutes
    Proceed with reload? [confirm]
    ----:::: expect data ::::----
    COMMAND:show reload
    ----:::: expect data ::::----
    Reload scheduled in 9 minutes by cisco on vty0 (172.26.240.97)
    ----:::: expect data ::::----
');
ok($cmd_out =~ /ios reload_in 10 is being initiated/,
    'ios reload_in1 starting');
ok($cmd_out =~ /ios reload_in 10 confirmed as scheduled/,
    'ios reload_in1 confirmed');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios reload_in1 clean exit');

# test reload_in failure
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->reload_in(10);
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:reload in 10
    ----:::: expect data ::::----
    Reload scheduled in 10 minutes
    Proceed with reload? [confirm]
    ----:::: expect data ::::----
    COMMAND:show reload
    ----:::: expect data ::::----
    No reload is scheduled.
    ----:::: expect data ::::----
');
ok($cmd_out =~ /ios reload_in 10 is being initiated/,
    'ios reload_in2 starting');
ok($cmd_out =~ /\S+ 4 \S+ ios reload_in 10 confirmation error/,
    'ios reload_in2 confirmed');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios reload_in2 clean exit');

# test reload cancel
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    my $r1 = $ios->reload_cancel;
    &log("r1 = 1") if $r1;
    $ios->reload_in(10);
    my $r2 = $ios->reload_cancel;
    &log("r2 = 1") if $r2;
    my $r3 = $ios->reload_cancel;
    &log("r3 = 1") if $r3;
    &log("r3 = 0") if not $r3;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:reload cancel
    ----:::: expect data ::::----
    %No reload is scheduled.
    ----:::: expect data ::::----
    COMMAND:show reload
    ----:::: expect data ::::----
    No reload is scheduled.
    ----:::: expect data ::::----
    COMMAND:reload in 10
    ----:::: expect data ::::----
    Reload scheduled in 10 minutes
    Proceed with reload? [confirm]
    ----:::: expect data ::::----
    COMMAND:show reload
    ----:::: expect data ::::----
    Reload scheduled in 9 minutes by cisco on vty0 (172.26.240.97)
    ----:::: expect data ::::----
    COMMAND:reload cancel
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:show reload
    ----:::: expect data ::::----
    No reload is scheduled.
    ----:::: expect data ::::----
    COMMAND:reload cancel
    ----:::: expect data ::::----
    %No reload is scheduled.
    ----:::: expect data ::::----
    COMMAND:show reload
    ----:::: expect data ::::----
    Reload scheduled in 9 minutes by cisco on vty0 (172.26.240.97)
    ----:::: expect data ::::----
');
ok($cmd_out =~ /r1 = 1/, 'ios reload_cancel1 confirmed');
ok($cmd_out =~ /ios reload_in 10 confirmed/, 'ios reload_cancel2 prepared');
ok($cmd_out =~ /r2 = 1/, 'ios reload_cancel2 confirmed');
ok($cmd_out =~ /r3 = 0/, 'ios reload_cancel3 not confirmed');
ok($cmd_out =~ /\S+ 4 \S+ ios reload_cancel error, could not confirm/,
    'ios reload_cancel3 error detected');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios reload_cancel clean exit');

# test reload_now
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->reload_now;
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:write mem
    ----:::: expect data ::::----
    Warning: Attempting to overwrite an NVRAM configuration previously written
    by a different version of the system image.
    Overwrite the previous NVRAM configuration?[confirm]
    Building configuration...
    [OK]
    ----:::: expect data ::::----
    COMMAND:reload
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:show version
    ----:::: expect data ::::----
    Cisco Internetwork Operating System Software 
    IOS (tm) 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)
    Copyright (c) 1986-2004 by cisco Systems, Inc.
    Compiled Sat 31-Jul-04 01:09 by eaarmas
    Image text-base: 0x60008930, data-base: 0x6145C000

    ROM: ROMMON Emulation Microcode
    ROM: 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)

    router1 uptime is 0 minutes
    System returned to ROM by unknown reload cause - suspect boot_data[BOOT_COUNT] 0x0, BOOT_COUNT 0, BOOTDATA 19
    System image file is "tftp://255.255.255.255/unknown"

    cisco 3640 (R4700) processor (revision 0xFF) with 45056K/4096K bytes of memory.
    Processor board ID 00000000
    R4700 CPU at 100Mhz, Implementation 33, Rev 1.2
    Bridging software.
    X.25 software, Version 3.0.0.
    SuperLAT software (copyright 1990 by Meridian Technology Corp).
    TN3270 Emulation software.
    2 FastEthernet/IEEE 802.3 interface(s)
    DRAM configuration is 64 bits wide with parity enabled.
    125K bytes of non-volatile configuration memory.
    8192K bytes of processor board System flash (Read/Write)

    Configuration register is 0x2102
    ----:::: expect data ::::----
');
ok($cmd_out =~ /ios write_mem saving running config/,
    'ios reload_now1 write_mem');
ok($cmd_out =~ /ios reload_now command being entered/,
    'ios reload_now1 entered');
ok($cmd_out =~ /ios reload_now delay for one minute/,
    'ios reload_now1 delay');
ok($cmd_out =~ /ios reload_now method attempting to reconnect/,
    'ios reload_now1 reconnecting');
ok($cmd_out =~ /ios reload_now method reconnected/,
    'ios reload_now1 reconnected');
ok($cmd_out =~ /ios reload_now verified using show version uptime/,
    'ios reload_now1 verified');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios reload_now1 clean exit');

# test show_version 
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->show_ver or die "show_version error\n";
    foreach my $key (sort keys %$ios) {
        next if $key !~ /^ios_/;
        &inf("show_ver $key = $ios->{$key}") 
    }
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:show version
    ----:::: expect data ::::----
    Cisco Internetwork Operating System Software 
    IOS (tm) 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)
    Copyright (c) 1986-2004 by cisco Systems, Inc.
    Compiled Sat 31-Jul-04 01:09 by eaarmas
    Image text-base: 0x60008930, data-base: 0x6145C000

    ROM: ROMMON Emulation Microcode
    ROM: 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)

    router1 uptime is 1 day, 15 hours, 5 minutes
    System returned to ROM by unknown reload cause - suspect boot_data[BOOT_COUNT] 0                                                               x0, BOOT_COUNT 0, BOOTDATA 19
    System image file is "tftp://255.255.255.255/unknown"

    cisco 3640 (R4700) processor (revision 0xFF) with 45056K/4096K bytes of memory.
    Processor board ID 00000000
    R4700 CPU at 100Mhz, Implementation 33, Rev 1.2
    Bridging software.
    X.25 software, Version 3.0.0.
    SuperLAT software (copyright 1990 by Meridian Technology Corp).
    TN3270 Emulation software.
    2 FastEthernet/IEEE 802.3 interface(s)
    DRAM configuration is 64 bits wide with parity enabled.
    125K bytes of non-volatile configuration memory.
    8192K bytes of processor board System flash (Read/Write)

    Configuration register is 0x2102
    ----:::: expect data ::::----
');
ok($cmd_out =~ /show_ver ios_cfg_reg = 0x2102\s*$/m,
    'ios show_ver ios_cfg_reg found');
ok($cmd_out =~ /show_ver ios_disk = tftp\s*$/m,
    'ios show_ver ios_disk found');
ok($cmd_out =~ /show_ver ios_dram = 48\s*$/m,
    'ios show_ver ios_ram found');
ok($cmd_out =~ /show_ver ios_file = unknown\s*$/m,
    'ios show_ver ios_file found');
ok($cmd_out =~ /show_ver ios_hostname = router1\s*$/m,
    'ios show_ver ios_hostname found');
ok($cmd_out =~ /show_ver ios_image = unknown\s*$/m,
    'ios show_ver ios_image found');
ok($cmd_out =~ /show_ver ios_model = 3640\s*$/m,
    'ios show_ver ios_model found');
ok($cmd_out =~ /show_ver ios_path = \/\/255.255.255.255\/\s*$/m,
    'ios show_ver ios_path found');
ok($cmd_out =~ /show_ver ios_sh_ver = Cisco Internetwork Operating System/,
    'ios show_ver ios_sh_ver found');
ok($cmd_out =~ /show_ver ios_uptime = 140700\s*$/m,
    'ios show_ver ios_uptime found');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios reload_now1 clean exit');

# test copy and delete
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->delete("flash:test") and &log("delete 1 complete");
    $ios->copy("nvram:startup-config", "flash:test", "abcdef123");
    $ios->delete("flash:test") and &log("delete 2 complete");
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:delete flash:test
    ----:::: expect data ::::----
    delete flash:testDelete filename [test]? Delete flash:test? [confirm]
    %Error deleting flash:test (No such file or directory)
    ----:::: expect data ::::----
    COMMAND:copy nvram:startup-config flash:test
    ----:::: expect data ::::----
    copy nvram:startup-config flash:testDestination filename [test]? Erase flash: be                                                               fore copying? [confirm]n
    Verifying checksum...  OK (0xF21A)
    681 bytes copied in 0.012 secs (56750 bytes/sec)
    ----:::: expect data ::::----
    COMMAND:verify /md5 flash:test abcdef123
    ----:::: expect data ::::----
    verify /md5 flash:test abcdef123
           ^
    % Invalid input detected at "^" marker.
    ----:::: expect data ::::----
    COMMAND:verify flash:test
    ----:::: expect data ::::----
    Verified flash:test
    ----:::: expect data ::::----
    COMMAND:delete flash:test
    ----:::: expect data ::::----
    delete flash:testDelete filename [test]? Delete flash:test? [confirm]
    ----:::: expect data ::::----
');
ok($cmd_out =~ /delete 1 complete/, 'ios copy/delete delete 1 complete');
ok($cmd_out =~ /copy complete nvram:startup-config to flash:test/,
    'ios copy/delete copy complete');
ok($cmd_out =~ /copy attempting md5 verification of flash:test/,
    'ios copy/delete md5 attempted');
ok($cmd_out =~ /copy md5 verify not supported, using checksum/,
    'ios copy/delete checksum fallback');
ok($cmd_out =~ /copy attempting checksum verification of flash:test/,
    'ios copy/delete checksum attempted');
ok($cmd_out =~ /copy checksum verify succeeded for flash:test/,
    'ios copy/delete checksum complete');
ok($cmd_out =~ /delete 2 complete/, 'ios copy/delete delete 2 complete');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios copy/delete clean exit');

# test show_run
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->show_run or die "show_run error";
    &log("show_run ios_model from show_ver")
        if $ios->{"ios_model"} =~ /3640/;
    &log("ios_domain = " . $ios->{"ios_domain"});
    &log("ios_sh_run begin ok") if $ios->{"ios_sh_run"} =~ /^Building config/m;
    &log("ios_sh_run end ok") if $ios->{"ios_sh_run"} =~ /^end/m;
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:show version
    ----:::: expect data ::::----
    Cisco Internetwork Operating System Software 
    IOS (tm) 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)
    Copyright (c) 1986-2004 by cisco Systems, Inc.
    Compiled Sat 31-Jul-04 01:09 by eaarmas
    Image text-base: 0x60008930, data-base: 0x6145C000

    ROM: ROMMON Emulation Microcode
    ROM: 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)

    router1 uptime is 1 hour, 30 minutes
    System returned to ROM by unknown reload cause - suspect boot_data[BOOT_COUNT] 0x0, BOOT_COUNT 0, BOOTDATA 19
    System image file is "tftp://255.255.255.255/unknown"

    cisco 3640 (R4700) processor (revision 0xFF) with 45056K/4096K bytes of memory.
    Processor board ID 00000000
    R4700 CPU at 100Mhz, Implementation 33, Rev 1.2
    Bridging software.
    X.25 software, Version 3.0.0.
    SuperLAT software (copyright 1990 by Meridian Technology Corp).
    TN3270 Emulation software.
    2 FastEthernet/IEEE 802.3 interface(s)
    DRAM configuration is 64 bits wide with parity enabled.
    125K bytes of non-volatile configuration memory.
    8192K bytes of processor board System flash (Read/Write)

    Configuration register is 0x2102
    ----:::: expect data ::::----
    COMMAND:show running-config
    ----:::: expect data ::::----
    Building configuration...

    Current configuration : 1054 bytes
    !
    version 12.2
    service timestamps debug uptime
    service timestamps log uptime
    no service password-encryption
    !
    hostname router1
    !
    enable secret 5 $1$TBO7$iLMS24rVMdmju0MiXg8cD.
    !
    username cisco password 0 ciscou
    ip subnet-zero
    ip domain-name test.local
    !
    !
    no ip domain-lookup
    !
    call rsvp-sync
    !
    !
    !
    !
    !
    !
    !
    class-map match-any bulk
      match access-group name bulk
    !
    !
    policy-map qos
      class bulk
       set ip dscp af11
    !
    !
    !
    interface FastEthernet0/0
     description test router lan interface
     ip address 172.26.240.98 255.255.255.240
     service-policy input qos
     duplex auto
     speed auto
    !
    interface FastEthernet1/0
     description test router shutdown interface
     no ip address
     shutdown
     duplex auto
     speed auto
    !
    ip classless
    ip route 0.0.0.0 0.0.0.0 172.26.240.97
    no ip http server
    !
    !
    ip access-list extended bulk
     permit ip any any
    !
    snmp-server community public RO
    snmp-server location virtual
    snmp-server contact 555-5555
    snmp-server chassis-id jmx1234
    snmp-server enable traps tty
    !
    dial-peer cor custom
    !
    !
    !
    !
    line con 0
    line aux 0
    line vty 0 4
     password ciscou
     login local
    !
    end
    ----:::: expect data ::::----
');
ok($cmd_out =~ /show_run ios_model from show_ver/,
    'ios show_run show_ver model correct');
ok($cmd_out =~ /ios_sh_run begin ok/, 'ios show_run begin');
ok($cmd_out =~ /ios_sh_run end ok/, 'ios show_run end');
ok($cmd_out =~ /ios_domain = test\.local\s*$/m, 'ios show_run ios_domain set');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios show_run clean exit');

# test show_int
$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    my @ints = $ios->show_int;
    die "show_int error: no interfaces" if not @ints;
    &log("show_int ints = @ints");
    &log("show_int ios_ints_all = " . $ios->{"ios_ints_all"});
    &log("show_int ios_ints_lan = " . $ios->{"ios_ints_lan"});
    &log("show_int ios_ints_wan = " . $ios->{"ios_ints_wan"});
    &log("show_int ios_wan_high = " . $ios->{"ios_wan_high"});
    &log("show_int ios_wan_low = " . $ios->{"ios_wan_low"});
    &log("show_int ios_sh_int = correct")
        if defined $ios->{"ios_sh_int"}
        and $ios->{"ios_sh_int"} =~ /\S/
        and $ios->{"ios_sh_int"} !~ /\%/;
    &log("show_int ios_sh_inv = correct")
        if defined $ios->{"ios_sh_inv"}
        and $ios->{"ios_sh_inv"} =~ /\S/;
    &log("show_int ios_sh_cdp = correct")
        if defined $ios->{"ios_sh_cdp"}
        and $ios->{"ios_sh_cdp"} !~ /\S/;
    &log("show_int ios_sh_switch = correct")
        if defined $ios->{"ios_sh_switch"}
        and $ios->{"ios_sh_switch"} =~ /invalid input detected/i;
    &log("show_int ios_model from show_ver")
        if $ios->{"ios_model"} =~ /3640/;
    $ios->close;
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:show version
    ----:::: expect data ::::----
    Cisco Internetwork Operating System Software 
    IOS (tm) 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)
    Copyright (c) 1986-2004 by cisco Systems, Inc.
    Compiled Sat 31-Jul-04 01:09 by eaarmas
    Image text-base: 0x60008930, data-base: 0x6145C000

    ROM: ROMMON Emulation Microcode
    ROM: 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)

    router1 uptime is 1 hour, 30 minutes
    System returned to ROM by unknown reload cause - suspect boot_data[BOOT_COUNT] 0x0, BOOT_COUNT 0, BOOTDATA 19
    System image file is "tftp://255.255.255.255/unknown"

    cisco 3640 (R4700) processor (revision 0xFF) with 45056K/4096K bytes of memory.
    Processor board ID 00000000
    R4700 CPU at 100Mhz, Implementation 33, Rev 1.2
    Bridging software.
    X.25 software, Version 3.0.0.
    SuperLAT software (copyright 1990 by Meridian Technology Corp).
    TN3270 Emulation software.
    2 FastEthernet/IEEE 802.3 interface(s)
    DRAM configuration is 64 bits wide with parity enabled.
    125K bytes of non-volatile configuration memory.
    8192K bytes of processor board System flash (Read/Write)

    Configuration register is 0x2102
    ----:::: expect data ::::----
    COMMAND:show running-config
    ----:::: expect data ::::----
    Building configuration...

    Current configuration : 1264 bytes
    !
    version 12.2
    service timestamps debug uptime
    service timestamps log uptime
    no service password-encryption
    !
    hostname router1
    !
    enable secret 5 $1$TBO7$iLMS24rVMdmju0MiXg8cD.
    !
    username cisco password 0 ciscou
    ip subnet-zero
    !
    !
    no ip domain-lookup
    !
    call rsvp-sync
    !
    !
    !
    !
    !
    !
    !
    class-map match-any bulk
      match access-group name bulk
    !
    !
    policy-map qos
      class bulk
       set ip dscp af11
    !
    !
    !
    interface Tunnel1
     bandwidth 100
     no ip address
    !
    interface Tunnel2
     bandwidth 200
     no ip address
    !
    interface Tunnel3
     bandwidth 300
     no ip address
    !
    interface Tunnel4
     bandwidth 400
     no ip address
     shutdown
    !
    interface FastEthernet0/0
     description test router lan interface
     ip address 172.26.240.98 255.255.255.240
     service-policy input qos
     duplex auto
     speed auto
    !
    interface FastEthernet1/0
     description test router shutdown interface
     no ip address
     shutdown
     duplex auto
     speed auto
    !
    ip classless
    ip route 0.0.0.0 0.0.0.0 172.26.240.97
    no ip http server
    !
    !
    ip access-list extended bulk
     permit ip any any
    !
    snmp-server community public RO
    snmp-server location virtual
    snmp-server contact 555-5555
    snmp-server chassis-id jmx1234
    snmp-server enable traps tty
    !
    dial-peer cor custom
    !
    !
    !
    !
    line con 0
    line aux 0
    line vty 0 4
     password ciscou
     login local
    !
    end
    ----:::: expect data ::::----
    COMMAND:show interface
    ----:::: expect data ::::----
    FastEthernet0/0 is up, line protocol is up 
      Hardware is AmdFE, address is cc00.38f2.0000 (bia cc00.38f2.0000)
      Description: test router lan interface
      Internet address is 172.26.240.98/28
      MTU 1500 bytes, BW 100000 Kbit, DLY 100 usec, 
         reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation ARPA, loopback not set
      Keepalive set (10 sec)
      Full-duplex, 100Mb/s, 100BaseTX/FX
      ARP type: ARPA, ARP Timeout 04:00:00
      Last input 00:00:00, output 00:00:00, output hang never
      Last clearing of "show interface" counters never
      Input queue: 7/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/40 (size/max)
      5 minute input rate 1000 bits/sec, 1 packets/sec
      5 minute output rate 1000 bits/sec, 1 packets/sec
         792 packets input, 44367 bytes
     Received 4 broadcasts, 0 runts, 0 giants, 0 throttles
     0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored
     0 watchdog
     0 input packets with dribble condition detected
     1630 packets output, 154038 bytes, 0 underruns
     0 output errors, 0 collisions, 0 interface resets
     0 babbles, 0 late collision, 0 deferred
     0 lost carrier, 0 no carrier
     0 output buffer failures, 0 output buffers swapped out
    FastEthernet1/0 is administratively down, line protocol is down 
      Hardware is AmdFE, address is cc00.38f2.0010 (bia cc00.38f2.0010)
      Description: test router shutdown interface
      MTU 1500 bytes, BW 100000 Kbit, DLY 100 usec, 
         reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation ARPA, loopback not set
      Keepalive set (10 sec)
      Full-duplex, 100Mb/s, 100BaseTX/FX
      ARP type: ARPA, ARP Timeout 04:00:00
      Last input never, output never, output hang never
      Last clearing of "show interface" counters never
      Input queue: 0/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/40 (size/max)
      5 minute input rate 0 bits/sec, 0 packets/sec
      5 minute output rate 0 bits/sec, 0 packets/sec
         0 packets input, 0 bytes
         Received 0 broadcasts, 0 runts, 0 giants, 0 throttles
         0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored
         0 watchdog
         0 input packets with dribble condition detected
         0 packets output, 0 bytes, 0 underruns
         0 output errors, 0 collisions, 0 interface resets
         0 babbles, 0 late collision, 0 deferred
         0 lost carrier, 0 no carrier
         0 output buffer failures, 0 output buffers swapped out
    Tunnel1 is up, line protocol is down 
      Hardware is Tunnel
      MTU 1514 bytes, BW 100 Kbit, DLY 500000 usec, 
         reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation TUNNEL, loopback not set
      Keepalive not set
      Tunnel source 0.0.0.0, destination 0.0.0.0
      Tunnel protocol/transport GRE/IP, key disabled, sequencing disabled
      Checksumming of packets disabled,  fast tunneling enabled
      Last input never, output never, output hang never
      Last clearing of "show interface" counters never
      Input queue: 0/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/0 (size/max)
      5 minute input rate 0 bits/sec, 0 packets/sec
      5 minute output rate 0 bits/sec, 0 packets/sec
         0 packets input, 0 bytes, 0 no buffer
         Received 0 broadcasts, 0 runts, 0 giants, 0 throttles
         0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored, 0 abort
         0 packets output, 0 bytes, 0 underruns
         0 output errors, 0 collisions, 0 interface resets
         0 output buffer failures, 0 output buffers swapped out
    Tunnel2 is up, line protocol is down 
      Hardware is Tunnel
      MTU 1514 bytes, BW 200 Kbit, DLY 500000 usec, 
         reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation TUNNEL, loopback not set
      Keepalive not set
      Tunnel source 0.0.0.0, destination 0.0.0.0
      Tunnel protocol/transport GRE/IP, key disabled, sequencing disabled
      Checksumming of packets disabled,  fast tunneling enabled
      Last input never, output never, output hang never
      Last clearing of "show interface" counters never
      Input queue: 0/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/0 (size/max)
      5 minute input rate 0 bits/sec, 0 packets/sec
      5 minute output rate 0 bits/sec, 0 packets/sec
         0 packets input, 0 bytes, 0 no buffer
         Received 0 broadcasts, 0 runts, 0 giants, 0 throttles
         0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored, 0 abort
         0 packets output, 0 bytes, 0 underruns
         0 output errors, 0 collisions, 0 interface resets
         0 output buffer failures, 0 output buffers swapped out
    Tunnel3 is up, line protocol is down 
      Hardware is Tunnel
      MTU 1514 bytes, BW 300 Kbit, DLY 500000 usec, 
         reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation TUNNEL, loopback not set
      Keepalive not set
      Tunnel source 0.0.0.0, destination 0.0.0.0
      Tunnel protocol/transport GRE/IP, key disabled, sequencing disabled
      Checksumming of packets disabled,  fast tunneling enabled
      Last input never, output never, output hang never
      Last clearing of "show interface" counters never
      Input queue: 0/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/0 (size/max)
      5 minute input rate 0 bits/sec, 0 packets/sec
      5 minute output rate 0 bits/sec, 0 packets/sec
         0 packets input, 0 bytes, 0 no buffer
         Received 0 broadcasts, 0 runts, 0 giants, 0 throttles
         0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored, 0 abort
         0 packets output, 0 bytes, 0 underruns
         0 output errors, 0 collisions, 0 interface resets
         0 output buffer failures, 0 output buffers swapped out
    Tunnel4 is administratively down, line protocol is down 
      Hardware is Tunnel
      MTU 1514 bytes, BW 400 Kbit, DLY 500000 usec, 
         reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation TUNNEL, loopback not set
      Keepalive not set
      Tunnel source 0.0.0.0, destination 0.0.0.0
      Tunnel protocol/transport GRE/IP, key disabled, sequencing disabled
      Checksumming of packets disabled,  fast tunneling enabled
      Last input never, output never, output hang never
      Last clearing of "show interface" counters never
      Input queue: 0/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/0 (size/max)
      5 minute input rate 0 bits/sec, 0 packets/sec
      5 minute output rate 0 bits/sec, 0 packets/sec
         0 packets input, 0 bytes, 0 no buffer
         Received 0 broadcasts, 0 runts, 0 giants, 0 throttles
         0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored, 0 abort
         0 packets output, 0 bytes, 0 underruns
         0 output errors, 0 collisions, 0 interface resets
         0 output buffer failures, 0 output buffers swapped out
    ----:::: expect data ::::----
    COMMAND:show inventory
    ----:::: expect data ::::----
    NAME: "Chassis", DESCR: "12008/GRP chassis"
    PID: GSR8/40           ,  VID: V01,  SN: 63915640

    ----:::: expect data ::::----
    COMMAND:show cdp neighbor detail
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:show interface switchport
    ----:::: expect data ::::----
    show interface switchport
                     ^
    % Invalid input detected at "^" marker.
    ----:::: expect data ::::----
');
ok($cmd_out =~ /show_int ios_model from show_ver/,
    'ios show_int show_ver model correct');
my $ints_all = "Tunnel1 Tunnel2 Tunnel3 Tunnel4 ";
$ints_all .= "FastEthernet0\/0 FastEthernet1\/0";
ok($cmd_out =~ /show_int ints = $ints_all\s*$/m,
    'ios show_int ints all present');
ok($cmd_out =~ /show_int ios_ints_all = $ints_all\s*$/m,
    'ios show_int ios_ints_all all present');
ok($cmd_out =~ /show_int ios_ints_lan = FastEthernet0\/0\s*$/m,
    'ios show_int ios_ints_lan all present');
ok($cmd_out =~ /show_int ios_ints_wan = Tunnel1 Tunnel2 Tunnel3\s*$/m,
    'ios show_int ios_ints_wan all present');
ok($cmd_out =~ /show_int ios_wan_high = 300\s*$/m,
    'ios show_int ios_wan_high correct');
ok($cmd_out =~ /show_int ios_wan_low = 100\s*$/m,
    'ios show_int ios_wan_high correct');
ok($cmd_out =~ /show_int ios_sh_int = correct\s*$/m,
    'ios show_int ios_sh_int correct');
ok($cmd_out =~ /show_int ios_sh_inv = correct\s*$/m,
    'ios show_int ios_sh_inv correct');
ok($cmd_out =~ /show_int ios_sh_cdp = correct\s*$/m,
    'ios show_int ios_sh_cdp correct');
ok($cmd_out =~ /show_int ios_sh_switch = correct\s*$/m,
    'ios show_int ios_sh_switch correct');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios show_int clean exit');

$cmd_out = &test_ios('
    use Mnet;
    use Mnet::Expect::IOS;
    my $cfg = &object;
    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
    $ios->show_int;
    my $show_stanza1 = $ios->show_stanza;
    my $show_stanza1_count = 0;
    $show_stanza1_count++ foreach split(/\n/, $show_stanza1);
    &inf("show_stanza1 starts ok") if $show_stanza1 =~ /^Building config/; 
    &inf("show_stanza1 ends ok") if $show_stanza1 =~ /end$/;
    &inf("show_stanza1_count = $show_stanza1_count");
    &output(2, $ios->show_stanza("line"));
    &output(3, $ios->show_stanza("access-list 100"));
    &output(4, $ios->show_stanza("class-map match-any bulk"));
    &output(5, $ios->show_stanza("lin"));
    &output(6, $ios->show_stanza("policy-map qos"));
    &output(7, $ios->show_stanza("/interface FastEthernet/"));
    &output(8, $ios->show_stanza("interface FastEthernet0/0"));
    &output(9, $ios->show_stanza("interface FastEthernet1/0"));
    &output(10, $ios->show_stanza("interface", sub {
        my $ios = shift or die "missing object";
        return 1 if $ios->{"ios_int_name"} =~ /FastEthernet1\/0/;
        return 0;
    }));
    $ios->close;
    &output("stanza_recreate1", $ios->stanza_recreate("access-list 100", "
        + access-list 100 permit ip any any
        access-list 100 deny ip any any
    "));
    &output("stanza_recreate2",
        $ios->stanza_recreate( "ip access-list extended bulk", "
        ip access-list extended bulk
         remark bulk acl
         permit ip any any
    "));
    &output("stanza_recreate3", $ios->stanza_recreate("access-list 101", "
        + access-list 101 permit ip any any
    "));
    &output("stanza_recreate4", $ios->stanza_recreate("access-list 100", "
        access-list 100 permit ip any any
    "));
    &output("stanza_recreate5",
        $ios->stanza_recreate( "ip access-list extended bulk", "
        ip access-list extended bulk
         remark bulk acl
    "));
    &output("stanza_update1", $ios->stanza_update("interface \\\\S+", sub {
        my $session = shift;
        return 0 if not $session->{"ios_int_name"};
        return 0 if $session->{"ios_int_name"} !~ /ethernet/i;
        return 1;
    }, "
        # ethernet interface configs
         ! new config
         duplex auto
         + shutdown
         - service-policy input
    "));
    &output("stanza_rebuild1",
        $ios->stanza_rebuild("ip access-list extended bulk", "
        ip access-list extended bulk
         ! test
         remark new acl
    "));
    &output("stanza_global1", $ios->stanza_global("
        ! snmp settings
        + snmp-server location virtual
        - snmp-server chassis-id
        snmp-server contact test
        - class bulk
    "));
    sub output {
        my ($header, $show_stanza) = @_;
        $header = "show_stanza$header" if $header =~ /^\d+$/;
        foreach my $line (split(/\n/, $show_stanza)) {
            syswrite STDOUT, "$header: $line\n";
        }
        return if $header !~ /^show_stanza\d+$/;
        foreach my $key (sort keys %$ios) {
            next if $key !~ /^ios_(stanza|int)_/;
            next if $key =~ /^ios_(stanza|int)_config/;
            next if not defined $ios->{$key} or $ios->{$key} eq "";
            foreach my $line (split(/\n/, $ios->{$key})) {
                syswrite STDOUT, "$header $key = $line\n";
            }
        }
    }
', '
    COMMAND:term length 0
    ----:::: expect data ::::----

    ----:::: expect data ::::----
    COMMAND:show version
    ----:::: expect data ::::----
    Cisco Internetwork Operating System Software 
    IOS (tm) 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)
    Copyright (c) 1986-2004 by cisco Systems, Inc.
    Compiled Sat 31-Jul-04 01:09 by eaarmas
    Image text-base: 0x60008930, data-base: 0x6145C000

    ROM: ROMMON Emulation Microcode
    ROM: 3600 Software (C3640-JS-M), Version 12.2(26), RELEASE SOFTWARE (fc2)

    router1 uptime is 2 days, 6 hours, 5 minutes
    System returned to ROM by unknown reload cause - suspect boot_data[BOOT_COUNT] 0x0, BOOT_COUNT 0, BOOTDATA 19
    System image file is "tftp://255.255.255.255/unknown"

    cisco 3640 (R4700) processor (revision 0xFF) with 45056K/4096K bytes of memory.
    Processor board ID 00000000
    R4700 CPU at 100Mhz, Implementation 33, Rev 1.2
    Bridging software.
    X.25 software, Version 3.0.0.
    SuperLAT software (copyright 1990 by Meridian Technology Corp).
    TN3270 Emulation software.
    2 FastEthernet/IEEE 802.3 interface(s)
    DRAM configuration is 64 bits wide with parity enabled.
    125K bytes of non-volatile configuration memory.
    8192K bytes of processor board System flash (Read/Write)

    Configuration register is 0x2102
    ----:::: expect data ::::----
    COMMAND:show running-config
    ----:::: expect data ::::----
    Building configuration...

    Current configuration : 1139 bytes
    !
    version 12.2
    service timestamps debug uptime
    service timestamps log uptime
    no service password-encryption
    !
    hostname router1
    !
    enable secret 5 $1$TBO7$iLMS24rVMdmju0MiXg8cD.
    !
    username cisco password 0 ciscou
    ip subnet-zero
    !
    !
    no ip domain-lookup
    !
    call rsvp-sync
    !
    !
    !
    !
    !
    !
    !
    class-map match-any bulk
      match access-group name bulk
    !
    !
    policy-map qos
    description qos map
      class bulk
       set ip dscp af11
    !
    !
    !
    interface FastEthernet0/0
     description test router lan interface
     ip address 172.26.240.98 255.255.255.240
     service-policy input qos
     duplex auto
     speed auto
    !
    interface FastEthernet1/0
     description test router shutdown interface
     no ip address
     shutdown
     duplex auto
     speed auto
    !
    ip classless
    ip route 0.0.0.0 0.0.0.0 172.26.240.97
    no ip http server
    !
    !
    ip access-list extended bulk
     remark bulk acl
     permit ip any any
    access-list 100 permit ip any any
    access-list 100 deny   ip any any
    !
    snmp-server community public RO
    snmp-server location virtual
    snmp-server contact 555-5555
    snmp-server chassis-id jmx1234
    snmp-server enable traps tty
    !
    dial-peer cor custom
    !
    !
    !
    !
    line con 0
    line aux 0
    line vty 0 4
     password ciscou
     login local
    !
    end
    ----:::: expect data ::::----
    COMMAND:show interface
    ----:::: expect data ::::----
    FastEthernet0/0 is up, line protocol is up 
      Hardware is AmdFE, address is cc00.7520.0000 (bia cc00.7520.0000)
      Description: test router lan interface
      Internet address is 172.26.240.98/28
      MTU 1500 bytes, BW 100000 Kbit, DLY 100 usec, 
         reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation ARPA, loopback not set
      Keepalive set (10 sec)
      Full-duplex, 100Mb/s, 100BaseTX/FX
      ARP type: ARPA, ARP Timeout 04:00:00
      Last input 00:00:00, output 00:00:00, output hang never
      Last clearing of "show interface" counters never
      Input queue: 7/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/40 (size/max)
      5 minute input rate 1000 bits/sec, 2 packets/sec
      5 minute output rate 2000 bits/sec, 2 packets/sec
         562 packets input, 31567 bytes
         Received 2 broadcasts, 0 runts, 0 giants, 0 throttles
         0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored
         0 watchdog
         0 input packets with dribble condition detected
         23793 packets output, 2277754 bytes, 0 underruns
         0 output errors, 0 collisions, 0 interface resets
         0 babbles, 0 late collision, 0 deferred
         0 lost carrier, 0 no carrier
         0 output buffer failures, 0 output buffers swapped out
    FastEthernet1/0 is administratively down, line protocol is down 
      Hardware is AmdFE, address is cc00.7520.0010 (bia cc00.7520.0010)
      Description: test router shutdown interface
      MTU 1500 bytes, BW 100000 Kbit, DLY 100 usec, 
      reliability 255/255, txload 1/255, rxload 1/255
      Encapsulation ARPA, loopback not set
      Keepalive set (10 sec)
      Full-duplex, 100Mb/s, 100BaseTX/FX
      ARP type: ARPA, ARP Timeout 04:00:00
      Last input never, output never, output hang never
      Last clearing of "show interface" counters never
      Input queue: 0/75/0/0 (size/max/drops/flushes); Total output drops: 0
      Queueing strategy: fifo
      Output queue: 0/40 (size/max)
      5 minute input rate 0 bits/sec, 0 packets/sec
      5 minute output rate 0 bits/sec, 0 packets/sec
         0 packets input, 0 bytes
         Received 0 broadcasts, 0 runts, 0 giants, 0 throttles
         0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored
         0 watchdog
         0 input packets with dribble condition detected
         0 packets output, 0 bytes, 0 underruns
         0 output errors, 0 collisions, 0 interface resets
         0 babbles, 0 late collision, 0 deferred
         0 lost carrier, 0 no carrier
         0 output buffer failures, 0 output buffers swapped out
    ----:::: expect data ::::----
    COMMAND:show inventory
    ----:::: expect data ::::----
    NAME: "Chassis", DESCR: "12008/GRP chassis"
    PID: GSR8/40           ,  VID: V01,  SN: 63915640

    NAME: "slot 0", DESCR: "GRP"
    PID: GRP-B             ,  VID: V01,  SN: CAB021300R5

    NAME: "1", DESCR: "4 port ATM OC3 multimode"
    PID: 4OC3/ATM-MM-SC    ,  VID: V01,  SN: CAB04036GT1

    NAME: "slot 16", DESCR: "GSR 12008 Clock Scheduler Card"
    PID: GSR8-CSC/ALRM     ,  VID: V01,  SN: CAB0429AUYH

    NAME: "sfslot 1", DESCR: "GSR 12008 Switch Fabric Card"
    PID: GSR8-SFC          ,  VID: V01,  SN: CAB0428ALOS

    NAME: "PSslot 1", DESCR: "GSR 12008 AC Power Supply"
    PID: FWR-GSR8-AC-B     ,  VID: V01,  SN: CAB041999CW

    ----:::: expect data ::::----
    COMMAND:show cdp neighbor detail
    ----:::: expect data ::::----
    Device ID: router2.local
    Entry address(es): 
      IP address: 172.26.240.97
    Platform: Cisco 2821,  Capabilities: Router Switch IGMP 
    Interface: FastEthernet0/0,  Port ID (outgoing port): GigabitEthernet0/0
    Holdtime : 128 sec

    Version :
    Cisco IOS Software, 2800 Software (C2800NM-ADVIPSERVICESK9-M), Version 12.4(15)T7, RELEASE SOFTWARE (fc3)
    Technical Support: http://www.cisco.com/techsupport
    Copyright (c) 1986-2008 by Cisco Systems, Inc.
    Compiled Wed 13-Aug-08 17:09 by prod_rel_team

    advertisement version: 2
    VTP Management Domain: ""
    Duplex: full
    Management address(es): 
    ----:::: expect data ::::----
    COMMAND:show interface switchport
    ----:::: expect data ::::----
    Name: Fa0/0
    Switchport: Enabled
    Administrative Mode: static access
    Operational Mode: down
    Administrative Trunking Encapsulation: dot1q
    Negotiation of Trunking: Off
    Access Mode VLAN: 10 (112.56.31.0/25)
    Trunking Native Mode VLAN: 1 (default)
    Administrative Native VLAN tagging: enabled
    Voice VLAN: none
    Administrative private-vlan host-association: none 
    Administrative private-vlan mapping: none 
    Administrative private-vlan trunk native VLAN: none
    Administrative private-vlan trunk Native VLAN tagging: enabled
    Administrative private-vlan trunk encapsulation: dot1q
    Administrative private-vlan trunk normal VLANs: none
    Administrative private-vlan trunk associations: none
    Administrative private-vlan trunk mappings: none
    Operational private-vlan: none
    Trunking VLANs Enabled: ALL
    Pruning VLANs Enabled: 2-1001
    Capture Mode Disabled
    Capture VLANs Allowed: ALL

    Protected: false
    Unknown unicast blocked: disabled
    Unknown multicast blocked: disabled
    Appliance trust: none

    Name: Fa1/0
    Switchport: Enabled
    Administrative Mode: static access
    Operational Mode: down
    Administrative Trunking Encapsulation: dot1q
    Negotiation of Trunking: Off
    Access Mode VLAN: 1 (default)
    Trunking Native Mode VLAN: 1 (default)
    Administrative Native VLAN tagging: enabled
    Voice VLAN: none
    Administrative private-vlan host-association: none 
    Administrative private-vlan mapping: none 
    Administrative private-vlan trunk native VLAN: none
    Administrative private-vlan trunk Native VLAN tagging: enabled
    Administrative private-vlan trunk encapsulation: dot1q
    Administrative private-vlan trunk normal VLANs: none
    Administrative private-vlan trunk associations: none
    Administrative private-vlan trunk mappings: none
    Operational private-vlan: none
    Trunking VLANs Enabled: ALL
    Pruning VLANs Enabled: 2-1001
    Capture Mode Disabled
    Capture VLANs Allowed: ALL

    Protected: false
    Unknown unicast blocked: disabled
    Unknown multicast blocked: disabled
    Appliance trust: none
    ----:::: expect data ::::----
');
ok(($cmd_out =~ /show_stanza1 starts ok/
    and $cmd_out =~ /show_stanza1 ends ok/
    and $cmd_out =~ /show_stanza1_count = 81\s*$/m),
    'ios show_stanza1 entire config');
ok(($cmd_out =~ /show_stanza2: line con 0/
    and $cmd_out =~ /show_stanza2: line aux 0/
    and $cmd_out =~ /show_stanza2: line vty 0 4/
    and $cmd_out =~ /show_stanza2:  password \S+/
    and $cmd_out =~ /show_stanza2:  login local/
    and $cmd_out !~ /show_stanza2 \S+/),
    'ios show_stanza2 multiple stanzas');
ok(($cmd_out =~ /show_stanza3: access-list 100 permit ip any any/
    and $cmd_out =~ /show_stanza3: access-list 100 deny ip any any/
    and $cmd_out !~ /show_stanza2 \S+/),
    'ios show_stanza3 numbered acl');
ok(($cmd_out =~ /show_stanza4: class-map match-any bulk/
    and $cmd_out =~ /show_stanza4:   match access-group name bulk/
    and $cmd_out =~ /show_stanza4 ios_stanza_name = class-map match-any bulk/),
    'ios show_stanza4 class-map, ios_stanza_name');
ok($cmd_out !~ /show_stanza5/,
    'ios show_stanza5 partial word');
ok(($cmd_out =~ /show_stanza6: policy-map qos/
    and $cmd_out =~ /show_stanza6:  description qos map/
    and $cmd_out =~ /show_stanza6:   class bulk/
    and $cmd_out =~ /show_stanza6:    set ip dscp af11/
    and $cmd_out =~ /show_stanza6 ios_stanza_name = policy-map qos/
    and $cmd_out =~ /show_stanza6 ios_stanza_desc = qos map/),
    'ios show_stanza6 policy-map, ios_stanza_desc');
ok(($cmd_out =~ /show_stanza7: interface FastEthernet0\/0/
    and $cmd_out =~ /show_stanza7: interface FastEthernet1\/0/
    and $cmd_out =~ /show_stanza7:  ip address 172\.26\.240\.98 \S+/
    and $cmd_out =~ /show_stanza7:  no ip address/
    and $cmd_out !~ /show_stanza7 \S+/),
    'ios show stanza7 interface regex');
ok(($cmd_out =~ /show_stanza8: interface FastEthernet0\/0/
    and $cmd_out =~ /show_stanza8:  service-policy input qos/
    and $cmd_out =~ /show_stanza8:  speed auto/
    and $cmd_out =~ /show_stanza8 ios_int_desc = test router lan interface/
    and $cmd_out =~ /show_stanza8 ios_int_name = FastEthernet0\/0/),
    'ios show_stanza8 single interface, ios_int_desc and ios_int_name');
ok(($cmd_out =~ /show_stanza8 ios_int_cdp = device id: router2\.local/i
    and $cmd_out =~ /show_stanza8 ios_int_cdp =\s+ip address: 172\.26\.240\.97/i
    and $cmd_out =~ /show_stanza8 ios_int_cdp = platform: cisco 2821,/i
    and $cmd_out =~ /show_stanza8 ios_int_cdp = interface: fastethernet0\/0,/i
    and $cmd_out =~ /show_stanza8 ios_int_cdp = duplex: full/i),
    'ios show_stanza8 single interface, ios_int_cdp');
ok(($cmd_out =~ /show_stanza8 ios_int_sh = fastethernet0\/0 is up, line/i
    and $cmd_out !~ /show_stanza8 ios_int_sh = fastethernet1\/0 is/i
    and $cmd_out !~ /show_stanza8 ios_int_sh = tunnel/i
    and $cmd_out =~ /show_stanza8 ios_int_sh = \s*internet address is 172\./i
    and $cmd_out =~ /show_stanza8 ios_int_sh = \s*description: test router/i
    and $cmd_out =~ /show_stanza8 ios_int_sh = \s*562 packets input, 31567/i
    and $cmd_out =~ /show_stanza8 ios_int_sh = \s*0 output buffer failures/i),
    'ios show_stanza8 single interface, ios_int_sh');
ok(($cmd_out =~ /show_stanza8 ios_int_switch = name: fa0\/0/i
    and $cmd_out !~ /show_stanza8 ios_int_switch = name: fa1\/0/i
    and $cmd_out =~ /show_stanza8 ios_int_switch = switchport: enabled/i
    and $cmd_out =~ /show_stanza8 ios_int_switch = capture vlans allowed: all/i
    and $cmd_out =~ /show_stanza8 ios_int_switch = \s*protected: false/i
    and $cmd_out =~ /show_stanza8 ios_int_switch = appliance trust: none/i),
    'ios show_stanza8 single interface, ios_int_switch');
ok(($cmd_out =~ /show_stanza8 ios_int_kb = 100000\s*$/m
    and $cmd_out !~ /show_stanza8 ios_int_shut = 1/
    and $cmd_out =~ /show_stanza8 ios_int_ip = 172\.26\.240\.98\s*$/m),
    'ios show_stanza8 single interface, ios_int_kb, ios_int_ip, ios_int_shut');
ok(($cmd_out =~ /show_stanza8 ios_int_lan = 1\s*$/m
    and $cmd_out !~ /show_stanza8 ios_int_wan =/),
    'ios show_stanza8 single interface, ios_int_lan, ios_int_wan');
ok(($cmd_out =~ s/show_stanza9 ios_int_inv = .* 4oc3\/atm-mm-sc.*//mi
    and $cmd_out =~ s/show_stanza9 ios_int_inv = .* gsr8-sfc.*//mi,
    and $cmd_out =~ s/show_stanza9 ios_int_inv = .* fwr-gsr8-ac-b.*//mi,
    and $cmd_out !~ /show_stanza9 ios_int_inv =/i),
    'ios show_stanza9 single interface, ios_int_inv');
ok(($cmd_out =~ /show_stanza10: interface fastethernet1\/0\s*$/mi
    and $cmd_out =~ /show_stanza10:  description test router shutdown/
    and $cmd_out =~ /show_stanza10:  speed auto/
    and $cmd_out !~ /show_stanza10: interface fastethernet0/i
    and $cmd_out !~ /show_stanza10 \S+/),
    'ios show_stanza10 match_sub interface');
ok(($cmd_out !~ /^stanza_recreate1:/m),
    'ios stanza_recreate1 matching numbered acl');
ok(($cmd_out !~ /^stanza_recreate2:/m),
    'ios stanza_recreate2 matching named acl');
ok(($cmd_out =~ s/^stanza_recreate3: access-list 101 permit ip any any//m
    and $cmd_out !~ /^stanza_recreate3:/),
    'ios stanza_recreate3 missing acl');
ok(($cmd_out =~ s/^stanza_recreate4: no access-list 100//m
    and $cmd_out =~ s/^stanza_recreate4: access-list 100 permit ip any any//m
    and $cmd_out !~ /^stanza_recreate4:/),
    'ios stanza_recreate4 mismatched numbered acl');
ok(($cmd_out =~ s/^stanza_recreate5: ! recreate ip access-list extended bulk//m
    and $cmd_out =~ s/^stanza_recreate5: no ip access-list extended bulk//m
    and $cmd_out =~ s/^stanza_recreate5: ip access-list extended bulk//m
    and $cmd_out =~ s/^stanza_recreate5:  remark bulk acl//m
    and $cmd_out !~ /^stanza_recreate5:/m),
    'ios stanza_recreate5 mismatched named acl');
ok(($cmd_out =~ s/^stanza_update1: ! update interface \S+\s*$//m
    and $cmd_out =~ s/^stanza_update1: interface fastethernet0\/0\s*$//mi
    and $cmd_out =~ s/^stanza_update1:  ! new config\s*$//m
    and $cmd_out =~ s/^stanza_update1:  shutdown\s*$//m
    and $cmd_out =~ s/^stanza_update1:  no service-policy input qos\s*$//m
    and $cmd_out !~ /^stanza_update1:/m),
    'ios stanza_update1 interface config');
ok(($cmd_out =~ s/^stanza_rebuild1: ! rebuild ip access-list extended bulk//m
    and $cmd_out =~ s/^stanza_rebuild1: ip access-list extended bulk\s*$//mi
    and $cmd_out =~ s/^stanza_rebuild1:  no remark bulk acl\s*$//m
    and $cmd_out =~ s/^stanza_rebuild1:  no permit ip any any\s*$//m
    and $cmd_out =~ s/^stanza_rebuild1:  ! test\s*$//m
    and $cmd_out =~ s/^stanza_rebuild1:  remark new acl\s*$//m
    and $cmd_out !~ /^stanza_rebuild1:/m),
    'ios stanza_rebuild1 access-list config');
ok(($cmd_out =~ s/^stanza_global1: ! snmp settings//m
    and $cmd_out =~ s/^stanza_global1: no snmp-server chassis-id jmx1234//m
    and $cmd_out =~ s/^stanza_global1: snmp-server contact test//m
    and $cmd_out !~ /^stanza_global1:/m),
    'ios stanza_global1 snmp config');
ok($cmd_out =~ /mnet script \S+ clean exit/, 'ios show_stanza clean exit');

# test something
#$cmd_out = &test_ios('
#    use Mnet;
#    use Mnet::Expect::IOS;
#    my $cfg = &object;
#    my $ios = new Mnet::Expect::IOS or die "could not connect\n";
#    $ios->config_push("show clock");
#    $ios->close;
#', undef, 't/data/test_ios.record');

# finished
&done_testing;
exit;
