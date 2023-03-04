#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_serve.pl,v 1.3 2007-05-23 13:18:32 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 
#
#
#
use CGI::Carp qw(fatalsToBrowser);
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 0;
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
$pagename = $ENV{'REQUEST_URI'};
my $script = $ENV{'SCRIPT_NAME'};
$pagename =~ s/$script\///;			# Pull out the page to serve from the end of the URL
if ($pagename =~ /(.*?)\?(.*)/)
	{
	$pagename = $1;
	}
$rolename = 'self' if $pagename =~ /^self/;
$rolename = 'boss' if $pagename =~ /^boss/;
my $ufile = "$qt_droot/$config{participant}/web/u$input{password}.pl";
&my_require($ufile,0);
#$ufields{id} = $input{'id'};
#$ufields{password} = $input{'password'};

&add2hdr(<<HDR);
<TITLE>$config{title} listing page </TITLE>
   <META NAME="Triton Information Technology Software">
   <META NAME="Author" CONTENT="Mike King (213) 488 2811">
   <META NAME="Copyright" CONTENT="Triton Information Technology 1995-2001">
<link rel="stylesheet" href="/$config{case}/style.css">
HDR
#
$survey_id = $config{master};			# This is a hack to use PPRKIT as the central authentication spot
$resp{'survey_id'} = $survey_id;
#
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
