#!/usr/bin/perl
# $Id: pwikit_recalc.pl,v 1.1 2007-08-08 15:18:42 triton Exp $
#
# Script to recalculate PWI Kit participant data.
#
# By Mike King
#
#	$Header: /au/apps/alltriton/cvs/scripts/pwikit_recalc.pl,v 1.1 2007-08-08 15:18:42 triton Exp $
#
#----------------------------------------------------------------------
#
use strict;
use Getopt::Long;							#perl2exe
use TPerl::TritonConfig;    				#perl2exe
use Date::Manip;							#perl2exe
our (%cnt,%ufields,%config,$qt_root,%resp,$dbt);
require 'TPerl/qt-libdb.pl';				#perl2exe
require 'TPerl/360-lib.pl';					#perl2exe
require 'TPerl/pwikit_cfg.pl';				#perl2exe

require 'TPerl/360_updatep.pl';

Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");
  

sub die_usage
	{
	print <<USAGE;
Usage: $0 [-version] [-debug] [-help] [-trace] [-all] [-only=xxx] [-seq=999]
	-help     Display help
	-version  Display version no
	-trace    Display program trace information
	-debug    Display debugging information (more detailed)
	-all      Do all participants
	-only=    Do only for participant id=
USAGE
	exit 0;
	}

#-----------------------------------------------------------
#
# Main line starts here
#
#-----------------------------------------------------------
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_all,$opt_only,$opt_seq);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			all=> \$opt_all,
			'only=s' => \$opt_only,
			version => \$opt_v,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwikit_recalc.pl,v 1.1 2007-08-08 15:18:42 triton Exp $'."\n";
	exit 0;
	}
#my $qt_root = '/triton';
my %files = ();
my %warn = ();
&get_root;

&db_conn;
	


my $where = ($opt_only eq '') ? '' : " AND uid='$opt_only'";
my $sql = "SELECT DISTINCT UID,PWD FROM MAP_CASES WHERE SID='MAP001' $where ORDER BY UID";
my $th = &db_do($sql);
my $tbl_ary_ref = $th->fetchall_arrayref;
$th->finish;
$dbt=1 if ($opt_d);
foreach my $aref (@${tbl_ary_ref})
	{
	my ($uid,$pwd) = @{$aref};
	undef %ufields;
	my $ufile = "$qt_root/$config{participant}/web/u$pwd.pl";
	print "$uid: Requiring file $ufile\n" if ($opt_t);
	my_require ("$ufile",0);
	if ($opt_t)
		{
		print qq{  Participant $ufields{fullname}:\n};
		for (my $k=1;$k<=$config{nboss};$k++)		# Bosses
			{
			next if (($ufields{"bossfirstname$k"} eq '') 
						&& ($ufields{"bosslastname$k"} eq '') 
						&& ($ufields{"bossemail$k"} eq ''));
			print qq{    Boss $k: $ufields{"bossfirstname$k"} $ufields{"bosslastname$k"} ($ufields{"bossemail$k"})\n};
			}
		for (my $k=1;$k<=$config{npeer};$k++)		# Peers
			{
			next if (($ufields{"peerfirstname$k"} eq '') 
						&& ($ufields{"peerlastname$k"} eq '') 
						&& ($ufields{"peeremail$k"} eq ''));
			print qq{    KP $k: $ufields{"peerfirstname$k"} $ufields{"peerlastname$k"} ($ufields{"peeremail$k"})\n};
			}
		}
	&update_participant;		# Common code does all the work
	}
&db_disc;
#
# Return true just in case we need it
#
1;
