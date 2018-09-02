package Mnet::Version;

BEGIN { our $VERSION = 'dev'; }

=head1 NAME

Mnet::Version

=head1 SYNOPSIS

This module makes available an Mnet::Version::info function that can be used
by other scripts and modules.

=cut

# required modules
use warnings;
use strict;
use Cwd;
use Digest::MD5;
use POSIX;



sub info {

=head1 $info = Mnet::Version::info()

Output multiple lines of information about the current script, Mnet modules,
and operating system. This is used by Mnet::Opts::Cli and Mnet::Log.

=cut

    # note script name, without path
    my $script_name = $0;
    $script_name =~ s/^.*\///;

    # note path to Mnet modules
    my $mnet_path = $INC{"Mnet/Version.pm"};
    $mnet_path =~ s/\/Mnet\/Version\.pm$//;

    # note posix uname
    my @uname = POSIX::uname();
    my $uname = lc($uname[0]." ".$uname[2]);

    # note current working directory
    my $cwd = Cwd::getcwd();

    # init output version info string, and sprintf pad string to align outputs
    my ($info, $spad) = ("", "35s");
    $spad = "1s =" if caller eq "Mnet::Log";

    # output caller script version if known, and mnet version
    $info .= sprintf("%-$spad $main::VERSION", $script_name) if $main::VERSION;
    $info .= sprintf("%-$spad $Mnet::Version::VERSION\n", "Mnet");

    # add a blank line in before md5 outputs, looks better from cli --version
    $info .= "\n" if caller ne "Mnet::Log";

    # append basic version info to output string
    $info .= sprintf("%-$spad $^V\n",        "perl version");
    $info .= sprintf("%-$spad $uname\n",     "system uname");
    $info .= sprintf("%-$spad $cwd\n",       "current dir");
    $info .= sprintf("%-$spad $0\n",         "exec path");
    $info .= sprintf("%-$spad $mnet_path\n", "Mnet path");

    # add a blank line in before md5 outputs, looks better from cli --version
    $info .= "\n" if caller ne "Mnet::Log";

    # append m5d info for executable and all Mnet modules to output string
    my $script_md5 = _info_md5($0) // "";
    $info .= sprintf("%-$spad $script_md5\n", "md5 $script_name");
    foreach my $module (sort keys %INC) {
        next if $module !~ /^Mnet\//;
        my $md5 = _info_md5($INC{$module});
        $module =~ s/\//::/g;
        $module =~ s/\.pm$//;
        $info .= sprintf("%-$spad $md5\n", "md5 $module");
    }

    # finished Mnet::Version::info, return info string
    return $info;
}



sub _info_md5 {

# $md5 = _info_md5($file)
# purpose: return hex md5 for specified file
# $md5: hex md5 string, of undef on file errors

    # read file, open it, and return md5, return undef on errors
    my $file = shift // undef;
    my $contents = "";
    open(my $fh, "<", $file) or return undef;
    $contents .= $_ while <$fh>;
    close $fh;
    my $md5 = Digest::MD5::md5_hex($contents);
    return $md5;
}



=head1 SEE ALSO

 Mnet

=cut

# normal end of package
1;

