#!/usr/bin/perl
# $Id: serve.pl,v 2.3 2012-08-08 23:33:48 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
use strict;
our $copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# go.pl - starts off a survey
#
#
require 'TPerl/cgi-lib.pl';
require 'TPerl/qt-libdb.pl';
require 'TPerl/360-lib.pl';
require 'TPerl/pwikit_cfg.pl';
#
use CGI::Carp qw(fatalsToBrowser);
#
# Settings
#
#$dbt = 1;
our $do_body = 1;
our $plain = 1;
our $form = 0;
our $rolename = 'admin';
our (%input,$qt_droot,%config,%resp,$survey_id,%ufields,$external);
#--------------------------------------------------------------------------------------------
# Subroutines
#
#--------------------------------------------------------------------------------------------
# Start of main code 
#
&ReadParse(*input);
#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
our $simulate_frames = 0 if ($input{simulate_frames} eq '0');
our $pagename = $ENV{'REQUEST_URI'};
my $script = $ENV{'SCRIPT_NAME'};
$pagename =~ s/$script\///;			# Pull out the page to serve from the end of the URL
if ($pagename =~ /(.*?)\?(.*)/)
	{
	$pagename = $1;
	}
$rolename = 'self' if $pagename =~ /^self/i;
$rolename = 'boss' if $pagename =~ /^boss/i;
my $ufile = "$qt_droot/$config{participant}/web/u$input{password}.pl";
&my_require($ufile,0);

&add2hdr(qq{<TITLE>$config{title} listing page </TITLE>
<META NAME="Triton Information Technology Software">
<META NAME="Author" CONTENT="Mike King (213) 488 2811">
<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2012">
<link rel="stylesheet" href="/$config{case}/style.css">
});
#
$survey_id = $config{master};			# This is a hack to use PWIKIT as the central authentication spot
$resp{survey_id} = $survey_id;
if (!$simulate_frames)
	{
	%resp = %ufields;
	%resp = %input;
#	$resp{token} = $resp{password};
	&debug("Showing external page, resp{id}=$resp{id}");
	$survey_id = $input{survey_id};
	$resp{survey_id} = $survey_id;
	$external = $pagename;									# This is a little messy to revert to usual external page serving
	}
#
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
