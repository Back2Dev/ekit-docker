#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_clear.pl,v 1.4 2012-01-19 01:11:11 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_clear.pl - deletes a participant
#
#
use CGI::Carp qw(fatalsToBrowser);
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
my %dfiles = ();
my %docfiles = ();
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
&add2hdr(<<HDR);
	<TITLE>$config{title} login page </TITLE>
	<META NAME="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King (213) 627 7100">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2002">
	<link rel="stylesheet" href="/$config{case}/style.css">
HDR
&db_conn;
&db_conn2;

#
$survey_id = $config{master};			# This is a hack to use the master as the central authentication spot
$id = $input{id};
$pwd = $input{password};
$sql = "SELECT UID,PWD,SID FROM $config{index} WHERE UID='$id'";
&db_do($sql);
my $cnt = 0;
while (@row = $th->fetchrow_array())
	{
	($theid,$thepwd,$sid) = @row;
	$sql2 = "SELECT SEQ from $sid WHERE PWD='$thepwd' AND UID='$theid' AND SEQ>0";
	$th2 = &db_do2($sql2);
	while (@srow = $th2->fetchrow_array())
		{
		my $seq = $srow[0];
		$dfiles{"$qt_root/$sid/web/D$seq.pl"}++;
		$docfiles{"$qt_root/$sid/doc/$seq.rtf"}++ if (-f "$qt_root/$sid/doc/$seq.rtf");
		}
	$th2->finish;
	$sql2 = "UPDATE $sid SET STAT=0,SEQ=0 WHERE PWD='$thepwd' AND UID='$theid'";
	&db_do2($sql2);
	$cnt++;
	}
if ($config{status})
	{
# If used for MAP, need to update the status here
#	$sql2 = "DELETE FROM $config{status} WHERE UID='$id'";
#	&db_do2($sql2);
#	$cnt++;
	}
add2body("Deleting previous response files: <BR>-".join("\n<BR>-",sort keys(%dfiles))."<BR>\n");
unlink keys %dfiles;
add2body("Deleting previous documents: <BR>-".join("\n<BR>-",sort keys(%docfiles))."<BR>\n");
unlink keys %docfiles;



&add2body(<<BODY);
<P class="title">DONE !</P>
Responses for ID $id have been successfully cleared from the database, $cnt records updated<BR><BR>
BODY
&db_disc;
&db_disc2;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
