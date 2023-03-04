#!/usr/bin/perl
## $Id: 360_editp.pl,v 2.21 2007-09-27 23:56:56 triton Exp $
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
# 360_editp.pl - Edit a person's details
#
# As this is generic, it assumes require statements have been done already.
#
use CGI::Carp qw(fatalsToBrowser);
#
# Settings
#
#$dbt = 1;
#$t=1;
$do_body = 1;
$plain = 1;
$form = 1;
#--------------------------------------------------------------------------------------------
# Subroutines
#
#--------------------------------------------------------------------------------------------
# Start of main code 
#
#ReadParse(*input);
our $q = new TPerl::CGI;
our %input = $q->args;
#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
print qq{<link rel="stylesheet" href="/$config{case}/style.css">};
&db_conn;						# Connect to database
&db_new_survey($config{master});		# Make sure the receiving table exists
# Potential problem here: (see below ???)
$survey_id = $config{participant};		# This is a hack to use this as the central authentication spot
$resp{'survey_id'} = $survey_id;
$case = $config{case};
my $pwd = $input{password};
my_require("$qt_root/$config{participant}/web/u$pwd.pl");
#
if ($input{confirm})
	{
#	print <<HTML;
#<HTML><HEAD>
#<TITLE>Triton Technology</TITLE>
#<link rel="stylesheet" href="/$config{case}/style.css">
#</HEAD>
#<BODY class="body">
#HTML
	my $cnt = 0;
	my $nem = 0;
#
# Force these off, as they are checkboxes and may not appear in the data
#
	$ufields{partner} = 0;
	$ufields{new} = 0;
# Update the main ufields file:
	foreach $key (keys %input)
		{
		next if ($key eq 'id');
		next if ($key eq 'password');
		if ($input{$key} ne $ufields{$key})
			{
			$ufields{$key} = $input{$key};
			$cnt++;
			}
		}
##################################
	&update_participant;		# Call code to do the updating
# Now send the emails that we were asked to, assuming that the above has updated everything it needed to:
	if ($input{email_participant})					# Participant email
		{
# First email should be queued, 2nd or more is sent immediately
		my ($stat,$msg) = smart_send($config{participant},'participant',$ufields{id},$ufields{password}, $ufields{email},'',$input{fmt}, $ufields{startdate}, 1);
		&add2body(qq{<!--Participant: $msg<BR>-->\n});
# Send a notification to the exec as well, will only do it first time.
		&queue_invite($config{participant}, 'execinvite', $ufields{id}, $ufields{password}, $ufields{execemail},'','') if($ufields{execemail});
		$nem++;
		}
	for (my $k=1;$k<=$config{nboss};$k++)		# Boss emails
		{
		next if (($ufields{"bossfirstname$k"} eq '') 
					&& ($ufields{"bosslastname$k"} eq '') 
					&& ($ufields{"bossemail$k"} eq ''));
		if ($input{"email_boss$k"})
			{
# First email should be queued, 2nd or more is sent immediately
			my ($stat,$msg) = smart_send($config{boss},'boss',$ufields{id},$ufields{"bosspassword$k"}, $ufields{"bossemail$k"},'',$input{fmt}, $ufields{startdate}, 1);
			&add2body(qq{<!--Boss $k: $msg<BR>-->\n});
# Send a notification to the exec as well, will only do it first time.
			&queue_invite($config{boss}, 'execbossinvite',$ufields{id},$ufields{"bosspassword$k"}, $ufields{execemail},'','') if($ufields{execemail});
			$nem++;
			}
		}
	for (my $k=1;$k<=$config{npeer};$k++)		# Peer emails
		{
		next if (($ufields{"peerfirstname$k"} eq '') 
					&& ($ufields{"peerlastname$k"} eq '') 
					&& ($ufields{"peeremail$k"} eq ''));
		if ($input{"email_peer$k"})
			{
# First email should be queued, 2nd or more is sent immediately
			my ($stat,$msg) = smart_send($config{peer},'peer',$ufields{id},$ufields{"peerpassword$k"}, $ufields{"peeremail$k"},'',$input{fmt}, $ufields{startdate}, 1);
			&add2body(qq{<!--Peer $k: $msg<BR>-->\n});
			$nem++;
			}
		}
# Tell the user we are done:
	&add2body(<<HTML);
  <table width="80%" cellpadding="5" cellspacing="0" class="mytable">
    <tr class="heading"> 
      <td colspan="4" height="27"> 
        Database update completed: $cnt fields updated, $nem emails sent
      </td>
    </tr>
  </table>
HTML

##################################
	}
elsif (($input{lastname} eq '') && ($input{firstname} eq ''))		# Is this a request to display ?
	{
	foreach (my $n=1;$n<=$config{npeer};$n++)
		{
		$resp{"ext_peerfirstname$n"} = $resp{"peerfirstname$n"} if ($resp{"peerfirstname$n"} ne '');
		$resp{"ext_peerlastname$n"} = $resp{"peerlastname$n"} if ($resp{"peerlastname$n"} ne '');
		$resp{"ext_peeremail$n"} = $resp{"peeremail$n"} if ($resp{"peeremail$n"} ne '');
		}
		showpage('editp.htm');
	}
else
	{
	&add2body(<<HTML);

<SCRIPT LANGUAGE="JavaScript">
<!--
function QValid()
	{
	if (confirm('This will save your changes to the database and send out emails (if any selected).\\n\\n Proceed ?'))
		{
		return true;
		}
	return false;
	}
//-->
</SCRIPT>

<FORM NAME="q" ACTION="/cgi-adm/$config{case}_editp.pl" ENCTYPE="www-x-formencoded" METHOD="POST" onsubmit="return (QValid())">
<INPUT type="hidden" name="confirm" value="1">
<input type="hidden" name="password" size="20" value="$pwd">
<input type="hidden" name="id" size="20" value="$input{id}">
  <table width="80%" cellpadding="5" cellspacing="0" class="mytable">
    <tr class="heading"> 
      <td colspan="3"> 
		Details of changes:</TD></tr>
HTML
	my $cnt = 0;
	my %changed = ();
	my $htbuf = '';
	foreach $key (keys %input)
		{
		next if ($key eq 'id');
		next if ($key eq 'password');
		next if ($key eq 'survey_id');
		if ($input{$key} ne $ufields{$key})
			{
			$changed{$key}++;
			my $hidden = qq{<INPUT type="hidden" value="$input{$key}" name="$key">\n};
			$htbuf .= qq{<tr class="options"><Td align=right><B>$key:</B></Td><TD>$ufields{$key}</TD><TD>$input{$key} $hidden</TD></tr>\n};
			$ufields{$key} = $input{$key};
			$cnt++;
			}
		}
	if ($cnt == 0)
		{
		&add2body(qq{<tr class="options"><TD colspan="3">*** no changes made to database***</TD></tr>\n});
		}
	else
		{
		&add2body(<<HTML);
    <tr class="heading"> 
		<TD>Field</TD><TD>Old value</TD><TD>New value</TD></tr>
		$htbuf
      </td>
    </tr>
HTML
		}		
	&add2body(qq{</TABLE> \n<BR>\n});
	if ($cnt > -1)
		{
		my $checked = ($changed{email}) ? 'CHECKED' : '';
		&add2body(<<HTML);
<table wi dth="80%" cellpadding="5" cellspacing="0" border="0" class="mytable">
  <tr class="heading"> 
    <td colspan="3"> 
    Re-send emails ? 
    	
    </td>
  </tr>
  <tr class="options"> 
    <td align="right"> 
    <B>Participant</B> </td>
    </td>
    <td>
    <INPUT TYPE="checkbox" NAME="email_participant" VALUE="1" $checked>
    </td>
    <td>
    $ufields{firstname} $ufields{lastname} ($ufields{email})
    </td>
  </tr>
	</TR><tr height="2" class="heading"><TD height="2" class="heading" colspan="9"></TD></tr>
HTML
		for (my $k=1;$k<=$config{nboss};$k++)
			{
			if ($ufields{"bossemail$k"} ne '')
				{
				my $boss_email = $ufields{"bossfirstname$k"}.' '.$ufields{"bosslastname$k"}.' ('.$ufields{"bossemail$k"}.')';
				my $checked = ($changed{"bossemail$k"}) ? 'CHECKED' : '';
				&add2body(<<HTML);   
  <tr class="options"> 
    <td align="right"> 
    <B>Boss $k:</B> 
    </td>
    <td>
    <INPUT TYPE="checkbox" NAME="email_boss$k" VALUE="1" $checked>
    </td>
    <td>
    $boss_email
    </td>
  </tr>
HTML
				}
			}
		}
	&add2body(qq{</TR><tr height="2" class="heading"><TD height="2" class="heading" colspan="9"></TD></tr>\n});
	for (my $k=1;$k<=$config{npeer};$k++)
		{
		if ($ufields{"peeremail$k"} ne '')
			{
			my $peer_email = $ufields{"peerfirstname$k"}.' '.$ufields{"peerlastname$k"}.' ('.$ufields{"peeremail$k"}.')';
				my $checked = ($changed{"peeremail$k"}) ? 'CHECKED' : '';
			&add2body(<<HTML);   
  <tr class="options"> 
    <td align="right"> 
    <B>Peer $k:</B> 
    </td>
    <td>
    <INPUT TYPE="checkbox" NAME="email_peer$k" VALUE="1" $checked>
    </td>
    <td>$peer_email
    </td>
  </tr>
HTML
			}
		}
	&add2body(<<HTML);   
	</TR><tr height="2" class="heading"><TD height="2" class="heading" colspan="9"></TD></tr>
  <TR class="options">
		<TD ><CENTER><INPUT TYPE="RESET" VALUE="Reset all fields"></TD>
		<TD colspan="2"><CENTER><INPUT TYPE="SUBMIT" VALUE="Save changes and send emails"></TD>
  </tr>
</table>
HTML
	&add2body(<<HTML);   
</FORM>
HTML
	}
$form = 0;
&qt_Footer;
&db_disc;
#
#
# OK, we're done now
#
1;
