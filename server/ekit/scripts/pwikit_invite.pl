#!/usr/bin/perl
# $Id: pwikit_invite.pl,v 1.16 2007-09-26 16:24:07 triton Exp $
#
# Cron script to automatically send out reminder emails to:
# Participants
# Bosses
# KP's
#
our $simulate_frames = 0;
our %config;
our %temp;
our $dbt;

use Getopt::Long;							#perl2exe
use File::Path;								#perl2exe
use File::Basename;							#perl2exe
use Data::Dumper;							#perl2exe

use TPerl::TritonConfig;    				#perl2exe
use TPerl::Error;							#perl2exe
use TPerl::Engine;							#perl2exe
use TPerl::EScheme;							#perl2exe

require 'TPerl/qt-libdb.pl';				#perl2exe
require 'TPerl/360-lib.pl';					#perl2exe
$simulate_frames = 0;
require 'TPerl/pwikit_cfg.pl';				#perl2exe

use strict;
my $args = join(" ",@ARGV);

sub die_usage
	{
	my $errmsg = shift;
	print <<USAGE;
$errmsg
Usage: $0 [-version] [-debug] [-help] [-trace] [-noaction] [-only=ID] 
  -help       Display help
  -version    Display version no
  -trace      Show trace output 
  -debug      Show debug output
  -noaction   Don't action anything, just go through the motions
  -only=ID    Do it only for the supplied participant ID
  -welcome    Send welcome email (6weeks 4days prior [+6w +4d])
  -invite     Send invitation email (6weeks 3days prior [+6w +3d])
  -post       Send post workshop email (4weeks after [-4w])
  -delta=      Override default delta settings (eg -delta="+4w")
USAGE
	exit 0;
	}

our %ufields;
our %done;
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_n,$opt_only,
		$opt_invite,$opt_welcome,$opt_post,
		$opt_delta,
		);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			noaction => \$opt_n,
			'only=s' => \$opt_only,
			invite => \$opt_invite,
			welcome => \$opt_welcome,
			post => \$opt_post,
			'delta=s' => \$opt_delta,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwikit_invite.pl,v 1.16 2007-09-26 16:24:07 triton Exp $'."\n";
	exit 0;
	}
die_usage("Please specify at least one of -welcome -invite -post") if (! ($opt_invite||$opt_welcome||$opt_post));
my %files = ();
our $qt_root;
&get_root;
&db_conn;
my $data_dir = "$qt_root/MAP001/web";

$dbt=1 if ($opt_d);
my %cnt = ();

# -------------------------------------------------------
#
# Mainline starts here
#
# -------------------------------------------------------
my $myname = $0;
my $matrix;
$myname =~ s/\.\w+$//;
my $logfile = "$qt_root/log/$myname.log";
mkpath (dirname($logfile),1);

my $err = new TPerl::Error ();
my $en = new TPerl::Engine;
my $es = new TPerl::EScheme;

my $fh;
if ($fh = new FileHandle (">> $logfile"))
	{
	$err->fh ([$fh,\*STDOUT]);
	}
else
	{
	$err->E("Could not write to $logfile")
	}
$err->I(sprintf ("Starting $0 at %s with cmd=$0 $args",scalar(localtime)));
#
# Locate the people who are scheduled to attend
#
if ($opt_invite)
	{
# 
# Send invites for people who are scheduled within 6 weeks 3 days, or have a specific invite date
#
	my $delta = $opt_delta || "+6w +3d";
	my $today = &ParseDate('today');
	my $todayplus6 = &DateCalc($today,$delta);
	my @params = (UnixDate($today,"20%y-%m-%d"),UnixDate($todayplus6,"20%y-%m-%d"));
	my $sql = qq{select * from PWI_STATUS WHERE CMS_STATUS='S' and WSDATE_D>=? and WSDATE_D<?};
	if ($opt_only ne '')
		{
		$sql .= qq{ and UID=? };
		push @params,$opt_only;
		}
	$sql .= qq{ ORDER BY WSDATE_D};
	my $p = join(",",@params);
	print qq{SQL CMD: $sql (params=$p)\n} if ($opt_t);
	my $th = &db_do($sql,@params);
	$matrix = $th->fetchall_hashref(['UID']);
	$th->finish();
	foreach my $key (sort sortbyws keys %{$matrix})
		{
		scan_invites($matrix->{$key});
		}
	undef $matrix;
	}
if ($opt_welcome)
	{
# Send welcome messages when people are first created in the system,
# but not after 6 weeks, 4 days prior
	my $delta = $opt_delta || "+6w +4d";
	my $date = &ParseDate('today');
	$date = &DateCalc($date,$delta);
	my @params = (UnixDate($date,"20%y-%m-%d"));
	my $sql = qq{select * from PWI_STATUS WHERE CMS_STATUS='S' and WSDATE_D>=?};
	if ($opt_only ne '')
		{
		$sql .= qq{ and UID=? };
		push @params,$opt_only;
		}
	$sql .= qq{ ORDER BY WSDATE_D};
	my $p = join(",",@params);
	print qq{SQL CMD: $sql (params=$p)\n} if ($opt_t);
	my $th = &db_do($sql,@params);
	$matrix = $th->fetchall_hashref(['UID']);
	$th->finish();
	foreach my $key (sort sortbyws keys %{$matrix})
		{
		scan_welcomes($matrix->{$key});
		}
	undef $matrix;
	}
if ($opt_post)
	{
# Send the post workshop invitation email when status changes to 'Complete' 
# but not after 1 month has elapsed
	my $delta = $opt_delta || "-4w";
	my $date = &ParseDate('today');
	$date = &DateCalc($date,$delta);
	my @params = (UnixDate($date,"20%y-%m-%d"));
	my $sql = qq{select * from PWI_STATUS WHERE CMS_STATUS='C' and 1=2 and WSDATE_D>=?};
	if ($opt_only ne '')
		{
		$sql .= qq{ and UID=? };
		push @params,$opt_only;
		}
	$sql .= qq{ ORDER BY WSDATE_D};
	my $p = join(",",@params);
	print qq{SQL CMD: $sql (params=$p)\n} if ($opt_t);
	my $th = &db_do($sql,@params);
	$matrix = $th->fetchall_hashref(['UID']);
	$th->finish();
	foreach my $key (sort sortbyws keys %{$matrix})
		{
		scan_posts($matrix->{$key});
		}
	undef $matrix;
	}
	
&db_disc;
$err->I(sprintf ("Completed $0 at %s",scalar(localtime)));

#
# Subroutines...
#	
our ($u,$href,$ufile);
#----------------------------------------------------------------------
# Invitations
sub scan_invites
	{
	$href = shift;
# Check to see if a scheme already exists for this dude
# See how long until the workshop, so we can choose the right scheme:
	my $today = &ParseDate('today');
	my $wsdate = &ParseDate($href->{WSDATE_D});
	my $delta = DateCalc($today,$wsdate);
	$delta = ParseDateDelta($delta,'semi');
	my ($deltaweeks) = Delta_Format($delta,1,('%wt'));
	my $num = '';
	if ($deltaweeks >= 3)
		{$num = '';}
	else 
		{$num = $deltaweeks + 1;}
	$ufile = qq{$qt_root/$config{participant}/web/u$href->{PWD}.pl};
	$u = $en->u_read($ufile);
	try2send_invite('',$$u{email},'',$num);
	for (my $i=1;$i<$config{nboss};$i++)
		{
		try2send_invite('boss',$$u{"bossemail$i"},$i);
		}
#	for (my $i=1;$i<$config{npeer};$i++)
#		{
#		try2send_invite('peer',$$u{"peeremail$i"},$i);
#		}
	undef $u;
	}

sub try2send_invite
	{
	my ($role,$email,$ix,$num) = @_;
	my $msg = $role || 'participant';
	my $scheme = "$msg";
	my $pwd = $$u{"${role}password$ix"};
	next if (!$pwd);
	if (!$$u{"${role}email$ix"})
		{
		$err->E(qq{** $$href{UID} No $msg$ix email for $$u{"${role}fullname$ix"} $$u{batchname} $$u{execname}/$$u{adminname}});
		}
	else
		{
		my $em_SID = $config{$msg};
# First email should be queued, 2nd or more is sent immediately
		my $action = ($opt_n) ? "Would have sent" : "Send";
#		$err->I(qq{$$href{UID} $action [$scheme] to $msg$ix $$u{"${role}fullname$ix"} [$$u{"${role}email$ix"}] $$u{batchname}});
		my $manual = 0;
		my ($cc,$fmt);
		my ($stat,$emsg) = smart_send($em_SID,${scheme},$$u{id},$pwd, $$u{"${role}email$ix"},$cc,$fmt,$$u{startdate},$manual) if (!$opt_n);
		if ($emsg ne '')
			{
			$emsg = qq{$$href{UID} ($msg$ix) $$u{"${role}fullname$ix"} <$$u{"${role}email$ix"}> $emsg};
			if ($stat)
				{
				$err->I($emsg);
				if ($config{emails}{$msg}{notify} && ($$u{execemail} ne ''))
					{
					my ($exstat,$exmsg) = &queue_invite($em_SID, $config{emails}{$msg}{notify}, $$u{id}, $pwd, $$u{execemail},'','') ;
					if ($exstat)
						{$err->I("Sending $config{emails}{$msg}{notify} to exec ($$u{execname}): $exmsg");}
					else
						{$err->E("Failed to send $config{emails}{$msg}{notify} to exec ($$u{execname}): $exmsg");}
					}
				}
			else
				{$err->W($emsg);}
			}
		}
	}
#----------------------------------------------------------------------
# Welcome emails
sub scan_welcomes
	{
	$href = shift;
	$ufile = qq{$qt_root/$config{welcome}/web/u$href->{PWD}.pl};
	$u = $en->u_read($ufile);
# Only send welcome email to participant
	try2send_1('welcome',$$u{email});
	undef $u;
	}

sub try2send_1
	{
	my ($msg,$email) = @_;
	my $pwd = $$u{password};
	next if (!$pwd);
	if (!$$u{email})
		{
		$err->W(qq{** $$href{UID} No email address for $$u{fullname} $$u{batchname} $$u{execname}/$$u{adminname}});
		}
	else
		{
		my $em_SID = $config{$msg};
# Have we sent an email already ?
		print qq{Searching for $msg $pwd $$u{fullname} [$$u{email}]\n} if ($opt_t);
		my @schemes = @{$es->search_by_pwd(pwd => $pwd, SID => $em_SID, scheme_name => $msg)};
		print Dumper @schemes if ($opt_d);
		if (@schemes)
			{
			print qq{$msg EScheme for $pwd exists already\n} if ($opt_t);
			}
		else
			{
# First email should be queued, 2nd or more is sent immediately
			print qq{Making new $msg EScheme for $pwd\n} if ($opt_t);
			my $action = ($opt_n) ? "Would have sent" : "Send";
			$err->I(qq{$$href{UID} $action [$msg] to $$u{fullname} [$$u{email}] $$u{batchname}});
			my ($stat,$emsg) = smart_send($em_SID,${msg},$$u{id},$pwd, $$u{email},'','',$$u{startdate},0) if (!$opt_n);
			$err->E($emsg) if ($emsg ne '');
			}
		}
	}

#----------------------------------------------------------------------
# Post Workshop email
# This kind of relies on pwi_cms_par_import detected when a participant 
# has moved to 'Completed', and automatically creating an entry in MAP026
# for the post workshop survey.
sub scan_posts
	{
	$href = shift;
	$ufile = qq{$qt_root/$config{post}/web/u$href->{PWD}.pl};
# Be defensive in case it's not present (although it should be)
	if (-f $ufile)
		{
		$u = $en->u_read($ufile);
# Only send post workshop email to participant
# MJC 01-14-2014: disable post workshop survey notification
		#try2send_1('post',$$u{email});
		undef $u;
		}
	}


#----------------------------------------------------------------------
sub sortbyws
	{
	$matrix->{$b}{WSDATE_D} <=> $matrix->{$a}{WSDATE_D};
	}

# Leave me be please:
1;
