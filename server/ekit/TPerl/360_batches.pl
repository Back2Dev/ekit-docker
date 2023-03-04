#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_batches.pl,v 2.6 2012-11-14 10:47:28 triton Exp $
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# This is a slave - should be called by a higher level wrapper
#
# NB Does not require things - assume that is already done !
#
use CGI::Carp qw(fatalsToBrowser);
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
$rolename = 'admin';
#--------------------------------------------------------------------------------------------
# Subroutines
#
#--------------------------------------------------------------------------------------------
# Start of main code 
#
#&ReadParse(*input);
our $q = new TPerl::CGI;
our %input = $q->args;
#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
&db_conn;
#
$survey_id = $config{master};			# This is a hack to use PWIKIT as the central authentication spot
$resp{'survey_id'} = $survey_id;
#
#$dbt=1;
my @dt = localtime();
my $y2 = $dt[5] - 100;		# Work out the 2 digit year		# Work out the 2 digit year
my $yp2 = $y2+1;
my $m = $dt[4] + 1;
my $yy;
for (my $i=0;$i<6;$i++) {
	my $mym = $m + $i;
	$yy = $y2 ;
	if ($mym >= 13) {
		$yy = $y2 + 1;
		$mym -= 12;
		}
	my $mm = sprintf (qq{%02d},$mym);
	push @clauses,qq{ BAT_NAME like '%\.$mm\.%\.$yy' }
}
my $next6 = " AND (".join(" OR ",@clauses)." ";
$next6 .= " or BAT_NAME in ('CANCEL','HOLD'))";


#my $sql = "select batchno,BAT_NAME as BATCHNAME,count(distinct uid) AS CNT from $config{index} where casename='$config{case}' and rolename='Self' group by batchno,BAT_NAME";
my $sql = "select batchno,BAT_NAME as BATCHNAME,count(distinct uid) AS CNT from $config{index} where casename='$config{case}' and rolename='Self' and (BAT_NAME like '%\.$y2' or BAT_NAME like '%\.$yp2' or BAT_NAME in ('CANCEL','HOLD')) group by batchno,BAT_NAME";
$sql = "select BATCHNO,BAT_NAME as BATCHNAME,count(distinct uid) AS CNT from $config{index},$config{batch} where casename='$config{case}' and rolename='Self' and BATCHNO=BAT_KV  
$next6 
group by batchno,bat_name
order by bat_name" if ($config{batch} ne '');
$sql = "select BATCHNO,BAT_NAME as BATCHNAME,count(distinct uid) AS CNT from $config{index},$config{batch} where casename='$config{case}' and rolename='Self' and BATCHNO=BAT_NO group by batchno,bat_name" if ($config{batch} ne '') && ($input{old});
&db_do($sql);
&add2hdr(<<HDR);
	<TITLE>$config{title} listing page </TITLE>
	<META NAME="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King (213) 627 7100">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2002">
	<link rel="stylesheet" href="/$config{case}/style.css">
HDR

&add2body(<<HEADER);
</CENTER>
<TABLE BORDER="0" cellpadding="6" CELLSPACING="0" class="mytable">
	<TR>
		<TH class="heading">Batch no.</TH>
		<TH class="heading">Name</TH>
		<TH class="heading">Participants</TH>
	</TR>
HEADER
while (@row = $th->fetchrow_array())
	{
	my $batchno = $row[0];
	my $count = $row[1];
	my $batchname = '';
#	if ($config{batch})
#		{
		$batchname = $row[1];
		$count = $row[2];
#		}
	my $batch = qq{<A HREF="/cgi-adm/$config{case}_listall.pl?batchno=$batchno&show=99">Batch $batchno</A>};
	&add2body(qq{<tr class="options"><TD align="center">$batch</TD><TD align="center">$batchname</TD><TD align="center">$count</TD></tr>});
	}
&add2body(qq{</TABLE>});
&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
