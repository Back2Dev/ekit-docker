## $Id: TritonConfig.pm,v 1.36 2011-08-26 22:02:12 triton Exp $
package TPerl::TritonConfig;
require Exporter;
@ISA = qw (Exporter);
@EXPORT = qw( getConfig getUserConfig selectJob getRefHash getJobConfig GetWKSTID SetWKSTID getServerConfig getdbConfig getInidir getOtherConfig getTritonPeople);

use strict;
use Data::Dumper;
# use Config::Ini;
# Not in CPAN any more...
use Config::IniFiles;
use Date::Manip;
use Cwd;

# module globals...
my $debug = 0;
my $currjob = undef;
my $cur_dur = cwd();

print "OS=$^O\n" if $debug;

# fix for mobile devices
if ($cur_dur eq "/") {
        chdir "/home/vhosts/mobile_device/";
}



# 
# Read the config file which tells us where the .ini files live, and hang on to that information
#

my $inidir = '';
my $refdir = '';
$refdir = '../refdata';
## Now if your on windows and TPerl dir does not exist, assume \triton\cfg
if ($^O =~ /win32/i && ! -d 'TPerl')			
	{
		# print "no TPerl\n";
	$inidir = '/triton/cfg' if (-d '/triton/cfg');			# Use it if it's there
	$inidir = '/cfg' if (-d '/cfg') && ($inidir eq '');
	}
else
	{
		# print "Conventional cfgroot\n";
	my $cfgfile = "TPerl/cfgroot.txt";		# This is for Unix
	die "cfgfile '$cfgfile' does not exist" unless -e $cfgfile;
	#print "Reading config file: $cfgfile\n";
	open (CFG,"<$cfgfile") || die "Error $! encountered while trying to read file: $cfgfile\n";
	$inidir = <CFG>;
	chomp $inidir;
	$inidir =~ s/\r//;
	die "the first line of $cfgfile should be the dir where 'server.ini' lives" unless $inidir;
	close CFG;
	}
# print "inidir=$inidir\n";
die "inidir '$inidir' does not exist" unless -d $inidir;

#
#------- SUBROUTINES FROM HERE --------------------------
#
sub selectJob {
	my $jobname = shift;
	my $fname = "$inidir/$jobname.ini";
	die "Job config file not found: $fname\n" if (!-f $fname);
	# $currjob = new Config::Ini($fname);
	$currjob = new Config::IniFiles(-file=>$fname);
}

sub getRefHash {
	my $refname = shift;
	my $fname = "$refdir/$refname.ini";
#	die "Reference data config file not found: $fname\n" if (!-f $fname);
	# $currjob = new Config::Ini($fname);
	my %refini;
	tie %refini, 'Config::IniFiles', ( -file => $fname );
  	\%refini;
}

#my $ini = new Config::Ini("$inidir/server.ini");
die "Ini file: '$inidir/server.ini' does not exist" unless -e "$inidir/server.ini";
my $ini = new Config::IniFiles(-file=>"$inidir/server.ini");
die "Error parsing  '$inidir/server.ini' as an ini file\n" . join ("\n",@Config::IniFiles::errors) unless $ini;
#print "Initializing $inidir/server.ini\n";
die "Error in $inidir/server.ini file: missing TritonRoot\n" if ($ini->val('server','TritonRoot') eq '');
#die "Error in $inidir/server.ini file: missing TritonRoot\n" if ($ini->get(['server','TritonRoot']) eq '');
#print "TritonRoot = ".$ini->get(['server','TritonRoot'])."\n";
#
# This is for Win32 systems, that generally don't have a TZ Environment variable:
#
if ($ENV{TZ} eq '')
	{
	my $unix_date_tz = `date +%z` unless $^O =~ /win32/i ;
	my $tz = getConfig("TZ") || $unix_date_tz || die "Missing TZ in server.ini\n";
	#Date::Manip::Date_SetConfigVariable("TZ",$tz);
	&Date_Init("TZ=$tz");
	}

sub getInidir
	{
	$inidir;
	}

## don't actually open this file unless we need it.  ie don;t force a user.ini
# on linux systems..
my $user_file = "$inidir/user.ini";
my $user_ini = undef;

sub getConfig
	{
	my $key = shift;
	# $ini->get(['server', $key]);
	$ini->val('server', $key);
	}

sub getServerConfig
	{
	my $key = shift;
	#$ini->get(['server', $key]);
	$ini->val('server', $key);
	}

sub getUserConfig
	{
	my $key = shift;
	die "First Param must be a key in '$user_file'" unless $key;
	unless ($user_ini){
 		die "User ini '$user_file' does not exist" unless -e $user_file;
		$user_ini = new Config::IniFiles (-file=>$user_file);
		die "Could not open '$user_file' as an ini file" unless $user_ini;
 		die "section 'user' does not exist in $user_file" unless 
 			grep 'user',$user_ini->Sections;
	}
	return $user_ini->val('user', $key);
	}

sub getJobConfig
	{
	my $key = shift;
	# $currjob->get(['job', $key]);
	$currjob->val('job', $key);
	}

sub getdbConfig
	{
	my $key = shift;
	# $ini->get(['database', $key]);
	$ini->val('database', $key);
	}
#
# Usage of this sub:
# my $value = getOtherConfig('360','notify_email',1);
# Params are [0] - Section name
#			 [1] - Key name
#			 [2] - Mandatory flag (Will die if value not found)
sub getOtherConfig
	{
	my $section = shift;
	my $key = shift;
	my $mandatory = shift;
	die qq{Missing either section name [$section] or key name [$key] in call to getOtherConfig\n} if ($section eq '') || ($key eq '');
	my $value = $ini->val($section, $key);
	die "server.ini file: No value found in [$section] for $key\n" if (($value eq '') && $mandatory);
	$value;
	}


sub GetWKSTID
	{
	my @lines = (1,1);
	my $troot = getConfig ('TritonRoot');
	my $wksfile = "$inidir/wkstid.txt";
	if (-f $wksfile)
		{
		open (WKF,"<$wksfile") || die "Error $! while reading file: $wksfile\n";
		@lines = <WKF>;		# If it's there already, read it
		close WKF;
		chomp $lines[0];
		$lines[0] =~ s/\r//;
		chomp $lines[1];
		$lines[1] =~ s/\r//;
		$lines[0] = 1 if (!($lines[0] =~ '^\d+$'));
		$lines[1] = 1 if (!($lines[1] =~ '^\d+$'));	# Default to 1
		}
	else
		{
		$lines[0] = getUserConfig('WKSTID') || 1;	# Look in the user's registry for it
		$lines[1] = getUserConfig('WKSTID2') || 1;
		if ($lines[0] == 1)
			{
			$lines[0] = getConfig('WKSTID') || 1;	# Look in the system registry for it
			$lines[1] = getConfig('WKSTID2') || 1;
			}
		}
	($lines[0],$lines[1]);				# Return the goods now
	}

sub SetWKSTID
	{
	my $wkstid = shift;
	my $wkstid2 = shift;
	my $troot = getConfig ('TritonRoot');
	my $wksfile = "$inidir/wkstid.txt";
	open(WKF,">$wksfile") || die "Cannot created WKSTID file: $wksfile\n";
	print WKF "$wkstid\n";
	print WKF "$wkstid2\n";
	close WKF;
	}

sub getTritonPeople {
	my $tpeople = getOtherConfig ('TritonPeople','list',1);
	my @people = split /,/,$tpeople;
	s/^\s*(.*?)\s*$/$1/ foreach @people;
	return \@people;
}
1;
