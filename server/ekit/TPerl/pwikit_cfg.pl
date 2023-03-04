#!/usr/local/bin/perl
#
## $Id: pwikit_cfg.pl,v 1.36 2012-10-02 23:11:57 triton Exp $
#
use Time::Local;							#perl2exe
use Date::Manip;							#perl2exe
#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

undef %config;
require 'TPerl/qt-libfrm.pl' if ($simulate_frames);
%config = 	(
			nkoi => 8,
			nboss => 10,
			npeer => 20,
			master => 'MAP101',			# NB This is not a real survey, it is used for centralised data storage
			participant => 'MAP001',
			max_per_page => 10,
			us_date_format => 1,
			show_batch => 1,
			notify_first_login => 1,
# 
# List of forms that are handled externally (i.e. by someone else)
#
			externals => [qw{MAP006}],
# This flag says they will only get to do them once
			externals_once_only => 1,
# This flag says open them in a new window
			externals_new_window => 0,
#
			selflist => [qw{MAP001 MAP002 MAP003 MAP004 MAP005 MAP006 MAP007 MAP010A MAP018}],
			newlist => [qw{MAP008 MAP009}],						# New company list
			banner => qq{<table border=0 cellpadding=0 cellspacing=0 class="bannertable" style="margin:10px;" width="100%"><tr><TD class="bannerlogo" colspan="3">&nbsp;<tr>
						<TD class="bluebarw" ALIGN="left"> &nbsp;&nbsp; <%title%>&nbsp;&nbsp;</table>},
			title => 'MAP Pre Workshop Kit',
			stafflist => [qw{MAP010}],
			peerlist => [qw{MAP010}],
			bosslist => [qw{MAP011 MAP012}],					# Boss list (same for partner or boss)
# Not sure if the next 2 are needed or not...
			peer => 'MAP010',	
			boss => 'MAP011',	
			execboss => 'MAP011',	
			koi =>	'MAP005',
			execkoi =>	'MAP005',
			execq10 =>	'MAP010A',
			bossq10 =>	'MAP010A',
			welcome => 'MAP001',
			post => 'MAP026',
			hotel => 'MAP018',

			index => 'MAP_CASES',
			status => 'PWI_STATUS',
			status_script => '../scripts/pwikit_prime_status.pl',
			batch => 'PWI_BATCH',
			location => 'PWI_LOCATION',
			case => 'pwikit', 
			doc_merge => 1,
			can_email => 1,
# This one is superceded
			send_emails =>	0,					# This is also a setting in xxx_kickoff.tt
			autosend_post => 1,					# Send 'Post workshop' email immediately ?
			autosend_new_welcome => 1,			# Send 'Welcome' email immediately ?
			autosend_new_emails => 0,			# New participant emails are sent 6 weeks prior
			email_send_method => 2,				# Backward compatibility flag :
#
# These are supplied as defaults in case there is not a proper entry in the emails list
#
			from_name => 'Cathy Webb',
			from_email => 'ctwebb@mapconsulting.com',
			email_subject => 'MAP Workshop: Feedback request',
#
# List of people with admin access - can delete participants
#
			admins => [qw{admin mikkel trking ac}],
#
# Try this structure
#		
			emails =>	{
						# Participant welcome
						welcome =>	{
										from_name => 'MAP Workshop Administrator ',
										from_email => '[%adminemail%]',
										subject => 'Welcome to your MAP Workshop!',
										},
						# Participant invite
						participant =>	{
										from_name => 'MAP Workshop Administrator ',
										from_email => '[%adminemail%]',
										subject => 'MAP Workshop Materials For [%fullname%]',
										notify => 'execinvite',
										},
						# Boss invite
						boss =>	{
										from_name => 'MAP Workshop Administrator ',
										from_email => '[%adminemail%]',
										subject => 'MAP Workshop Materials For [%fullname%]',
										notify => 'execbossinvite',
										},
						# Peer or KP (Q10) invite
						peer =>	{
										from_name => 'MAP Workshop Administrator ',
										from_email => '[%adminemail%]',
										subject => 'MAP Workshop Materials For [%fullname%]',
										},
						# KOI email
						koi =>	{
										from_name => '[%fullname%]',
										from_email => '[%email%]',
										subject => '[%fullname%]\'s Upcoming MAP Workshop',
										},
						# Exec notification of initial invite
						execinvite =>	{
										from_name => '[%adminname%]',
										from_email => '[%adminemail%]',
										subject => 'PWI EMAIL: [%fullname%] Has Been Emailed',
										},
						# Exec notification of initial invite
						execbossinvite =>	{
										from_name => '[%adminname%]',
										from_email => '[%adminemail%]',
										subject => 'PWI EMAIL: [%bossfullname%] Has Been Emailed',
										},
						# Exec notification of first participant login
						execstart =>	{
										from_name => '[%adminname%]',
										from_email => '[%adminemail%]',
										subject => 'PWI START: [%fullname%] Has Signed On',
										},
						# Exec notification of first boss login
						execbossstart =>	{
										from_name => '[%adminname%]',
										from_email => '[%adminemail%]',
										subject => 'PWI START: [%bossfullname%] Has Signed On',
										},
						# Exec notification of changes to Q10
						execq10 =>	{
										from_name => '[%adminname%]',
										from_email => '[%adminemail%]',
										subject => '[%fullname%]: Key Personnel List (Q10A)',
										},
						# Boss notification of changes to Q10
						bossq10 =>	{
										from_name => '[%adminname%]',
										from_email => '[%adminemail%]',
										subject => '[%fullname%]: Key Personnel List (Q10A)',
										},
						# Exec notification of changes to Q5 (KOI List)
						execkoi =>	{
										from_name => '[%adminname%]',
										from_email => '[%adminemail%]',
										subject => '[%fullname%]: KOI List',
										},
						# Participant Reminder 1
						participant_reminder1 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# Participant Reminder 2
						participant_reminder2 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder #2: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# Participant Reminder 3
						participant_reminder3 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder #3: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# Boss Reminder 1
						boss_reminder1 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# Boss Reminder 1
						boss_reminder2 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder #2: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# Boss Reminder 1
						boss_reminder3 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder #3: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# KP Reminder 1
						peer_reminder1 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# KP Reminder 2
						peer_reminder2 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder #2: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						# KP Reminder 3
						peer_reminder3 =>	{
										from_name => '[%execname%]',
										from_email => '[%execemail%]',
										subject => 'Reminder #3: MAP - [%duedate%] deadline - MAP Workshop Materials For [%fullname%]',
										},
						},
			snames => 	{
						MAP001  => 'Q1. Participant\'s Questionnaire',
						MAP002  => 'Q2. Management and Leadership Inventory - Participant',
						MAP003  => 'Q3. Time Allocation',
						MAP004  => 'Q4. Professional Career Summary',
						MAP005  => 'Q5. Key Outside Influences List',
						MAP006  => 'Q6. Style Insights&reg; (DISC)',		
						MAP007  => 'Q7. FIRO-B',
						MAP008  => 'Q8. Organizational Summary',
						MAP009  => 'Q9. Spreadsheet of Vital Financial Factors ',
						MAP010A => 'Q10A. Key Personnel List',
						MAP010  => 'Q10. Key Personnel Questionnaire',
						MAP011  => 'Q11. Questionnaire for Supervising Manager or Partner',
						MAP012  => 'Q12. Management and Leadership Inventory - Manager or Partner',
						MAP018  => 'Q18. Hotel Reservation',
						MAP026  => 'Q26. Post Workshop Feedback',
						},
			roles =>	{
						q1 =>	{
									name => 'Q1',
									selflist => ['MAP001'],		
									code => 'MAP001',
									caption  => 'Q1. Participant\'s Questionnaire',
								},
						q2 =>	{
									name => 'Q2',
									selflist => ['MAP002'],		
									code => 'MAP002',
									caption  => 'Q2. Management and Leadership Inventory - Participant',
								},
						q3 =>	{
									name => 'Q3',
									selflist => ['MAP003'],		
									code => 'MAP003',
									caption  => 'Q3. Time Allocation',
								},
						q4 =>	{
									name => 'Q4',
									selflist => ['MAP004'],		
									code => 'MAP004',
									caption  => 'Q4. Professional Career Summary',
								},
						q5 =>	{
									name => 'Q5',
									selflist => ['MAP005'],		
									code => 'MAP005',
									caption  => 'Q5. Key Outside Influences List',
								},
						q6 =>	{
									name => 'Q6',
									selflist => ['MAP006'],		
									code => 'MAP006',
									caption  => 'Q6. Style Insights&reg; (DISC)',		
								},
						q7 =>	{
									name => 'Q7',
									selflist => ['MAP007'],		
									code => 'MAP007',
									caption  => 'Q7. FIRO-B',
								},
						q8 =>	{
									name => 'Q8',
									selflist => ['MAP008'],		
									code => 'MAP008',
									caption  => 'Q8. Organizational Summary',
								},
						q9 =>	{
									name => 'Q9',
									selflist => ['MAP009'],		
									code => 'MAP009',
									caption  => 'Q9. Spreadsheet of Vital Financial Factors ',
								},
						q10 =>	{
									name => 'Q10',
									selflist => ['MAP010'],		
									code => 'MAP010',
									caption  => 'Q10. Key Personnel List',
								},
						q10a =>	{
									name => 'Q10A',
									selflist => ['MAP010A'],		
									code => 'MAP010A',
									caption  => 'Q10A. Key Personnel Questionnaire',
								},
						q11 =>	{
									name => 'Q11',
									selflist => ['MAP011'],		
									code => 'MAP011',
									caption  => 'Q11. Questionnaire for Supervising Manager or Partner',
								},
						q12 =>	{
									name => 'Q12',
									selflist => ['MAP012'],		
									code => 'MAP012',
									caption  => 'Q12. Management and Leadership Inventory - Manager/Partner',
								},
						q18 =>	{
									name => 'Q18',
									selflist => ['MAP018'],		
									code => 'MAP018',
									caption  => 'Q18. Hotel Reservation',
								},
						q26 =>	{
									name => 'Q26',
									selflist => ['MAP026'],		
									code => 'MAP026',
									caption  => 'Q26. Post Workshop Feedback',
								},
						},
			sort_order => 	{
						MAP001  => '3',
						MAP002  => '4',
						MAP003  => '5',
						MAP004  => '6',
						MAP005  => '2',
						MAP006  => '7',		
						MAP007  => '8',
						MAP008  => '9',
						MAP009  => '10',
						MAP010A => '1',
						MAP010  => '201',
						MAP011  => '301',
						MAP012  => '302',
						MAP018  => '11',
						MAP026  => '12',
						},
			);
# 
# This is for the participant listing:
#
sub list_hdr_extra
	{
	"Workshop";
	}
sub list_body_extra
	{
	($ufields{ws_id} eq '') ? qq{$ufields{locationcode} $ufields{workshopdate}} : $ufields{ws_id};
	}
#
# This bit is appended after a new boss/peer
#
sub extra_addnew()
	{
	&add2body("\t<TR><TD class=\"heading\">Workshop dates: </TD><TD class=\"options\">$ufields{'workshopdate'}</TD></TR>");
	&add2body("\t<TR><TD class=\"heading\">Location: </TD><TD class=\"options\">$ufields{'location'}</TD></TR>");
	&add2body("\t<TR><TD class=\"heading\">Due date: </TD><TD class=\"options\">$ufields{'duedate'}</TD></TR>");
	}
#
# This bit is appended after a new participant
#
sub extra_new()
	{
	&add2body(<<XXX);
\t<TR><TD class="heading">Workshop dates: </TD><TD class="options">$ufields{workshopdate}</TD></TR>
\t<TR><TD class="heading">Location: </TD><TD class="options">$ufields{location}</TD></TR>
\t<TR><TD class="heading">Due date: </TD><TD class="options">$ufields{duedate}</TD></TR>
\t<TR><TD class="heading">Options: </TD>
\t\t<TD class="options">New: $new </TD></TR>
</TABLE>
XXX
	}
sub calc_duedate
	{
	my $startdate = shift;
	my $refdate = shift;
	my $format = shift;
	$format = "20%y-%m-%d" if ($format eq '');
	
	$refdate = 'today' if ($refdate eq '');
	my $wsdate = &ParseDate($startdate);
	my $today = &ParseDate($refdate);
	my $diff = &DateCalc($today,$wsdate);
# This is a workaround for a change in Date::Manip versionn 6
	$diff = ParseDateDelta($diff,'semi');
	my $togo = &Delta_Format($diff,1,"%wt");
#
# Now round $togo down to the nearest week
#
	my $itogo = int($togo);
# 
# Calculate due date
#
my %dues = (
	6 => '-3 weeks', 
	5 => '-3 weeks', 
	4 => '-2 weeks',
	3 => '-2 weeks', 
	2 => '-9 days', 
	1 => '-1 week', 
	);
	my $defdue = ($itogo > 6) ? &DateCalc("-3 weeks",$wsdate) : $refdate;
	my $duedate = ($dues{$itogo} eq '') ? $defdue : &DateCalc($dues{$itogo},$wsdate);
# Return the duedate as a formatted string
	UnixDate($duedate,$format);
	}

my @months = (qw{Bogus January February March April May June July August September October November December});
#
# Date formatting routine
#
sub format_date
	{
	my $datestr = shift;
	my ($yyyy,$mm,$dd) = split_date($datestr);	# Grab into variables
	$mm =~ s/^0//;
	$dd =~ s/^0//;
	$datestr = "$dd/$mm/$yyyy" ;
	$datestr = "$mm/$dd/$yyyy" if ($config{us_date_format});
#	$datestr = "$dd $months[$mm] $yyyy" ;
#	$datestr = "$months[$mm] $dd, $yyyy" if ($config{us_date_format});
	$datestr;
	}
#
# This is annoying, Interbase and MYSQL format dates differently when returned from the DB
# 
sub split_date
	{
	my $indate = shift;
	my ($yyyy,$mm,$dd) = (2000,1,1);
	if ($indate =~ /^(\d+)\.(\d+)\.(\d+)/)		# Allow for EU date format.
		{
		($yyyy,$mm,$dd) = ($1,$2,$3);	# Grab into variables
		}
	if ($indate =~ /^(\d+)\-(\d+)\-(\d+)/)
		{
		($yyyy,$mm,$dd) = ($1,$2,$3);	# Grab into variables
		}
	if ($indate =~ /^(\d+)\/(\d+)\/(\d+)/)
		{
		($yyyy,$mm,$dd) = ($3,$1,$2);	# Grab into variables
		$yyyy =~ s/^0//;
		$yyyy += ($yyyy < 50) ? 2000 : 1900 if ($yyyy < 2000);
		}
	($yyyy,$mm,$dd);
	}
#
# This subroutine brings in specific things for the PWIKit from the database
#
sub get_custom_new
	{
	my %things = (
					admin => {
								sql => 'SELECT ADMIN_KV,ADMIN_NAME AS ADMINNAME,ADMIN_EMAIL AS ADMINEMAIL FROM PWI_ADMIN WHERE ADMIN_KV=?',
							},
					exec => {
								sql => 'SELECT EXEC_KV,EXEC_NAME AS EXECNAME,EXEC_EMAIL AS EXECEMAIL FROM PWI_EXEC WHERE EXEC_KV=?',
							},
					batchno => {
								sql => 'SELECT BAT_KV,BAT_NAME AS BATCHNAME FROM PWI_BATCH WHERE BAT_KV=?',
							},
					workshop => {
								sql => 'SELECT WS_KV,WS_ID,WS_DUEDATE AS DUEDATE,WS_STARTDATE AS STARTDATE,LOC_ID AS LOCATIONCODE,LOC_DISPLAY AS LOCATION,"818-380-1177 x225" AS ADMINPHONE,"818-981-2717" AS RETURNFAX FROM PWI_WORKSHOP,PWI_LOCATION WHERE WS_KV=? and WS_LOCREF=LOC_KV',
							},
					);
	foreach my $thing (keys %things)
		{
		my $param = $q->param($thing);
		&db_do($things{$thing}{sql},$param);
		my $href = $th->fetchrow_hashref;
		die "Could not find $thing [$param] in database (using sql $things{$thing}{sql})\n" if (!$href);
		foreach my $key (keys %{$href})
			{
			$ufields{lc($key)} = $$href{$key} if ($ufields{lc($key)} eq '');	# Only fill them in if not already there
			}
		$th->finish;
		}
#
# Now we do some stuff with the dates to make them prettier
#
	$ufields{workshopdate} = format_wsdate($ufields{startdate});
	$ufields{startdate} = format_date($ufields{startdate});
#	$ufields{duedate} = format_date($ufields{duedate});
# Calculate duedate as well, being 3 weeks prior.
#	my $duedate=&DateCalc(&ParseDate($ufields{startdate}),"-3w");
#	$ufields{duedate} = UnixDate($duedate,"%m/%d/20%y");
# This is the new way to do this:
	$ufields{duedate} = calc_duedate($datestr,'today',"%m/%d/20%y");
# Calculate invitedate as well, being 6 weeks prior.
	my $invitedate=&DateCalc(&ParseDate($ufields{startdate}),"-6w");
	$ufields{invitedate} = UnixDate($invitedate,"%m/%d/20%y");
	}

sub format_wsdate
	{
	my $wsdate = shift;
	my $wsfmt = '';
	my ($yyyy,$mm,$dd) = split_date($wsdate);	# Grab into variables
	$mm =~ s/^0//;
	$dd =~ s/^0//;
	my $yr = $yyyy - 1900;			# Get ready for conversion to epoch
	my $mon = $mm - 1;
	my $day = $dd;
	my $startws = timelocal(0,1,1,$day,$mon,$yr);
	my $endws = $startws + (2*24*60*60); # Add 2 days to get into the third day of the workshop
	my ($esec,$emin,$ehour,$emday,$emon,$eyear,$ewday,$eyday,$eisdst) = localtime($endws);
	my $eyyyy = $eyear + 1900;
	$wsfmt = qq{$months[$mm] $dd-$emday, $yyyy};
	my $emm = $emon+1;
	$wsfmt = qq{$months[$mm] $dd-$months[$emm] $emday, $yyyy} if ($mm != $emm);
	$wsfmt = qq{$months[$mm] $dd-$months[$emm] $emday, $yyyy/$eyyyy} if (($mm != $emm) && ($yyyy ne $eyyyy));
	$wsfmt;
	}
	
sub custom_update_status()
	{
	my $sql = "insert into $config{status} (uid,pwd,batchno,fullname) values (?,?,?,?)";
	my $th = &db_do($sql,$ufields{id},$ufields{password},$ufields{batchno},$ufields{fullname});
	$th->finish;
	
	my %cnt = ();
	$cnt{DUEDATE} = $ufields{duedate};
#	$cnt{DUEDATE_D} = $ufields{duedate};
#	my $datestr = $cnt{DUEDATE_D};
#	$datestr =~ s/\/20(\d\d)/\/$1/;
#	print "Parsing duedate: $datestr\n";
	$cnt{DUEDATE_D} = UnixDate(ParseDate($ufields{duedate}),"20%y-%m-%d");
#	$cnt{DUEDATE} = $cnt{DUEDATE_D};
	$cnt{WSDATE_D} = $ufields{startdate};
#	$datestr = $cnt{WSDATE_D};
#	$datestr =~ s/\/20(\d\d)/\/$1/;
#	print "Parsing wsdate: $datestr\n";
	$cnt{WSDATE_D} = UnixDate(ParseDate($ufields{startdate}),"20%y-%m-%d");
#	$cnt{WSDATE} = $cnt{WSDATE_D};
	$cnt{EXECNAME} = $ufields{execname};
	$cnt{WSID} = $ufields{ws_id};
	$cnt{LOCNAME} = $ufields{location};
	$cnt{LOCID} = $ufields{locationcode};
	$cnt{CMS_STATUS} = $ufields{cms_status};			# This is essential for the invite process !!!
	&db_save_extras_uid($config{status},$ufields{id},\%cnt);
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
# This is the new way to do this:
	$ufields{duedate} = calc_duedate($ufields{startdate},'today',"%m/%d/20%y");
	$ufields{workshopdate} = format_wsdate($ufields{startdate});
#	print "duedate=$ufields{duedate}\n";
	}

#
1;
