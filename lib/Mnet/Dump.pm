package Mnet::Dump;

=head1 NAME

Mnet::Dump - Data::Dumper related functions with sorted outputs

=head1 SYNOPSIS

    use Mnet::Dump
    $line = Mnet::Dump::line($value)

=head1 DESCRIPTION

Mnet::Dump contains L<Data::Dumper> related functions with sorted outputs.

=head1 FUNCTIONS

Mnet::Dump implements the functions listed below.

=cut

# required modules
use warnings;
use strict;
use Data::Dumper;



sub line {

=head2 Mnet::Dump::line

    $line = Mnet::Dump::line($value)

This function returns L<Data::Dumper> output for the specified input value as
a single line in sorted order.

=cut

    # read input value, dump it as a sorted single Data::Dumper line
    #   Quotekeys set explicity here because some cpan tests failed otherwise
    #   www.cpantesters.org/cpan/report/9f2d1876-f370-11e9-a65e-fe3acca03743
    my $value = shift;
    my $value_dumper = Data::Dumper->new([$value]);
    $value_dumper->Indent(0);
    $value_dumper->Sortkeys(1);
    $value_dumper->Useqq(1);
    $value_dumper->Quotekeys(1);
    my $value_dump = $value_dumper->Dump;
    $value_dump =~ s/(^\$VAR1 = |;\n*$)//g;
    return $value_dump;
}



=head1 SEE ALSO

L<Mnet>

=cut

# normal end of package
1;

