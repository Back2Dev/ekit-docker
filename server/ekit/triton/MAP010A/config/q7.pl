#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:12:03 2012
#
$qtype = 27 ;
$prompt = '2B. Send out emails and assemble a story';
$qlab = 'Q2B';
$q_label = '2B';
undef $others;
$instr = '';
$code_block = q{
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
	if ($back2 eq '')		# Don't send emails if we are being asked to go back
	{
	my $sent;
	my @sendit  = split(/$array_sep/,$resp{_Q2});
	our $story = '';
	#
	# Pull in existing ufields ($resp hash is already present, as we are in godb/qt-libdb context
	#
	undef %ufields;
	my $ufile = "$qt_root/$config{participant}/web/u$resp{'token'}.pl";
	my_require ("$ufile",0);
	$resp{peerlisthtml} = "";
	foreach (my $n=1;$n<=$config{npeer};$n++)
	{
	#		&debug("I am here in part 2: $n");
	$resp{peerlisthtml} .= qq{$n. \[%peerfullname$n%] <BR>\n} if ($resp{"peerfullname$n"});
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
	my $colleague = $1 if ($fullname =~ /(\w+)\s+/);
	$story .= qq{<TR class="options"><TD >Sent peer email to $fullname ($email)</TD></TR>\n};
	queue_invite($config{peer},'peer',$resp{id},$pwd,$email);
	$sent++;
	$resp{"peersent$n"} = time();			# Timestamp when it was last sent
	debug("Saving send time as ".$resp{"peersent$n"});
	}
	}
	}
	$resp{peerlisttxt} = $resp{peerlisthtml};
	$resp{peerlisttxt} =~ s/<br>//ig;
	#$ufields{ext_msg} = $save_msg;
	save_ufile($config{participant},$resp{token});
	if ($story eq '')
	{
	$story = qq{<TR class="options"><TD >(None sent)</TD></TR>};
	}
	$story = qq{<TABLE class="mytable" border=0 cellspacing=0 cellpadding=5><TR class="heading"><TH >Sending emails to peers</TH></TR>$story</TABLE><BR>};
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
	if ($sent) {
	my $ret = &send_invite_now($config{execq10}, 'execq10', $ufields{id}, $ufields{password}, $ufields{execemail}) if ($ufields{execemail} ne '');
	&add2body("<!-- Sent email to Exec: $ufields{execname} ($ufields{execemail}) $ret -->");
	foreach (my $n=1;$n<=$config{nboss};$n++)
	{
	$ufields{bossfullname} = $ufields{"bossfullname$n"};
	if ($ufields{"bossemail$n"} ne '')
	{
	my $ret = &send_invite_now($config{bossq10}, 'bossq10', $ufields{id}, $ufields{password}, $ufields{"bossemail$n"});
	&add2body(qq{<!-- Sent email to Boss: $ufields{"bossfullname$n"} ($ufields{"bossemail$n"}) $ret -->});
	}
	}
	}
	}
	&db_disc;
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
