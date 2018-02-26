package Mnet;

=head1 NAME

Mnet

=head1 SYNOPSIS

This module can be used as a shortcut to load the following modules and make
available the following methods:

 use Mnet::Test qw($stderr $stdout);

 use Mnet::Opts::Cli;
 my $cli = Mnet->Cli();

 use Mnet::Log qw(DEBUG INFO WARN FATAL);
 my $log = Mnet->Log();

If this doesn't work for you then as an alternative you can load only the
individual Mnet modules that you need.

Refer to the SEE ALSO section of this document for a list of all Mnet modules.

=cut

# required modules
use warnings;
use strict;
use Exporter qw( import );
use Mnet::Log qw( DEBUG INFO WARN FATAL );
use Mnet::Opts::Cli;
use Mnet::Test qw( $stderr $stdout );

# export function names
our @EXPORT = qw( DEBUG INFO WARN FATAL );

# defined constructors for Mnet sub-modules
sub Cli  { shift; return Mnet::Opts::Cli->new(@_); }
sub Log  { shift; return Mnet::Log->new(@_); }
sub Opts { shift; return Mnet::Opts->new(@_); }

#? create .t tests for all modules

#? double check all perldoc

#? create Mnet::Expect module
#   $self = Mnet::Expect->new
#   add -re '\r\N' progress bar handling
#       $match = $expect->match;
#       $match =~ /\N*\r(\N)/$1/;
#       $match .= $expect->after;
#       expect->set_accum($match);
#   how far does this module go?
#   how can we support weird menus and characters, etc
#   can we have multiple types of expect wrapper modules?
#   can we layer/enable/disable various capabilities?

#? create Mnet::Report module
#   $self = Mnet::Report->new($name, \%opts)
#   allow for --report output to database in addition to csv, etc
#   maybe use key = value storage in db, example key = 'dev int attrib'

#? create Mnet::Stash module
#   --stash=s, set to sqlite file, or directory to use $name+$key files
#   init creates sqlite table named mnet_stash_$name with $key rows
#   Mnet::Stash::init($name, \%opts) # cli --stash opt, maybe stash_age_max
#   \%stash = Mnet::Stash->new($name, $key)
#   end block saves/updates dbi data, unless read-only opt set
#   end block can remove stash entries older than stash_age_max

=head1 AUTHOR

The Mnet perl module has been created and is maintained by Mike Menza. Mike can
be reached via email at mmenza@cpan.org.

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2013-2018 Michael J. Menza Jr.

Mnet is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see http://www.gnu.org/licenses/

=head1 SEE ALSO

 Mnet
 Mnet::Dump
 Mnet::Log
 Mnet::Log::Conditional
 Mnet::Opts
 Mnet::Opts::Cli
 Mnet::Opts::Cli::Cache
 Mnet::Opts::Set
 Mnet::Opts::Set::Debug
 Mnet::Opts::Set::Quiet
 Mnet::Opts::Set::Silent
 Mnet::Test
 Mnet::Version

=cut

# normal package return
1;

