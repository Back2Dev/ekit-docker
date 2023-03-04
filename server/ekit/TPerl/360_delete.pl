#!/usr/bin/perl
# $Id: 360_delete.pl,v 2.7 2012-01-19 01:11:11 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_delete.pl - deletes a participant
#
#
use CGI::Carp qw(fatalsToBrowser);

require 'TPerl/360_delete_core.pl';
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
our $opt_n;
my %files = ();


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

#
$survey_id = $config{master};			# This is a hack to use MAP101 as the central authentication spot
$id = $input{id};

my $result = &delete_by_id($survey_id,$id);
$result =~ s/\n/<br>\n/g;
&add2body($result);

&add2body(<<BODY);
<P class="title">DONE !</P>
ID $id has been successfully removed from the database, $cnt records deleted<BR><BR>
BODY
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
