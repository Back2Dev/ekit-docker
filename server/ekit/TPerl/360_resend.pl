#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_resend.pl,v 2.8 2012-01-19 01:11:11 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996.. Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_resend.pl - Re-sends email to a participant/boss/peer
#
# Assume require stmts are done already
#
use CGI::Carp qw(fatalsToBrowser);

#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
&db_conn;						# Connect to database
&db_new_survey($config{master});		# Make sure the receiving table exists
#
$do_body = 1;
$plain = 1;
$form = 1;



#--------------------------------------------------------------------------------------------
# Start of main code 
#
#&ReadParse(*input);
our $q = new TPerl::CGI;
our %input = $q->args;
#
&add2hdr("<TITLE>$config{title} </TITLE>");
add2body(qq{   <META NAME="Triton Information Technology Software">});
add2body(qq{   <META NAME="Author" CONTENT="Mike King (213) 488 2811">});
add2body(qq{   <META NAME="Copyright" CONTENT="Triton Technology 1995-2000">});
add2body(qq{<link rel="stylesheet" href="/$config{case}/style.css">});
#
# We have a list of surveys to enable
#
$ok = 1;
$id = $input{'id'};
if ($id eq '')
	{
	&add2body("<HR><P class='title'>Error: Missing User ID </P>");
	&add2body("<P>Please go back and try again</P><HR>");
	$ok = 0;
	}
my $thesid = $config{participant};
if ($ok)
	{
	my @try_list = ($config{participant});
	my @myroles = keys %{$config{roles}};
#	add2body("roles=".join(",",@myroles));
	if ($#myroles != -1)
		{
#		&add2body("Trying list<BR>\n");
#		pop @try_list;	# Dump the default one
		foreach my $rname (keys %{$config{roles}})
			{
#			add2body($config{roles}{$rname}{selflist}[0]);
			push @try_list,$config{roles}{$rname}{selflist}[0];
			}
		}
	foreach $mysid (@try_list)
		{
		$thesid = $mysid;
		($part_pwd,$part_fullname) = &db_get_case($config{index},$thesid,$id);
		last if ($part_pwd ne '');
		}
	if ($part_pwd eq '')
		{
		$ok = 0;
		my $list = join(",",(@try_list,keys %{$config{roles}}));
		&add2body("<P>Could not find a participant with the id: $id, tried $list</P><HR>");
		}
	}
#add2body("Part_pwd=$part_pwd, thesid=$thesid");
my $ix = 1;
if ($ok)
	{
	&db_new_case($config{index});			# Make sure table exists first
	undef %ufields;
#
# Pull in existing ufields 
#
	$ufile = "$qt_root/$thesid/web/u${part_pwd}.pl";
	&my_require ("$ufile",0);
	my $ix = 1;
	my $rolename = 'boss';
	if ($input{role} =~ /(.*?)(\d+$)/)
		{
		$rolename = $1;
		$role = $1;
		$ix = $2;
		}
	else
		{
		$role = $input{role};
		$rolename = '';
		$ix = '';
		}
	$srcname = $rolename;
	$srcname = 'boss' if ($rolename eq 'reviewer');
	$temp{"${rolename}fullname"} = $ufields{"${srcname}fullname$ix"};
	my $who = $ufields{"${srcname}email$ix"};
	my $em_SID = $config{master};
	$em_SID = $config{lc($role)} if $config{email_send_method}==2;
#	&queue_invite($em_SID,$role,$ufields{id},$ufields{"${srcname}password$ix"}, $ufields{"${srcname}email$ix"});
# First email should be queued, 2nd or more is sent immediately
	smart_send($em_SID,$role,$ufields{id},$ufields{"${srcname}password$ix"}, $ufields{"${srcname}email$ix"},'','', $ufields{startdate}, 1);
#	print "role=$role, $config{emails}{lc($role)}{notify} exec=$ufields{execname} <$ufields{execemail}>\n";
# Send a notification to the exec as well, will only do it first time.
	&queue_invite($em_SID, $config{emails}{lc($role)}{notify},$ufields{id},$ufields{"${srcname}password$ix"}, $ufields{execemail},'','') if($ufields{execemail} && ($config{emails}{lc($role)}{notify} ne ''));
#
# Let the user know what we have done:
#
#	&add_script("shaddap","JavaScript","window.close();");
	&add2body(<<HTML);
<CENTER>
<TABLE class="mytable" cellpadding="8" cellspacing="0" width="600">
	<tr class="heading"><TD>Sent email to $role ($thesid)</TD></tr>
	<tr class="options"><TD align="CENTER">&nbsp; $who </td></tr>
	<tr class="options"><TD align="CENTER"><HR> </td></tr>
</TABLE>
HTML
#	<tr class="options"><TD align="CENTER"><BUTTON onclick="shaddap()"> OK </BUTTON></td></tr>
#
# OK, we're done now, so output the standard footer :-
#
	}
&qt_Footer;
&db_disc;
1;
