#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_listall.pl,v 2.3 2007-04-18 11:52:56 triton Exp $
# Perl library for QT project
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
#$case = 'pwikit';
#
my $batches = '';
$batches = " AND batchno='$input{batchno}'" if ($input{batchno} ne '');
my $sql = "select distinct uid from $config{index} where casename='$config{case}' $batches order by fullname,uid";
&db_do($sql);
@ids = ();
while (@row = $th->fetchrow_array())
	{
	push (@ids,$row[0]);		# Stack up the ID's
	}
my $show = ($input{show}) ? $input{show} : $config{max_per_page};
&list_cases($show,$input{start_at},@ids);
&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
