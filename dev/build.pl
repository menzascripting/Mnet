#!/usr/bin/env perl

# purpose: execute from git checkout to build new release using new git tag
# note: you may want to use the 'git tag v1.2.3` command to assign new tag
# note: don't do a commit after the new tag until you accept the new build

# use standard modules
use warnings;
use strict;

# print opening message
print "\n";
print "BEFORE CONTINUING...\n\n";
print "You should have done the following:\n\n";
print "    - Ensure Changes document has been updated\n";
print "    - Executed a `git commit` to update your repo\n";
print "    - For a public release use `git tag v1.2.3` to assign version\n\n";
print "Do NOT do a commit or push right after assigning the new tag!\n";
print "You can then back out of the new release and delete the new tag.\n";
print "Commit and push the new release and tag after verifying all is well\n\n";
print "Hit enter to continue, or ctrl-c to cancel... ";
my $input = <STDIN>;
print "\n";

# determine path of git repo directory
die "unable to parse git repo path from execution path $0"
    if $0 !~ /^(.*)\/?dev\/[^\/]+\.pl$/;
my $git_dir = $1;
$git_dir =~ s/\/$//;
$git_dir = "." if $git_dir eq "";
print "set git_dir $git_dir\n";

# determine program name, use last subdir in git directory path
chdir $git_dir or die "could not change to git_dir $git_dir";
my $program = `pwd`;
chomp $program;
$program =~ s/^.*\///;
print "set program $program\n";

# determine current git tag, and be sure there release doesn't already exist
my $git_ver = `git describe --tags 2>/dev/null`;
chomp $git_ver;
die "unable to parse valid git version (returned '$git_ver')"
    if $git_ver !~ /^v\d+\.\d+\.\d+/;
die "a release already exists for this tag"
    if -f "$git_dir/Released/$program-$git_ver.tar.gz";
print "set git_ver $git_ver\n";

# set temp new build directory
my $tmp_dir = "$git_dir/tmp.build";
print "set tmp_dir $tmp_dir\n";

# create a temp new build directory and copy mnst files into it
print "removing old tmp_dir $tmp_dir\n";
system("rm -Rf '$tmp_dir' 2>/dev/null");
die if -d $tmp_dir;
print "creating new tmp_dir $tmp_dir\n";
system("mkdir '$tmp_dir'");
die if not -d $tmp_dir;

# copy all files from manifest into temp new build directory
print "copying manifest files from git_dir to tmp_dir\n";
my $cp_count = 0;
foreach my $file (`cat '$git_dir/MANIFEST' 2>/dev/null`) {
    chomp $file;
    if ($file =~ /^(.+)\//) {
        my $sub_dir = $1;
        if (not -d "$tmp_dir/$sub_dir") {
            system("mkdir -p '$tmp_dir/$sub_dir'");
            die "error creating $tmp_dir/$sub_dir"
                if not -d "$tmp_dir/$sub_dir";
        }
    }
    system("cp '$git_dir/$file' '$tmp_dir/$file'");
    die "error copying $git_dir/$file to $tmp_dir/$file"
        if not -f "$tmp_dir/$file";
    $cp_count++;
}
print "copied $cp_count manifest files successfully\n";

# change to temp build dir
print "changed to tmp_dir $tmp_dir\n";
chdir $tmp_dir;

# replace version string with version number from git tag
print "execting find and replace for git_ver\n";
foreach my $regex ('.*\.pl', '.*\.pm', '.*\.pod', '\.\/script\/Mnet-.*') {
    my $find_replace = "find . -regex \"$regex\" ";
    $find_replace .= "-type f -print0 | xargs -0 ";
    $find_replace .= "sed -ie 's/+++VERSION+++/$git_ver/g'";
    system("$find_replace");
}

# start perl build process on temp files
print "executing perl Makefile.PL\n";
system("perl Makefile.PL");

# create distribution
print "executing make dist\n";
system("make dist");

# copy distribution to release folder, ready for repo
print "copy $program-$git_ver.tar.gz to ../Released\n";
system("cp $program-$git_ver.tar.gz ../Released");
die "error copying $program-$git_ver.tar.gz to ../Released"
    if not -f "../Released/$program-$git_ver.tar.gz";

# execute tests
print "executing make test\n";
system("make test");

# print followup steps to accept or reject new build
print "\n";
print "EITHER ABORT THIS NEW BUILD:\n";
print "    rm $git_dir/Released/$program-$git_ver.tar.gz\n";
print "    git tag -d $git_ver\n" if $git_ver !~ /-\d+-\S{8}$/;
print "    rm -Rf $git_dir/tmp.build\n";
print "\n";
print "OR KEEP THIS NEW BUILD:\n";
print "    git add $git_dir/Released/$program-$git_ver.tar.gz\n";
print "    rm -Rf $git_dir/tmp.build\n";
print "\n";

# finished
exit;

