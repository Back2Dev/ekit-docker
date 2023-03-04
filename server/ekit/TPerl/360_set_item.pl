#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_set_item.pl,v 2.4 2012-01-19 01:11:12 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_set_item.pl - set/reset a survey (usually a peer or boss form)
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
add2body(qq{<TITLE>$config{title} login page </TITLE>});
add2body(qq{   <META NAME="Triton Information Technology Software">});
add2body(qq{   <META NAME="Author" CONTENT="Mike King (213) 488 2811">});
add2body(qq{   <META NAME="Copyright" CONTENT="Triton Technology 1995-2000">});
add2body(qq{<link rel="stylesheet" href="/$config{case}/style.css">});

my $survey_id = $input{'survey_id'};			# This is a hack to use MAP101 as the central authentication spot
my $id = $input{'id'};
my $pwd = $input{'password'};

sub update_item
	{
	$newstat = shift;

	&db_conn;
	#
	my $sql = "UPDATE $survey_id SET STAT=? WHERE PWD=? AND UID=?";
	&db_do($sql,$newstat,$pwd,$id);
	&db_disc;
	&add2body(<<BODY);
	<P class="title">DONE !</P>
	ID/PWD $id/$pwd has been successfully updated<BR><BR>
BODY
	&qt_Footer;
	}

sub reset_item
	{
	&db_conn;
	my $seq = &db_get_user_seq($survey_id,$id,$pwd);
	my $newstat = 0;
	my $sql = "UPDATE $survey_id SET STAT=?,SEQ=0 WHERE PWD=? AND UID=?";
	&db_do($sql,$newstat,$pwd,$id);
	&db_disc;
	&add2body(<<BODY);
	<P class="title">DONE !</P>
	ID/PWD $id/$pwd has been successfully updated<BR><BR>
BODY
	my $docfile = "$qt_root/$survey_id/doc/$seq.rtf";
	if (-f $docfile)
		{
		unlink $docfile;
		&add2body("Deleted document file: $docfile<BR>");
		}
	my $dfile = "$qt_root/$survey_id/web/D$seq.pl";
	if (-f $dfile)
		{
		unlink $dfile;
		&add2body("Deleted data file: $dfile<BR>");
		}
	&qt_Footer;
	}


1;
