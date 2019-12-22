
# purpose: tests Mnet::Report::Table row_on_error method functionality

# required modules
use warnings;
use strict;
use Mnet::T;
use Test::More tests => 2;

# init perl code for tests
my $perl = <<'perl-eof';
    use warnings;
    use strict;
    use Mnet::Log;
    use Mnet::Log::Test;
    use Mnet::Opts::Cli;
    use Mnet::Report::Table;
    use Mnet::Test;
    my ($cli, @args) = Mnet::Opts::Cli->new;
    my $table = Mnet::Report::Table->new({
        columns => [
            data => "string",
            error => "error"
        ],
    });
    $table->row_on_error({ data => "row_on_error" });
    die "died\n" if $args[0] and $args[0] eq "die";
    $table->row({ data => "not row_on_error" });
perl-eof

# row_on_error method, no die
Mnet::T::test_perl({
    name    => 'row_on_error method, no log, no die',
    perl    => $perl,
    args    => '--test',
    expect  => <<'    expect-eof',
        --- - Mnet::Log - started
        inf - Mnet::Opts::Cli new parsed opt cli test = 1
        inf - Mnet::Report::Table row {
        inf - Mnet::Report::Table row    data  => "not row_on_error"
        inf - Mnet::Report::Table row    error => undef
        inf - Mnet::Report::Table row }
        --- - Mnet::Log finished with no errors
    expect-eof
    debug   => '--debug',
});

# row_on_error method, die
Mnet::T::test_perl({
    name    => 'row_on_error method, no log, die',
    perl    => $perl,
    args    => '--test die',
    filter  => 'grep -v ^err',
    expect  => <<'    expect-eof',
        --- - Mnet::Log - started
        inf - Mnet::Opts::Cli new parsed opt cli test = 1
        inf - Mnet::Opts::Cli new parsed cli arg (extra) = "die"
        ERR - main perl die, died
        inf - Mnet::Report::Table row {
        inf - Mnet::Report::Table row    data  => "row_on_error"
        inf - Mnet::Report::Table row    error => "main perl die, died"
        inf - Mnet::Report::Table row }
        --- - Mnet::Log finished with errors
    expect-eof
    debug   => '--debug',
});

# finished
exit;
