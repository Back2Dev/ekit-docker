#!/usr/bin/perl
## $Id: 360_new.pl,v 2.8 2012-01-19 01:11:11 triton Exp $
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
# 360_new.pl - Adds a new participant
#
#
use TPerl::CGI;
use CGI::Carp qw(fatalsToBrowser);

#
# Start of main code 
#
use CGI::Carp qw(fatalsToBrowser);
our $q = new TPerl::CGI;
our %input = $q->args;
#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
&db_conn;						# Connect to database
&db_new_survey($config{master});		# Make sure the receiving table exists
#
$do_body = 1;					# Legacy stuff for libraries
$plain = 1;
$form = 1;
	
undef %temp;
%temp = ();
#--------------------------------------------------------------------------------------------
# Start of main code 
#
#&ReadParse(*input);
#
&add2hdr(<<HDR);
	<TITLE>$config{title} login page </TITLE>
	<META NAME="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King (213) 627 7100">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2002">
	<link rel="stylesheet" href="/$config{case}/style.css">
HDR
#
# Let's get down to action here
#
#$dbt = 1;
my $jobtitle = $q->param('jobtitle');

our @selflist = @{$config{selflist}};
&debug("roles\->$jobtitle\->selflist\[0\]=".$config{roles}{$jobtitle}{selflist}[0]);
if ($config{roles}{$jobtitle}{selflist}[0] ne '')
	{
	@selflist = @{$config{roles}{$jobtitle}{selflist}};
	if ($q->param('new'))							# New customer ?
		{
		push @selflist,@{$config{roles}{$jobtitle}{newlist}};			# Add newlist to this 1
		}
	}
else
	{
	if ($q->param('new'))							# New customer ?
		{
		push @selflist,@{$config{newlist}};			# Add newlist to this 1
		}
	}
#
# We have a list of surveys to enable
#
my $ok = 1;
#
my $id = $q->param('id');
&debug("auto_id=".$q->param('auto_id'));
if (($id eq '') && ($q->param('auto_id')))
	{
	$id = &next_uid();
	}
if ($id eq '')
	{
	&add2body("<HR><P class='title'>Error: Missing User ID </P>");
#	&add2body("keys=".join(",<BR>",$q->param));
	&add2body("<P>Please go back and try again</P><HR>");
	$ok = 0;
	}
if ($ok)
	{
	if (&db_user_exists($config{master},$id))
		{
		&add2body("<HR><P class='title'>Error: User ID $id is already taken</P>");
		&add2body("<P>Please go back and try again</P><HR>");
		$ok = 0;
		}
	}
if ($ok)
	{
	undef %ufields;
#
# Copy all the data into the ufields hash
#
	foreach my $key ($q->param)
		{
		my $val = $q->param($key);
		$ufields{$key} = $val;
		}
	$ufields{id} = $id if ($q->param('id') eq '');
	&new_participant(\%ufields);
#
# Let the user know what we have done:
#
	&add2body(<<HTML);
<P class="title"> Confirmation of new participant for $ufields{fullname} (ID: $ufields{'id'})</P>
HTML
	$partner = ($ufields{'partner'} == 1) ? 'Yes' : 'No';
	$new = ($ufields{new} == 1) ? 'Yes' : 'No';
	&add2body(qq{<TABLE CELLPADDING="3" BORDER="0" CELLSPACING="0" class="mytable">});
	&add2body(qq{\t<TR><TD class="heading">Participant:</TD>});
	&add2body(qq{\t<TD class="options"> <B>$ufields{fullname}, ($ufields{'email'}) </B><BR>});
	&add2body(qq{$ufields{'company'}<BR>});
	&add2body(qq{\t\tID: $ufields{'id'}<BR> Password: $ufields{password}<BR>});
	&add2body("\t\t</TD></TR>");
	if ($ufields{bosspassword1} eq '')
		{
		&add2body(qq{\t<TR><TD class="heading">Boss: </TD><TD class="options">No boss supplied });
		}
	else
		{
		for (my $i=1;$i<=$config{nboss};$i++)
			{
			if ($ufields{"bosspassword$i"} ne '')
				{
				&add2body(qq{\t<TR><TD class="heading">Boss $i: </TD><TD class="options"><B>}.$ufields{"bossfullname$i"}.", (".$ufields{"bossemail$i"}.") </B><BR>");
				&add2body("\t\tBoss Password: ".$ufields{"bosspassword$i"}."<BR>");
				}
			}
		}
	&add2body("\t\t</TD></TR>");
	&add2body("\t\t</TD></TR>");
	if ($ufields{peerpassword1} eq '')
		{
		&add2body(qq{\t<TR><TD class="heading">Peers: </TD><TD class="options">No peers supplied });
		}
	else
		{
		for (my $i=1;$i<=$config{npeer};$i++)
			{
			if ($ufields{"peerpassword$i"} ne '')
				{
				&add2body(qq{\t<TR><TD class="heading">Peer $i: </TD><TD class="options"><B>}.$ufields{"peerfullname$i"}.", (".$ufields{"peeremail$i"}.") </B><BR>");
				&add2body(qq{\t\tPeer Password: ".$ufields{"peerpassword$i"}."<BR>});
				}
			}
		}
	&add2body("\t\t</TD></TR>");
	&extra_new;
	
	&add2body(qq{</TABLE>});
#
# OK, we're done now, so output the standard footer :-
#
	}
&qt_Footer;
&db_disc;
1;
