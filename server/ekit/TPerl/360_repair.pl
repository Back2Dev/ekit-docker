#!/usr/bin/perl
# $Id: 360_repair.pl,v 1.3 2008-06-11 08:05:12 triton Exp $
#
# Look for discrepancies in ufiles/database etc - call by XXX_repair.pl
#
our ($survey_id,%resp,%input,$array_sep,%email_action,$do_cookies);
our ($form,$data_dir,$qt_droot,$demo);
our ($ufile,$qt_root,%ufields,$external,$use_tnum,$relative_root,$script);
our ($th,@ufiles, %config,$dbt);

use strict;
use Getopt::Long;							#perl2exe
use Term::ReadKey;		  					#perl2exe
use File::Copy;		  						#perl2exe
use File::Path;	  							#perl2exe
use File::Basename;  						#perl2exe
use TPerl::Error;		  					#perl2exe

#$dbt=1;
sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if $msg ne '';
	print <<END;
Usage: $0 [-help] [-version] [-trace] [-age=nn] [-confirm] [-noaction] [-ufiles] [-only=UID] [-live]
	-help Display help
	-version Display version no
	-trace Trace mode
	-noaction Don't do anything
	-confirm Confirm each action
	-age=nn Don't process any ufile older than nn days
	-ufiles Scan ufiles
	-only=UID only deal with a specific ID
	-live Restricts search to entries in  {\$JOB}_CASES table
END
	exit(0);
	}
my($opt_d,$opt_h,$opt_v,$opt_t,$opt_age,$opt_confirm,$opt_n,$opt_all,$opt_quit,$opt_ufile,$opt_live,$opt_only);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			'age=n' => \$opt_age,
			confirm => \$opt_confirm,
			noaction => \$opt_n,
			live => \$opt_live,
			'only=s' => \$opt_only,
			ufile => \$opt_ufile,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/TPerl/360_repair.pl,v 1.3 2008-06-11 08:05:12 triton Exp $'."\n";
	exit 0;
	}
if ($opt_age eq '')
	{
	print STDERR "No age supplied, defaulting to 5 days\n";
	$opt_age = 5;
	}
if ($opt_only ne '')
	{
	print STDERR "Limiting operations to ID=$opt_only\n";
	}

my $err = new TPerl::Error ();
my $app = $0;
$app =~ s/\.pl$//;
my $logfile = "$relative_root${qt_root}/log/$app.log";
mkpath(dirname($logfile),1);
if (my $fh = new FileHandle (">> $logfile"))
	{
	$err->fh ($fh);
	}
else
	{
	$err->E("Could not write to $logfile")
	}

our $t = $opt_t;
$err->I(sprintf ("Starting $0 at %s",scalar(localtime)));
&db_conn;
#
my $sql = "select SID,UID,ROLENAME,PWD from $config{index} order by uid,rolename";
my $day = 24 * 60 * 60;
my $now = time();
#
$| = 1;
my @sids = ();
my %ids = ();
my @uids = ();
my @cases = ();
our %ufields = ();
&db_do($sql);
print "Reading in cases from $config{index}...";
while (my $href = $th->fetchrow_hashref())
	{
	push @cases,"${$href}{UID}/${$href}{PWD}/${$href}{SID}";
	}
$th->finish;
print "\n";
if ($opt_live)
	{
	$sql = "select DISTINCT UID from $config{index} order by UID";
	&db_do($sql);
	print "Reading in ID's from $config{index}...";
	while (my $href = $th->fetchrow_hashref())
		{
		$ids{${$href}{UID}}++;
		}
	$th->finish;
	print "\n";
	}
if ($opt_ufile)
	{
	print "Scanning Database records in individual surveys ...";
	foreach my $row (@cases)
		{
		my ($uid,$pwd,$SID) = split(/\//,$row);
		next if (!($uid =~ /$opt_only/i) && ($opt_only ne ''));
	#	print "$uid/$pwd/$SID $row\n";
		my $sql = "select UID,PWD,TS from $SID where uid=? and pwd=?";
		&db_do($sql,($uid,$pwd));
		my $found = 0;
		my $ts = '';
		while (my $href = $th->fetchrow_hashref())
			{
			$ts = ${$href}{TS};
			$found++;
			}
		my $age = localtime($ts);
		print "Missing DB record in $SID for $SID/$uid/$pwd\n" if (!$found);
		$th->finish;	
		my $dest = "$qt_root/$SID/web/u$pwd.pl";
		if (!(-f $dest))
			{
			if ((time() - $ts) < 60*60*24*90)
				{
				print "Missing ufile $SID/$pwd  $age\n";
				}
			else
				{
				print "!";
				}
			}
		print ".";
		}
	print "\n";
	}
print "\n PASS 2 - CHECKING UFILES\n\n";
if ($opt_ufile){
foreach my $SID (keys %{$config{snames}})
	{
	print "Checking for missing database entries in $SID...\n";
	my $webdir = "$qt_root/$SID/web";
	if ((!-d $webdir))
		{
		&force_dir($webdir);		#warn("Directory not found: $webdir");
		next;
		}
	
	opendir(DDIR,$webdir) || die "Error $! encountered while opening directory $webdir\n";
	@ufiles = grep (/^u.*?\.pl$/,readdir(DDIR));
	closedir(DDIR);
	foreach my $ufile (@ufiles)
		{
		undef %ufields;
		if (-f "$webdir/$ufile")
			{
			my @statsrc = stat("$webdir/$ufile") or die "No file $webdir/$ufile: $!";
			my $ts = $statsrc[9];			# modification time
			my $age = int(($now - $ts ) / $day);
			next if ($age > $opt_age);
			require "$webdir/$ufile";
			next if (!($ufields{id} =~ /$opt_only/i) && ($opt_only ne ''));
			my $key = "$ufields{id}/$ufields{password}/$SID";
			my @found = grep(/$ufields{id}\/$ufields{password}\/$SID/,@cases);
			print "$ufile ";
			my $email = $ufields{email};
			if ($#found == -1)
				{
				if ($SID eq $config{participant})	# Give these another try
					{
					@found = grep(/$ufields{id}\/$ufields{password}\/$config{peer}/,@cases);
					}
				if ($#found == -1)
					{
					my $myrole = 'Self';
					my $ok = 0;
					for (my $i=1;$i<=$config{nboss};$i++)
						{
						if ($ufields{password} eq $ufields{"bosspassword$i"})
							{
							print "$ufields{id} Boss $i OK\n";
							$myrole = 'Boss';
							$email = $ufields{"bossemail$i"};
							$ok++ if ($SID eq $config{participant});
							last;
							}
						}
					if (!$ok)
						{
						for (my $i=1;$i<=$config{npeer};$i++)
							{
							if ($ufields{password} eq $ufields{"peerpassword$i"})
								{
								print "$ufields{id} Peer $i OK\n";
								$myrole = 'Peer';
								$email = $ufields{"peeremail$i"};
								$ok++ if ($SID eq $config{participant});
								last;
								}
							}
						}
					if (!$ok)
						{
						print "$key ($myrole/$ufields{who} for $ufields{fullname}) is not in database\n" ;
						if ((!$opt_live) || ($opt_live && ($ids{$ufields{id}} ne '' )))
							{
							if (confirm("$ufile: Create $config{index} entry for $key ?"))
								{
								&db_add_invite($config{index},$config{case},$SID,$ufields{id},
								$ufields{password},$ufields{who},$myrole,$ufields{batchno},
								$config{sort_order}{$SID});
								&db_add_pwd($SID,$ufields{password},$ufields{batchno},$email,$ufields{who},$ufields{id});
								}
							}
						}
					}
				else
					{
					print "$ufields{id} OK\n";
					}
				}
			else
				{
				my $stat = db_get_user_status($SID,$ufields{id},$ufields{password});
				if ($stat eq '')
					{
					if ((!$opt_live) || ($opt_live && ($ids{$ufields{id}} ne '' )))
						{
						if (confirm("$ufile: Add DB entry to $SID for $SID,$ufields{password},$ufields{batchno},$email,$ufields{who},$ufields{id} ?"))
							{
							&db_add_pwd($SID,$ufields{password},$ufields{batchno},$email,$ufields{who},$ufields{id});
							}
						}
					}
				print "$ufields{id} OK\n";
				}
			}
		else
			{
			print "File not found: $webdir/$ufile\n";
			}
		}
	}
}
print "\n PASS 3 - CHECKING DFILES\n\n";
foreach my $SID (keys %{$config{snames}})
	{
	print "Checking for missing database entries in $SID...\n";
	my $webdir = "$qt_root/$SID/web";
	my $webdir = "$qt_root/$SID/web";
	if (!(-d $webdir))
		{
		warn("Directory not found: $webdir");
		next;
		}
	opendir(DDIR,$webdir) || die "Error $! encountered while opening directory $webdir\n";
	our @dfiles = grep (/^D.*?\.pl$/,readdir(DDIR));
	closedir(DDIR);
	foreach my $dfile (@dfiles)
		{
		undef %resp;
		if (-f "$webdir/$dfile")
			{
			my @statsrc = stat("$webdir/$dfile") or die "No file $webdir/$dfile: $!";
			my $ts = $statsrc[9];			# modification time
			my $age = int(($now - $ts ) / $day);
			next if ($age > $opt_age);
			require "$webdir/$dfile";
			next if (!($resp{id} =~ /$opt_only/i) && ($opt_only ne ''));
			if (($resp{id} eq '' ) || ($resp{token} eq ''))
				{
				$err->W("Missing id[$resp{id}] or password[$resp{token}] (or both) in file $dfile, skipping");
				next;
				}
#			print "$dfile ? ";
			my $stat = db_get_user_status($SID,$resp{id},$resp{token});
			if ($stat eq '')
				{
				my $fullname = $resp{who};
				my $email = '';
				my $ok = 0;
				for (my $i=1;$i<=$config{nboss};$i++)
					{
					if ($resp{token} && ($resp{token} eq $resp{"bosspassword$i"}))
						{
						print "$dfile $resp{id} Boss $i OK\n";
						$fullname = $resp{"bossfullname$i"};
						$email = $resp{"bossemail$i"};
						$ok++ if ($SID eq $config{participant});
						last;
						}
					}
				if (!$ok)
					{
					for (my $i=1;$i<=$config{npeer};$i++)
						{
						if ($resp{token} && ($resp{token} eq $resp{"peerpassword$i"}))
							{
							print "$dfile $resp{id} Peer $i OK\n";
							$fullname = $resp{"peerfullname$i"};
							$email = $resp{"peeremail$i"};
							$ok++ if ($SID eq $config{participant});
							last;
							}
						}
					}
				if (!$ok)
					{
					if ((!$opt_live) || ($opt_live && ($ids{$ufields{id}} ne '' )))
						{
						if (confirm("$dfile: Add record to $SID for $resp{aboutname}, Reviewer=$fullname/$resp{token}?"))
							{
							&db_add_pwd($SID,$resp{token},$resp{batchno},$email,$fullname,$resp{id});
							&db_set_status($SID,$resp{id},$resp{token},$resp{status},$resp{seqno});
							}
						}
					}
				}
			elsif (($stat ne $resp{status}) && ($resp{status} ne ''))
				{
				if ((!$opt_live) || ($opt_live && ($ids{$ufields{id}} ne '' )))
					{
					if (confirm("$dfile: Update record status to ($resp{status}) [was $stat] $SID for $resp{id}/$resp{token}?"))
						{
						&db_set_status($SID,$resp{id},$resp{token},$resp{status},$resp{seqno});
						}
					}
				}
			}
		else
			{
			print "File not found: $webdir/$dfile\n";
			}
		}
	}

&db_disc;

#--------------------------------------------------------
# SUBS
#
sub confirm
	{
	my $prompt = shift;
	$prompt = "Proceed ?" if ($prompt eq '');
	my $ans = 1;
	$ans = -1 if ($opt_confirm);
	$ans = 1 if ($opt_all);
	$ans = 0 if ($opt_quit);
	while ($ans == -1)
		{
		print STDERR "$prompt (Y/N/A/Q): ";
		my $x;
		while (not defined ($x = ReadLine(0))){
			#no key yet
		}
#		my $x = getc();
		if ($x =~ /^a/i)
			{
			$ans = 1;
			$opt_all = 1;
			}
		if ($x =~ /^y/i)
			{
			$ans = 1;
			}
		if ($x =~ /^n/i)
			{
			$ans = 0;
			}
		if ($x =~ /^q/i)
			{
			$ans = 0;
			$opt_quit = 1;
			print STDERR "\nQuitting, no more actions will be taken\n";
			}
		print STDERR "\n";
		}
	$ans = 0 if ($opt_n);		# Override the confirmation response if -noaction is selected
	$ans;
	}

sub info
	{
	my $msg = shift;
	print "[I] $msg\n";
	$err->I($msg);
	}
sub warn
	{
	my $msg = shift;
	print "[W] $msg\n";
	$err->W($msg);
	}
sub error
	{
	my $msg = shift;
	print "[E] $msg\n";
	$err->E($msg);
	}
sub fatal
	{
	my $msg = shift;
	print "[F] $msg\n";
	$err->F($msg);
	}

1;
