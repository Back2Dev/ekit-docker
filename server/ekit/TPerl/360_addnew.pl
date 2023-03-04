#!/usr/bin/perl
## $Id: 360_addnew.pl,v 2.6 2012-01-19 01:11:11 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
$copyright = "Copyright 1996.. Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_addnew.pl - Adds a boss/peer
#
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
&add2hdr(<<HDR);
	<TITLE>$config{title} login page </TITLE>
	<META NAME="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King (213) 627 7100">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2002">
	<link rel="stylesheet" href="/$config{case}/style.css">
HDR
#
# We have a list of surveys to enable
#
$ok = 1;
$id = $input{id};
if ($id eq '')
	{
	&add2body("<HR><P class='title'>Error: Missing User ID </P>");
	&add2body("<P>Please go back and try again</P><HR>");
	$ok = 0;
	}
if ($ok)
	{
	($part_pwd,$part_fullname) = &db_get_case($config{index},$config{participant},$id);
	if ($part_pwd eq '')
		{
		$ok = 0;
		&add2body("<P>Could not find a participant with the id: $id</P><HR>");
		}
	}
my $ix = 1;
if ($ok)
	{
	&db_new_case($config{index});			# Make sure table exists first
	undef %ufields;
#
# Pull in existing ufields 
#
	$ufile = "$qt_root/$config{participant}/web/u${part_pwd}.pl";
#	&add2body("Requiring file: $ufile");
	&my_require ("$ufile",0);

#	%ufields = %input;
#
# Now do the new role:
#
	my $nmax = $config{"n$input{role}"};
#	add2body("n=$nmax");
	my $found = 0;
	for ($ix=1;$ix<=$nmax;$ix++)
		{
		if ($ufields{"$input{role}lastname$ix"} eq '')
			{
			$found = 1;
			last;
			}
		}
	if (!$found)
		{
		$ok = 0;
		add2body(qq{<P class="title">All $input{role} slots are taken</P>});
		add2body(qq{You should probably use the <B><A HREF="/cgi-adm/$config{case}_editp.pl?id=$ufields{id}&password=$ufields{password}">Edit Participant</A></B> form});
		}
	}
if ($ok)
	{
#	add2body("ix=$ix");
	if ($input{newemail} ne '')		# Send email only if present.
		{
		my $myrole = '';
		$ufields{"$input{role}fullname"}  = $ufields{"$input{role}fullname$ix"} = mk_fullname($input{newfirstname},$input{newlastname});
		$ufields{"$input{role}firstname"} = $ufields{"$input{role}firstname$ix"} = $input{newfirstname};
		$ufields{"$input{role}lastname"}  = $ufields{"$input{role}lastname$ix"} = $input{newlastname};
		$ufields{"$input{role}email"}     = $ufields{"$input{role}email$ix"} = $input{newemail};
		$temp{"$input{role}fullname"} = $ufields{"$input{role}fullname$ix"};
		$temp{"$input{role}firstname"} = $ufields{"$input{role}firstname$ix"};
		$ufields{"$input{role}password$ix"} = ($ufields{id} eq '1234') ? '1235' : &db_getnextpwd($config{master});
		$ufields{who} = $temp{"$input{role}fullname"};
		&db_save_pwd_full($config{master},$ufields{id},$ufields{"$input{role}password$ix"},
					$ufields{"$input{role}fullname$ix"},0,$ufields{batchno},$input{newemail});
		$ufields{who} = $ufields{fullname};	# Save the name of the person filling in the form.
		&save_ufile($config{participant},$ufields{password});	# Save the master config file
		my @mylist = ();
		if ($input{role} eq 'boss')
			{
			@mylist = @{$config{bosslist}};
			$myrole = 'Boss';
			}
		else			# Must be a peer ?
			{
			@mylist = @{$config{peerlist}};
			$myrole = 'Peer';
			}
		foreach $survey_id (@mylist)
			{
			$resp{'survey_id'} = $survey_id;
			&db_new_survey($survey_id);		# Make sure the receiving table exists
			&db_save_pwd_full($survey_id,$ufields{id},$ufields{"$input{role}password$ix"},$ufields{"$input{role}fullname$ix"},0,$ufields{batchno},$input{newemail});
			$ufields{who} = $temp{"$input{role}fullname"};
			&db_add_invite($config{index},$config{case},$survey_id,$ufields{id},
					$ufields{"$input{role}password$ix"},$ufields{"$input{role}fullname$ix"},$myrole,$ufields{batchno});
			&save_ufile($survey_id,$ufields{"$input{role}password$ix"});
			}
		$ufields{who} = $ufields{fullname};	# Save the name of the person filling in the form.
		&save_ufile($config{participant},$ufields{"$input{role}password$ix"});	# Save a master ufile for the boss too
		my $SID = $config{master};
		$SID = $config{lc($myrole)} if $config{email_send_method}==2;
		&queue_invite($SID,lc($myrole),$ufields{id},$ufields{"$input{role}password$ix"}, $input{newemail},'',$input{fmt});
# Tell the exec about it too:
#		print "exec=$ufields{execemail}, role=$lc($myrole), msg=$config{emails}{lc($role)}{notify},\n";
		&queue_invite($SID, $config{emails}{lc($myrole)}{notify},$ufields{id},$ufields{"$input{role}password$ix"}, $ufields{execemail},'',$input{fmt}) if($ufields{execemail} && ($config{emails}{lc($myrole)}{notify} ne ''));
		}
#
# Let the user know what we have done:
#
	&add2body(<<HTML);
<P class="title"> Added new $input{role} for participant $ufields{fullname} (ID: $ufields{id})</P>
HTML
	&add2body(qq{<TABLE CELLPADDING="3" BORDER="0" CELLSPACING="0" class="mytable">});
	&add2body(qq{\t<TR><TD class="heading">Participant:</TD>});
	&add2body(qq{\t\t<TD class="options">$ufields{fullname}, ID: $ufields{id}</TD>});
	&add2body("\t\t</TD></TR>");
	if ($ufields{"$input{role}password$ix"} eq '')
		{
		&add2body(qq{\t<TR><TD class="heading">$input{role}: </TD><TD class="options">No $input{role} supplied });
		}
	else
		{
		my $fullname = $ufields{"$input{role}fullname$ix"};
		my $pwd = $ufields{"$input{role}password$ix"};
		if ($input{role} eq 'boss')
			{
			&add2body("\t<TR><TD class=\"heading\">Boss: </TD><TD class=\"options\"><B>$fullname, ($input{newemail}) </B><BR>");
			&add2body("\t\tBoss Password: $pwd<BR>");
			}
		else
			{
			&add2body("\t<TR><TD class=\"heading\">Peer: </TD><TD class=\"options\"><B>$fullname, ($input{newemail}) </B><BR>");
			&add2body("\t\tPeer Password: $pwd<BR>");
			}
		}
	&add2body("\t\t</TD></TR>");
	&extra_addnew();
	&add2body("</TABLE>");
#
# OK, we're done now, so output the standard footer :-
#
	}
&qt_Footer;
&db_disc;
1;

