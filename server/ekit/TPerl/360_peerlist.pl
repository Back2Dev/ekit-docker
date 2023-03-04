#!/usr/bin/perl
# $Id: 360_peerlist.pl,v 2.3 2006/12/22 04:11:12 triton Exp $
# pwikit_peerlist.pl
#
# Special script to process peer list form
#
#
sub die_usage
	{
	my $msg = shift;

	print "$msg\n" if ($msg ne '');
	print "Usage: $0 [-v] [-t] [-h] AAA101\n" ;
	print "\t-h Display help\n";
	print "\t-v Display version no\n";
	print "\t-t Trace mode\n";
	print "\t-seq=nnn\n";
	print "\tAAA101 Survey ID\n";
	exit 0;
	}
if ($h)
	{
	die_usage;
	}
if ($v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/TPerl/360_peerlist.pl,v 2.3 2006/12/22 04:11:12 triton Exp $'."\n";
	exit 0;
	}



#------------------------------------------------------------------------------------------
# MAINLINE STARTS HERE
#
# Check the parameter (The Survey ID)
#
$survey_id = $ARGV[0];
&get_root;

die_usage("Missing survey id argument") if ($survey_id eq '');
die_usage("Missing sequence number parameter")  if ($seq eq '');

die "Cannot find directory $relative_root${qt_root}/${survey_id}\n" if (! -d "$relative_root${qt_root}/${survey_id}") ;

$data_dir = "${qt_root}/${survey_id}/web";
die "Cannot find data directory $relative_root$data_dir\n" if (! -d "$relative_root$data_dir" ) ;

$config_dir = "${qt_root}/${survey_id}/config";
die "Cannot find data directory $relative_root$config_dir\n" if (! -d "$relative_root$config_dir" ) ;

#
# Get the list of question labels from the designer
#
my $respfile = "$qt_root/$survey_id/web/D$seq.pl";
my_require ("$respfile",1);
#
# Pull in existing ufields 
#
my $ufile = "$qt_root/$config{participant}/web/u$resp{'token'}.pl";
my_require ("$ufile",0);

#
# Scan through the incoming data:
#
#$dbt=1;
&db_conn;						# Connect to database
&db_new_survey($config{master});		# Make sure the receiving table exists
&db_new_survey($config{peer});		# Make sure the receiving table exists
#
# ??? may need to look at this again
#
$ufields{sponsor} = $config{sponsor};
$ufields{from_email} = $config{from_email};
$temp{subject} = "$config{title}: Appraisal request";
$temp{sponsor} = $ufields{execname};
$temp{from_email} = $ufields{adminemail};

$t=1;
my $story = '';
my $save_msg = $resp{'ext_msg'};
for (my $i=1;$i<=$config{npeer};$i++)
	{
	if ($resp{"ext_peeremail$i"} ne '')
		{
		my $fullname = $resp{"ext_peerfullname$i"};
		my $email = lc($resp{"ext_peeremail$i"});
		my $sendit = $resp{"ext_peersend$i"};
		&debug(qq{Trying $fullname: $resp{"ext_peeremail$i"}, sendit=$sendit});
		$resp{"ext_peersend$i"} = '';	# Reset the value now
#		my $proceed = 1;
		my $new_pwd = 1;
		my $pwd = &db_case_id_name_role($config{index},$config{peer},$resp{id},$fullname,'Peer');
		if ($pwd ne '')
			{
#			$proceed = 0;
			my $em = lc(db_get_user_email($config{peer},$pwd,$resp{id},$pwd));
#			print "em=$em\n";
			if (lc($email) ne $em)
				{
#				$proceed = 1;
				$new_pwd = 0;
				}
			}
		if ($sendit && ($email ne ''))
			{
			if ($new_pwd)
				{
				$pwd = db_getnextpwd($config{master}) ;
				db_add_invite($config{index},$config{case},$config{peer},$resp{id},$pwd,$fullname,'Peer');
				}
	#
	# Put together the context information
	#
			$temp{peerfullname} = $fullname;
			$temp{peerfirstname} = $fullname ;
			if ($fullname =~ /^(\w+)\s+(.*)$/)
				{
				$temp{peerfirstname} = $1;
				$temp{peerlastname} = $2;
				}
#			print "fullname=$fullname, [$temp{peerlastname},$temp{peerfirstname}]\n";
# Hang on to the ufields stuff for 'Ron
			$ufields{"peerfirstname$i"} = $temp{peerfirstname};
			$ufields{"peerlastname$i"} = $temp{peerlastname};
			$ufields{"peerfullname$i"} = $temp{peerfullname};
			$ufields{"peeremail$i"} = $email;
			$ufields{"peerpassword$i"} = $pwd;
#			save_ufile($config{participant},$pwd);
	#
			if ($new_pwd)
				{
				db_save_pwd_full($config{master},$resp{id},$pwd,$fullname,0,0,$email);
				db_save_pwd_full($config{peer},$resp{id},$pwd,$fullname,0,0,$email);
				}
			my $colleague = $1 if ($fullname =~ /(\w+)\s+/);
			$resp{'ext_msg'} = $save_msg;
			$resp{'ext_msg'} =~ s/<colleague>/$colleague/ig;
			$resp{'ext_msg'} =~ s/</<%/g;
			$resp{'ext_msg'} =~ s/>/%>/g;
			$resp{'ext_msgt'} = $resp{'ext_msg'};		# This is the text only version, without HTML tags or <BR>
			$resp{'ext_msgt'} =~ s/\\n/\n/ig;
			$resp{'ext_msg'} =~ s/\\n/<BR>/ig;
			$story .= qq{<TR class="options"><TD >Sent peer email to $fullname ($email)</TD></TR>\n};
			my $em_SID = $config{master};
			$em_SID=$config{peer} if $config{email_send_method}==2;
			send_invite($em_SID,'peer',$resp{id},$pwd,$email);
			save_ufile($config{peer},$pwd);
			}
		}
	}
$tfile = '';
$dfile = "D$resp{seqno}.pl";
$data_dir = "${qt_root}/${survey_id}/web";
&qt_save;
$ufields{ext_msg} = $save_msg;
save_ufile($config{participant},$resp{token});
if ($story eq '')
	{
	$story = qq{<TR class="options"><TD >(None sent)</TD></TR>};
	}
print <<STORY;
<TABLE class="mytable" border=0 cellspacing=0 cellpadding=5><TR class="heading"><TH >Sending emails to peers</TH></TR>
$story
</TABLE>
<HR>
STORY
1;
