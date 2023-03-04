#!/usr/bin/perl
#$Id: get-cpan-modules.pl,v 1.19 2007-07-18 06:04:45 triton Exp $
use strict;
use CPAN;
#
# WATCH OUT ALSO FOR:
# Win32/TieRegistry.pm - This is just a dummy
# Config/Ini.pm - This is defunct, but we still use it
# DNS/ZoneParse


# This is should not be alphabetised.
my @modlist = (
# now we can add comments.

	'Bundle::CPAN',
	'POSIX',
	'Digest::base',
	'Data::Dumper',
	'CGI',
	'FindBin',
	'HTML::Tagset',
	'HTML::Parser',
	'URI',
	'Bundle::LWP',
	'IO::Stringy',
	'Mail::Field',
	'Mail::Header',
	'Mail::Internet',
	'MIME::Tools',
	'IO::Scalar',
	'Test::Harness',
	'Test::More',
	'AppConfig',
	'DBI',
	'Apache::DBI',
	'Apache::Session',
	'DNS::ZoneParse',
	'Storable',
	'File::Slurp',
	'File::Rsync',
	'Time::Local',
	'Date::Manip',
	'List::Util',
	'String::Approx',
	'Tie::IxHash',
	'Data::Dump',
	'LockFile::Simple',
	'Email::Valid',
	'Mail::Sender',
	'Template',

	# 'DBD::InterBase',
	# 'DBD::mysql',
	'Email::Find',
	'File::lockf',
	'Mail::Audit',
	'Config::IniFiles',
	'Math::Round',
	'Text::CSV_XS',
	'Text::CSV',
	'Parse::RecDescent',
	'Spreadsheet::WriteExcel',
	'Digest::SHA1',
	'Mail::SpamAssassin',
	'File::Path',
	'Getopt::Long',
	'Mail::MboxParser',
	'FileHandle',
	'DirHandle',
	'HTML::Entities',
	'File::Temp',
	'HTTP::Cookies',
	'Cwd',
	#'File::Copy',
	'File::Spec',
	'Time::localtime',
	# 'Carp',
	'IO::Socket',
	'IO::Select',
	'Unicode::Map',
	'Unicode::String',
	'File::Tail',
	# 'Pod::Usage',
	'Proc::ProcessTable',
	#'File::Basename',
	'Term::ReadKey',
	'IO::WrapTie',
	'Proc::Background',
	'File::Touch',
	# 'Carp::Heavy',
	'Env',
	'Params::Validate',
	#'Pod::Man',
	'Getopt::Std',
	'IO::ScalarArray',
	'Class::Factory::Util',
	'Class::Singleton',
	'Module::Build',
	'DateTime::Locale',
	'DateTime::TimeZone',
	'Net::POP3',
	'File::lockf',

	'IPC::ShareLite',
	'Error',
	'Cache::Cache',
	'Devel::StackTrace',
	'Class::Data::Inheritable',
	'Exception::Class',
	'Apache::Test',
	'Apache::Request',
	'Class::Container',
	'HTML::Mason',
	'MLDBM',
	'FreezeThaw',
	'Test::Manifest',
	'XML::Parser',
	'XML::RSS',
	'Font::AFM',
	'HTML::TreeBuilder',
	'HTML::FormatText',
	'Test::Inline',
	'Class::ReturnValue',
	'Want',
	'Cache::Simple::TimedExpiry',
	'DBIx::SearchBuilder',
	'Sub::Uplevel',
	'Test::Builder::Tester',
	'Test::Exception',
	'Text::Reform',
	'Text::Template',
	'HTML::Scrubber',
	'Log::Dispatch',
	'Locale::Maketext::Lexicon',
	'Locale::Maketext::Fuzzy',
	'Text::Wrapper',
	'Time::ParseDate',
	'Text::Autoformat',
	'Text::Quoted',
	'Tree::Simple',
	'Module::Versions::Report',
	'Regexp::Common',
	'Test::Inline',
	'Apache::Test',
	'WWW::Mechanize',
	'FCGI',
	'Compress::Zlib',
	'Archive::Zip',

);
foreach my $mod (@modlist){
	my $class = 'Module';
	$class = 'Bundle' if $mod =~ /^Bundle/;
	my $obj = CPAN::Shell->expand($class,$mod);
	if ($obj){
		if ($obj->uptodate){
			print "$mod is up to date\n";
			next;
		}
		if ($obj->inst_version eq $obj->cpan_version){
			print "$mod is uptodate, bad uptodate though\n";
			next;
		}
		# use Data::Dumper;print Dumper $obj;
		# printf "Module %s is installed as %s, could be updated to %s from CPAN\n",
			# $obj->id, $obj->inst_version, $obj->cpan_version;

		if ( $obj->install ){
		}else{
			# sometimes the install 
			next if $obj->uptodate;
			use CPAN::Config;
			my $build_dir =  $CPAN::Config->{build_dir};
			my $msg ="\n\n$0:  $mod failed to install.\n You may want to manually  force an install \nin the $mod dir of '$build_dir/'\n";
			print $msg;
			# print Dumper $obj;
			exit;
		}
	}
}
print "\n$0 completed successfully\n";
