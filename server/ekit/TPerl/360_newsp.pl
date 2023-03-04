#!/usr/bin/perl
## $Id: 360_newsp.pl,v 1.4 2012-01-19 01:11:11 triton Exp $
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
use CGI;
use CGI::Carp qw(fatalsToBrowser);
#
# Start of main code 
#
$q = new CGI;
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
my @selflist = @{$config{selflist}};
my $jobtitle = $q->param('jobtitle');
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
# ??? Will need to do something to auto-generate the ID's for PPR
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
#
# Copy all the data into the ufields hash
#
	undef %ufields;
	foreach my $key ($q->param)
		{
		my $val = $q->param($key);
		$ufields{$key} = $val;
		}
	$ufields{id} = $id if ($q->param('id') eq '');
# Force same password for test ID - this is probably deprecated now
	$ufields{password} = ($ufields{id} eq '1234') ? '1234' : &db_getnextpwd($config{master});
# Do the regular calcs now
	&calc_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
#
	&db_save_pwd_full($config{master},$ufields{id},$ufields{password},$ufields{fullname},0,0,$ufields{'email'});
	&db_new_case($config{index});			# Make sure table exists first
	foreach my $survey_id (@selflist)
		{
		$resp{'survey_id'} = $survey_id;		# This looks like some legacy stuff
		&db_new_survey($survey_id);				# Make sure the receiving table exists
		&db_save_pwd_full($survey_id,$ufields{id},$ufields{password},$ufields{fullname},0,0,$ufields{'email'});
	
		&db_add_invite($config{index},$config{case},$survey_id,
						$ufields{id},$ufields{password},
						$ufields{fullname},'Self',
						$ufields{batchno},$config{sort_order}{$survey_id});
		&save_ufile($survey_id,$ufields{password});
		}
	if ($config{email_send_method} != 2){
		# Don't want these if we are using eschemes.
	$ufields{subject} = "$config{title} Kit";
	$ufields{sponsor} = $config{sponsor};
	$ufields{from_email} = $config{from_email};
	}
	if ($config{autosend_new_emails})
		{
		my $em_SID = $config{master};
		$em_SID=$config{participant} if $config{email_send_method}==2;
		&queue_invite($em_SID, 'participant', $ufields{id}, $ufields{password}, $ufields{'email'},'',$input{fmt});
		}
#
# Now do the boss(es):
#
	&calc_boss_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
	for (my $i=1;$i<=$config{nboss};$i++)
		{
		if ($ufields{"bossfullname$i"} ne '')
			{
			&debug("Adding boss $i: ".$ufields{"bossfullname$i"});
			$temp{bossfullname} = $ufields{"bossfullname$i"};
			$temp{bossfirstname} = $ufields{"bossfirstname$i"};
			$temp{bosslastname} = $ufields{"bosslastname$i"};
			$ufields{who} = $temp{bossfullname};
			$ufields{"bosspassword$i"} = ($ufields{id} eq '1234') ? '1235' : &db_getnextpwd($config{master});
			&db_save_pwd_full($config{master},$ufields{id},$ufields{"bosspassword$i"},$ufields{"bossfullname$i"},0,0,$ufields{"bossemail$i"});
			my @bosslist = @{$config{bosslist}};		
			&debug("roles\->$jobtitle\->bosslist\[0\]=".$config{roles}{$jobtitle}{bosslist}[0]);
			if ($config{roles}{$jobtitle}{bosslist}[0] ne '')
				{
				@bosslist = @{$config{roles}{$jobtitle}{bosslist}};
				}
			foreach my $survey_id (@bosslist)
				{
				$resp{'survey_id'} = $survey_id;
				&db_new_survey($survey_id);		# Make sure the receiving table exists
				&db_save_pwd_full($survey_id,$ufields{id},$ufields{"bosspassword$i"},$ufields{"bossfullname$i"},0,0,$ufields{"bossemail$i"});
				&db_add_invite($config{index},$config{case},$survey_id,
								$ufields{id},$ufields{"bosspassword$i"},
								$ufields{"bossfullname$i"},'Boss',
								$ufields{batchno},$config{sort_order}{$survey_id});
				&save_ufile($survey_id,$ufields{"bosspassword$i"});
				}
			&save_ufile($config{participant},$ufields{"bosspassword$i"});	# Save a master ufile for the boss too
			if ($ufields{"bossemail$i"} ne '')			# Assume we're handling the first boss 
				{
				if ($config{autosend_new_emails})
					{
					my $em_SID = $config{master};
					$em_SID = $config{boss} if $config{email_send_method}==2;
					&queue_invite($em_SID,'boss',$ufields{id},$ufields{"bosspassword$i"}, $ufields{"bossemail$i"},'',$input{fmt});
					}
				}
			}
		}
#
# Now do the peer(s):
#
	&calc_peer_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
	for (my $i=1;$i<=$config{npeer};$i++)
		{
		if ($ufields{"peerfullname$i"} ne '')
			{
			&debug("Adding peer $i: ".$ufields{"peerfullname$i"});
			$temp{peerfullname} = $ufields{"peerfullname$i"};
			$temp{peerfirstname} = $ufields{"peerfirstname$i"};
			$temp{peerlastname} = $ufields{"peerlastname$i"};
			$ufields{"peerpassword$i"} = ($ufields{id} eq '1234') ? '1235' : &db_getnextpwd($config{master});
			&db_save_pwd_full($config{master},$ufields{id},$ufields{"peerpassword$i"},$ufields{"peerfullname$i"},0,0,$ufields{"peeremail$i"});
			my @peerlist = @{$config{peerlist}};		
			&debug("roles\->$jobtitle\->peerlist\[0\]=".$config{roles}{$jobtitle}{peerlist}[0]);
			if ($config{roles}{$jobtitle}{peerlist}[0] ne '')
				{
				@peerlist = @{$config{roles}{$jobtitle}{peerlist}};
				}
			foreach my $survey_id (@peerlist)
				{
				$ufields{who} = $ufields{"peerfullname$i"};
				$resp{'survey_id'} = $survey_id;
				&db_new_survey($survey_id);		# Make sure the receiving table exists
				&db_save_pwd_full($survey_id,$ufields{id},$ufields{"peerpassword$i"},$ufields{"peerfullname$i"},0,0,$ufields{"peeremail$i"});
				&db_add_invite($config{index},$config{case},$survey_id,
								$ufields{id},$ufields{"peerpassword$i"},
								$ufields{"peerfullname$i"},'Peer',
								$ufields{batchno},$config{sort_order}{$survey_id});
				&save_ufile($survey_id,$ufields{"peerpassword$i"});
				}
			&save_ufile($config{participant},$ufields{"peerpassword$i"});	# Save a master ufile for the peer too
			if ($ufields{"peeremail$i"} ne '')			# Assume we're handling the first peer 
				{
				if ($config{autosend_new_emails})
					{
					my $em_SID = $config{master};
					$em_SID = $config{peer} if $config{email_send_method}==2;
					&send_invite($em_SID,'peer',$ufields{id},$ufields{"peerpassword$i"}, $ufields{"peeremail$i"},'',$input{fmt});
					}
				}
			}
		}
	&calc_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
	$ufields{who} = $ufields{fullname};	# Save the name of the person filling in the form.
	&save_ufile($config{participant},$ufields{password});	# Get the boss & peer changes to the master
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
				&add2body(qq{\t<TR><TD class="heading">Boss $i: </TD><TD class="options"><B>".$ufields{"bossfullname$i"}.", (".$ufields{"bossemail$i"}.") </B><BR>});
				&add2body(qq{\t\tBoss Password: ".$ufields{"bosspassword$i"}."<BR>});
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
				&add2body("\t\tPeer Password: ".$ufields{"peerpassword$i"}."<BR>");
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
