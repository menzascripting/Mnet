#!/usr/bin/env perl

# strict warnings
use warnings;
use strict;

# create module make file
use ExtUtils::MakeMaker;

# create make file
WriteMakefile(
    ABSTRACT         => 'Testable network automation scripting module',
    AUTHOR           => 'Mike Menza <mmenza@cpan.org>',
    LICENSE          => 'gpl_3',
    MIN_PERL_VERSION => '5.10.0',
    NAME             => 'Mnet',
    NO_MYMETA        => 1,
    VERSION_FROM     => 'lib/Mnet.pm'
);

# finished
exit;

