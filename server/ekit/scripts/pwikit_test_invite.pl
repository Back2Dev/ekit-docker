#!/usr/bin/perl
# $Id: pwikit_test_invite.pl,v 1.3 2007-09-25 02:07:59 triton Exp $
#
# Test script to send out emails to:
# Participants
# Bosses
# KP's
#
#------------------------------------------------------------------
our $simulate_frames = 0;
our %config;
our %temp;
our $dbt;

use Getopt::Long;							#perl2exe
use File::Path;								#perl2exe
use File::Basename;							#perl2exe
use Data::Dumper;							#perl2exe

use TPerl::TritonConfig;    				#perl2exe
use TPerl::Error;							#perl2exe
use TPerl::Engine;							#perl2exe
use TPerl::EScheme;							#perl2exe

require 'TPerl/qt-libdb.pl';				#perl2exe
require 'TPerl/360-lib.pl';					#perl2exe
$simulate_frames = 0;
require 'TPerl/pwikit_cfg.pl';				#perl2exe

use strict;
my $args = join(" ",@ARGV);

sub die_usage
	{
	my $errmsg = shift;
	print <<USAGE;
$errmsg
Usage: $0 [-version] [-debug] [-help] [-trace] [-noaction] -only=ID
  -help               Display help
  -version            Display version no
  -trace              Show trace output 
  -debug              Show debug output
  -noaction           Don't action anything, just go through the motions
  -pwd=PWD            Password (needed for peers and bosses)
  -only=ID            Do it only for the supplied participant ID
  -wsdate=YYYY-MM-DD  Calculate for this Workshop date
  -invite=NAME        Name of email invite, eg participant/boss/peer defaults to "participant"
  -sid=SID            SID to use (defaults to "MAP001")
  -manual             We are manually resending invite
USAGE
	exit 0;
	}

our %ufields;
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_n,$opt_only,
		$opt_wsdate,$opt_itype,$opt_sid,
		$opt_pwd,$opt_manual,
		);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			no => \$opt_n,
			'only=s' => \$opt_only,
			'wsdate=s' => \$opt_wsdate,
			'invite=s' => \$opt_itype,
			'sid=s' => \$opt_sid,
			'pwd=s' => \$opt_pwd,
			manual => \$opt_manual,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwikit_test_invite.pl,v 1.3 2007-09-25 02:07:59 triton Exp $'."\n";
	exit 0;
	}
our $qt_root;
&get_root;
&db_conn;

$dbt=1 if ($opt_d);

# -------------------------------------------------------
#
# Mainline starts here
#
# -------------------------------------------------------
my $myname = $0;
$myname =~ s/\.\w+$//;
my $logfile = "$qt_root/log/$myname.log";
mkpath (dirname($logfile),1);

my $err = new TPerl::Error ();
my $en = new TPerl::Engine;

my $fh;
if ($fh = new FileHandle (">> $logfile"))
	{
	$err->fh ([$fh,\*STDOUT]);
	}
else
	{
	$err->E("Could not write to $logfile")
	}
die_usage("Error: you must specify -only= and -pwd=") if (($opt_only eq '') || ($opt_pwd eq ''));
#
# Locate the participant 
#
my $itype = $opt_itype || 'participant';
my $em_SID=$config{master};
$em_SID=$config{$itype};
my $ufile = "$qt_root/$em_SID/web/u$opt_pwd.pl";
$err->F("Couldn't find participant $opt_only/$opt_pwd (ufile=$ufile)") if (! -f $ufile);
&my_require($ufile,1);
#
# No die's after this point, so we start logging activity
#
$err->I(sprintf ("Starting $0 at %s with cmd=$0 $args",scalar(localtime)));

my $manual = $opt_manual;
my $response = &smart_send($em_SID, $itype, $opt_only, $opt_pwd, $ufields{email},'','',$opt_wsdate, $manual); 	# cc and fmt are blank
$err->E($response) if ($response);
$err->I("Done");
