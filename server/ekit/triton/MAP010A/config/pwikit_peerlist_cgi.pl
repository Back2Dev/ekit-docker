#!/usr/bin/perl
#
# pwikit_peerlist_cgi.pl
#
# Special script to process MAP peer list form
#
# Assumes that it is run by the CGI script, so does not need to require any libraries
#
require 'TPerl/360-lib.pl';
$simulate_frames = 0;		# Prevent simulated frames from being used
require 'TPerl/pwikit_cfg.pl';
my @peers = ();
my @tpeers = ();
my @checks = ();
my $back2 = &input('BACK2');
$back2 =~ s/^\s+//;		# Netscape 4.7 gives us spaces
my $show_password = 0;
# Get a list of the boss email addresses (Can't invite them to do this):
my %verboten = ();
foreach (my $n=1;$n<=$config{nboss};$n++)
	{
	$verboten{lc($resp{"bossemail$n"})}++ if ($resp{"bossemail$n"} ne '');
	}
#
# Also make sure they cannot add themselves to the list (Although we cannot guard against other personal email addresses):
#
$verboten{lc($resp{email})}++;

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
		undef %ufields;
		my $ufile = "$qt_root/$config{participant}/web/u$resp{'token'}.pl";
		my_require ("$ufile",0);
#		my $n = join(",",keys %ufields);
#		my $m = join(",",keys %resp);
#		debug("resp=$m, ufields=$n ");
		foreach (my $n=1;$n<=$config{npeer};$n++)
			{
	#		&debug("I am here in part 2: $n");
			if ($sendit[$n-1])
				{
				my $fullname = mk_fullname($resp{"peerfirstname$n"},$resp{"peerlastname$n"});
				my $email = lc($resp{"peeremail$n"});
#				alert("Sending email to $fullname");
				&debug(qq{Trying $fullname: $email"});
#				my $pwd = &db_case_id_name_role($config{index},$config{peer},$resp{id},$fullname,'Peer');
				my $pwd = $resp{"peerpassword$n"};	# Do we have a password for them already ?
				if ($email ne '')			# Only send email if we have an email address
					{
			#
			# Put together the context information
			#
					$temp{peerfullname} = $fullname;
					$temp{peerfirstname} = $resp{"peerfirstname$n"};
					$temp{peerlastname} = $resp{"peerlastname$n"};
		#			print "fullname=$fullname, [$temp{peerlastname},$temp{peerfirstname}]\n";
			#
					my $colleague = $1 if ($fullname =~ /(\w+)\s+/);
	# THIS IS NOT USED, BUT COULD BE RESUSCITATED LATER
	#				$resp{'ext_msg'} = $save_msg;
	#				$resp{'ext_msg'} =~ s/<colleague>/$colleague/ig;
	#				$resp{'ext_msg'} =~ s/</<%/g;
	#				$resp{'ext_msg'} =~ s/>/%>/g;
	#				$resp{'ext_msgt'} = $resp{'ext_msg'};		# This is the text only version, without HTML tags or <BR>
	#				$resp{'ext_msgt'} =~ s/\\n/\n/ig;
	#				$resp{'ext_msg'} =~ s/\\n/<BR>/ig;
					$story .= qq{<TR class="options"><TD >Sent peer email to $fullname ($email)</TD></TR>\n};
					$resp{"peersent$n"} = time();			# Timestamp when it was last sent
					debug("Saving send time as ".$resp{"peersent$n"});
					send_invite($config{master},'peer',$resp{id},$pwd,$email);
					}
				}
			}
		#$ufields{ext_msg} = $save_msg;
		save_ufile($config{participant},$resp{token});
		if ($story eq '')
			{
			$story = qq{<TR class="options"><TD >(None sent)</TD></TR>};
			}
		$story = <<STORY;
<TABLE class="mytable" border=0 cellspacing=0 cellpadding=5><TR class="heading"><TH >Sending emails to peers</TH></TR>
$story
</TABLE>
<BR>
STORY
# Save the data back to the ext_ fields for Ron
		foreach (my $n=1;$n<=$config{npeer};$n++)
			{
			$resp{"ext_peerfirstname$n"} = $resp{"peerfirstname$n"};
			$resp{"ext_peerlastname$n"} = $resp{"peerlastname$n"};
			$resp{"ext_peeremail$n"} = $resp{"peeremail$n"};
			$resp{"ext_peerfullname$n"} = mk_fullname($resp{"peerfirstname$n"},$resp{"peerlastname$n"});
			}

# Now recalculate mask in case we are coming back to it.
		foreach (my $n=1;$n<=$config{npeer};$n++)
			{
			$peers[$n-1] = 0;
			$checks[$n-1] = '';
			my $fullname = mk_fullname($resp{"peerfirstname$n"},$resp{"peerlastname$n"});
			if ($fullname ne '')
				{
				$peers[$n-1] = 1;
				$tpeers[$n-1] = "$n. $fullname (".$resp{"peeremail$n"}.")";
				my $pwd = $resp{"peerpassword$n"};
				$tpeers[$n-1] .= qq{[$pwd]} if $show_password;
				if ($resp{"peersent$n"} ne '')
					{
					my $now_string = localtime($resp{"peersent$n"});
					$tpeers[$n-1] .= qq{ <I><B>email last sent at $now_string <I></B>};
					$resp{"disabled$n"} = "DISABLED";
					}
				$checks[$n-1] = 1 if ($resp{"peersent$n"} eq '');	# Turn new ones (ie unsent) on
				$checks[$n-1] = 1 if ($input{"peeremail$n"} ne $resp{"ext_peeremail$n"});	# Turn new ones (ie unsent) on
				my $email = $resp{"peeremail$n"};
				if ($verboten{lc($email)})
					{
					$tpeers[$n-1] .= qq{<FONT color="red" size="+1"> - <B>Error:</B> You cannot include yourself, your supervising manager or partner on this list, please go back and correct it.</FONT>};
					$checks[$n-1] = -1;	# -1 Means disable the control
					}
				$checks[$n-1] = 0 if ($resp{"disabled$n"} ne '');
				}
			}
		$resp{mask_peers} = join($array_sep,@peers);
		$resp{maskt_peers} = join($array_sep,@tpeers);
		$resp{_Q2} = join($array_sep,@checks);	
		$data_dir = "${qt_root}/$input{survey_id}/web";
		&qt_save;
		if ($resp{changed} >= 0)
			{
			my $ret = &send_invite_now($config{execq10}, 'execq10', $ufields{id}, $ufields{password}, $ufields{execemail}) if ($ufields{execemail} ne '');
			&add2body("<!-- Sent email to Exec: $ufields{execname} ($ufields{execemail}) $ret -->");
			$resp{changed} = 0;
			}
		}
	}
else
# This part is run when we are receiving the list of names. 
#  We just need to save them and rebuild the mask used for the second (sending) page
	{				
	&debug("just saving names...");
	$resp{changed} = 0;
    foreach my $key (grep (/\d$/,keys %input))
        {
        if ($input{$key} ne $resp{"ext_$key"})
            {
            next if ($key =~ /BACK/);
#           &add2body("Changed $key $resp{changed} ");
            $resp{changed}++ ;
            }
        }   

	my $pwd = $resp{token};
	my_require("$qt_root/$config{participant}/web/u$pwd.pl");		# Bring in the ufile first
	foreach (my $n=1;$n<=$config{npeer};$n++)
		{
		$peers[$n-1] = 0;
		$checks[$n-1] = '';
		my $firstname = &input("peerfirstname$n");	# We grab the input, to prevent it being saved to ther resp Hash as ext_...
		my $lastname = &input("peerlastname$n");
		my $email = &input("peeremail$n");
		if ($resp{"disabled$n"} ne '')
			{
			$firstname = $resp{"peerfirstname$n"};	
			$lastname = $resp{"peerlastname$n"};
			$email = $resp{"peeremail$n"};
			}
		my $fullname = mk_fullname($firstname,$lastname);
		$ufields{"peerfirstname$n"} = $resp{"peerfirstname$n"} = $firstname;
		$ufields{"peerlastname$n"}  = $resp{"peerlastname$n"}  = $lastname;
		$ufields{"peerfullname$n"}  = $resp{"peerfullname$n"}  = $fullname;
		$ufields{"peeremail$n"}     = $resp{"peeremail$n"}     = $email;
		if ($fullname ne '')
			{
			debug("n=$n, ".$resp{"peerfirstname$n"});
			$peers[$n-1] = 1;
			$tpeers[$n-1] = "$n. $fullname ($email)";
			my $pwd = $resp{"peerpassword$n"};
			if ($pwd eq '')
				{
				$resp{"peerpassword$n"} = db_getnextpwd($config{master});
				$ufields{"peerpassword$n"} = $resp{"peerpassword$n"};	
				$pwd = $resp{"peerpassword$n"};	
				db_add_invite($config{index},$config{case},$config{peer},$resp{id},$pwd,$fullname,'Peer',$resp{batchno},0);
				db_save_pwd_full($config{master},$resp{id},$pwd,$fullname,0,$resp{batchno},$email);
				db_save_pwd_full($config{peer},$resp{id},$pwd,$fullname,0,$resp{batchno},$email);
				}
			$tpeers[$n-1] .= qq{[$pwd]} if $show_password;
			if ($resp{"peersent$n"} ne '')
				{
				my $now_string = localtime($resp{"peersent$n"});
				$tpeers[$n-1] .= qq{ <I><B>email last sent at $now_string <I></B>};
				$resp{"disabled$n"} = "DISABLED";
				}
			$checks[$n-1] = 1 if ($resp{"peersent$n"} eq '');	# Turn new ones (ie unsent) on
			$checks[$n-1] = 1 if ($input{"peeremail$n"} ne $resp{"ext_peeremail$n"});	# Turn new ones (ie unsent) on
			if ($verboten{lc($email)})
				{
				$tpeers[$n-1] .= qq{<FONT color="red" size="+1"> - <B>Error:</B> You cannot include yourself, your supervising manager or partner on this list, please go back and correct it.</FONT>};
				$checks[$n-1] = -1;	# -1 Means disable the control
				}
			$checks[$n-1] = 0 if ($resp{"disabled$n"} ne '');
			
			my @mylist = @{$config{peerlist}};
			my $jobtitle = $ufields{jobtitle};
#			&debug("roles\->$jobtitle\->peerlist\[0\]=".$config{roles}{$jobtitle}{peerlist}[0]);
			if ($config{roles}{$jobtitle}{peerlist}[0] ne '')
				{
				@mylist = @{$config{roles}{$jobtitle}{peerlist}};
				}
			my %extras = ();
			$extras{fullname} = $ufields{"peerfullname$n"};
			&db_save_extras($config{index},$pwd,\%extras);
			$extras{email} = $ufields{"peeremail$n"};
			foreach my $mysid (@mylist)
				{
				&debug("Updating peer $n info");
				&save_ufile($mysid,$pwd);
				update_dfile($mysid,$resp{id},$resp{"peerpassword$n"});
				&db_save_extras($mysid,$resp{"peerpassword$n"},\%extras);
				}
			debug("n=$n, ".$resp{"peerfirstname$n"});
			}
		}
	$resp{mask_peers} = join($array_sep,@peers);
	$resp{maskt_peers} = join($array_sep,@tpeers);
	$resp{_Q2} = join($array_sep,@checks);	
	$data_dir = "${qt_root}/$input{survey_id}/web";
	$resp{survey_id} = $input{survey_id};
	&qt_save;
	save_ufile($config{participant},$resp{token});
	}
&db_disc;
&debug("pwikit_peerlist_cgi sid=$survey_id $resp{survey_id} Done");
#
1;
