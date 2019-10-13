#!/usr/bin/env perl

# users should refer to INSTALLATION section of perldoc README for install info

# developers should follow the steps below to create a new release:
#   commit updated Changes document, with date and new release number
#   temporarily update lib/Mnet.pm $VERSION variable with new release number
#   perl Markfile.PL && make distcheck, ensure all files are in MANIFEST
#   make test && make dist && make realclean
#   restore lib/Mnet.pm $VERSION variable to it's normal value of "dev"
#   git add Mnet-<RELEASE>.tar.z && git commit, <RELEASE> in format "5.01"
#   git push origin master
#   git tag "v<RELEASE>" `git log -1 --pretty=%H`
#   git push origin "v<RELEASE>"

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

