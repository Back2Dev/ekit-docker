#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_del_item.pl,v 2.4 2012-01-19 01:11:11 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_delete.pl - deletes a survey (usually a peer or boss form)
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
my (%ufiles,%dfiles);
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

#
$survey_id = $input{survey_id};			# This is a hack to use MAP101 as the central authentication spot
$id = $input{id};
$pwd = $input{password};

my $cnt = 0;
my $sql = "SELECT SEQ FROM $survey_id WHERE PWD=? AND UID=?";
my $th = &db_do($sql,$pwd,$id);
while (@row = $th->fetchrow_array())
	{
	$dfiles{"$qt_root/$survey_id/web/D$row[0].pl"}++ if (-f "$qt_root/$survey_id/web/D$row[0].pl");
	}
$th->finish;
my $sql = "DELETE FROM $survey_id WHERE PWD=? AND UID=?";
&db_do($sql,$pwd,$id);
$ufiles{"$qt_root/$survey_id/web/u$pwd.pl"}++;
$cnt++;

my $sql = "DELETE FROM $config{index} WHERE PWD=? AND UID=? AND SID=?";
&db_do($sql,$pwd,$id,$survey_id);
$cnt++;

#add2body("deleting files: <BR>-".join("\n<BR>-",sort keys(%ufiles))."<BR>\n");
unlink keys %ufiles;


my $nfiles = $#{keys %ufiles}+1;
&add2body(<<BODY);
<P class="title">DONE !</P>
ID/PWD $id/$pwd has been successfully removed from the database, $cnt records deleted, $nfiles context files deleted<BR><BR>
BODY
&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
