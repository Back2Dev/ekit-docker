#!/usr/bin/perl
# $Id: 360_sleep.pl,v 1.3 2012-01-19 01:11:12 triton Exp $
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
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
my %ufiles = ();
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
&db_conn;

#
$survey_id = $config{participant};			# This is a hack to use MAP101 as the central authentication spot
$id = $input{'id'};
$pwd = $input{'password'};

my $ufile = qq{$qt_root/$survey_id/web/u$pwd.pl};
my_require($ufile,1);
$ufields{inactive} = 1;
&save_ufile($config{participant},$pwd);	

&add2body(<<BODY);
<P class="title">DONE !</P>
ID $id has been successfully updated<BR><BR>
BODY
&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
