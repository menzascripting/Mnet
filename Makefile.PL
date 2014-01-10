#!/usr/bin/env perl

# strict warnings
use warnings;
use strict;

# create module make file
use ExtUtils::MakeMaker;

# get list of scripts from manifest
my @scripts = ();
push @scripts, $_ foreach split(/\n/, `cat MANIFEST | grep ^script`);

# create make file
WriteMakefile(
    ABSTRACT         => 'network automation scripting module',
    AUTHOR           => 'Mike Menza <mmenza@cpan.org>',
    EXE_FILES        => \@scripts,
    LICENSE          => 'gpl',
    MIN_PERL_VERSION => '5.8.0',
    NAME             => 'Mnet',
    NO_MYMETA        => 1,
    VERSION_FROM     => 'lib/Mnet.pm'
);

# finished
exit;

