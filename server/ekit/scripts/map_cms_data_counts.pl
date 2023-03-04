#!/usr/bin/perl
# $Id: map_cms_data_counts.pl,v 1.5 2005-11-15 04:46:05 triton Exp $
# Kwik script to list record counts in MAP CMS database (on MS SQLServer)
#
use strict;
use DBI;
use TPerl::TritonConfig;
use TPerl::MyDB;
use TPerl::DBEasy;
use Getopt::Long;						#perl2exe

our ($opt_h,$opt_t,$opt_d,$opt_showt,$opt_all,
		$opt_dsn, $opt_user, $opt_pass);
GetOptions (
	'trace'			=>\$opt_t,
	'debug'			=>\$opt_d,
	'help'			=>\$opt_h,
	'show_tables'	=>\$opt_showt,
	'all'			=>\$opt_all,
	'dsn=s'			=>\$opt_dsn,
	'user=s'		=>\$opt_user,
	'password=s'	=>\$opt_pass,
) or die usage ('Bad Command line options');
if ($opt_h)
	{
	die <<HELP;
Usage: $0 [-h] [-n] [-t]
  Where:
  [-h] - Displays this help message
  [-t] - Turns on trace output, tells you what it is doing
HELP
	}

my @tables = ();
#my $server = 'wic003q.server-sql.com\SQL1,4656';		# Local SQL Server on Mike's machine
#my $DSN = "DRIVER={SQL Server};SERVER=$server;port=4656;Database=vs154189_2;";
#my $dbh = DBI->connect("dbi:ADO:$DSN",'vs154189_2_dbo','Uz4csQBa2w') 
#    	or die "$DBI::errstr\n"; 

my $dbh;
# $opt_dsn = qq{dbi:ADO:DRIVER={SQL Server};SERVER=192.168.77.136;Database=CMS;};
if ($opt_dsn)
	{
#my $server = 'wic003q.server-sql.com\SQL1,4656';		# Local SQL Server on Mike's machine
#my $DSN = "DRIVER={SQL Server};SERVER=$server;port=4656;Database=vs154189_2;";
#my $dbh = DBI->connect("dbi:ADO:$DSN",'vs154189_2_dbo','Uz4csQBa2w') 
#    	or die "$DBI::errstr\n"; 
	$dbh = DBI->connect($opt_dsn,$opt_user,$opt_pass) 
    	or die "$DBI::errstr\n"; 
	}
else
	{
	$dbh = dbh TPerl::MyDB(db=>'mssql',debug=>1,) or die ("Could not connect to database :".DBI->errstr);
	}
# Don't set a default limit here, because it messes things up.
my $opt_limit = 9999;
my $opt_d = 0;

my $when = localtime;
print "$when Record counts for non-system tables\n";
#
# First up let's list out the tables in the database
#
my $sql = "SP_TABLES";
$sql = "SHOW TABLES" if ($opt_showt);
#$sql = qq{select name as TABLE_NAME from sysobjects where xtype='U'};
my $rowcnt = 0;
my $th = $dbh->prepare($sql);
$th->execute;
$rowcnt = 0;
while (my $href = $th->fetchrow_hashref)
	{
	if ($rowcnt == 0)
		{
		print join("\t",keys %$href)."\n" if ($opt_d);
		}
	$rowcnt++;
	print join("\t",values %$href)."\n" if ($opt_d);
	if ($opt_showt)
		{
		my ($key) = keys %$href;
		push @tables,$$href{$key};
		}
	else
		{
		print qq{$$href{TABLE_NAME} ($$href{TABLE_TYPE})\n} if ($opt_d);
		if (!$opt_all)
			{
			next if ($$href{TABLE_TYPE} =~ /^system/i);
			next if ($$href{TABLE_TYPE} =~ /^VIEW/i);
			next if ($$href{TABLE_NAME} =~ /^dtprop/);
			next if ($$href{TABLE_NAME} =~ /^SPT_/i);
			}
		push @tables,$$href{TABLE_NAME};
		}
#print "table=$$href{TABLE_NAME}\n";
	last if ($rowcnt > $opt_limit) && $opt_limit;
	}
$th->finish();

# 
# Now we have a list of tables, count the records in each one.
#
$rowcnt = 0;
foreach my $table (@tables)
	{
#	print "\n";
	my $sql = qq{SELECT count(*) as $table FROM $table};
	my $th = $dbh->prepare($sql);
	$th->execute;
	$rowcnt = 0;
	while (my $href = $th->fetchrow_hashref)
		{
		if ($rowcnt == 0)
			{
			print join("\t",keys %$href).":		";
			}
		print join("\t",values %$href)." Records\n";
		$rowcnt++;
		last if ($rowcnt >$opt_limit) && $opt_limit;
		}
	}
$th->finish();
$dbh->disconnect;

