#!/usr/bin/perl
# $Id: pwikit_boss_stop_flag.pl,v 1.1 2007-08-08 21:49:23 triton Exp $
#
# Cron script to update boss stop flags:
#
our $dbt;

use Getopt::Long;							#perl2exe
use File::Path;								#perl2exe
use File::Basename;							#perl2exe
use Data::Dumper;							#perl2exe

use TPerl::TritonConfig;    				#perl2exe
use TPerl::Error;							#perl2exe
use TPerl::Engine;							#perl2exe

use strict;

require 'TPerl/qt-db.pl';
require 'TPerl/qt-libdb.pl';

sub die_usage
	{
	my $errmsg = shift;
	print <<USAGE;
$errmsg
Usage: $0 [-version] [-debug] [-help] [-trace] [-noaction] [-only=ID] 
  -help       Display help
  -version    Display version no
  -trace      Show trace output 
  -debug      Show debug output
USAGE
	exit 0;
	}

our %ufields;
our %done;
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_n,$opt_only,
		);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			no => \$opt_n,
			'only=s' => \$opt_only,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwikit_boss_stop_flag.pl,v 1.1 2007-08-08 21:49:23 triton Exp $'."\n";
	exit 0;
	}
our $qt_root;
$dbt = $opt_d;
&db_conn;
my $sql = qq{select MAP011.UID from MAP011 inner join MAP012 ON MAP011.PWD=MAP012.PWD and MAP011.STAT=MAP012.STAT where MAP011.STAT=4};
my $th = &db_do($sql);
my $tbl_ary_ref = $th->fetchall_arrayref;
$th->finish;
foreach my $aref (@${tbl_ary_ref})
	{
	my ($uid) = @{$aref};
	my $sql = "UPDATE MAP011 set STOP_FLAG=1 where uid=?";
	&db_do($sql,$uid);
	}
