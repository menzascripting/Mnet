package Mnet::Expect::Cli;

=head1 NAME

Mnet::Expect::Cli

=head1 SYNOPSIS

This module can be used to create new Mnet::Expect::Cli objects, which inherit
Mnet::Expect methods and have additional methods to handle logins, command
execution, caching, and testing.

=head1 TESTING

#? When used with the Mnet::Test --record option this module will...

=cut

# required modules
use warnings;
use strict;
use parent qw( Mnet::Expect );
use Carp;
use Errno;
use Mnet::Dump;
use Mnet::Opts::Cli::Cache;
use Time::HiRes;



sub new {

=head1 $self = Mnet::Expect::Cli->new(\%opts)

This method can be used to create new Mnet::Expect::Cli objects.

Mnet::Expect new input opts may be specified, along with the following:

 failed_re      default recognizes failed logins
 paging_key     default key to send for pagination prompt
 paging_re      default recognizes pagination prompt --more--
 password       set to password for spawned command, if needed
 password_in    stderr prompt for stdin entry of password if not set
 password_re    default recognizes password and passcode prompts
 prompt_re      default recognizes prompts ending with $ % # : >
 timeout        seconds for Expect restart_timeout_upon_receive
 username       set to username for spawned command, if needed
 username_re    default recognizes login, user, and username prompts

A value of undefined will be returned if there were spawn errors, and the
global Mnet::Expect::spawn_error will be set with error text.

For example, the following call will start an ssh expect session to a device:

 my $opts = { spawn => "ssh 1.2.3.4", prompt => 1 };
 my $expect = Mnet::Expect::Cli->new($opts)
    or die "expect error, $Mnet::Expect::error";

Note that all Mnet::Expect session activity is logged for debugging, refer to
the Mnet::Log module for more information.

=cut

    # read input class and optional opts hash ref
    my $class = shift // croak("missing class arg");
    croak("invalid call to class new") if ref $class;
    my $opts = shift // {};

    # note default options for this class
    #   update perldoc for this sub with changes
    my $defaults = {
        failed_re   => '(?i)(closed|error|denied|fail|incorrect|invalid|refused|sorry)',
        paging_key  => ' ',
        paging_re   => '--(M|m)ore--',
        password_re => '(?i)pass(word|code):?\s*(\r|\n)?$',
        prompt_re   => '\S.*(\$|\%|#|:|>)\s?$',
        timeout     => 30,
        username_re => '(?i)(login|user(name)?):?\s*(\r|\n)?$',
    };

    # create new object hash from input opts, refer to perldoc for this sub
    #   this allows first debug log entry according to input opts
    my $self = bless Mnet::Opts::Cli::Cache::get($opts), $class;
    $self->debug("new starting");

    # debug output of opts used to create this new object
    #   skip this if we are being called from an extended subclass
    if ($class eq "Mnet::Expect::Cli") {
        foreach my $opt (sort keys %$opts) {
            my $value = Mnet::Dump::line($opts->{$opt});
            $value = "****" if $opt eq "password" and defined $opts->{$opt};
            $self->debug("new opts $opt = $value");
        }
    }

    # set input opts to defaults if not defined
    foreach my $opt (keys %$defaults) {
        $self->{$opt} = $defaults->{$opt} if not defined $self->{$opt};
    }

    # call Mnet::Expect to create spawned object
    $self->debug("new calling Mnet::Expect::new");
    $self = Mnet::Expect::new($class, $self);

    # return undef if Expect spawn does not succeed
    if (not $self) {
        $self->debug("new finished, Mnet::Expect::new failed, returning undef");
        return undef;
    }

    # return undef if login does not succeed
    if (not $self->login) {
        $self->debug("new finished, login failed, returning undef");
        return undef;
    }

    # finished new method, return spawned object
    $self->debug("new finished, returning $self");
    return $self;
}



sub login {

# $ok = $self->login
# purpose: used to authenticate to session
# $ok: set true on success, false on failure
# note: global variable Mnet::Expect::error is set for failures

    # read input object
    my $self = shift;
    $self->debug("login starting");

    # $match = _login_expect($self, $re)
    #   purpose: wait for next login prompt, output debug and error messages
    #   $self: current Mnet::Expect::Cli object
    #   $re: set to keyword username_re, password_re, or prompt_re
    #   $match: set to matched $re text, or undef with Mnet::Expect::error set
    #   note: failed_re is checked if $re is not set prompt_re
    sub _login_expect {
        my ($self, $re) = (shift, shift);
        $self->debug("login_expect $re starting");
        my @matches = ('-re', $self->{failed_re}, '-re', $self->{$re});
        my $expect = $self->expect->expect($self->{timeout}, @matches);
        my $match = Mnet::Dump::line($self->expect->match);
        if (not $expect or $expect == 1) {
            $Mnet::Expect::error = "login $re timed out";
            $Mnet::Expect::error = "login failed_re matched $match" if $expect;
            $self->debug("login_expect $re error, $Mnet::Expect::error");
            return undef;
        }
        $self->debug("login_expect $re finished, matched $match");
        return $self->expect->match;
    }

    # if username is set then wait and respond to username_re prompt
    #   return if _login_expect fails, Mnet::Expect::error will be set
    if (defined $self->{username}) {
        _login_expect($self, "username_re") // return undef;
        $self->expect->send("$self->{username}\r");

    }

    # if password is set then wait and respond to password_re prompt
    #   return if _login_expect fails, Mnet::Expect::error will be set
    #   prompt user for password if password not set and password_in is set
    #   _log_filter used to keep password out of Mnet::Expect->log
    if (defined $self->{password} or $self->{password_in}) {
        _login_expect($self, "password_re") // return undef;
        my $password = $self->{password};
        if (not defined $password) {
            $self->debug("login password_in prompt starting");
            {
                local $SIG{INT} = sub { system("stty echo 2>/dev/null") };
                syswrite STDERR, "\nEnter $self->{password_in}: ";
                system("stty -echo 2>/dev/null");
                chomp($password = <STDIN>);
                system("stty echo 2>/dev/null");
                syswrite STDERR, "\n";
            };
            $self->debug("login password_in prompt finished");
        }
        $self->debug("login sending password");
        $self->{_log_filter} = $password;
        $self->expect->send("$password\r");
    }

    # detect command prompt
    #   send a carraige return and ensure we get the same prompt back
    #   clear expect buffer before sending cr, to flush out banner text, etc
    #   set prompt_re to detected command prompt when finished
    my ($prompt1, $prompt2, $attempts) = ("", "", 3);
    foreach my $attempt (1.. $attempts) {
        $self->debug("login detect prompt attempt $attempt");
        $prompt1 = _login_expect($self, "prompt_re") // return undef;
        $self->{_log_filter} = undef;
        if ($prompt1 eq $prompt2) {
            $self->{prompt_re} = '(\r|\n)\Q'.$prompt1.'\E$';
            $self->debug("login detect prompt_re = /$self->{prompt_re}/");
            $self->debug("login finished, returning true");
            return 1;
        } else {
            $self->debug("login detect prompt sending cr");
            1 while $self->expect->expect(1, '-re', '(\s|\S)+');
            $self->expect->send("\r");
            $prompt2 = $prompt1;
        }
    }

    # finished login method, return true false for failure
    $self->debug("login finished, returning false");
    return 0;
}



sub prompt_re {

=head1 $prompt_re = $self->prompt_re($prompt_re)

Get and/or set new prompt_re for the current object.

=cut

    # read input object and new prompt_re
    my ($self, $prompt_re) = (shift, shift);

    # set new prompt_re, if defined
    if (defined $prompt_re) {
        $self->debug("prompt_re set = $prompt_re");
        $self->{prompt_re} = $prompt_re;
    }

    # finished, return prompt_re
    return $self->{prompt_re};
}



sub timeout {

=head1 $self->timeout($timeout)

Set a new timeout for the current object, refer to perldoc Expect.

=cut

    # set new timeout for curent object
    my $self = shift;
    my $timeout = shift // carp("missing tiemout arg");
    $self->debug("timeout set = $timeout");
    $self->{timeout} = $timeout;
    return;
}



#? finish me
#   Mnet::Expect::Cli
#       command_cache_clear
#           cache_clear causes cache_id to be incremented
#           cache_id used with record/replay to return newer outputs
#       command($cmd, $timeout, \%prompts)
#           @prompts is an ordered list of expect match conditions
#           @prompts processing needs to be able to handle the following:
#               prompt_re           (to disable or override default prompt_re)
#               paging_key          (to disable or override default paging_key)
#               paging_re           (to disable or override default paging_re)
#               timeout_ok          (gracefully return after disconnect)
#               match_re            (wait for regex, send response or run code)
#           order of @prompts?
#   Mnet::Expect::Cli::Cisco
#       new
#           option enable can be set
#           calls Cli->new with pagination default for cisco
#           enters enable mode, if enable option defined
#       close
#           call Cli->close("end\nexit\n") for cisco devs
#   add -re '\r\N' progress bar handling ability?
#       $match = $expect->match;
#       $match =~ /\N*\r(\N)/$1/;
#       $match .= $expect->after;
#       expect->set_accum($match);
#   also remember testing record and replay
#       along with the capability to handle multiple test sessions



=head1 SEE ALSO

 Expect
 Mnet
 Mnet::Expect
 Mnet::Expect::Cli::Cisco
 Mnet::Log::Conditional

=cut

# normal package return
1;

