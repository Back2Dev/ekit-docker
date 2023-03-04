#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_find.pl,v 2.2 2007/01/28 07:51:47 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# pwikit_find.pl - starts off a survey
#
# This is a generic function - assumes require statements already done.
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
$survey_id = $config{master};			# This is a hack to use MAP101 as the central authentication spot
$resp{'survey_id'} = $survey_id;
$find_id = $input{id};
$find_name = $input{name};
$find_boss = $input{boss};
$find_peer = $input{peer};
#
my %hits = ();
	my $sql = "select distinct uid,fullname,rolename from $config{index} where casename='$config{case}' order by uid";
	&db_do($sql);
	@ids = ();
	while (@row = $th->fetchrow_array())
		{
		if (($row[0] eq $find_id) && ($find_id ne ''))
			{
			if ($hits{$row[0]} eq '')
				{
				push (@ids,$row[0]) ;		# Stack up the ID's
#				add2body "id=$row[0], $row[1]<BR>";
				}
			$hits{$row[0]}++;
			}
		elsif (($row[1] eq $find_name) && ($row[2] eq 'Self') && ($find_name ne ''))
			{
			push (@ids,$row[0]) if ($hits{$row[0]} eq '');		# Stack up the ID's
			$hits{$row[0]}++;
#			print "name=$row[1]<BR>";
			}
		elsif (($find_name ne '') && ($row[1] =~ /$find_name/i) && ($row[2] eq 'Self'))
			{
			push (@ids,$row[0]) if ($hits{$row[0]} eq '');		# Stack up the ID's
			$hits{$row[0]}++;
#			print "self re match on /$find_name/ =$row[1]<BR>";
			}
		elsif (($row[1] eq $find_boss) && ($row[2] eq 'Boss') && ($find_boss ne ''))
			{
			push (@ids,$row[0]) if ($hits{$row[0]} eq '');		# Stack up the ID's
			$hits{$row[0]}++;
#			print "boss=$row[1]<BR>";
			}
		elsif (($find_boss ne '') && ($row[1] =~ /$find_boss/i) && ($row[2] eq 'Boss'))
			{
			push (@ids,$row[0]) if ($hits{$row[0]} eq '');		# Stack up the ID's
			$hits{$row[0]}++;
#			print "bossre match on /$find_boss/ =$row[1]<BR>";
			}
		elsif (($row[1] eq $find_peer) && ($row[2] eq 'Peer') && ($find_peer ne ''))
			{
			push (@ids,$row[0]) if ($hits{$row[0]} eq '');		# Stack up the ID's
			$hits{$row[0]}++;
#			print "peer=$row[1]<BR>";
			}
		elsif (($find_peer ne '') && ($row[1] =~ /$find_peer/i) && ($row[2] eq 'Peer'))
			{
			push (@ids,$row[0]) if ($hits{$row[0]} eq '');		# Stack up the ID's
			$hits{$row[0]}++;
#			print "peer re match on /$find_peer/ =$row[1]<BR>";
			}
#print "matches=$#ids"; 
		}
	&list_cases('','',@ids);
&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
