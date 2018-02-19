package Mnet::Dump;

=head1 NAME

Mnet::Dump

=head1 SYNOPSIS

This module contains Data::Dumper related functions with sorted outputs.


=cut

# required modules
use warnings;
use strict;
use Data::Dumper;



sub line {

=head1 $line = Mnet::Dump::line($value)

This function returns Data::Dumper output for the specified input value as
a single line in sorted order.

=cut

    # read input value, dump it as a sorted single Data::Dumper line
    my $value = shift;
    my $value_dumper = Data::Dumper->new([$value]);
    $value_dumper->Indent(1);
    $value_dumper->Sortkeys(1);
    $value_dumper->Useqq(1);
    my $value_dump = $value_dumper->Dump;
    $value_dump =~ s/(^\$VAR1 = |;\n*$)//g;
    return $value_dump;
}



=head1 SEE ALSO

 Mnet

=cut

# normal end of package
1;

