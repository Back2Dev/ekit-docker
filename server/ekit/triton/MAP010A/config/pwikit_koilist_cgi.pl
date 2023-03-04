#!/usr/bin/perl
#
# pwikit_koilist_cgi.pl
#
# Special script to process MAP KOI list form
#
# Assumes that it is run by the CGI script, so does not need to require any libraries
#
require 'TPerl/360-lib.pl';
$simulate_frames = 0;		# Prevent simulated frames from being used
require 'TPerl/pwikit_cfg.pl';
my @peers = ();
my @tpeers = ();
my @checks = ();
my $back2 = $input{BACK2};
$back2 =~ s/^\s+//;		# Netscape 4.7 gives us spaces

#foreach (my $n=1;$n<=$config{nkoi};$n++)
#	{
#	$resp{"ext_name$n"} = $resp{"name$n"};# if ($resp{"name$n"} ne '');
#	$resp{"ext_email$n"} = $resp{"email$n"};# if ($resp{"email$n"} ne '');
#	}
# Get a list of the boss email addresses (Can't invite them to do this):
my %verbotenboss = ();
foreach (my $n=1;$n<=$config{nboss};$n++)
	{
	$verbotenboss{lc($resp{"bossemail$n"})}++ if ($resp{"bossemail$n"} ne '');
	}
my %verbotenpeer = ();
foreach (my $n=1;$n<=$config{npeer};$n++)
	{
	$verbotenpeer{lc($resp{"peeremail$n"})}++ if ($resp{"peeremail$n"} ne '');
	}

undef %ufields;
my $ufile = "$qt_root/$input{survey_id}/web/u$resp{'token'}.pl";
my_require ("$ufile",0);
$subject = "KP request";
$id = $resp{'id'};
$ufields{sponsor} = $config{sponsor};
$ufields{from_email} = $config{from_email};
# These used to be $temp
$temp{subject} = "$config{title}: Appraisal request";
$temp{sponsor} = $ufields{fullname};
$temp{from_email} = $ufields{email};

&db_conn;
if ($external eq '')
	{
	if ($back2 eq '')		# Don't send emails if we are being asked to go back
		{
		my @sendit  = split(/$array_sep/,$resp{_Q2});
		our $story = '';
	#
	# Pull in existing ufields ($resp hash is already present, as we are in godb/qt-libdb context
	#
		foreach (my $n=1;$n<=$config{nkoi};$n++)
			{
	#		&debug("I am here in part 2: $n");
			if ($sendit[$n-1])
				{
				my $fullname = $resp{"name$n"};
				my $email = lc($resp{"email$n"});
				$ufields{companyname} = $resp{"ext_company$n"};
				$title = $resp{"ext_title$n"};
				$ufields{name} = $resp{"name$n"};
				$ufields{currdate} = localtime();
#
# Put together the context information
#
				$ufields{'email'} = $resp{'email'};
				$ufields{'fullname'} = $resp{'aboutname'};
				$ufields{'firstname'} = $resp{'firstname'};
				$ufields{'lastname'} = $resp{'lastname'};
				$ufields{'organization'} = $resp{'organization'};
				&debug(qq{Trying $fullname: $email"});
				if ($email ne '')			# Only send email if we have an email address
					{
			#
			# Put together the context information
			#
#					$temp{fullname} = $fullname;
		#			print "fullname=$fullname\n";
			#
					my $colleague = $1 if ($fullname =~ /(\w+)\s+/);
					$story .= qq{<TR class="options"><TD >Sent email to $fullname ($email)</TD></TR>\n};
					$resp{"koisent$n"} = time();			# Timestamp when it was last sent
					debug("Saving send time as ".$resp{"koisent$n"});
					send_invite_now($config{koi},'koi',$resp{id},'',$email);
					}
				}
			}
#		save_ufile($config{participant},$resp{token});
		if ($story eq '')
			{
			$story = qq{<TR class="options"><TD >(None sent)</TD></TR>};
			}
		$story = <<STORY;
<TABLE class="mytable" border=0 cellspacing=0 cellpadding=5><TR class="heading"><TH >Sending emails to outside influences</TH></TR>
$story
</TABLE>
<BR>
STORY
# Now recalculate mask in case we are coming back to it.
		foreach (my $n=1;$n<=$config{nkoi};$n++)
			{
			$peers[$n-1] = 0;
			$checks[$n-1] = '';
			my $fullname = $resp{"name$n"};
			if ($fullname ne '')
				{
				$peers[$n-1] = 1;
				$tpeers[$n-1] = "$n. $fullname (".$resp{"email$n"}.")";
				if ($resp{"koisent$n"} ne '')
					{
					my $now_string = localtime($resp{"koisent$n"});
					$tpeers[$n-1] .= qq{ <I><B>email last sent at $now_string <I></B>};
					}
				$checks[$n-1] = 1 if ($resp{"koisent$n"} eq '');	# Turn new ones (ie unsent) on
				my $email = $resp{"email$n"};
				if ($verbotenboss{lc($email)})
					{
					$tpeers[$n-1] .= qq{<FONT color="red" size="+1"> - <B>Error:</B> You cannot include your supervising manager or partner on this list, please go back and correct it.</FONT>};
					$checks[$n-1] = -1;	# -1 Means disable the control
					}
				elsif ($verbotenpeer{lc($email)})
					{
					$tpeers[$n-1] .= qq{<FONT color="red" size="+1"> - <B>Error:</B> You cannot include your peers on this list, please go back and correct it.</FONT>};
					$checks[$n-1] = -1;	# -1 Means disable the control
					}
				if ($email eq '')	# No email - can't send :-(
					{
					$tpeers[$n-1] = "$n. $fullname (no email address supplied)";
					$checks[$n-1] = -1;	# -1 Means disable the control
					}
				}
			}
		$resp{mask_peers} = join($array_sep,@peers);
		$resp{maskt_peers} = join($array_sep,@tpeers);
		$resp{_Q2} = join($array_sep,@checks);	
		$data_dir = "${qt_root}/$input{survey_id}/web";
		&qt_save;
		if ($resp{changed} >= 0)
			{
			my $ret = &send_invite_now($config{execkoi}, 'execkoi', $ufields{id}, $ufields{password}, $ufields{execemail}) if ($ufields{execemail} ne '');
			&add2body("<!-- Sent email to Exec: $ufields{execname} ($ufields{execemail}) $ret -->");
			$resp{changed} = 0;
			}
		}
	}
else
# This part is run when we are receiving the list of names. 
#  We just need to save them and rebuild the mask used for the second (sending) page
	{				
	$resp{changed} = 0;
	&debug("just saving names...");
	foreach my $key (grep (/\d$/,keys %input))
		{
		if ($input{$key} ne $resp{"ext_$key"})
			{
			next if ($key =~ /BACK/);
#			&add2body("Changed $key $resp{changed} ");
			$resp{changed}++ ;
			}
		}
	my $pwd = $resp{token};
	my_require("$qt_root/$config{participant}/web/u$pwd.pl");		# Bring in the ufile first
	foreach (my $n=1;$n<=$config{nkoi};$n++)
		{
		$peers[$n-1] = 0;
		$checks[$n-1] = '';
		my $fullname = $input{"name$n"};
		$resp{"name$n"} = $fullname;
		my $email = $input{"email$n"};
		$resp{"email$n"} = $email;
		if ($fullname ne '')
			{
			$peers[$n-1] = 1;
			$tpeers[$n-1] = "$n. $fullname ($email)";
			if ($resp{"koisent$n"} ne '')
				{
				my $now_string = localtime($resp{"koisent$n"});
				$tpeers[$n-1] .= qq{ <I><B>email last sent at $now_string <I></B>};
				}
			$checks[$n-1] = 1 if ($resp{"koisent$n"} eq '');	# Turn new ones (ie unsent) on
			my $email = $resp{"email$n"};
			if ($verbotenboss{lc($email)})
				{
				$tpeers[$n-1] .= qq{<FONT color="red" size="+1"> - <B>Error:</B> You cannot include your supervising manager or partner on this list, please go back and correct it.</FONT>};
				$checks[$n-1] = -1;	# -1 Means disable the control
				}
			elsif ($verbotenpeer{lc($email)})
				{
				$tpeers[$n-1] .= qq{<FONT color="red" size="+1"> - <B>Error:</B> You cannot include your peers on this list, please go back and correct it.</FONT>};
				$checks[$n-1] = -1;	# -1 Means disable the control
				}
			if ($email eq '')	# No email - can't send :-(
				{
				$tpeers[$n-1] = "$n. $fullname (no email address supplied)";
				$checks[$n-1] = -1;	# -1 Means disable the control
				}
			}
		}
	$resp{mask_peers} = join($array_sep,@peers);
	$resp{maskt_peers} = join($array_sep,@tpeers);
	$resp{_Q2} = join($array_sep,@checks);	
	$data_dir = "${qt_root}/$input{survey_id}/web";
	$resp{survey_id} = $input{survey_id};
	&qt_save;
	}
&db_disc;
&debug("pwikit_koilist_cgi sid=$survey_id $resp{survey_id} Done");
#
1;
