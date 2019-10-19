#!/usr/bin/env perl

# user install info is in the INSTALLATION section of perldoc lib/Mnet.pm

#? upload script to cpan
#   https://www.perl.com/article/how-to-upload-a-script-to-cpan/
#   add cpan update to developer new release steps below

# developer new release info is below
#
#   description of the new release process:
#
#       check that all tests pass and all necessary files are in manifest
#       Changes doc and Mnet module version information get updated
#       github is updated, replacing old release with tagged new release
#       github master contains new release README.md and Mnet-*.tar.gz
#       cpan is updated with new release distribution file
#       github development ready to continue on master branch
#
#   follow the steps listed below to correctly create a new release:
#
#       perl Makefile.PL && realclean, to start with a clean slate
#       perl Makefile.PL && make distcheck, commit any necessary fixes
#       make test, commit any necessary fixes, then we're ready for release
#       vim Changes, update w/date and new <RELEASE> number, 5.09, 5.011, etc
#       vim lib/Mnet.pm, update $VERSION variable to the new <REELEASE> number
#       git rm Mnet-*.tar.gz, to remove old distribution in repository
#       make realclean && perl Makefile.PL && make dist && make realclean
#       git add Changes Mnet-<RELEASE>.tar.gz && git commit -m 'new release'
#       git push origin master
#       git tag "v<RELEASE>" `git log -1 --pretty=%H`
#       git push origin "v<RELEASE>"
#       vim lib/Mnet.pm and update $VERSION variable to "dev"

# required modules
use warnings;
use strict;
use ExtUtils::MakeMaker;
use Pod::Markdown;
use Pod::Text;

# create README file from Mnet.pm, some perl tools supposedly look for this
my $pod_text = Pod::Text->new(sentence => 0, width => 78);
$pod_text->parse_from_file('lib/Mnet.pm', 'README');

# create README.md file from Mnet.pm for github, CPAN used Mnet.pm directly
my $pod_md = Pod::Markdown->new;
open(my $fh, '>', 'README.md') or die 'unable to write to README.md, $!';
$pod_md->output_fh($fh);
$pod_md->parse_file('lib/Mnet.pm');

# create make file, metacpan will use cpan v2 spec meta_merge github links
WriteMakefile(
    VERSION_FROM        => 'lib/Mnet.pm',
    ABSTRACT_FROM       => 'lib/Mnet.pm',
    AUTHOR              => 'Mike Menza <mmenza@cpan.org>',
    LICENSE             => 'gpl_3',
    META_MERGE          => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository  => {
                type => 'git',
                url  => 'https://github.com/menzascripting/Mnet.git',
                web  => 'https://github.com/menzascripting/Mnet',
            },
        },
    },
    MIN_PERL_VERSION    => '5.10.0',
    NAME                => 'Mnet',
    VERSION_FROM        => 'lib/Mnet.pm',
);

# finished
exit;
