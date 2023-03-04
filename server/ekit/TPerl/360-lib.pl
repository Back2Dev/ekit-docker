#!/usr/local/bin/perl
# $Id: 360-lib.pl,v 2.46 2012-06-20 00:17:57 triton Exp $
#
use Mail::Sender;

use Date::Parse;
use Time::Piece;

use TPerl::TritonConfig;
use TPerl::Sender;
use TPerl::CGI;
use TPerl::EScheme;

$simulate_frames = 1;

sub	showpage
	{
	my $pagename = shift;
	debugtrc($pagename);
	my $file = $qt_root."/$config{case}/html/admin/$pagename";
#	print "Reading file: $file<BR>\n";
	if (!open (SRC,"<$file"))
		{
		qt_CannaHandle("<B><I>Error: [$!] reading external html file: $file</B></I>"); 
		die;
		};
	my $selecting = 0;
	my $selval = -1;
	while (<SRC>)
		{
		chomp;
		s/\r//g;
		if (/<input/i)				# Is there an input field ?
			{
			my $name = "Bogus";
			if (/name=['"]*(\w+)["']*/i)				# Is there an input field ?
				{
				$name = $1;
				}
			if (/type=["']radio/i)		# Radio field ?
				{
				if (/value=["']*(\d+)["']*/i)
					{
					my $val = $1;
					debug("Looking for external data for radio button $name");
					if ($val == $ufields{$name})
						{
						s/value=["']*\d+["']*/VALUE="$val" CHECKED/i;
						}
					}
				}
			if (/type="checkbox/i)		# Checkbox field ?
				{
				if (/value=["']*(\d+)["']*/)
					{
					my $val = $1;
					debug("Looking for external data for checkbox $name");
					if (1 == $ufields{$name})
						{
						s/value=["']*\d+["']*/VALUE="$val" CHECKED/i;
						}
					}
				}
			if (/type=["']*text/i)		# Text field ?
				{
				debug("Looking for external data for text $name");
				my $val = $ufields{$name};
				s/name=["'](\w+)["']/NAME="$name" VALUE="$val"/i;
				}
			if (/type=["']*hidden/i)		# Hidden field ?
				{
				debug("Looking for external data for text $name");
				my $val = $ufields{$name};
				s/name=["'](\w+)["']/NAME="$name" VALUE="$val"/i;
				}
			}
		if (/<textarea/i)				# Is there an open-ended field ?
			{
			my $name = "Bogus";
			if (/name=['"]*(\w+)["']*/i)				# Is there an input field ?
				{
				$name = $1;
				}
			debug("Looking for external data for open-end $name");
			my $val = $ufields{$name};
			$val =~ s/\\n/\n/g;
			s/<\/TEXTAREA>/$val<\/TEXTAREA>/i;
			}
		if (/<\/select/i)				# Is the end of a pull-down field ?
			{
			$selecting = 0;
			}
		if (/<select/i)				# Is there an pull-down field ?
			{
			my $name = "Bogus";
			if (/name=['"]*(\w+)["']*/i)				# Is there an input field ?
				{
				$name = $1;
				$selecting = 1;
				}
			debug("Looking for external data for pulldown $name");
			$selval = $ufields{$name};
			}
		if (/<option/i)				# Is there an pull-down item ?
			{
#			debug("Pulldown found");
			if (/value=['"]*(\w+)["']*/i)
				{
#			debug("Value retrieved($1)");
				my $val = $1;
				if ($selecting and ($val eq $selval))
					{
#			debug("Pulldown item found");
					s/<OPTION/<OPTION SELECTED/i;
					}
				}
			}
		s/action=['"]['"]/action="${vhost}${virtual_cgi_adm}$go.$extension"/i;
		last if (/<\/form>/i);
		my $loopcnt = 0;
		while (/<%(\w+)%>/)
			{
			my $thing = $1;
			my $newthing = '';
			$newthing = $ufields{$thing};
			debug("<%$thing%> ==> $newthing");
			s/<%${thing}%>/$newthing/gi;
			last if ($loopcnt++ > 10);
			}
		&add2body ($_);
		}
	close (SRC);
	endsub;
	}

sub calc_ustuff
	{
# Assemble the person's full name
	$ufields{fullname} = mk_fullname($ufields{'firstname'},$ufields{'lastname'});
	$ufields{who} = $ufields{fullname};
	$ufields{hisher} = ($ufields{gender} == 1) ? 'his' : 'her';
	$ufields{himher} = ($ufields{gender} == 1) ? 'him' : 'her';
# These 2 are custom for MAP/pwikit
    $ufields{yourrole} = ($ufields{partner}) ? 'partner' : 'supervising manager';
	$ufields{yourrole} = 'supervising manager or partner';
    $ufields{profit} = ($ufields{nonprofit}) ? '' : 'profit and';
# Stuff related to the boss
	$ufields{abouthisher} = ($ufields{gender} == 1) ? 'his' : 'her';
	$ufields{abouthimher} = ($ufields{gender} == 1) ? 'him' : 'her';
	$ufields{aboutname} = $ufields{fullname};
	$ufields{kitdoc} = ($ufields{new} == 1) ? 'PWIKitNew' : 'PWIKit';
	for (my $i=1;$i<=$config{nboss};$i++)
		{
		$ufields{"bossfullname$i"} = mk_fullname($ufields{"bossfirstname$i"},$ufields{"bosslastname$i"});
		}
	for (my $i=1;$i<=$config{npeer};$i++)
		{
		$ufields{"peerfullname$i"} = mk_fullname($ufields{"peerfirstname$i"},$ufields{"peerlastname$i"});
		}
	}
sub calc_boss_ustuff(){}
sub calc_peer_ustuff(){}
	
sub save_ufile
	{
	my $survey_id = shift;
	my $pwd = shift;

	die "$survey_id: Missing ufile PWD" if ($pwd eq '');
	
	my $ddir = "${qt_root}/${survey_id}/web";
	&force_dir($ddir);
	my $fn = "$ddir/u$pwd.pl";
	&debug("Saving file: $fn");
	my $user = getpwuid($<);
	open (X,">$fn") || &my_die("Cannot create temp file: $fn\n $! $user");
	print X "#!/usr/local/bin/perl\n#\n# Data for user: $pwd\n%ufields = (\n";
	foreach $key (sort keys (%ufields))
		{
	# Escape out unwanted characters in input string
		$this = $ufields{$key};
		$this =~ s/\r\n/\n/g;
		$this =~ s/\n/\\n/g;
		$this =~ s/([\\'])/\\\1/g;
		$this = $pwd if ($key eq 'password');
		print DATA_FILE "\t\t'$key','$this',\n";
		
		print X "\t'$key' => '$this',\n";
		}
	print X "\t);\n# Please leave this soldier alone:\n1;\n";
	close X;
	}

sub update_dfile
	{
	my $sid = shift;
	my $uid = shift;
	my $pwd = shift;
	my %save_resp = %resp;		# Hang on to the resp hash, so we don't break it
	my $xdfile = $dfile;
	&subtrace("Updating dfiles for $sid uid=$uid pwd=$pwd");
	my $sql = qq{select SEQ,stat,PWD from $sid where UID=? and PWD=?};
	&db_do_new($sql,$uid,$pwd);
	if (@row = $th->fetchrow_array())
		{
		if (($row[0] ne '') && ($row[0] != 0))
			{
			undef %resp;
			$dfile = "D$row[0].pl";
			$tfile = '';
			$data_dir = "$qt_root/$sid/web";
			&my_unrequire("$data_dir/$dfile");
			&my_require ("$data_dir/$dfile",0);
			foreach my $key (keys %ufields)
				{
				next if (grep(/$key/,qw{seq uid pwd id token ver tnum wkstid status start modified lastq}));
				$resp{$key} = $ufields{$key};
				}
			qt_save;	# Save the updated file back
			}
		}
	$th->finish();
	%resp = %save_resp;		# Restore the resp hash
	$dfile = $xdfile;
	&endsub;
	}
#
# This method is deprecated
#
sub send_invite
	{
	if ($config{email_send_method}==1)
		{send_invite_now(@_);}
	elsif ($config{email_send_method}==2)
		{queue_invite(@_)}
	else
		{die "[F] send_invite: No email_send_method specfied in config hash\n";}
	}

sub send_invite_now
	{
	my ($sid, $itype, $id, $password, $email,$cc,$fmt) = @_;

	debug("send_invite_now(".join(",",@_));

	my $sender = new TPerl::Sender (name => $itype,
									SID => $sid,
									);
# some data for the email.
	# my $data = {}; 
	my %data = ();
	$data{password} = $password; 
	$data{to} = $email;
	foreach (keys %temp)
		{$data{$_} = $temp{$_} if ($data{$_} eq '');}
	foreach (keys %ufields)
		{$data{$_} = $ufields{$_} if ($data{$_} eq '');}
	foreach (keys %resp)
		{$data{$_} = $resp{$_} if ($data{$_} eq '');}
	$data{subject} = $config{emails}{$itype}{subject} if ($config{emails}{$itype}{subject} ne '');
	$data{from_email} = $config{emails}{$itype}{from_email} if ($config{emails}{$itype}{from_email} ne '');
	$data{from_name} = $config{emails}{$itype}{from_name} if ($config{emails}{$itype}{from_name} ne '');
	if (my $status=$sender->send(data=>\%data) )
		{
		}
	else
		{
		# template is broken, 
		# smtp_host not defined,
		# mail sender error
		die "Error ".TPerl::Error->fmterr($sender->err)." encountered while trying to send email message '$itype'";
		}

	
	my $mail_status = "Sending $itype email to $email: <BR>&nbsp;&nbsp;&nbsp;".$sender->err;
	debug($sender->err);
#	.= ($Mail::Sender::Error eq '') ? '' : qq{$ret: $Mail::Sender::Error};	# A way of passing the status back to the caller
#	&add2body(qq{$mail_status<BR>\n});
	}
#
# This is the brand spanker, which should be a fair bit smaller than the old one
#
sub queue_invite {
	my ($sid, $itype, $id, $password, $email, $cc, $fmt) = @_;

	debug("queue_invite(".join(",",@_).")");
	my $msg = '';
	my $stat = 0;

	my $eso = new TPerl::EScheme();
	if (my $scheme_id = $eso->id_by_name(name=>$itype,SID=>$sid)){
		if (my $new_id = $eso->duplicate_scheme(tear_off=>1,scheme_id=>$scheme_id,password=>$password)){
			$msg = qq{Escheme '$itype' created for password=$password and SID=$sid};
 			&add2body(qq{<!--$msg.<BR>-->});
 			$stat = 1;
		}else{
			$msg = qq{Could not get duplicate scheme}.$eso->err;
 			&add2body($msg);
		}
	}else{
		my $q= new TPerl::CGI ('');
		$msg = "Could not find scheme $itype ".$q->dumper($eso->err);
 		&add2body($msg);
	}
return ($stat,$msg);
}
#--------------------------------------------------------
# This one is probably MAP specific, but we can sort of get away with it.
# Top Level Logic
# 1) Check workshop date
#    - Too early (more than 6w 3d prior): Do nothing
#    - Too late (less than 1w prior): Do nothing
# 2) Look for existing scheme of name beginning with...
#    - If found
#		- If we are manually resending, 
#			- Send again and exit
#		- Else 
#			- Exit
#	 - Else (ie existing scheme not found)
#		- Look for template to suit time remaining
#	 		- If found
#				- Send email
# Interface designed to be similar to queue_invite, to make it easier to change
# Basically $startdate and $manual flags are additional, the rest is the same
sub smart_send 
	{
	my ($sid, $itype, $id, $password, $email, $cc, $fmt, $startdate, $manual) = @_;

	debug("smart_send(".join(",",@_).")");
	my $es = new TPerl::EScheme;
	my $msg = "";
	my $wsdate = &ParseDate($startdate);
	my $today = &ParseDate('today');
	$delta = ParseDateDelta($delta,'semi');
	my $delta = &DateCalc($today,$wsdate);
	my $togo = &Delta_Format($delta,1,"%wt");
#
# Now round $togo down to the nearest week
#
	my $itogo = int($togo);
#	print "togo=$togo, itogo=$itogo\n";
#	print "Participant has $togo weeks to go until the workshop\n" if $opt_t;
	return (0,"  More than 6w 3d to go to $startdate ($togo days) - skipping") if (($togo > 6.4) && !$manual);
	return (0,"  Less than 1w to go $startdate ($togo days) - skipping") if (($togo > 6.4) && !$manual);
# 
# Calculate due date - should have been done somewhere before this...
#
#	my $duedate = calc_duedate($startdate,'today',"%m/%d/20%y");
#	$msg = "Participant has $togo weeks to go until the workshop, Due date is $duedate";
#
# Look to see if a scheme exists already by this name or similar
#
	my $found = 0;
#	print qq{Searching for $itype $password\n};
	my @schemes = @{$es->search_by_pwd(pwd => $password, SID => $sid)};
#	print Dumper @schemes if ($opt_d);
	if (@schemes)
		{
		foreach my $s (@schemes)
			{
			if ($s->{SCHEME_STATUS_NAME} =~ /^$itype/i)
				{
				$msg = qq{Existing EScheme [$sid/$s->{SCHEME_STATUS_NAME}] found for $password};
				$found++;
				}
			}	
		}
	if ($found)
		{
		if ($manual)
			{
			&queue_invite($sid, $itype, $id, $password, $email, $cc, $fmt);
			return (1,"$msg - sent again");
			}
		else
			{return (0,"$msg - not sent");}
		}
#
# It didn't exist at all, so work out which template to use 
#
	$found = 0;
	my $name = $itype;
	for(my $i=$itogo;$i>=0;$i--)
		{
		$name = "$itype${i}w";
		$name = $itype if ($i == 0);	# Last gasp - try naked template
#		print "$i. Looking for '$name'\n";
		my $r = $es->id_by_name(SID=>$sid, name => $name);
		if ($r)
			{
#			print Dumper $r if ($opt_d);
			$found++;
			last;
			}
		}
	if ($found)
		{
		&queue_invite($sid, $name, $id, $password, $email, $cc, $fmt);
		return(1,"Sent scheme $name to $email");
		}	
	return (0,"I could not find a template within $itogo weeks");
	}



sub mk_fullname
	{
	my ($firstname,$lastname) = @_;
	my $fullname = '';
#	my $fullname = qq{$lastname, $firstname};
	my $fullname = qq{$firstname $lastname};
	$fullname = '' if ($fullname eq ', ');
	$fullname = '' if ($fullname eq ' ');
	$fullname;
	}
	
sub get_prog
	{
	my $role = shift;
	my $ready = 0;
	my $done = 0;

	$sql1 = "SELECT max(WSDATE) FROM PWI_STATUS WHERE UID='$id' ";
	$th = &db_do($sql1);
	while (@row = $th->fetchrow_array())
	{
		($wsdate) = @row;
	}


	open my $skiphandle, '<', '/home/vhosts/ekit/htekit/surveyshutdown';
	chomp(my @lines = <$skiphandle>);
	close $skiphandle;

	$found = 0;
	$time = str2time($wsdate);
	$found = 1;
	foreach (@lines) {
		@values = split(/:/,$_);

				$time2 = str2time(@values[1]);
				if ($time2 lt $time)
				{
						$found = 1;
				}
	}


#	if ($found == 1)
#	{
		$sql = "select distinct sid from $config{index} where casename='$config{case}' and uid='$id' and Rolename = '$role' and sid != 'MAP026' and sid != 'MAP007'";
#	}
#	else {
#		$sql = "select distinct sid from $config{index} where casename='$config{case}' and uid='$id' and Rolename = '$role' and sid != 'MAP026'";
#	}
#	add2body("get_prog $config{index} for $role sql=$sql<BR>");
	&db_do($sql);


	my @sids = ();
	while (my @row = $th->fetchrow_array())
		{
		push(@sids,$row[0]);
#		add2body("push $row[0]");
		}
	foreach	$sid (@sids)
		{
		my $tsql = "Select stat,uid from $sid where uid='$id'";
		&db_do($tsql);
		while (my @row = $th->fetchrow_array())
			{
			if ($row[0] eq '4')
				{
				$done++;
				}
			else
				{
				$ready++;
				}
			}
		}
	($ready,$done);
	}


sub list_cases
	{
	my $show_n = shift;
	my $start_at = shift;
	my @ids = @_;		# Grab the supplied list of ID's
	
	$show_n = 20 if ($show_n eq '');
	$start_at = 0 if ($start_at eq '');
	my %pwds = ();
	my %bosspwds = ();
	my $bosslabel = ($config{role_lookup}{Boss} eq '') ? 'Boss' : $config{role_lookup}{Boss};
	my $peerlabel = ($config{role_lookup}{Peer} eq '') ? 'Peer' : $config{role_lookup}{Peer};
&add2hdr(<<HDR);
	<TITLE>$config{title} listing page </TITLE>
	<META NAME="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King (213) 627 7100">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2002">
	<link rel="stylesheet" href="/$config{case}/style.css">
HDR
	&add2hdr(<<SCRIPT);
<SCRIPT LANGUAGE="JavaScript">
function confirm_delete(partname,params)
	{
	if (window.confirm('Delete all data for '+partname+' ? (This cannot be undone)'))
		{
		document.location.href = '/cgi-adm/$config{case}_delete.pl'+params;
		}
	}
function confirm_clone(partname,params)
	{
	if (window.confirm('Clone participant and supervisor/team for '+partname+' ? (This creates a empty copy without the responses, suitable for the next annual review)'))
		{
		document.location.href = '/cgi-adm/$config{case}_serve.pl/clone'+params;
		}
	}
function confirm_clear(partname,params)
	{
	if (window.confirm('Clear all data for '+partname+' ? This does not delete the participant. (This cannot be undone)'))
		{
		document.location.href = '/cgi-adm/$config{case}_clear.pl'+params;
		}
	}
function confirm_sleep(partname,params)
	{
	if (window.confirm('Set '+partname+' as inactive? '))
		{
		document.location.href = '/cgi-adm/$config{case}_sleep.pl'+params;
		}
	}
function confirm_wake(partname,params)
	{
	if (window.confirm('Set '+partname+' as active? '))
		{
		document.location.href = '/cgi-adm/$config{case}_wake.pl'+params;
		}
	}
function confirm_clear(partname,params)
	{
	if (window.confirm('Clear all data for '+partname+' ? This does not delete the participant. (This cannot be undone)'))
		{
		document.location.href = '/cgi-adm/$config{case}_clear.pl'+params;
		}
	}
function confirm_hide(partname,params)
	{
	if (window.confirm('Hide participant '+partname+' ? (This is not permanent, they can be un-hidden later)'))
		{
		alert("Hide functionality not implemented yet");
		document.location.reload;
		}
	}
function confirm_editp(partname,params)
	{
	if (true)//window.confirm('Edit participant record for '+partname+' ?'))
		{
		document.location.href = '/cgi-adm/$config{case}_editp.pl'+params;
		}
	}
function confirm_sendp(partname,params)
	{
	if (window.confirm('Re-Send email to participant ('+partname+') ?'))
		{
		document.location.href = '/cgi-adm/$config{case}_resend.pl'+params;
		}
	}
function confirm_sendb(partname,params)
	{
	if (window.confirm('Re-Send email to $bosslabel ('+partname+') ? '))
		{
		document.location.href = '/cgi-adm/$config{case}_resend.pl'+params;
		}
	}
</SCRIPT>
SCRIPT
	my $peername = '';
	if ($config{show_peername})
		{
		$peername = qq{<TH class="heading" NOWRAP>$peerlabel</TD>};
		$peerlabel = '';
		}
	my $extra = (list_hdr_extra() eq '') ? '' : qq{<TH class="heading">}.list_hdr_extra()."</TH>";
 	&add2body(<<HEADER);
<TABLE BORDER="0" cellpadding="6" CELLSPACING="0" class="mytable" width="100%">
	<TR>
		<TH class="heading">ID</TH>
		$extra
		<TH class="heading">Name</TH>
		<TH class="heading">Progress</TH>
		<TH class="heading">$bosslabel</TH>
		<TH class="heading">Progress</TH>
		$peername 
		<TH class="heading">$peerlabel Prog.</TH>
		<TH class="heading">Action</TH>
	</TR>
HEADER
	my $display_cnt = 0;
	my $more = 0;
	my $less = 0;
	foreach $id (@ids)
		{
		if ($display_cnt >= $start_at)
			{
#
# Get the batch names
#
		if ($config{batch})
			{
			%batchnames = ();
			my $sql = "SELECT BAT_KV AS BATCHNO,BAT_NAME AS BATCHNAME FROM $config{batch} WHERE BAT_STATUS <3";
			&db_do($sql);
			while (my @row = $th->fetchrow_array())
				{
				$batchnames{$row[0]} = $row[1];
				}
			$th->finish;
			}
#
# Get the names
#
		$sql = "select distinct fullname,pwd,batchno from $config{index} where casename='$config{case}'";
		$sql .= " and rolename='Self' and uid='$id'";
		&db_do($sql);
		my @row = $th->fetchrow_array();
		my $momname = $row[0];
		$pwds{$id} = $row[1];		# Stack up the ID's
		$batch{$id} = $row[2];		# Stack up the Batchno's
		$batch{$id} = $batchnames{$row[2]} if ($batchnames{$row[2]} ne '');		# Stack up the Batchno's
		$sql = "select distinct fullname,pwd,batchno from $config{index} where casename='$config{case}' and rolename='Boss' and uid='$id'";
		&db_do($sql);
		my $ufile = "$qt_root/$config{participant}/web/u$pwds{$id}.pl";
		if (-f $ufile)
			{
#			undef %ufields;
			my_require ($ufile,0);
			}
		$twinaname = "";
		for (my $n=1;$n<=$config{nboss};$n++)
			{
			if ($ufields{"bossemail$n"} ne '')
				{
				my $name = $ufields{"bossfullname$n"};
				$name = "$1 $2" if ($name =~ /^(\w)\w*\s+([\w']+)$/i);
				$name = "$2 $1"	if ($name =~ /^([\w']+),\s+(\w)\w*$/i);
				my $sname = $name;
				$sname =~ s/'/\\'/g;
				my $bem = $ufields{"bossemail$n"};
				$twinaname .= "<BR>" if ((!($twinaname =~ /<BR>$/i)) && ($n > 1));
				if ($config{can_email})
					{
					$twinaname .= qq{<IMG SRC="/$config{case}/resend.gif" alt="Re-send email to $bosslabel $n $sname ($bem)" }; 
					$twinaname .= qq{			onclick="confirm_sendb('$sname ($bem)','?id=$id&role=boss$n')">};
					}
				my $pwd = $ufields{"bosspassword$n"};
				$twinaname .= qq{&nbsp;$name};
	#			$bosspwds{$id} .= '<br>';
				$bosspwds{$id} .= $pwd;		# Stack up the ID's
				}
			}
		
		
		$sql = "select distinct fullname,pwd,batchno from $config{index} where casename='$config{case}' and rolename='Peer' and uid='$id'";
		&db_do($sql);
		my $twinbname = '';
		my $n = 1;
		while (my @row = $th->fetchrow_array())
			{
			if ($twinbname ne '')	# More than one, assemble a list
				{
				my $name = $row[0];
#				if ($name =~ /^(\w)\w+\s+.*?(\w+)$/)
				if ($name =~ /^(\w)\w*\s+([\w']+)$/i)
					{
#					$name = "$2,$1";
					$name = "$1 $2";					
					}
				if ($name =~ /^([\w']+),\s+(\w)\w*$/i)
					{
#					$name = "$1,$2";
					$name = "$2 $1";					
					}
				my $sname = $name;
				$sname =~ s/'/\\'/g;
				$twinbname .= "<BR>" if (!($twinbname =~ /<BR>$/i));
				if ($config{can_email})
					{
					$twinbname .= qq{<IMG SRC="/$config{case}/resend.gif" alt="Re-send email to $bosslabel $n ($name)" }; 
					$twinbname .= qq{			onclick="confirm_sendb('$sname','?id=$id&role=boss$n')">};
					}
				my $pwd = $row[1];
				$twinbname .= qq{&nbsp;$name};
				}
			else
				{
				my $name = $row[0];
				if ($name =~ /^(\w)\w*\s+([\w']+)$/i)
					{
					$name = "$1 $2";					
					}
				if ($name =~ /^([\w']+),\s+(\w)\w*$/i)
					{
					$name = "$2 $1";					
					}
				my $sname = $name;
				$sname =~ s/'/\\'/g;
				if ($config{can_email})
					{
					$twinbname .= qq{<IMG SRC="/$config{case}/resend.gif" alt="Re-send email to $bosslabel 1 ($name)" }; 
					$twinbname .= qq{			onclick="confirm_sendb('$sname','?id=$id&role=boss1')">};
					}
				$twinbname .= qq{&nbsp;$name};
				}
			$n++;
			}
#
# Get the counters
#	
		my ($ready,$done) = &get_prog('Self',$id);
		my ($readya,$donea) = &get_prog('Boss',$id);
		my ($readyb,$doneb) = &get_prog('Peer',$id);
			
		my $perc = 0;
		$perc = int(100*($done/($done+$ready))) if (($done+$ready) > 0);
		my $progm_html = &get_progress_html($perc,70,10,'leftprog','rightprog');
		
		$perc = 0;
		$perc = int(100*($donea/($donea+$readya))) if (($donea+$readya) > 0);
		my $proga_html = '';
		$proga_html = &get_progress_html($perc,70,10,'leftprog','rightprog') if ($bosspwds{$id} ne '');
	
		$perc = 0;
#		add2body("doneb=$doneb, readyb=$readyb");
		$perc = int(100*($doneb/($doneb+$readyb))) if (($doneb+$readyb) > 0);
		my $peername = "";
		$peername = qq{<TD class="options" NOWRAP>$twinbname</TD>} if ($config{show_peername});
		$progb_html .= "$twinbname " if ($config{show_peername});
		my $progb_html = &get_progress_html($perc,70,10,'leftprog','rightprog') if (($readyb+$doneb) > 0);
		my $bosslinks = '';
		if ($bosspwds{$id} =~ /,/)
			{
			my @bp = split(/,/,$bosspwds{$id});
			foreach my $b (@bp)
				{
				$bosslinks = qq{<A h ref="/cgi-mr/$config{case}_login.pl?id=$id&password=$bosspwds{$id}">$bosspwds{$id}</A>};
				}
			}
		else
			{
			$bosslinks = qq{<A h ref="/cgi-mr/$config{case}_login.pl?id=$id&password=$bosspwds{$id}">$bosspwds{$id}</A>};
			}
		my $smomname = $momname;
		$smomname =~ s/'/\\'/g;
		my $hide_me = <<HIDE_ME if (0);
							<IMG SRC="/$config{case}/hide.gif" alt="Hide this participant ($momname)" 
								onclick="confirm_hide('$smomname','?id=$id&password=$pwds{$id}')"> 
HIDE_ME
		my $delete_me = <<DELETE_ME if (grep /$ENV{'REMOTE_USER'}/, @{$config{admins}});#	$config{admins});
							&nbsp;&nbsp;&nbsp;&nbsp;<IMG SRC="/$config{case}/trash.gif" alt="Delete this participant ($momname)" 
								onclick="confirm_delete('$smomname','?id=$id&password=$pwds{$id}')">
DELETE_ME
		my $clone_me = '';
		$clone_me = <<CLONE_ME if ((grep /$ENV{'REMOTE_USER'}/, @{$config{admins}}) && ($config{can_clone}));
							&nbsp;&nbsp;&nbsp;&nbsp;<IMG SRC="/$config{case}/clone.gif" alt="Clone this participant ($momname)" 
								onclick="confirm_clone('$smomname','?id=$id&password=$pwds{$id}')">
CLONE_ME
		my $clear_me = <<CLEAR_ME if (grep /$ENV{'REMOTE_USER'}/, @{$config{admins}});#	$config{admins});
							&nbsp;&nbsp;&nbsp;&nbsp;<IMG SRC="/$config{case}/clear.gif" alt="Clear this participant ($momname)" 
								onclick="confirm_clear('$smomname','?id=$id&password=$pwds{$id}')">
CLEAR_ME
		my $wake_me = '';
		if ($config{can_sleep})
			{
			$wake_me = <<SLEEP_ME if (grep /$ENV{'REMOTE_USER'}/, @{$config{admins}});#	$config{admins});
							&nbsp;&nbsp;<IMG SRC="/$config{case}/sleep.gif" alt="Make this participant inactive ($momname)" 
								onclick="confirm_sleep('$smomname','?id=$id&password=$pwds{$id}')">
SLEEP_ME
			$wake_me = <<WAKE_ME if ((grep /$ENV{'REMOTE_USER'}/, @{$config{admins}}) && ($ufields{inactive}));
							&nbsp;&nbsp;<IMG SRC="/$config{case}/wakeme.gif" alt="Make this participant active ($momname)" 
								onclick="confirm_wake('$smomname','?id=$id&password=$pwds{$id}')">
WAKE_ME
			}
		my $clear_me = <<CLEAR_ME if (grep /$ENV{'REMOTE_USER'}/, @{$config{admins}});#	$config{admins});
							&nbsp;&nbsp;&nbsp;&nbsp;<IMG SRC="/$config{case}/clear.gif" alt="Clear this participant ($momname)" 
								onclick="confirm_clear('$smomname','?id=$id&password=$pwds{$id}')">
CLEAR_ME
		my $batchno = ($config{show_batch}) ? ".$batch{$id}" : '';
		my $jobname = '';
		my $ufile = "$qt_root/$config{participant}/web/u$pwds{$id}.pl";
		my $link = qq{$id Archived };
		if (-f $ufile)
			{
#			undef %ufields;
			my_require ($ufile,0);
			if ($ufields{jobtitle} ne '')
				{
				$jobname ="(".$config{roles}{$ufields{jobtitle}}{name}.")";
				}
			$link = qq{$ufields{cms_status} $ufields{cms_flag} <A href="/cgi-mr/$config{case}_login.pl?id=$id&password=$pwds{$id}&admin=1">$id$batchno</A>};
			if ($config{can_sleep})
				{
				$link = qq{$link <IMG src="/$config{case}/asleep.gif" border="0" align="middle">} if ($ufields{inactive});
				}

			}
		my $em = '';
		$em = qq{<IMG SRC="/$config{case}/resend.gif" alt="Re-send email to participant ($momname)" onclick="confirm_sendp('$smomname','?id=$id&role=participant')">}
			if ($config{can_email});
		my $extra = (list_hdr_extra() eq '') ? '' : qq{<TD class="options">}.list_body_extra()."</TD>";
		my $edit_me = qq{ <IMG SRC="/$config{case}/edit.gif" alt="Edit this participant ($momname)" };
		$edit_me .= qq{ onclick="confirm_editp('$smomname','?id=$id&password=$pwds{$id}')"> };
		if (!(-f $ufile))
			{
			$em = '';
			$edit_me = '';
			$twinaname = '';
			}
		$twinaname = '&nbsp;' if ! $twinaname;
		$proga_html = '&nbsp;' if ! $proga_html;
		$progb_html = '&nbsp;' if ! $progb_html;
		&add2body(<<ROW);
	<TR>
		<TD class="options">$link</TD>
		$extra
		<TD class="options">$em
			&nbsp;$momname $jobname</Td>
		<TD class="options">$progm_html</th>		
		<TD class="options">$twinaname</td>
		<TD class="options">$proga_html</tD>		
		$peername
		<TD class="options" NOWRAP>$progb_html</TD>		
		<TD class="options"><CENTER>
							$edit_me
							$hide_me
							$wake_me
							$clone_me
							$clear_me
							$delete_me
							</TD>
	</TR><!--<tr height="1" class="heading"><TD height="1" class="heading" colspan="9"></TD></tr>-->
ROW
		}
		$display_cnt++;
		if ($display_cnt >= $start_at + $show_n)
			{
			$more = 1 if ($display_cnt <= $#ids);
			last;
			}	
		}
	&add2body(<<BODY);
</TABLE>
BODY
	$less = 1 if ($start_at > 0);
	if ($more || $less)
		{
		my $uri = $ENV{REQUEST_URI};
		$uri =~ s/\?.*$//g;
		$uri .= '?';
		$uri .= "batchno=$input{batchno}&" if ($input{batchno} ne '');
		&add2body(<<BODY);
<A href="${uri}start_at=0"><IMG border="0" src="/$config{case}/first.gif" alt="First page"></A>&nbsp;
BODY
		if ($less)
			{
			my $new_start = $start_at - $show_n;
			&add2body(<<BODY);
<A href="${uri}start_at=$new_start"><IMG border="0" src="/$config{case}/prev.gif" alt="Previous page" disabled></A>&nbsp;
BODY
			}
		else
			{
			&add2body(qq{<IMG border="0" src="/$config{case}/blanknext.gif" alt="already at first page">});
			}
		if ($more)
			{
			&add2body(<<BODY);
<A href="${uri}start_at=$display_cnt"><IMG border="0" src="/$config{case}/next.gif" alt="Next page"></A>&nbsp;
BODY
			}
		else
			{
			&add2body(qq{<IMG border="0" src="/$config{case}/blanknext.gif" alt="already at last page">});
			}
		$last = $#ids - ($#ids % $show_n);
		my $d_one = $start_at + 1;
		my $d_last = $start_at + $show_n;
		my $d_tot = $#ids + 1;
		&add2body(<<BODY);
<A href="${uri}start_at=$last"><IMG border="0" src="/$config{case}/last.gif" alt="last page"></A>
Records $d_one to $d_last of $d_tot <BR>
BODY
		}
	}

#
# If the client does not care about ID numbers, we can allocate our own
#
sub next_uid
    {
	my $inidir = getInidir || '/triton';
	my $filename = "$inidir/360id.txt";		# Input file
    &debug("Opening 360 uid file: $filename");
    if (open (UID_FILE, "<$filename"))
        {
        while (<UID_FILE>)
            {
            $uid = $_;
            $uid++;
            break;
            }
        close(UID_FILE);
        }
    else
        {
		&debug("Starting new uid series");
        $uid = 100;
        }
#
# Now write the new number back to the file
#
    if (open (UID_FILE, ">$filename"))
        {
        print UID_FILE "$uid\n";
        close(UID_FILE);
        }
    else
        {
		die "Cannot open 360 id file: $filename for writing\n";
        }
    $uid;
    }

sub list_hdr_extra
	{
	"";
	}
sub list_body_extra
	{
	"";
	}
#
# Check that the batch exists, getting the batchno, or auto-create it
# This code is probably eKit specific, should probably move it out of here
#
sub check_batch
	{
	my $uref = shift;
	if ($$uref{batchname})		# Only do this if it's supplied (for backward compatibility)
		{
		my $found = 0;
#		print "Looking for Batch $$uref{batchname}\n";
		my $sql = "SELECT BAT_KV AS BATCHNO,BAT_NAME AS BATCHNAME FROM $config{batch} WHERE BAT_NAME=?";
		&db_do($sql,$$uref{batchname});
		while (my @row = $th->fetchrow_array())
			{
			$$uref{batchno} = $row[0];
			$found++;
			}
		$th->finish;
		if (!$found)
			{
			my $prefix = $$uref{locationcode};
			$prefix =~ s/\D+//ig;
#			print "Looking for Location $$uref{locationcode}\n";
			my $sql = "SELECT LOC_KV FROM $config{location} WHERE LOC_CODE=?";
			&db_do($sql,$$uref{locationcode});
			while (my @row = $th->fetchrow_array())
				{
				$prefix = $row[0];
				}
			$th->finish;
			my $batchno = $$uref{batchname};
			$batchno =~ s/^.*?\.//g;
			$batchno =~ s/\D//g;
			$$uref{batchno} = qq{$prefix$batchno};
			my $sql = "INSERT INTO $config{batch} (BAT_KV,BAT_NO,BAT_NAME,BAT_STATUS) VALUES(?,?,?,?)";
			my @params = ($$uref{batchno},$$uref{batchno},$$uref{batchname},1);
#			print "INSERTING BATCH, VALUES=".join(",",@params)."\n";
			&db_do($sql,@params);
			$th->finish;
			}
		}
	}
	
sub new_participant
	{
	my $uref = shift;
	check_batch($uref);
#
# New bit here to pull in stuff from the database:
#
	&get_custom_new;		# Assume that this is defined in ???_cfg.pl
#
# Force same password for test ID - this is probably deprecated now
	$$uref{password} = ($$uref{id} eq '1234') ? '1234' : &db_getnextpwd($config{master});
# Do the regular calcs now
	&calc_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
#
	&db_save_pwd_full($config{master},$$uref{id},$$uref{password},$$uref{fullname},0,0,$$uref{'email'});
	&db_new_case($config{index});			# Make sure table exists first
	&my_die("Fatal error: selflist is empty\n") if ($#selflist == -1);
	foreach my $survey_id (@selflist)
		{
		$resp{'survey_id'} = $survey_id;		# This looks like some legacy stuff
		&db_new_survey($survey_id);				# Make sure the receiving table exists
		&db_save_pwd_full($survey_id,$$uref{id},$$uref{password},$$uref{fullname},0,0,$$uref{'email'});
	
		&db_add_invite($config{index},$config{case},$survey_id,
						$$uref{id},$$uref{password},
						$$uref{fullname},'Self',
						$$uref{batchno},$config{sort_order}{$survey_id});
		&save_ufile($survey_id,$$uref{password});
		}
	if ($config{email_send_method} != 2){
		# lets use the info in the templates when we are doing eschemes.
		$$uref{subject} = "$config{title} Kit";
		$$uref{sponsor} = $config{sponsor};
		$$uref{from_email} = $config{from_email};
	}
	if ($config{autosend_new_welcome})
		{
		my $em_SID=$config{master};
		$em_SID=$config{participant} if $config{email_send_method}==2;
		&queue_invite($em_SID, 'welcome', $$uref{id}, $$uref{password}, $$uref{email},'',$input{fmt}) if ($$uref{email} ne '');
		}
	$$uref{part_email} = $$uref{email};	# Get around a local variable problem
# The following code is pretty much deprecated, because it's done by pwikit_invite.pl now
	if ($config{autosend_new_emails})
		{
		my $em_SID=$config{master};
		$em_SID=$config{participant} if $config{email_send_method}==2;
		&queue_invite($em_SID, 'participant', $$uref{id}, $$uref{password}, $$uref{email},'',$input{fmt}) if ($$uref{email} ne '');
		&queue_invite($em_SID, 'execinvite', $$uref{id}, $$uref{password}, $$uref{execemail},'',$input{fmt}) if ($$uref{execemail} ne '');
		}
#
# Now do the boss(es):
#
	&calc_boss_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
	for (my $i=1;$i<=$config{nboss};$i++)
		{
		if ($$uref{"bossfullname$i"} ne '')
			{
			&debug("Adding boss $i: ".$$uref{"bossfullname$i"});
			$temp{bossfullname} = $$uref{"bossfullname$i"};
			$temp{bossfirstname} = $$uref{"bossfirstname$i"};
			$temp{bosslastname} = $$uref{"bosslastname$i"};
			$$uref{who} = $temp{bossfullname};
			$$uref{"bosspassword$i"} = ($$uref{id} eq '1234') ? '1235' : &db_getnextpwd($config{master});
			&db_save_pwd_full($config{master},$$uref{id},$$uref{"bosspassword$i"},$$uref{"bossfullname$i"},0,0,$$uref{"bossemail$i"});
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
				&db_save_pwd_full($survey_id,$$uref{id},$$uref{"bosspassword$i"},$$uref{"bossfullname$i"},0,0,$$uref{"bossemail$i"});
				&db_add_invite($config{index},$config{case},$survey_id,
								$$uref{id},$$uref{"bosspassword$i"},
								$$uref{"bossfullname$i"},'Boss',
								$$uref{batchno},$config{sort_order}{$survey_id});
				&save_ufile($survey_id,$$uref{"bosspassword$i"});
				}
			&save_ufile($config{participant},$$uref{"bosspassword$i"});	# Save a master ufile for the boss too
			if ($$uref{"bossemail$i"} ne '')			# Assume we're handling the first boss 
				{
				if ($config{autosend_new_emails})
					{
					my $em_SID = $config{master};
					$em_SID = $config{boss} if $config{email_send_method}==2;
					&queue_invite($em_SID,'boss',$$uref{id},$$uref{"bosspassword$i"}, $$uref{"bossemail$i"},'',$input{fmt});
					&queue_invite($em_SID, 'execbossinvite', $$uref{id}, $$uref{"bosspassword$i"}, $$uref{execemail},'',$input{fmt}) if ($$uref{execemail} ne '');
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
		if ($$uref{"peerfullname$i"} ne '')
			{
			&debug("Adding peer $i: ".$$uref{"peerfullname$i"});
			$temp{peerfullname} = $$uref{"peerfullname$i"};
			$temp{peerfirstname} = $$uref{"peerfirstname$i"};
			$temp{peerlastname} = $$uref{"peerlastname$i"};
			$$uref{"peerpassword$i"} = ($$uref{id} eq '1234') ? '1235' : &db_getnextpwd($config{master});
			&db_save_pwd_full($config{master},$$uref{id},$$uref{"peerpassword$i"},$$uref{"peerfullname$i"},0,0,$$uref{"peeremail$i"});
			my @peerlist = @{$config{peerlist}};		
			&debug("roles\->$jobtitle\->peerlist\[0\]=".$config{roles}{$jobtitle}{peerlist}[0]);
			if ($config{roles}{$jobtitle}{peerlist}[0] ne '')
				{
				@peerlist = @{$config{roles}{$jobtitle}{peerlist}};
				}
			foreach my $survey_id (@peerlist)
				{
				$resp{'survey_id'} = $survey_id;
				&db_new_survey($survey_id);		# Make sure the receiving table exists
				&db_save_pwd_full($survey_id,$$uref{id},$$uref{"peerpassword$i"},$$uref{"peerfullname$i"},0,0,$$uref{"peeremail$i"});
				&db_add_invite($config{index},$config{case},$survey_id,
								$$uref{id},$$uref{"peerpassword$i"},
								$$uref{"peerfullname$i"},'Peer',
								$$uref{batchno},$config{sort_order}{$survey_id});
				&save_ufile($survey_id,$$uref{"peerpassword$i"});
				}
			&save_ufile($config{participant},$$uref{"peerpassword$i"});	# Save a master ufile for the peer too
			if ($$uref{"peeremail$i"} ne '')			# Assume we're handling the first peer 
				{
				if ($config{autosend_new_emails})
					{
					my $em_SID = $config{master};
					$SID = $config{peer} if $config{email_send_method}==2;
					&queue_invite($config{master},'peer',$$uref{id},$$uref{"peerpassword$i"}, $$uref{"peeremail$i"},'',$input{fmt});
					}
				}
			}
		}
	&calc_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
	$$uref{who} = $$uref{fullname};	# Save the name of the person filling in the form.
	&save_ufile($config{participant},$$uref{password});	# Get the boss & peer changes to the master
	if ($config{status})
		{
		&custom_update_status;		# Assume this is defined in ???_cfg.pl
		}
	}

# Leave me here please:
1;
