#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:12:03 2012
#
$qtype = 27 ;
$prompt = '1B. Receive names';
$qlab = 'Q1B';
$q_label = '1B';
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
	&debug("just saving names...");
	my $pwd = $resp{token};
	my_require("$qt_root/$config{participant}/web/u$pwd.pl");		# Bring in the ufile first
	foreach (my $n=1;$n<=$config{npeer};$n++)
	{
	$peers[$n-1] = 0;
	$checks[$n-1] = '';
	my $firstname = &input("peerfirstname$n");	# We grab the input, to prevent it being saved to the resp Hash as ext_...
	my $lastname = &input("peerlastname$n");
	my $email = &input("peeremail$n");
	if ($resp{"disabled$n"} ne '')
	{
	$firstname = $resp{"peerfirstname$n"};
	$lastname = $resp{"peerlastname$n"};
	$email = $resp{"peeremail$n"};
	}
	my $fullname = mk_fullname($firstname,$lastname);
	$ufields{peerfirstname} = $ufields{"peerfirstname$n"} = $resp{"peerfirstname$n"} = $firstname;
	$ufields{peerlastname}  = $ufields{"peerlastname$n"}  = $resp{"peerlastname$n"}  = $lastname;
	$ufields{who} = $ufields{peerfullname}  = $ufields{"peerfullname$n"}  = $resp{"peerfullname$n"}  = $fullname;
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
	&db_disc;
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
