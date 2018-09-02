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
use Mnet::Opts::Cli::Cache;



sub new {

=head1 $self = Mnet::Expect::Cli->new(\%opts)

This method can be used to create new Mnet::Expect::Cli objects. The following
input hash options may be specified:

 log_id     note that other Mnet::Log->new opts may be specified
 password   login password for spawned command authentication
 prompt     stderr prompt for stdin password entry if password not set
 spawn      command and arguments array ref, or space separated string
 username   defaults to USER environment variable, if not set
 winsize    specify session rows and columns, defaults to 99999x999

A value of undefined will be returned if there were spawn errors, and the
global Mnet::Expect::spawn_error will be set with error text.

For example, the following call will start an ssh expect session to a device:

 my $opts = { spawn => "ssh 1.2.3.4", prompt => 1 };
 my $expect = Mnet::Expect::Cli->new($opts) or die;

Note that all Mnet::Expect session activity is logged for debugging, refer to
the Mnet::Log module for more information.

=cut

    # read input class and optional opts hash ref
    my $class = shift // croak("missing class arg");
    croak("invalid call to class new") if ref $class;
    my $opts = shift // {};

    # create new object hash from input opts:
    #   the following keys are set from input opts:
    #       debug       => option for methods inherited from Mnet::Log module
    #       log_id      => option for methods inherited from Mnet::Log module
    #       password    => login password for spawned command authentication
    #       prompt      => stderr prompt for stdin password if password not set
    #       quiet       => option for methods inherited from Mnet::Log module
    #       silent      => option for methods inherited from Mnet::Log module
    #       spawn       => command and args array ref, or space separated string
    #       username    => defaults to USER environment variable, if not set
    #       winsize     => specify session rows and columns, defaults 99999x999
    #   the following keys starting with underscore are used internally:
    #       _expect     => spawned Expect object, refer to Mnet::Expect->expect
    my $self = bless Mnet::Opts::Cli::Cache::get($opts), $class;
    $self->debug("new starting");

    # debug output of opts used to create this new object
    foreach my $opt (sort keys %$opts) {
        my $value = Mnet::Dump::line($opts->{$opt});
        $value = "****" if $opt eq "password" and defined $opts->{$opt};
        $self->debug("new opts $opt = $value");
    }

    # return undef if Expect spawn does not succeed
    if (not $self->spawn) {
        $self->debug("new finished, spawn failed, returning undef");
        return undef;
    }

    #? finish me, execute login, handle username/password/prompt

    # finished new method, return spawned object
    $self->debug("new finished, returning $self");
    return $self;
}



#? finish me
#   Mnet::Expect::Cli
#       cache_clear (clears expect cache, uses while loop to empty, etc)
#       cmd($cmd, \@prompts)
#           @prompts is an ordered list of expect match conditions
#           @prompts processing needs to be able to handle the following:
#               prompt detection    (to disable or override default detection)
#               pagination          (should we have some kind of default?)
#               throttling          (to disable or override default?)
#               progress bars       (to disable or override default?)
#               timeouts            (gracefully return after disconnect)
#               match+response      (wait for a regex, then send response)
#               code references     (used to implement many/all of the above?)
#           maybe @prompts would need to be more complex, to hook in via expect
#       cmd_prompt (call Expect->_clean, confirm and return prompt)
#       support for --record and --replay lives in this module?
#           cache_clear causes cache_id to be incremented
#   Mnet::Expect::Cli::Cisco
#       opt_def --enable
#       new (calls Cli->new with pagination default for cisco)
#       login (calls Cli->login, with --enable opt defined in this module)
#       cmd (calls Cli->cmd, Expect->_clean after, has pagination/etc prompts)
#       close (call Cli->close("end\nexit\n") for cisco devs)
#   add -re '\r\N' progress bar handling ability
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

