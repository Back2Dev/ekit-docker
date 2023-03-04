#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_clickthru.pl,v 1.1 2012-04-11 12:46:32 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_login.pl - starts off a survey
#
# Assumes require's have been done already
#
use CGI::Carp qw(fatalsToBrowser);

use TPerl::Event;
use TPerl::EScheme;
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
my $reviewer = 0;
my %role_heading = (
					self => '',
					peer => 'Peer',
					boss => 'Boss',
					reviewer => 'Supervisor/Reviewer',
					);
#
# Copy stuff from config (If it's defined)
#
foreach my $role (keys %role_heading)
	{
	$role_heading{$role} = $config{role_lookup}{$role_heading{$role}} if ($config{role_lookup}{$role_heading{$role}} ne '');
	}
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
$survey_id = $config{master};			# This is a hack to use MAP101 as the central authentication spot
$resp{'survey_id'} = $survey_id;
#
&add2hdr(<<HDR);
	<TITLE>$config{title} Confirmation page </TITLE>
	<META NAME="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King (213) 627 7100">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2012">
	<link rel="stylesheet" href="/$config{case}/style.css">
HDR
#
$msg = '';
if ($input{from} eq 'default')
	{
	$bad = 1;
	}
else
	{
	$admin = $input{admin};
	$uid = $input{id};
	$uid =~ s/\s+//g;						# Trim spaces
	$pwd = uc($input{password});			# Force upper case to make sure
	$pwd =~ s/\s+//g;						# Trim spaces
	if (($pwd eq '') || ($uid eq ''))
		{
		$msg = 'Missing id/password';
		$bad = 1;
		}
	if (!$bad)
		{
		$stat = &db_get_user_status($config{master},$uid,$pwd);
		$stat = '0';
		if ($stat eq '')
			{
			$msg = "Cannot find userid, or incorrect password";
			$bad++;
			}
		}
	}
#
# Work out the role of the person first
#
	if (!$bad)
		{
		my $sql = "SELECT DISTINCT ROLENAME,FULLNAME FROM $config{index} WHERE UID='$uid' AND CASENAME='$config{case}' AND PWD='$pwd'";
		&db_do($sql);
		while (my @row = $th->fetchrow_array())
			{
			next if ((lc($row[0]) ne lc($input{rolename})) && ($input{rolename} ne ''));
			$rolename = $row[0];
			$fullname = $row[1];
			}
		$th->finish;
		if ($rolename eq '')
			{
			$bad++;
			$msg = 'Cannot find your role in the database';
			}
		}
#
# Validation finished - either deliver the bad news or let them in.
#
if ($bad)
	{
	$rolename = 'bad';
	my $code = <<SCRIPT;
	if (document.q.id.value == '')
		{
		alert("Please enter your id and try again");
		return false;
		}
	if (document.q.password.value == '')
		{
		alert("Please enter your password and try again");
		return false;
		}
	return true;
SCRIPT
	&add_script('QValid',"JavaScript",$code);
	&add2body(<<LOGIN);
<FORM name="q" method=POST ACTION="${virtual_cgi_bin}$config{case}_login.$extension"
		ENCTYPE="x-www-form-encoded"
		OnSubmit="return QValid()"
		>
<TABLE BORDER="0" CELLPADDING="3" CELLSPACING="0" width="600">
	<TR>
		<TD class="title" colspan="2">
			Welcome to the $config{title} confirmation page. 
		</TD>
	</TR>
	<TR>	
		<TD class="body" colspan="2">
			Please bookmark this page for future reference.<BR><BR>
			To find out more about this process, please click <A HREF="/$config{case}/explain.html">here</A><BR>
		</TD>
	</TR>
	<TR>
		<TD class="options" ALIGN="RIGHT">
			Please enter your ID:
		</TD>
		<TD class="options">
			<INPUT TYPE="TEXT" NAME="id" VALUE="$uid"> 
		</TD>
	</TR>
	<TR>
		<TD class="options" ALIGN="RIGHT">
			Please enter your PASSWORD:
		</TD>
		<TD class="options">
			<INPUT TYPE="TEXT" NAME="password" value="$pwd"> <FONT color="red">$msg</FONT>
		</TD>
	</TR>
	<TR>
		<TD class="heading">&nbsp;</TD>
		<TD class="heading" ALIGN="CENTER">
			<INPUT TYPE="SUBMIT" VALUE="Logon">
		</TD>
	</TR>
</TABLE>
<HR>
LOGIN
	}
else
	{
	my $actions = '&nbsp;';	# Default to no actions available
	$rolename = 'Self';
	my $SID = $config{participant};
    $rolename = 'Boss' if (-f "$qt_root/$config{boss}/web/u$pwd.pl");
    $rolename = 'Peer' if (-f "$qt_root/$config{peer}/web/u$pwd.pl");
    $rolename = 'Boss' if ($input{rolename} =~ /reviewer/i);
	$ufile = "$qt_root/$SID/web/u$pwd.pl";
#	if (-f "$qt_root/$config{peer}/web/u$pwd.pl")	# Try peer
#		{
#		$rolename = 'Peer';
#		$SID = $config{peer};
#		$ufile = "$qt_root/$SID/web/u$pwd.pl";
#		}
#	if (-f "$qt_root/$config{boss}/web/u$pwd.pl")	# Try boss
#		{
#		$rolename = 'Boss';
#		$SID = $config{boss};
#		$ufile = "$qt_root/$SID/web/u$pwd.pl";
#		}
	if (!(-f $ufile))
		{
		&add2body(<<MSG);

<CENTER><TABLE border=0 cellspacing=0 cellpadding=10><TR><TD class="warning" border=1 ><B><font size="+1" color="red">Your information has been archived from the system - please contact MAP to unarchive your data</font></B></table><BR><BR>

This may have happened because your workshop has been rescheduled. If you have partially completed the forms, your information will still be on file.<BR><BR>
You can email us at <A HREF="mailto:pwisupport\@mapconsulting.com">pwisupport\@mapconsulting.com</a>, or call us at 1 800 834 0445.<BR><BR>
</CENTER>
MSG
		$rolename = 'bad';
		}
	else
		{
		my_require ($ufile,0);
	#	} The matching brace for this is near the end of file
#	&add2body("who=$ufields{'fullname'} <BR>");
#
# In theory we should stop the email track, but in the currently reduced implementation there is no need.
#
		if (0)
			{
			my $eso = new TPerl::EScheme;
			my $tracks = $eso->click_through( pwd => $pwd ) || die $eso->err."\n";
			}
		my $ev = new TPerl::Event;
		$ev->I(msg  => "Login for $uid $fullname",
				code => 217,
				pwd  => $pwd,
				SID  => $SID,
				);
		&add2body("Hello");
		$pagename = "self_clickthru";
		&add2body(<<BODY);
</TABLE>
BODY
#
# Now check to see if this is the first sign on:
#
# HACK THE notify flag to prevent notification to exec for click-thru
		$config{notify_first_login} = 0;
		if (($ufields{firsttime} eq '') 
			&& !$admin 
			&& $config{notify_first_login} 
			&& ($ufields{execemail} ne '')
			&& ($rolename eq 'Self')
				)
			{
			$ufields{firsttime} = localtime;
	#		add2body(qq{send_invite($config{master}, 'execstart', $ufields{id}, $ufields{password}, $ufields{execemail})});
			$ufields{part_email} = $ufields{email};	# Get around a local variable problem
			my $em_SID = $config{master};
			$em_SID = $config{participant} if $config{email_send_method}==2;
			&queue_invite($em_SID, 'execstart', $ufields{id}, $ufields{password}, $ufields{execemail});
			&save_ufile($config{participant},$ufields{password});
			}
#
# Now check to see if this is the first sign on for the boss:
#
        if (($ufields{bossfirsttime} eq '')
            && !$admin
            && $config{notify_first_login}
            && ($ufields{execemail} ne '')
            && ($rolename eq 'Boss')
                )
            {
            $ufields{bossfirsttime} = localtime;
    #       add2body(qq{send_invite($config{master}, 'execstart', $ufields{id}, $ufields{password}, $ufields{execemail})});
            $ufields{part_email} = $ufields{email};  # Get around a local variable problem
            &queue_invite($config{boss}, 'execboss', $ufields{id}, $ufields{password}, $ufields{execemail});
            &save_ufile($config{participant},$ufields{password});
            }
		}
	}
#
# OK, we're done now, so output the standard footer :-
#
&db_disc;
&qt_Footer;
1;
