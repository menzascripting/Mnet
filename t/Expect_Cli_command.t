
# purpose: tests Mnet::Expect::Cli command method functionality

# required modules
use warnings;
use strict;
use Mnet::T;
use Test::More tests => 12;

# init perl code for these tests
my $perl = <<'perl-eof';
    use warnings;
    use strict;
    use Mnet::Expect::Cli;
    use Mnet::Log qw( DEBUG INFO );
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    use Mnet::Test;
    my $opts = Mnet::Opts::Cli->new;
    DEBUG("spawn script: $_") foreach (split/\n/, `cat $ENV{EXPECT} 2>&1`);
    my $expect = Mnet::Expect::Cli->new({
        paging_key  => "\n",
        paging_re   => "MORE(\\r?\\n)",
        spawn       => $ENV{EXPECT},
        timeout     => 2,
    });
perl-eof

# command method call
Mnet::T::test_perl({
    name    => 'command method call',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%;   read INPUT
            echo -n prompt%;   read INPUT
            echo output
            echo -n prompt%;   read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test") . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "output",
    debug   => '--debug',
});

# command method timeout
Mnet::T::test_perl({
    name    => 'command method timeout',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%; read INPUT
            echo -n prompt%; read INPUT
            echo output;     read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test") // "<undef>";
        print "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "<undef>",
    debug   => '--debug',
});

# command method timeout handling
Mnet::T::test_perl({
    name    => 'command method timeout handling',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%; read INPUT
            echo -n prompt%; read INPUT
            echo output;     read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test", undef, [ "" => undef ]) . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "output",
    debug   => '--debug',
});

# command method prompt response text
Mnet::T::test_perl({
    name    => 'command method prompt response text',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%;  read INPUT
            echo -n prompt%;  read INPUT
            echo -n question; read INPUT
            echo output
            echo -n prompt%;  read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test", undef, [ question => "-\r" ]) . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "question-\noutput",
    debug   => '--debug',
});

# command method prompt response undef
Mnet::T::test_perl({
    name    => 'command method prompt response undef',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%;  read INPUT
            echo -n prompt%;  read INPUT
            echo -n question; read INPUT
            echo output
            echo -n prompt%;  read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test", undef, [ question => undef ]) . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "question",
    debug   => '--debug',
});

# command method prompt code response text
Mnet::T::test_perl({
    name    => 'command method prompt code response text',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%;  read INPUT
            echo -n prompt%;  read INPUT
            echo preamble
            echo -n question; read INPUT
            echo output
            echo -n prompt%;  read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test", undef, [ question => sub {
            shift; return "-\r" if shift =~ /preamble/;
        }]) . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "preamble\nquestion-\noutput",
    debug   => '--debug',
});

# command method prompt code response undef
Mnet::T::test_perl({
    name    => 'command method prompt code response undef',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%;  read INPUT
            echo -n prompt%;  read INPUT
            echo preamble
            echo -n question; read INPUT
            echo output
            echo -n prompt%;  read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test", undef, [ question => sub {
            shift; return undef if shift =~ /preamble/;
        }]) . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "preamble\nquestion",
    debug   => '--debug',
});

# command method output with extra prompt
Mnet::T::test_perl({
    name    => 'command method output with extra prompt',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%; read INPUT
            echo -n prompt%; read INPUT
            echo prompt%
            echo output
            echo -n prompt%; read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test") . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "prompt%\noutput",
    debug   => '--debug',
});

# command method with multiple prompts
Mnet::T::test_perl({
    name    => 'command method with multiple prompts',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%; read INPUT
            echo -n prompt%; read INPUT
            echo -n one;     read INPUT
            echo -n two;     read INPUT
            echo output
            echo -n prompt%; read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test", undef, [ one => "1\r", two => "2\r" ]);
        print "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "one1\ntwo2\noutput",
    debug   => '--debug',
});

# command method with output pagination
Mnet::T::test_perl({
    name    => 'command method with output pagination',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%; read INPUT
            echo -n prompt%; read INPUT
            echo output
            echo MORE;       read INPUT
            echo more output
            echo -n prompt%; read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test") . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "output\nmore output",
    debug   => '--debug',
});

# command method cached output
Mnet::T::test_perl({
    name    => 'command method cached output',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%; read INPUT
            echo -n prompt%; read INPUT
            echo output
            echo -n prompt%; read INPUT
            echo uncached output
            echo -n prompt%; read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test") . "\n";
        print $expect->command("test") . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "output\noutput",
    debug   => '--debug',
});

# command cache clear method
Mnet::T::test_perl({
    name    => 'command cache clear method',
    pre     => <<'    pre-eof',
        export EXPECT=$(mktemp); chmod 700 $EXPECT; echo '
            echo -n prompt%; read INPUT
            echo -n prompt%; read INPUT
            echo output
            echo -n prompt%; read INPUT
            echo uncached output
            echo -n prompt%; read INPUT
        ' >$EXPECT
    pre-eof
    perl    => $perl . '
        print $expect->command("test") . "\n";
        $expect->command_cache_clear;
        print $expect->command("test") . "\n";
    ',
    filter  => 'grep -v "Mnet::Log - started" | grep -v "Mnet::Log finished"',
    expect  => "output\nuncached output",
    debug   => '--debug',
});

# finished
exit;
