#!/usr/bin/perl
# $Id: pwicms_getstatus.pl,v 1.2 2005-08-22 01:56:14 triton Exp $
# Kwik scritp to test MS SQL Server connection options
#
#use strict;
use DBI;

my $server = '192.168.77.128';		# Local SQL Server on Mike's machine
#$server = '192.168.10.239';
$server = '209.223.156.14';
# This one is Tim's machine:
#$server = '209.223.156.10';
my $DSN = "DRIVER={SQL Server};SERVER=$server;Database=CMS;";
$| = 1;
print "Connecting to $DSN ...";
my $dbh = DBI->connect("dbi:ADO:$DSN", 'triton_ekit','!triton_ekit!') 
    	or die "$DBI::errstr\n"; 
print "OK\n";

my $sql = <<SQL;
select cst_fname,cst_lname,cst_ref_no,par_status from VW_WSPARTS
WHERE WSH_START_DATE>'1/1/2002'
AND (PAR_STATUS='C' 
OR PAR_STATUS='X')
SQL

$sql = <<X;
SELECT workshop.wsh_map_id, hotel.htl_map_id, workshop.wsh_start_date, hotel.htl_name, customer.cst_fname, customer.cst_lname, customer.cst_ref_no
FROM ((participant INNER JOIN customer ON participant.par_cst_id = customer.cst_id) INNER JOIN workshop ON participant.par_wsh_id = workshop.wsh_id) INNER JOIN hotel ON workshop.wsh_htl_id = hotel.htl_id
where wsh_map_id=10668 and customer.cst_ref_no>722250 order by wsh_start_date desc;
X
print "Preparing sql query: $sql\n";
my $th = $dbh->prepare($sql);
$th->execute;
$rowcnt = 0;
while (my $href = $th->fetchrow_hashref)
	{
	if ($rowcnt == 0)
		{
		print join("\t",keys %$href)."\n";
		}
	print join("\t",values %$href)."\n";
	$rowcnt++;
	last if ($rowcnt >20) && $opt_limit;
	}

$dbh->disconnect;

