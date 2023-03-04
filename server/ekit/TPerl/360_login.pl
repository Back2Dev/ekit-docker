#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_login.pl,v 2.27 2012-11-27 01:45:20 triton Exp $
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
use Date::Parse;
use Time::Piece;
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
my $tick = qq{<img src="/pwikit/tick.gif">};
my $cross = qq{<font color="red" size="+1">X</font>};
my $question = qq{<font color="RED" size="+1">?</font>};
my $spinwheel = qq{<IMG src="/pix/ajax-loader2.gif">};

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
	<TITLE>$config{title} login page </TITLE>
	<META NAME="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King (213) 627 7100">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2002">
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
			Welcome to the $config{title} login page. 
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
else	# No problems - continue from here
	{
	if ($admin)
		{
		&add2hdr(<<SCRIPT);
<script type="text/javascript" src="/pwikit/ajaxget.js"></script>
<SCRIPT LANGUAGE="JavaScript">
var fixup = new Array;
fixup["Approved"] = '$tick';
fixup["Rejected"] = '$cross';
function log(logmsg)
	{
//	document.getElementById('status').innerHTML = document.getElementById('status').innerHTML + "<BR>\\n" + logmsg;
	}
function logDebug(logmsg)
	{
//	document.getElementById('status').innerHTML = document.getElementById('status').innerHTML + "<BR>\\n" + logmsg;
	}

function view(seq)
	{
	alert("Viewing "+seq);
//	document.getElementById(pwd).innerHTML = '$spinwheel';
//	ajaxGet('/cgi-mr/pwikit_yesno.pl/MAP010/approve/'+pwd);
	}

function approve(pwd,uid)
	{
//	alert("Approving "+pwd);
	document.getElementById(pwd).innerHTML = '$spinwheel';
	ajaxGet('/cgi-mr/pwikit_yesno.pl/MAP010/approve/'+pwd+'/'+uid);
	}
function reject(pwd,uid)
	{
//	alert("Rejecting "+pwd);
	document.getElementById(pwd).innerHTML = '$spinwheel';
	ajaxGet('/cgi-mr/pwikit_yesno.pl/MAP010/reject/'+pwd+'/'+uid);
	}
// Showerr is just a call back function, called when an error is detected
function showerr(msg)
	{
	document.getElementById('status').innerHTML = msg;
	}
// Showme is just a call back function, called when the data has been retrieved
function showme(resp)
	{
//	alert("In showme");
	var r = resp;
   	r = r.replace(/\\r/g,'');		// Trim out DOS CR
   	r = r.replace(/\\n\$/g,'');		// Trim blank trailing line
    var lines = r.split(/\\n/);
    for (i=0;i<lines.length;i++)
    	{
//    	alert("line ["+i+"] = "+lines[i]); 
   		if (lines[i] == '')
    		continue;
        if(lines[i].indexOf('=') != -1) 
        	{
//       		alert ("Line "+i+' = ['+lines[i]+']');
            var bits = lines[i].split('=');
            if (document.getElementById(bits[0]))
            	{
	            document.getElementById(bits[0]).innerHTML = bits[1];
	            if (fixup[bits[1]]) 
		            document.getElementById(bits[0]).innerHTML = fixup[bits[1]];
		        }
        	}
	    }
	}

function confirm_sum_item(partname,params)
	{
	if (window.confirm('Summarize information collected so far and give to '+partname+' ?'))
		{
		document.location.href = '/cgi-adm/$config{case}_sum_item.pl'+params;
		}
	}
function confirm_re_sum_item(partname,params)
	{
	if (window.confirm('Re-Summarize information collected so far ?'))
		{
		document.location.href = '/cgi-adm/$config{case}_sum_item.pl'+params;
		}
	}
function confirm_del_item(partname,params)
	{
	if (window.confirm('Delete all data for '+partname+' ? (This cannot be undone)'))
		{
		document.location.href = '/cgi-adm/$config{case}_del_item.pl'+params;
		}
	}
function confirm_reopen(partname,params)
	{
	if (window.confirm('Re-open '+partname+' ? '))
		{
		document.location.href = '/cgi-adm/$config{case}_reopen_item.pl'+params;
		}
	}
function confirm_reset(partname,params)
	{
	if (window.confirm('Reset '+partname+' ? '))
		{
		document.location.href = '/cgi-adm/$config{case}_reset_item.pl'+params;
		}
	}
function confirm_close(partname,params)
	{
	if (window.confirm('Close off '+partname+' ? '))
		{
		document.location.href = '/cgi-adm/$config{case}_close_item.pl'+params;
		}
	}
</SCRIPT>
SCRIPT
		}
	my $actions = '&nbsp;';	# Default to no actions available
	$rolename = 'Self';
	my $SID = $config{participant};
    $rolename = 'Boss' if (-f "$qt_root/$config{boss}/web/u$pwd.pl");
    $rolename = 'Peer' if (-f "$qt_root/$config{peer}/web/u$pwd.pl");
    $rolename = 'Boss' if ($input{rolename} =~ /reviewer/i);
	$ufile = "$qt_root/$SID/web/u$pwd.pl";
	if (-f "$qt_root/$config{peer}/web/u$pwd.pl")	# Try peer
		{
		$rolename = 'Peer';
		$SID = $config{peer};
		$ufile = "$qt_root/$SID/web/u$pwd.pl";
		}
	if (-f "$qt_root/$config{boss}/web/u$pwd.pl")	# Try boss
		{
		$rolename = 'Boss';
		$SID = $config{boss};
		$ufile = "$qt_root/$SID/web/u$pwd.pl";
		}
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
	#	 The matching brace for this is near the end of file
		{
		my_require ($ufile,0);
#	&add2body("who=$ufields{'fullname'} <BR>");
		if (!$admin)		# Only log it if it's bona-fide (ie not an admin login)
			{
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
			}
		my (%firsttime);
#
# Now check to see if this is the first sign on:
#
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
			$firsttime{$rolename}++;
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
#           add2body(qq{send_invite($config{master}, 'execstart', $ufields{id}, $ufields{password}, $ufields{execemail})});
            $ufields{part_email} = $ufields{email};  # Get around a local variable problem
            &queue_invite($config{boss}, 'execboss', $ufields{id}, $ufields{password}, $ufields{execemail});

            &save_ufile($config{boss},$ufields{password});
			$firsttime{$rolename}++;
            }
#
# If this is the first time login, we send them to the instructions page 
#

		if ($firsttime{$rolename}) 
			{
			my $role = lc($rolename);
			my $url = qq{/cgi-mr/serve.pl/${role}_explain?survey_id=pwikit&password=$ufields{password}&id=$ufields{id}};
			&add2hdr(qq{<META HTTP-EQUIV="refresh" CONTENT="0;URL=$url" />});
			&add2body(qq{Moved to here: <a href="$url">$url</a>\n});
			}
		else
			{
			my $please = qq{Please complete and submit the following forms.  Begin at the top of the list};
#			$please .= "1" if ($rolename eq 'Boss');
#			$please .= ".";
			my $aboutname = $ufields{'aboutname'};
			$welcome = ($admin) ? "$config{title} Status for Key No. $uid: $aboutname "
						: "Welcome to the $config{title} for $aboutname ";
			$actions .= qq{Actions&nbsp;} if ($admin);
			my $document = ($config{doc_merge}) ? '&nbsp;Document&nbsp;' : '&nbsp;';
			&add2body(<<BODY);
	<FORM name="q" method=POST ACTION="${virtual_cgi_bin}$config{case}_login.$extension"
			ENCTYPE="x-www-form-encoded"
			>
	<INPUT TYPE="HIDDEN" VALUE="$uid" NAME="id">
	<INPUT TYPE="HIDDEN" VALUE="$pwd" NAME="password">
	<TABLE BORDER="0" CELLPADDING="3" CELLSPACING="0" width="100%" class="mytable">
		<TR>
			<TD class="title" colspan="5">
			$welcome
			<BR><br>$please
			</TD>
		</TR>
		<TR>
			<TH class="heading">
			Form
			</TH>
			<TH class="heading">
			&nbsp;Responsibility&nbsp;
			</TH>
			<TH class="heading">
			&nbsp;Status&nbsp;
			</TH>
			<TH class="heading">
			$document
			</TH>
			<TH class="heading">
			$actions
			</TH>
		</TR>
BODY
#
# Query the db and display it all
#	
			my $sql = "SELECT CMS_STATUS FROM $config{status} WHERE UID='$uid' ";
			my $th = &db_do($sql);
			my $hr = $th->fetchrow_hashref();
			my $cstatus = $$hr{CMS_STATUS};
			$role_select = " AND $config{index}.PWD='$pwd' " if (!$admin);
			my $sql = "SELECT SID, UID, PWD, FULLNAME, ROLENAME FROM $config{index} WHERE UID='$uid' AND CASENAME='$config{case}' $role_select ORDER BY ROLENAME DESC,SORT_ORDER,SID";
#			$sql = "SELECT $config{index}.SID, $config{index}.UID, $config{index}.PWD, $config{index}.FULLNAME, $config{index}.ROLENAME, PWI_STATUS.WSDATE FROM $config{index} JOIN PWI_STATUS ON PWI_STATUS.UID = $config{index}.UID WHERE $config{index}.UID='$uid' AND $config{index}.CASENAME='$config{case}' $role_select ORDER BY $config{index}.ROLENAME DESC,$config{index}.SORT_ORDER,$config{index}.SID";
			$sql = "SELECT $config{index}.SID, $config{index}.UID, $config{index}.PWD, $config{index}.FULLNAME, $config{index}.ROLENAME, PWI_STATUS.WSDATE FROM $config{index} JOIN PWI_STATUS ON PWI_STATUS.UID = $config{index}.UID WHERE $config{index}.UID='$uid' AND $config{index}.CASENAME='$config{case}' AND SID != 'MAP007' $role_select ORDER BY $config{index}.ROLENAME DESC,$config{index}.SORT_ORDER,$config{index}.SID";
			#&add2body(qq{$sql});
			$th = &db_do($sql);
			$lastRole = 'Self';
			my $loopcnt = 0;
			my $sum_offer = 0;
			while (@row = $th->fetchrow_array())
				{
				($survey_id,$theid,$thepwd,$responsible,$role,$wsdate) = @row;
				next if(($survey_id eq $config{post}) && ($config{case} eq 'pwikit') && ($cstatus eq 'S'));

				open my $skiphandle, '<', '/home/vhosts/ekit/htekit/surveyshutdown';
				chomp(my @lines = <$skiphandle>);
				close $skiphandle;

				$found = 0;
				$time = str2time($wsdate);


				if ($survey_id eq "MAP007")
				{
					&add2body(qq{<p>Workshop Date: $wsdate</p>});
				}

				foreach (@lines) {
					@values = split(/:/,$_);
					if (@values[0] eq $survey_id)
					{

						$time2 = str2time(@values[1]);
						if ($time2 lt $time)
						{

							$found = 1;
						}
					}
				}

				next if($found == 1);
				$resp{'survey_id'} = $survey_id;

				

				my $ur = &db_get_user_data($survey_id,$theid,$thepwd);
				my $stat = $$ur{STAT};
				if (($role ne $lastRole) && ($admin))
					{
		#			$config{can_summarize} = 0 if ($role eq 'Reviewer');
					$reviewer = 1 if ($role eq 'Reviewer');
					my $rh = $role_heading{lc($role)};
					$cspan = 4;
					$cspan++ if ($admin);
					&add2body(qq{<TR><TD COLSPAN="$cspan" class="heading">$rh</TD></TR>}) 
					}
				if (($role eq $rolename) || ($admin))
					{
					if ($stat == 4)
						{
						$status = '<B><FONT COLOR="GREEN">Done</FONT></B>';
						}
					elsif ($stat == 0)
						{
						$status = '<FONT COLOR="RED">Ready</FONT>';
						}
					elsif ($stat == 3)
						{
						$status = '<FONT COLOR="BLUE">Started</FONT>';
						}
					my $seq = $$ur{SEQ};
					$document = '&nbsp;';
					$docfile = "$qt_root/$resp{'survey_id'}/doc/$seq.rtf";
					if (-f $docfile)
						{	
			#			if ($role eq 'Self')
						if (($role eq $rolename) || ($admin))
							{
							$mapq = $survey_id;
							$document = qq{<A HREF="${virtual_cgi_bin}getdoc.pl/${mapq}-$theid-$role.doc};
							$document .= qq{?sid=$survey_id&id=$theid&token=$thepwd" target="$survey_id">};
							$document .= qq{<IMG BORDER="0" SRC="/$config{case}/document.gif"> Download</A>};
							}
			#			else
			#				{
			#				$document = "<IMG BORDER=\"0\" SRC=\"/$config{case}/document.gif\">";
			#				}
						}
					$name = $config{snames}{$survey_id};
					$name =~ s/\t/. /;
			#		if (($stat != 4) && ($role eq 'Self'))
					if (1)#($stat != 4) && ($role eq $rolename))
						{
						my $target = "";
						my $reopen = 1;
						if (grep(/$survey_id/,@{$config{externals}}))
							{
							if ($config{externals_once_only})
								{
								$reopen = 0;
								}
							if ($config{externals_new_window})
								{
								$target = qq{TARGET="${survey_id}_ext"}; 
								}
							}
						if ($seq > 0)
							{
							if ($reopen)
								{
								$name = qq{<A HREF="${virtual_cgi_bin}${go}.${extension}?survey_id=$survey_id&seqno=$seq&q_label=first" $target>$name</A>} ;
								}
							else
								{
								if ($stat != 4)
									{
									$name = qq{<A HREF="${virtual_cgi_bin}${go}.${extension}?survey_id=$survey_id&seqno=$seq&q_label=first" $target>$name</A>} ;
									}
								}
							}
						else
							{
							$name = qq{<A HREF="${virtual_cgi_bin}tokendb.${extension}?survey_id=$survey_id\&id=$theid\&token=$thepwd" $target>$name</A>} ;
							}
						}
# 
# This part is an extra for the approval of Q10
#
				my $extra;
				my %astat = ( 
				0 => qq{ $question <button onclick="approve('$$ur{PWD}',$$ur{UID});return false;">Yes</button> 
									<button onclick="reject('$$ur{PWD}',$$ur{UID});return false;">No</button>
<!--									<button onclick="view('$$ur{SEQ}');return false;">View</button> -->
									},
				1 => $tick,
				2 => $cross,
				);
				if (($$ur{STAT} == 4) || ($$ur{STAT} == 3) )
					{
					$extra .= qq{<span id="$$ur{PWD}"> $astat{$$ur{APPROVED}} </span>} if ($admin);
					}
				$name .= " $extra ";
				my $act_delete = "";
				my $act_summarize = "";
				my $dname = $config{snames}{$survey_id};
				$dname =~ s/\t/. /g;
				my $dname2 = $dname;
				$dname2 =~ s/'/\\'/g;
#
# Determine which actions are available here:
#
				$actions = qq{&nbsp;};
				my $who = $responsible;
				$who =~ s/'/\\'/g;
				if ($config{can_summarize} && ($role eq 'Boss') && ($sum_offer == 0))
					{
					if ($reviewer)
						{
						$sum_offer++;
						$act_summarize = <<SUMMARIZE ;
									&nbsp;<IMG SRC="/$config{case}/sum.gif" alt="Re-Summarize information " 
										onclick="confirm_re_sum_item('$responsible for review','?survey_id=$survey_id&id=$theid&password=$thepwd')">
SUMMARIZE
						}
					else
						{
						$sum_offer++;
						$act_summarize = <<SUMMARIZE ;
									&nbsp;<IMG SRC="/$config{case}/sum.gif" alt="Summarize information and give to $responsible for review" 
										onclick="confirm_sum_item('$responsible for review','?survey_id=$survey_id&id=$theid&password=$thepwd')">
SUMMARIZE
						}
					}
#
				$act_delete = <<DELETE_ME if (($stat == 0) && ($role_heading{lc($role)} ne ''));
								&nbsp;<IMG SRC="/$config{case}/trash.gif" alt="Delete [$dname] for $responsible" 
									onclick="confirm_del_item('[$dname2] for $who','?survey_id=$survey_id&id=$theid&password=$thepwd')">
DELETE_ME
				my $act_reset = "";
				$act_reset = <<RESET_ME if (($stat == 3));
								&nbsp;<IMG SRC="/$config{case}/clear.gif" alt="Reset [$dname] for $responsible" 
									onclick="confirm_reset('[$dname2] for $who','?survey_id=$survey_id&id=$theid&password=$thepwd')">
RESET_ME
				my $act_reopen = "";
		#	$act_reopen = qq{<A HREF="${virtual_cgi_bin}$config{case}_reopen.$extension?survey_id=$survey_id&pwd=$thepwd">Re-open</A>} if ($stat == 4);
				$act_reopen = <<REOPEN_ME if (($stat == 4));
								&nbsp;<IMG SRC="/$config{case}/reopen.gif" alt="Re-open [$dname] for $responsible" 
									onclick="confirm_reopen('[$dname2] for $who','?survey_id=$survey_id&id=$theid&password=$thepwd')">
REOPEN_ME
				my $act_close = "";
		#	$act_close = qq{<A HREF="${virtual_cgi_bin}$config{case}_close.$extension?survey_id=$survey_id&pwd=$thepwd">Close</A>} if ($stat == 4);
				$act_close = <<CLOSE_ME if (($stat == 3));
								&nbsp;<IMG SRC="/$config{case}/close.gif" alt="Close [$dname] for $responsible" 
									onclick="confirm_close('[$dname2] for $who','?survey_id=$survey_id&id=$theid&password=$thepwd')">
CLOSE_ME
				$actions = qq{$act_summarize $act_delete $act_reset $act_reopen $act_close} if ($admin);
				$actions = '&nbsp;' if !($actions =~ /\S/);
#
# Do normal stuff now
#
				$responsible = '&nbsp;' if ! $responsible;
				$actions = '&nbsp' if ! $actions;
				&add2body(<<ROW);
		<TR>
			<TD class="options">
			$name
			</TD>
			<TD class="options" ALIGN="CENTER">
			$responsible
			</TD>
			<TD class="options" ALIGN="CENTER">
			$status
			</TD>
			<TD class="options" ALIGN="CENTER">
			$document
			</TD>
			<TD class="options">
			$actions
			</TD>
		</TR>
ROW
						}
				$lastRole = $role;
				$loopcnt++;
				if ($loopcnt > 100)
					{
					&add2body('Too many forms in list (>100) - aborting\n');
					last;
					}
				}
			$th->finish;
			&add2body(qq{\n </TABLE>\n <span id="status" class="error"></SPAn>\n});
			}
		}
	}
#
# OK, we're done now, so output the standard footer :-
#
&db_disc;
&qt_Footer;
1;
