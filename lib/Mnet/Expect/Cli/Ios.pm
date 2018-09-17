package Mnet::Expect::Cli::Ios;

=head1 NAME

Mnet::Expect::Cli::Ios

=head1 SYNOPSIS

This module can be used to create new Mnet::Expect::Cli::Ios objects,
which inherit Mnet::Expect::Cli methods.

=head1 TESTING

Mnet::Test --record and --replay functionality are supported. Refer to the
Mnet::Expect::Cli module for more information.

=cut

# required modules
use warnings;
use strict;
use parent qw( Mnet::Expect::Cli );
use Carp;
use Mnet::Opts::Cli::Cache;



sub new {

=head1 $self = Mnet::Expect::Cli::Ios->new(\%opts)

This method can be used to create new Mnet::Expect::Cli::Ios objects.

The following input opts may be specified, in addition to options from
the Mnet::Expect::Cli and Mnet::Expect modules:

 enable         set to password for enable mode during login
 enable_in      stderr prompt for stdin entry of enable if not set
 enable_user    default enable username set from username option
 failed_re      default recognizes failed ios logins
 paging_key     default space key to send for ios pagination prompts
 paging_re      default recognized ios pagination prompt --more--
 prompt_re      defaults to ios user or enable mode prompt

An error is issued if there are login problems.

For example, the following call will start an ssh expect session to a device:

 my $opts = { spawn => "ssh 1.2.3.4", prompt => 1 };
 my $expect = Mnet::Expect::Cli->new($opts);

Refer to the Mnet::Expect::Cli and Mnet::Expect modules for more information.

=cut

    # read input class and optional opts hash ref
    my $class = shift // croak("missing class arg");
    my $opts = shift // {};

    # create log object with input opts hash, cli opts, and pragmas in effect
    #   we do this so that logging works for this and modules that inherit this
    my $cli = Mnet::Opts::Cli::Cache::get($opts);
    my $log = Mnet::Log::Conditional->new($cli);
    $log->debug("new starting");

    # create hash that will become new object from input opts hash
    my $self = $opts;

    # note default options for this class
    #   includes recognized cli opts and opts for this object
    #   the following keys starting with underscore are used internally:
    #       _enable_ => causes enable password value to be hidden in opts debug
    #   update perldoc for this sub with changes
    #   refer also to Mnet::Expect::Cli defaults
    my $defaults = {
        enable      => undef,
        _enable_    => undef,
        enable_in   => undef,
        enable_user => undef,
        failed_re   => '(?i)(^\s*\%|closed|error|denied|fail|incorrect|invalid|refused|sorry)',
        paging_key  => ' ',
        paging_re   => '--(M|m)ore--',
        prompt_re   => '(^|\r|\n)\S+(>|#) $',
    };

    # update future object $self hash with default opts
    foreach my $opt (sort keys %$defaults) {
        $self->{$opt} = $defaults->{$opt} if not exists $self->{$opt};
    }

    # call Mnet::Expect::Cli::new to create new object
    $log->debug("new calling Mnet::Expect::Cli::new");
    $self = Mnet::Expect::Cli::new($class, $self);

    # return undef if Mnet::Expect::Cli object could not be created
    if (not $self) {
        $log->debug("new Mnet::Expect::Cli object failed, returning undef");
        return undef;
    }

    # change detected prompt to ensure it works in both user and enable prompts
    $self->debug("new checking prompt for enable and user mode");
    my $prompt_re = $self->prompt_re;
    $prompt_re =~ s/(>|#)/(>|#)/;
    $self->prompt_re($prompt_re);

    # call enable method if enable or enable_in option is set
    $self->enable if defined $self->{enable} or $self->{enable_in};

    # finished new method, return Mnet::Expect::Cli::Ios object
    $self->debug("new finished, returning $self");
    return $self;
}



sub enable {

=head1 $boolean = $self->enable($password)

Use this method to check for enable mode on an ios device, and/or to enter
enable mode on the device.

The input password will be used, or the enable and enable_in options for the
current object. An error results if a password is needed and none was set.

A fatal error is issued if an enable password is required and none is set.

A value of true is returned if the ios device is at an enable mode command
prompt, otherwise a value of false is returned.

=cut

    # read input object, password, and username args
    #   set undefined enable password and username args from object option
    my $self = shift or croak("missing self arg");
    my $password = shift // $self->{enable};
    my $username = shift // $self->{username};
    $self->debug("enable starting");

    # send enable comand
    #   return output if we receive normal cisco enable# prompt
    #   return output if we receive an % ios error
    #   send username if prompted for user or username
    #       return output if replay option is set
    #       return output if enable_user or username is not set
    #   send password if prompted for password_re
    #       return output if replay option is set
    #       prompt stderr/stdin for undef password if enable_in is set
    #       _log_filter is used to keep password out of Mnet::Expect->log
    #   return output if we get anything that matches prompt_re
    my $output = $self->command("enable", undef, [
        '#'  => undef,
        '\%' => undef,
        '(?i)\s*user(name)?:?\s*$' => sub {
            my ($self, $output) = (shift, shift);
            return undef if $self->{replay};
            return "$self->{enable_user}\r" if defined $self->{enable_user};
            return "$self->{username}\r" if defined $self->{username};
            return undef;
        },
        $self->{password_re} => sub {
            my ($self, $output) = (shift, shift);
            return undef if $self->{replay};
            if (not defined $password) {
                if ($self->{enable_in}) {
                    $self->debug("enable enable_in prompt starting");
                    {
                        local $SIG{INT} = sub {
                            system("stty echo 2>/dev/null")
                        };
                        syswrite STDERR, "\nEnter enable $self->expect->match: ";
                        system("stty -echo 2>/dev/null");
                        chomp($password = <STDIN>);
                        system("stty echo 2>/dev/null");
                        syswrite STDERR, "\n";
                    };
                    $self->debug("enable enable_in prompt finished");
                } else {
                    $self->fatal("enable or enable_in required and not set");
                }
            }
            $self->debug("enable sending password");
            $self->{_log_filter} = $password;
            return "$password\r";
        },
        $self->{prompt_re} => undef,
    ]);

    # return true if we confirmed we are at an enable prompt
    if (defined $output and $output =~ /#/) {
        $self->debug("enable finished, confirmed enable, returning true");
        return 1;
    }

    # finished enable method, return true
    $self->debug("enable finished, returning false");
    return 0;
}



sub close {

=head1 $self->close

This method sends the end and exit ios commands before closing the current
expect session. Timeouts are gracefully handled. Refer to the close method
in the Mnet::Expect module for more information.

=cut

    # send end and exit commands then close expect session
    #   gracefully handle timeouts on end and exit commands
    my $self = shift or croak("missing self arg");
    $self->command("end",  undef, [ "" => undef ]);
    $self->command("exit", undef, [ "" => undef ]);
    $self->SUPER::close();
    return
}



=head1 SEE ALSO

 Expect
 Mnet
 Mnet::Expect
 Mnet::Expect::Cli
 Mnet::Test

=cut

# normal package return
1;

