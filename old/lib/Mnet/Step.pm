package Mnet::Step;

=head1 NAME

Mnet::Step - network automation scripting module

=cut

# Copyright 2006, 2013-2014 Michael J. Menza Jr.
# Refer to `perldoc Mnet` for more information.

=head1 SYNOPSIS

Usage examples:

 # organize implementation and backout steps into plan and push phases
 use Mnet::Step;
 use Mnet::Expect;
 my $session = new Mnet::Expect or die;
 while (&step_process) {

     # numbered implement step, code or config sent during push pass
     &step($title, $instruct, $session, $config, $code);

     # manual implement step for plan, config added to review
     &step_manual($title, $instruct, $config);

     # numbered notification presented to engineer during push pass
     &step_notify($title, $instruct);

     # pause that will wait for engineer during push pass
     &step_pause($instruct);

     # numbered backout step for backout plan, manually used if needed
     &step_backout($title, $instruct, $config);

 # finish plan/push loop
 }

=head1 DESCRIPTION

The step module can be used to organize a step-by-step implementation
script into 'plan' and 'push' passes.

In the plan pass each step is detailed - notifications, manual steps
and steps that will push config or run code. In the push pass the
engineer is presented instructions for manual steps, notifications,
and the results of automated steps. The script is run in plan mode
by default. Push mode is set with the --step-push option.

Note that step_manual, step_notify and step_pause will prompt the
the engineer on stderr to hit the enter key. If --step-nopause is set
then these calls will skip the prompt and the keypress input.

=head1 CONFIGURATION

Alphabetical list of all config settings supported by this module:

 --step-config-error    regex for config push errors, default ios '%'
 --step-config-comment  defaults to exclamation point for ios
 --step-config-ignore   set regex for config push errors to ignore
 --step-config-prefix   defaults to 'config term' for ios
 --step-config-suffix   defaults to 'end' for ios
 --step-detail          extra debug logging, default disabled
 --step-diff            set to filename to save diffable plan review
 --step-nopause         set to skip manual, notify, pause keypresses
 --step-push            set to enable push pass
 --step-push-nodie      set to continue push after plan pass errors
 --step-review          set to output implementation review section
 --step-version         set at compilation to build number

Note that step-config-ignore is case-insensitive and stays in effect
for the next step call only.

=head1 EXPORTED FUNCTIONS

The following functions are exported from this module and intended
for use from scripts and libraries:

=cut



# modules used
use warnings;
use strict;
use Carp;
use Exporter;
use Mnet;

# export module function names
our @ISA = qw( Exporter );
our @EXPORT = qw(
    step step_backout step_manual step_notify step_pause step_process
);

# module initialization, set module defaults
BEGIN {

    # initialize module variables
    our $cfg = &Mnet::config({
        'step-config-error'   => '%',
        'step-config-comment' => '!',
        'step-config-prefix'  => 'config term',
        'step-config-suffix'  => 'end',
        'step-version'        => '+++VERSION+++',
    });

    # initialize global variables for step functions
    our ($push, $pass) = (0, undef);
    our ($implement_count, $implement_review, $diff) = (0, "", 0);
    our ($backout_count, $backout_plan) = (0, "");
}



sub format_config {

    # internal: $output = &format_config($config, $self)
    # purpose: output nicely formatted config commands
    # note: self is optional, object-name push comment output if present

    # read config
    my $config = shift or croak "internal error: missing config arg";
    my $self = shift;
    croak "step invalid self arg" if defined $self and not ref $self;

    # initialize output
    my $output = "";

    # add prefix, if configured
    $output .= "$Mnet::Step::cfg->{'step-config-prefix'}\n"
        if $Mnet::Step::cfg->{'step-config-prefix'};

    # add push comment
    $output .= " $Mnet::Step::cfg->{'step-config-comment'} "
        . "push to $self->{'object-name'}\n"
        if $self and $self->{'object-name'}
        and $Mnet::Step::cfg->{'step-config-comment'};

    # prepare output
    foreach my $line (split(/\n/, $config)) {
        next if $line !~ /\S/;
        $line =~ s/\s\s\s\s//g;
        $output .= " $line\n";
    }

    # add suffix, if configured
    $output .= "$Mnet::Step::cfg->{'step-config-suffix'}\n"
        if $Mnet::Step::cfg->{'step-config-suffix'};

    # finished
    return $output;
}



sub format_instructions {

    # internal: $output = &format_instructions($title, $instructions)
    # purpose: output nicely formatted title and instructions
    # note: lines are wrapped, text quoted in backticks doesn't get wrapped
    # note: \\n can be inserted into instructions to force a carriage return

    # read instructions argument and error if not defined, initialize output
    my $title = shift
        or croak "format_instructions: missing title arg";
    my $instructions = shift
        or croak "format_instructions: missing instructions arg";
    my $output = "";

    # remove extra whitespace from title and output anything left
    $title =~ s/(^\s+|\r|\n)/ /g;
    $title =~ s/\s\s+/ /g;
    $title =~ s/\s+$//;
    $output .= "! $title\n" if $title =~ /\S/;

    # remove extra whitespace and carriage returns
    $instructions =~ s/(^\s+|\r|\n)/ /g;
    $instructions =~ s/\s\s+/ /g;
    $instructions =~ s/\s+$//;

    # output word wrapped text, start lines with bang, don't wrap quoted text
    if ($instructions =~ /\S/) {
        my $chars = 0;
        $output .= "!\n!";
        while ($instructions =~ s/\s*(\S+)//) {
            my $word = $1;
            while ($word =~ s/^\s*\\n\s*//) {
                $output .= "\n!";
                $chars = 0;
            }
            my $eow_crs = undef;
            while ($word =~ s/\s*\\n\s*$//) {
                $eow_crs .= "\n!";
            }
            next if $word !~ /\S/;
            $word .= $1 if $word =~ /^`/ and $word !~ /'$/
                and $instructions =~ s/^([^`]*`)//;
            $chars += length($word) + 1;
            if ($chars > 78) {
                $output .= "\n!";
                $chars = length($word) + 2;
            }
            $output .= " $word";
            if (defined $eow_crs) {
                $output .= $eow_crs;
                $chars = 0;
            }
        }
        $output =~ s/\n?!\s*\n?$//;
        $output .= "\n";
    }

    # finished
    return $output;
}



sub heading {

    # internal: &heading($title)
    # purpose: output demarcated heading to terminal

    # read title, output heading and return
    my $title = uc(shift) or croak "internal error: missing title arg";
    &out("\n" . "-" x 79 . "\n$title\n" . "-" x 79 . "\n\n");
    return;
}



sub out {

    # internal: &out($text)
    # purpose: output step text to standard output
    # note: a carriage return is appended

    # read text
    my $text = shift or return;

    # output text
    syswrite STDOUT, $text;

    # finished
    return;
}



sub step {

=head2 step function

 $ok = &step($title, $instructions, $self, $config, $code)

 plan code: return $error (never set)
 plan config (default): return $ok (always set)
 plan config (no_die): return $ok

 push code: return $error (if code had error)
 push config (default):
 push config (no die):

Adds a step to the implementation plan.

 $title: title in plan phase, comment for config and for log text
 $instructions: text output during plan phase
 $self: expect, ios or other object with command method for config push
 $config: displayed in plan and review, sent during push pass
 $code: subroutine reference executed in push mode instead of config
 $ok: set true if there were no code or config warnings

Note: script will die during push errors unless step-push-nodie is set

Note: instructions and config text sent during plan phase

Note: config pushed and code run during push phase

=cut

    # read session, step title, descriptive text, config and perl code
    &dtl("step called from " . lc(caller));
    my ($title, $instructions, $self, $config, $code) = @_;
    croak "step missing title arg" if not $title;
    $instructions = "" if not defined $instructions;
    croak "step invalid self arg" if defined $self and not ref $self;
    croak "step invalid code arg" if defined $code and not ref $code;
    $config = "" if not defined $config;
    my $error = 0;

    # update step number
    $Mnet::Step::implement_count++;
    my $step_title = "Step $Mnet::Step::implement_count - $title";

    # output title, instructions and config commands during plan pass
    if ($Mnet::Step::pass ne 'push') {
        &dbg(lc("step: non-push call, $step_title"));
        &out("\n");
        &out(&format_instructions("$step_title", $instructions));
        $Mnet::Step::implement_review .= lc("! $step_title\n");
        if ($config =~ /\S/) {
            &out(&format_config($config, $self));
            $Mnet::Step::implement_review .= &format_config($config, $self);
        }
        &out("\n");

    # push config and execute code fragments during push pass
    } elsif ($Mnet::Step::pass eq 'push') {
        &dbg(lc("step: push call, $step_title"));
        &out("\n");
        &out(&format_instructions($step_title, $instructions));
        &out(&format_config($config, $self));
        &out("\n");
        if (defined $code) {
            &log(lc("executing code, $step_title"));
            $Mnet::Step::code_error = 0;
            &$code;
            $error = $@ if $@;
            if ($error) {
                my $err = "push code error, $step_title ($error)";
                croak $err if not $Mnet::Step::cfg->{'step-push-nodie'};
                carp($err);
                return 0;
            } elsif ($Mnet::Step::code_error) {
                my $err = "push code warning, $step_title";
                croak $err if not $Mnet::Step::cfg->{'step-push-nodie'};
                carp($err);
                return 0;
            } else {
                &dbg("step: executed code $step_title, no errors");
            }
        } elsif ($config =~ /\S/) {
            &log(lc("pushing config, $step_title"));
            my $cfg_error = $Mnet::Step::cfg->{'step-config-error'};
            my $cfg_ignore = $Mnet::Step::cfg->{'step-config-ignore'};
            &dbg("step: step-config-error is not set") if not $cfg_error;
            &dbg("step: step-config-ignore set $cfg_ignore") if $cfg_ignore;
            $config = "$Mnet::Step::cfg->{'step-config-prefix'}\n$config"
                if $Mnet::Step::cfg->{'step-config-prefix'};
            $config = "$config\n$Mnet::Step::cfg->{'step-config-suffix'}"
                if $Mnet::Step::cfg->{'step-config-suffix'};
            foreach my $cfg_line (split(/\n/, $config)) {
                &dtl("step pushing config $cfg_line");
                my $out = $self->command($cfg_line);
                if (not defined $out) {
                    my $err ="push config timeout, $step_title, line $cfg_line";
                    croak $err if not $Mnet::Step::cfg->{'step-push-nodie'};
                    carp($err);
                    return 0;
                }
                next if not $cfg_error or $out !~ /\Q$cfg_error\E/;
                if (not $cfg_ignore) {
                    my $err = "push config error, $step_title, line $cfg_line";
                    croak $err if not $Mnet::Step::cfg->{'step-push-nodie'};
                    carp($err);
                    return 0;
                }
                foreach my $err_line (split(/\n/, $out)) {
                    next if $err_line =~ /$cfg_ignore/i;
                    my $err = "push config error, $step_title, line $cfg_line";
                    croak $err if not $Mnet::Step::cfg->{'step-push-nodie'};
                    carp($err);
                    return 0;
                }
            }
            &dbg("step: config push finished $step_title");
        } else {
            &log(lc("nothing to do, $step_title"));
        }
        &out("\n");

    # finished processing for the current pass
    }

    # reset step config ignore setting after each completed step
    $Mnet::Step::cfg->{'step-config-ignore'} = undef;

    # return success
    return 1;
}



sub step_backout {

=head2 step_backout function

 &step_backout($title, $instructions, $config, $self)

Add intructions to backout plan.

 $title: title in plan phase, comment for config and for log text
 $instructions: text output with backout plan at end of plan phase
 $config: config output that gets displayed in backout plan
 $self: optional mnet instance with object-name set for config

Note: instructionss and config added to backout plan

=cut

    # read device address, step title, descriptive text and config
    &dtl("step_backout called from " . lc(caller));
    my ($title, $instructions, $config, $self) = @_;
    croak "step_backout: missing title arg" if not $title;
    $instructions = "" if not defined $instructions;
    $config = "" if not defined $config;
    croak "step_manual self arg not an instance" if $self and not ref $self;

    # only output in plan mode
    if ($Mnet::Step::pass eq 'push') {
        &dbg("step_backout: push mode skip, $title");
        return;
    }

    # increment backout step and set step title
    $Mnet::Step::backout_count++;
    my $step_title = "Step $Mnet::Step::backout_count - $title";

    # add to backout plan
    &dbg(lc("step_backout: adding $step_title"));
    $Mnet::Step::backout_plan .= "\n";
    $Mnet::Step::backout_plan
        .= &format_instructions($step_title, $instructions);
    if ($config =~ /\S/) {
        $Mnet::Step::backout_plan .= &format_config($config, $self);
    }
    $Mnet::Step::backout_plan .= "\n";

    # finished
    return;
}



sub step_manual {

=head step_manual function

 &step_manual($title, $instructions, $config, $self)

Add intructions for engineer to implementation plan.

The config argument is optional. This will present config that the
engineer would need to manually handle during a push. The optional
self argument will tag this config with the object-name name when
output in the implementation review section.

 $title: title in plan phase, comment for config and for log text
 $instructions: text output and highlighted for engineer
 $config: displayed in plan and review, sent during push pass
 $self: optional mnet instance with object-name set for config

=cut

    # read device address, step title, descriptive text and config
    &dtl("step_manual called from " . lc(caller));
    my ($title, $instructions, $config, $self) = @_;
    croak "step_manual: missing title arg" if not $title;
    $title = uc("engineer manual task, $title");
    $instructions = "" if not defined $instructions;
    $config = "" if not defined $config;
    croak "step_manual self arg not an instance" if $self and not ref $self;

    # handle step increment
    $Mnet::Step::implement_count++;
    my $step_title = "Step $Mnet::Step::implement_count - $title";

    # output manual task in plan mode
    if ($Mnet::Step::pass ne 'push') {
        &dbg(lc("step_manual: plan call, $step_title"));
        $Mnet::Step::implement_review .= lc("! $step_title\n");
        &out("\n");
        &out(&format_instructions($step_title, "
            The implementation engineer will need to perform the following
            manual task: $instructions
        "));
        if ($config) {
            &out(&format_config($config, $self));
            $Mnet::Step::implement_review .= &format_config($config, $self);
        }
        &out("\n");

    # output manual task in push mode
    } elsif ($Mnet::Step::pass eq 'push') {
        &dbg(lc("step_manual: push call, $step_title"));
        $instructions =~ s/(\r|\r)+$//g;
        &out("\n");
        &out(&format_instructions($step_title, $instructions));
        &out(&format_config($config, $self)) if $config;
        &out("\n");
        &log("pausing script, waiting for engineer to hit the enter key");
        &wait_enter_key;
        &out("\n");

    # finished processing manual task
    }

    # finished
    return;
}



sub step_notify {

=head2 step_notify function

 &step_notify($title, $instructions)

Output instructions during push phase.

 $title: title that goes with this notification
 $instructions: text output during push pass

=cut

    # read input title and text
    &dtl("step_notify called from " . lc(caller));
    my $title = shift or croak "step_notify: missing title arg";
    my $instructions = shift or croak "step_notify: missing instructions arg";

    # handle step increment
    $Mnet::Step::implement_count++;
    my $step_title = "Step $Mnet::Step::implement_count - ";
    $step_title .= uc("engineer notification, $title");

    # output notification in plan mode
    if (not $Mnet::Step::pass or $Mnet::Step::pass ne 'push') {
        &dbg(lc("step_notify: plan call, $step_title"));
        $Mnet::Step::implement_review .= lc("! $step_title\n");
        &out("\n");
        &out(&format_instructions($step_title, "
            The implementation engineer will be notified: $instructions
        "));
        &out("\n");

    # output notification in push mode
    } elsif ($Mnet::Step::pass eq 'push') {
        &dbg(lc("step_notify: push call, $step_title"));
        $instructions =~ s/(\r|\r)+$//g;
        &out("\n");
        &out(&format_instructions($step_title, $instructions));
        &out("\n");
        &log("pausing script, waiting for engineer to hit the enter key");
        &wait_enter_key;
        &out("\n");

    # finished processing notification
    }

    # finished
    return;
}



sub step_pause {

=head2 step_pause function

 &step_pause($instructions);

Pause during push phase and wait for engineer signal to continue

 $instructions: text instructions that go with the pause notification

Note: can change session user, address, enable_hint, pass_hint before call

=cut

    # read session, step title, descriptive text, config and perl code
    &dtl("step_pause called from " . lc(caller));
    my $instructions = shift;
    $instructions = "The script will wait." if not defined $instructions;

    # implement step count and set title depending on skip_pause state
    $Mnet::Step::implement_count++;
    my $step_title = "Step $Mnet::Step::implement_count - ";
    if ($Mnet::Step::cfg->{'step-nopause'}) {
        $step_title .= "script pause for engineer will be skipped";
    } else {
        $step_title .= uc("engineer manual task, script pause for engineer");
    }

    # handle if step_pause has been cleared
    if ($Mnet::Step::cfg->{'step_nopause'}) {
        &dbg("step_pause: step_nopause set, skip normal processing");
        &out("\n");
        &out(&format_instructions($step_title, "
            The script is configured to skip pause steps. Otherwise the
            engineer would have been notified: $instructions
        "));
        &out("\n");
        return;

    # return if not in push mode, we only pause if in push mode
    } elsif ($Mnet::Step::pass ne 'push') {
        &dbg("step_pause: plan call, notify that the script will pause");
        $Mnet::Step::implement_review .= lc("! $step_title\n");
        &out("\n");
        &out(&format_instructions($step_title, "
            The implementation engineer will be notified: $instructions"
        ));
        &out("\n");
        return;

    # handle push mode pause
    } elsif ($Mnet::Step::pass eq 'push') {
        &dbg("step_pause: push call beign processed");
        &out("\n");
        &out(&format_instructions($step_title, $instructions));
        &out("\n");
        &log("pausing script, waiting for engineer to hit the enter key");
        &wait_enter_key;
        &out("\n");
    }

    # finished
    &dbg("step_pause: finished");
    return;
}



sub step_process {

=head2 step_process function

 while (&step_process) {
    # other step calls processed in plan and push passes
 }

Handles going into plan then push modes. Headings are output. Push
mode is aborted if there were errors before plan finished, unless
step-push-nodie is set.

=cut

    # starting
    &dtl("step_process called from " . lc(caller));    

    # on first call set plan pass and output heading for plan mode
    if (not $Mnet::Step::pass) {
        &dbg("step_process: starting plan pass");
        $Mnet::Step::pass = 'plan';
        &heading("plan output"); 
        return 1;
    }

    # on third call we are finished with push, return false to exit pass loop
    if ($Mnet::Step::pass eq 'push') {
        &dbg("step_process: finished push pass");
        &heading("push finished");
        return 0;
    }

    # on second call we are moving from plan to push mode
    &dbg("step_process: processing end of plan mode");

    # output step-diff file, if configured
    if ($Mnet::Step::cfg->{'step-diff'}) {
        &dbg("step_process: saving step-diff $Mnet::Step::cfg->{'step-diff'}");
        if (open(my $fh, ">$Mnet::Step::cfg->{'step-diff'}")) {
            &dbg("step_process: opened step-diff file");
            my $output = $Mnet::Step::implement_review;
            $output = "" if not defined $output;
            print $fh $output;
            CORE::close $fh;
            &log("created step-diff file $Mnet::Step::cfg->{'step-diff'}");
        } else {
            carp "unable to save step-diff $Mnet::Step::cfg->{'step-diff'}, $!";
        }
    }

    # output end of plan warning on errors and if push will be aborted
    if ($Mnet::error) {
        carp "there were errors while creating plan";
        if ($Mnet::Step::cfg->{'step-push-die'}) {
            carp "automated step-push will abort due to plan errors";
        } else {
            carp "automated step-push will execute despite plan errors";
        }
    }

    # output backout section
    &heading("backout output");
    if ($Mnet::Step::backout_plan =~ /\S/) {
        &out(&format_instructions("Manual backout plan", "
            Note that this backout plan would need to be manually executed
            by the engineer if a backout is necessary. The script does not
            automate any of the backout.
        "));
        &out("\n");
        &out($Mnet::Step::backout_plan);
    } else {
        &out(&format_instructions("No backout plan", "
            There is no backout plan provided here.
        "));
        &out("\n");
    }

    # output plan review section if set in config
    if ($Mnet::Step::cfg->{'step-review'}) {
        &heading("review output");
        &out($Mnet::Step::implement_review);
        &out("\n");
        if ($Mnet::error) {
            carp "there were errors while creating plan, refer to plan output";
            if ($Mnet::Step::cfg->{'step-push-die'}) {
                carp "automated step-push will abort due to plan errors";
            } else {
                carp "automated step-push will execute despite plan errors";
            }
            &out("\n");
        }
    }

    # handle plan being finished when push not configured
    if (not $Mnet::Step::cfg->{'step-push'}) {
        &dbg("step_process: finished plan, step-push not set");
        if ($Mnet::Step::cfg->{'step-review'}) {
            &heading("review finished");
        } else {
            &heading("backout finished");
        }
        return 0;
    }

    # reset implementation step counter and set for push pass
    &dbg("step_process: starting push pass");
    $Mnet::Step::implement_count = 0;
    $Mnet::Step::pass = 'push';
    &heading("push output");

    # output start of push warnings on errors and if push will be aborted
    if ($Mnet::error) {
        if (not $Mnet::Step::cfg->{'step-push-nodie'}) {
            carp "automated step-push aborting due to plan warnings";
            &heading("push finished");
            croak "automated step-push aborted";
        } else {
            carp "automated step-push executing despite plan errors";
        }
    } 

    # should not get to this point
    &dbg("step_process: starting push mode");

    # finished
    return 1;
}



sub wait_enter_key {

    # &wait_enter_key
    # purpose: wait for the engineer to hit the enter key

    # starting
    &dbg("wait_enter_key: starting");

    # skip waiting on enter key if noinput option is set
    if ($Mnet::step::cfg->{'conf-noinput'}) {
        &dbg("wait_enter_key: skipped");
        return;
    }

    # flush input buffer the wait for engineer to hit key
    syswrite STDERR, "Hit enter key to continue... ";
    my $time = time;
    while (1) {
        chomp(my $enter = <STDIN>);
        last if time - $time > 0;
    }

    # finished
    &dbg("wait_enter_key: finished");
    return;
}



=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2014 Michael J. Menza Jr.
Refer to `perldoc Mnet` for more information.

=head1 SEE ALSO

Mnet

=cut



# normal package return
1;

