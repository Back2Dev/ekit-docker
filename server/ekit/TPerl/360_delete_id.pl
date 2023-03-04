#!/usr/bin/perl
## $Id: 360_delete_id.pl,v 1.3 2007/04/22 12:26:48 triton Exp $
# Script to delete all the documents and data for a respondent.
#
# Copyright Triton Information Technology 2004 on...
#
use strict;
use Getopt::Long;							#perl2exe
use File::Copy;								#perl2exe
use File::Basename;							#perl2exe

our (%config,$dbt,$qt_root,$th);
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_n,$opt_all);

require 'TPerl/qt-libdb.pl';
require 'TPerl/360_delete_core.pl';
#
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			noaction => \$opt_n,
			all => \$opt_all,
			) or die_usage ( "Bad command line options" );

sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if ($msg ne '');
	print <<ERR;
Usage: $0 [-version] [-trace] [-help] [-noaction] ID
	-help		Display help
	-version	Display version no
	-trace		Trace mode
	-noaction	Don't take any actions, just go through the motions
	-all        DELETE ALL Id's in database (Quite a serious move - confirmation required)
	ID			Delete this ID
ERR
	exit 0;
	}
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/TPerl/360_delete_id.pl,v 1.3 2007/04/22 12:26:48 triton Exp $'."\n";
	exit 0;
	}
if ($opt_all)
	{
	&db_conn;
	my $sql = "SELECT DISTINCT UID,FULLNAME from $config{index} where ROLENAME=? ORDER BY UID";
	&db_do($sql,'Self');
	my $aref = $th->fetchall_arrayref;
	$th->finish;
	my $num = @{$aref};
	print "Are you sure you want to delete ALL PARTICIPANT DATA from the database ($num of them)? ([n]/y):";
	my $ans = getc();
	if ($ans =~ /^y/i)
		{
		my $cnt = 0;
		foreach my $row (@{$aref})
			{
			my $id = $$row[0];
			my $fullname = $$row[1];
			my $result = &delete_by_id($config{master},$id);
			print "Deleting $id $fullname: \n";
			$cnt++;
			}
		print "Deleted $cnt participants\n";
		}
	}
else
	{
	my $id = shift;
	die_usage("Missing ID to delete\n") if ($id eq '');
	
	my $result = &delete_by_id($config{master},$id);
	print $result;
	}
#
# End of file
#
1;
