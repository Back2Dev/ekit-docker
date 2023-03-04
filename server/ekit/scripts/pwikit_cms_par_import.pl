#!/usr/bin/perl
# $Id: pwikit_cms_par_import.pl,v 1.38 2012-12-05 20:59:10 triton Exp $
# Script to read participant/workshop data from the CMS system and process it
#
# Script to read participant/workshop data from the CMS system and xfer it to the eKit Server
#
# This is the 2nd part of the script...
# 1st half of script runs on CMS Server: map_cms_par_upload.pl
# But wait, there is another script, pwikit_cms_refdata_import.pl, which does the reference data importing
#

use strict;
use DBI;
use Date::Manip;							#perl2exe
use Getopt::Long;							#perl2exe
use Data::Dumper;							#perl2exe

use TPerl::Error;		  					#perl2exe
use TPerl::TSV;								#perl2exe
use TPerl::MyDB;							#perl2exe
use TPerl::Engine;							#perl2exe

#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

our ($qt_root,$dbt,$oldu,%config);
require 'TPerl/qt-libdb.pl';				#perl2exe
require 'TPerl/360-lib.pl';					#perl2exe
require 'TPerl/pwikit_cfg.pl';				#perl2exe
require 'TPerl/360_updatep.pl';				#perl2exe
$| = 1;

my $en = TPerl::Engine->new();
my $e = TPerl::Error->new();
my $when = localtime();
my $auto_welcome = $config{autosend_new_welcome};
$e->I("Starting $0 at $when");
eval("sub get_custom_new	{&my_custom_new();}");
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_limit,$opt_flimit,$opt_complete,$opt_scheduled,
		$opt_reschedule,
		$opt_days,
		$opt_ahead,
		$opt_noemails,
#		$opt_only,
		$opt_file,
		$opt_status,
		$opt_reset,
		$opt_n,
		);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			'limit=i' => \$opt_limit,
			'flimit=i' => \$opt_flimit,
			'complete' => \$opt_complete,
			'scheduled' => \$opt_scheduled,
			'reschedule' => \$opt_reschedule,
			'days=i' => \$opt_days,
			'ahead=i' => \$opt_ahead,
			noemails => \$opt_noemails,
			noaction => \$opt_n,
#			'only=i' => \$opt_only,
			'file=s' => \$opt_file,
			status => \$opt_status,
			reset => \$opt_reset,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwikit_cms_par_import.pl,v 1.38 2012-12-05 20:59:10 triton Exp $'."\n";
	exit 0;
	}
$dbt = $opt_d;
$opt_days = 14 if (!$opt_days);
$opt_ahead = 42 if (!$opt_ahead);
our @selflist = @{$config{selflist}};
push @selflist,'MAP026';
my %admin2email = ();
my %admin2phone = ();
my %admin2fax = ();
my %exec2email = ();
my %exec2phone = ();
my %exec2fax = ();
my %locid2fax = ();

#
# List of field names from the query that we want 'as is':
#
my @cms2pwi = (
			'salutation',
			'lastname',
			'firstname',
			'email',
			'id',
			'title',
			'company',
			'flag',
            
            'execname', 
            
			'cms_status',
			
			'startdate',
			'location',
			'locationcode',
			'locationaddress',
			'locationcity',
			'locationstate',
			'hotelrate',
			
			'workshop_leader_name',
			'workshop_leader_initials',
			);

#
# List of boss field names from the query that we will process:
#
my @cms2boss = (
			'bossemail',
			'bosslastname',
			'bossfirstname',
			'bossid',
			);	


#--------------------------------------------------------------------------------------
#
# Mainline starts here
#
#--------------------------------------------------------------------------------------
# First up, connect to our local database and cache the admin and exec tables:
our $dbh = dbh TPerl::MyDB() or die ("Could not connect to database :".DBI->errstr);
cache_admin();

my $nprocessed = 0;
my $filecnt = 0;
my $currid = '';
our %ufields = ();
our @cmsdata;
my $SID = 'PARTICIPANT';
if ($opt_reset)
	{
	$| = 1;
	print "Are you sure you want to delete ALL PARTICIPANT uploaded data ? (y/[n]):";
	my $ans = getc();
	if ($ans =~ /^y/i)
		{
		my $sql = "DELETE FROM PWI_UPLOAD_PARTICIPANT";
		my $th = &db_do($sql);
		$th->finish;
		print "Done.\n";
		}
	else {print "Not done.\n";}
	}
elsif ($opt_status)
	{
	my $sql = "SELECT MIN(BATCHNO) AS MINB,MAX(BATCHNO) as MAXB FROM PWI_UPLOAD_PARTICIPANT";
	my $th = &db_do($sql);
	my ($minb,$maxb) = $th->fetchrow();
	$th->finish;

	my $sql = "SELECT MAX(LAST_UPDATE_DT) as MAXWHEN, MAX(ID) as MAXID,MIN(ID) as MINID FROM PWI_UPLOAD_PARTICIPANT";
	my $th = &db_do($sql);
	my ($whenb,$maxid,$minid) = $th->fetchrow();
	$th->finish;

	if (!$minb)
		{$minb = $maxb = $minid = $maxid = 0;$whenb='N/A';}		# Be kind with the report if nothing there :)
	$e->I("Uploaded batches $minb => $maxb, id's=$minid-$maxid (last record modified at $whenb)");
	}
else
	{
#
# Determine which batch we are dealing with, or if we are just slurping everything we have
#
	my $sql = "SELECT MAX(BATCHNO) FROM PWI_UPLOAD_PARTICIPANT";
	my $th = &db_do($sql);
	my @row = $th->fetchrow();
	$th->finish;
	my $frombatch = (@row) ? $row[0] : '100';
	my @upfiles = ();
	my $datadir;
	$datadir = "${qt_root}/$SID/data";
	if (!$opt_file)
		{
		die ("Error $! while opening directory $datadir\n") if (! opendir(DDIR,"$datadir"));
		@upfiles = grep (/^uploaded_participant_\d+\.txt$/i,readdir(DDIR));
		closedir(DDIR);
		}
	else
		{
		push @upfiles,$opt_file;
		}
	#
	# Process the files:
	#
	foreach my $upf (sort bytrailer @upfiles)
		{
		my $upfile =  qq{$datadir/$upf};
		die "Dodgy file name: $upf\n" if !($upf =~ /(\d+)\.txt/i);
		my $bno = $1;
		next if (($bno <= $frombatch) && !$opt_file);
		my $fwhen = localtime((stat($upfile))[9]);
		$e->I(" Reading file=$upf ($fwhen)");
	#
	# Suck the file in, and stack it up as hashes to iterate through
	#
		our @cmsdata = ();
		fatal("CMS Data file name (missing batchno): $upfile does not exist") unless -e $upfile;
		my $tsv = new TPerl::TSV (file=>$upfile);
		my $sql = "DELETE FROM PWI_UPLOAD_PARTICIPANT where BATCHNO=?";
		&db_do($sql,$bno);
		while (my $row = $tsv->row)
			{
			$$row{BATCHNO} = $bno;
			$$row{IMPORT_DT} = UnixDate('today',"%Y-%m-%d %H:%M:%S");
#			my $flist = join(",",keys %$row);
			my @values = ();
			my (@ph,@fl);
			foreach my $key (keys %$row)
				{
				my $v = trim($$row{$key});
				next if ($v eq '');
				push @values,$v;
				push @ph,"?";
				push @fl,$key;
				}
#			map {push @values,trim(($$row{$_}) ? $$row{$_}: 'NULL');push @ph,"?";} keys %$row;
			my $vlist = join ",",@ph;
			my $flist = join ",",@fl;
			my $sql = "INSERT INTO PWI_UPLOAD_PARTICIPANT ($flist) VALUES ($vlist)";
			&db_do($sql,@values);
			}
	#
	# Now fetch the data back and dispatch it:
	#
		my $sql = "SELECT * FROM PWI_UPLOAD_PARTICIPANT WHERE BATCHNO=?";
		my $th = &db_do($sql,$bno);
		my $rowcnt = 0;
		while (my $href = $th->fetchrow_hashref())
			{
#			print Dumper $href if ($opt_d);
			my %lchash = ();
			foreach my $key (keys %{$href})
				{
				$lchash{lc($key)} = $$href{$key};
				}
			push @cmsdata,\%lchash;
			$rowcnt++;
			}
		$th->finish;
		print "Processed $rowcnt records\n" if ($opt_t);
#
# Now we run through the data, creating eKit records as necessary
#
		kickoff();		# This calculates all the stuff for the u-file, ready for committing it to the DB
		print "Closing up file $upf...\n" if ($opt_t);
		last if ($opt_limit && ($nprocessed >= $opt_limit));
		$filecnt++;
		last if ($opt_flimit && ($filecnt >= $opt_flimit));
		}
	}
&db_disc;
$e->I("$0: Processed $nprocessed records in $filecnt files");

#-------------------------------------------------------------------------------------
#
# Subroutines:
#
#-------------------------------------------------------------------------------------

sub bytrailer 
	{
	my $c = $a;
	my $d = $b;
	$c =~ s/^\D+//;
	$c =~ s/\.\w+$//;
	$d =~ s/^\D+//;
	$d =~ s/\.\w+$//;
#  	print "Is $c < $d ? ($a,$b)\n";
	$c <=> $d;  # presuming numeric
	}

sub ispast
	{
	my $startdate = shift;
	my $cms_status = shift;
	my $result = 0;
	if (($cms_status =~ /[CS]/) && $startdate)
		{
	
#	$startdate =  qq{$3-$1-$2} if ($startdate =~ /(\d+)\/(\d+)\/(\d+)/);
		my $wsdate = ParseDate($startdate);
		my $today = ParseDate('today');
		if (Date_Cmp($wsdate,$today) <= 0)
			{
			$e->I("Date $startdate is past already ($wsdate,$today)") if ($opt_t);
			$result = 1;
			}
		}
	$result;
	}
	
sub process_data
	{
	if (($opt_limit) && ($nprocessed >= $opt_limit))
		{
		print "!" if ($opt_t);
		return 0;
		}
	print "." if ($opt_t);
	my $uref = shift;
	my $fullname = qq{$$uref{firstname} $$uref{lastname}};
	print "Processing id=$$uref{id} $fullname\n" if ($opt_t);
	foreach my $key (sort keys %{$uref})
		{
		$$uref{$key} =~ s/\s\s+/ /g;
		$$uref{$key} =~ s/\s+$//g;
#		print "	$key=[$$uref{$key}]\n";
		}
#
# Now let's get serious about this: we have everything together in this %ufields hash, 
# so let's see what we need to do with it:
#
	&my_custom_new;
	if (&db_user_exists($config{master},$$uref{id}))
		{
		my $did_work;
# User is already in the system, check and see if anything has changed:
		$e->I(" $$uref{id} $fullname ($$uref{batchname}) exists already");
# Ok, if they do exist, we need to retrieve details from u/D files
		my ($pwd,$fullname) = &db_get_case($config{index},$config{participant},$$uref{id});
#		my $oldu = $en->u_read("$qt_root/$config{participant}/web/u$pwd.pl");	# This is done already in kickoff, so the oldu hash already contains data
# 'New' participant does Q8 and Q9. Poss. values of 'FLAG' are A/B/N/O/F
# Was new but now not ?
		if ($$oldu{new} && !($$uref{flag} =~ /[ABN]/i))
			{
# Delete forms Q8 and Q9, along with their data
			$e->I("  Removing Q8/Q9 from $$uref{id} $fullname");
			foreach my $survey_id (@{$config{newlist}})
				{
				my $f = "$qt_root/$survey_id/web/u$pwd.rtf";					# Delete the u file
				unlink $f if (-f $f);
				my $seq = &db_get_user_seq($survey_id,$$uref{id},$pwd);		# Any data ?
				my $f = "$qt_root/$survey_id/web/D$seq.pl";					# Delete the d-file
				my $dest = "$qt_root/$survey_id/deleted/D$seq.pl";
				rename $f,$dest if (-f $f);
				my $f = "$qt_root/$survey_id/doc/$seq.rtf";					# Delete the document
				my $dest = "$qt_root/$survey_id/deleted/$seq.rtf";					# Delete the document
				rename $f,$dest if (-f $f);
				&db_reverse_id($survey_id,$$uref{id});						# DELETE from $SID table
				&db_del_invite($config{index},$survey_id,$$uref{id},$pwd);	# Delete from XXX_CASES table
				}
			$$oldu{new} = 0;			# Reset 'new' flag 
			$did_work = 1;
			}
# Was NOT new but now is new ?
		if (!$$oldu{new} && ($$uref{flag} =~ /[ABN]/i))
			{
# Add forms Q8 and Q9
			$e->I("  Adding Q8/Q9 to $$uref{id} $fullname");
			$$oldu{new} = 1;													# Remember that we are new now
			foreach my $survey_id (@{$config{newlist}})
				{
				if (&db_user_exists($survey_id,$$uref{id}))						# Be defensive just in case
					{
					$e->W("  Form $survey_id was present already - skipped");
					}
				else
					{
					&db_save_pwd_full($survey_id,$$uref{id},$pwd,$fullname,0,0,$$uref{email});
					&db_add_invite($config{index},$config{case},$survey_id,
									$$uref{id},$pwd,
									$fullname,'Self',
									$$oldu{batchno},$config{sort_order}{$survey_id});
					&save_ufile($survey_id,$pwd);
					}
				}
			$did_work = 1;
			}
# Has the workshop date or location changed? If so, wipe off Q18 data
# NB: Can use 'locationcode' and 'startdate'
		if (($$oldu{locationcode} ne $$uref{locationcode}) ||
			($$oldu{startdate} ne $$uref{startdate}) )
			{
			# DELETE Q18 data
			my $survey_id = $config{hotel};
			my $seq = &db_get_user_seq($survey_id,$$uref{id},$pwd);		# Any data ?
			my $f = "$qt_root/$survey_id/web/D$seq.pl";					# Delete the d-file
			if (-f $f)
				{
				$e->I("  Rescheduled: Clearing Q18 (hotel booking) for $$uref{id} $fullname");
				my $dest = "$qt_root/$survey_id/deleted/D$seq.pl";					# Delete the d-file
				rename $f,$dest;
				my $f = "$qt_root/$survey_id/doc/$seq.rtf";				# Delete the document
				my $dest = "$qt_root/$survey_id/deleted/$seq.rtf";		# 
				rename $f,$dest if (-f $f);
				&db_set_status($survey_id,$$uref{id},$pwd,0,undef);			# Reset status & seqno
				}
			$did_work = 1;
			}
# Workshop Completed, now do post workshop survey ?
# MJC: Changed status to RR to avoid invites
		if (($$uref{cms_status} eq 'RRR') && ($$oldu{cms_status} eq 'S') && $config{autosend_post})
			{
			my $survey_id = $config{post};
			if (!&db_user_exists($survey_id,$$uref{id}))
				{
				$e->I("  Workshop completed: Creating post workshop survey entry for $$uref{id} $fullname");
				&db_save_pwd_full($survey_id,$$uref{id},$pwd,$fullname,0,0,$$uref{email});
				&db_add_invite($config{index},$config{case},$survey_id,
								$$uref{id},$pwd,
								$fullname,'Self',
								$$oldu{batchno},$config{sort_order}{$survey_id});
				&save_ufile($survey_id,$pwd);
				}
			$e->I(qq{  Workshop completed: $$uref{id} Send [post] to $$uref{fullname} [$$uref{email}] });
			queue_invite($config{post},'post',$$uref{id},$$uref{password}, $$uref{email},'','') if (!$opt_n);
			$did_work = 1;
			}
		my $changes;
		foreach my $key (keys %{$uref})
			{
			if ($$oldu{$key} ne $$uref{$key})
				{
				$changes++;
				&debug("$key: old=[$$oldu{$key}], new=[$$uref{$key}]");
# ??? Very useful for debugging right now, might want to turn it off later
				$e->I("    Changing [$key] '$$oldu{$key}' >>> '$$uref{$key}'");
				$$oldu{$key} = $$uref{$key};	# Copy the new value in
				}
			}
		if ($changes)
			{
			$e->I("  Saving $changes changes to $$uref{id} $fullname");
			#??? Update u and D files with new data values (eg change of name/email/schedule etc)
			&update_participant($opt_d);
			$did_work = 1;
			}
		$nprocessed++ if ($did_work);
		$e->I("  No changes made to $$uref{id} $fullname") if (!$did_work);
		}
	elsif (ispast($$uref{startdate},$$uref{cms_status}))
		{
		$e->I(" Skipped $$uref{id} $fullname ($$uref{batchname}) does not exist, but is past already");
		}
	elsif ($$uref{cms_status} eq 'C')
		{
		$e->I(" Skipped $$uref{id} $fullname ($$uref{batchname}) does not exist, but has completed workshop already");
		}
	else
		{
		$nprocessed++;
		$e->I(" Adding $$uref{id} $fullname ($$uref{batchname}) $$uref{pwd}");
# This is a hack to ensure that welcome messages are only sent to scheduled participants
		if ($auto_welcome)
			{
			$config{autosend_new_welcome} = ($ufields{cms_status} =~ /[S]/);
			}
		&new_participant($uref);
		}
	}

#
# This one is called by the eval of get_custom_new (at top of file)
#
sub my_custom_new	
	{
#	print "pwikit_cms_par_import.pl: my_custom_new()\n";
	if ($ufields{cms_status} =~ /[CS]/)
		{
		my %things = (
						admin_id => {
									default => '624',
									sql => 'SELECT ADMIN_ID,ADMIN_NAME AS ADMINNAME,ADMIN_EMAIL AS ADMINEMAIL FROM PWI_ADMIN WHERE ADMIN_ID=?',
								},
						locationcode => {
									sql => 'SELECT ADMIN_PHONE AS ADMINPHONE,ADMIN_FAX AS RETURNFAX FROM PWI_LOCATION WHERE LOC_CODE=?',
								},
						);
		foreach my $thing (keys %things)
			{
			my $param = $ufields{$thing};
			$param = $things{$thing}{default} if ($things{$thing}{default} && !$param);
			my $th = &db_do($things{$thing}{sql},$param);
			my $href = $th->fetchrow_hashref;
			die "Could not find $thing [$param] in database (using sql $things{$thing}{sql})\n" if (!$href);
			foreach my $key (keys %{$href})
				{
				$ufields{lc($key)} = $$href{$key} if ($ufields{lc($key)} eq '');	# Only fill them in if not already there
				}
			$th->finish;
			}
		}
	}
	
sub fatal
	{
	my $msg = shift;
	die "Fatal error: $msg\n";
	}
sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if $msg;
	print <<USAGE;
Usage: $0 [-version] [-debug] [-help] [-limit=n] [-files=n] [-scheduled | -complete | -reschedule] [-days=n] [-noemails] [-file=filename] [-reset]
	-ahead=n       Max days ahead for participants in workshops (default=42 [6 weeks])
	-complete      Only look at participants that have completed the workshop
	-days=n        Look for participants in workshops starting n days from now (default=14)
	-file=filename Read from Tab separated file instead of from database	
	-help          Display help
	-limit=n       Limits number of records to be processed this pass
	-flimit=n      Limits number of files to be processed
	-noemails      Don't send emails
	-noaction      Don't do anything, just run through the motions
	-reschedule    Only look at participants that have been Re-scheduled 
	-reset         reset table (ie remove already imported data)
	-scheduled     Only look at participants that are Scheduled to attend
	-status        Show status
	-version       Display version no
USAGE
	exit 0;
	}

sub cache_admin
	{
	my $sql = "SELECT ADMIN_NAME,ADMIN_EMAIL,ADMIN_PHONE,ADMIN_FAX from PWI_ADMIN";
	my $th = &db_do($sql);
	while (my @row = $th->fetchrow())
		{
		$admin2email{$row[0]} = $row[1];
		$admin2phone{$row[0]} = $row[2];
		$admin2fax{$row[0]} = $row[3];
		}
	$th->finish;
	
	my $sql = "SELECT EXEC_NAME,EXEC_EMAIL,EXEC_PHONE,EXEC_FAX from PWI_EXEC";
	my $th = &db_do($sql);
	while (my @row = $th->fetchrow())
		{
		$exec2email{$row[0]} = $row[1];
		$exec2phone{$row[0]} = $row[2];
		$exec2fax{$row[0]} = $row[3];
		}
	$th->finish;
	
	my $sql = "SELECT LOC_ID,LOC_FAX FROM PWI_LOCATION WHERE LOC_ACTIVE=1";
	my $th = &db_do($sql);
	while (my @row = $th->fetchrow())
		{
		$locid2fax{$row[0]} = $row[1];
		}
	$th->finish;
	
	print "Cached admin and exec records OK\n" if ($opt_t);	
	}
#
# Calculate the index of the (supplied) boss, or return
#  the next empty slot
#
sub getbossix{
	my $bossid = shift;
	print "Looking for bossid $bossid\n" if ($opt_d);
	my $ix = 0;
	for (my $i=1; $i<=9;$i++){		# Maximum of 9 bosses
		if (($ufields{"bossid$i"} eq "") 
		|| ($bossid eq $ufields{"bossid$i"})) {
			$ix = $i;		# Use this slot
			last;			# Quit the loop
		}
	}
	print "Returning bossix=$ix\n" if ($opt_d);
	$ix;	
}

sub kickoff
	{
#
# This assumes that the array @cmsdata is already primed with records
#
	my $bossix = 0;
	foreach my $href (@cmsdata)
	    {
	#	print join("\t",values %$href)."\n";
	#
	# Convert the data into our internal format:
	#
		die "Record is missing id \n" if ($$href{id} eq '');
		if ($currid eq $$href{id})	# New record, or continuation ?
			{
			$bossix = getbossix($$href{bossid});
			if ($bossix > 0) 
				{
				foreach my $key (@cms2boss)
					{
					my $bkey = qq{$key$bossix};
					$ufields{$bkey} = $$href{$key};
					}
				}
			}
		else	# Starting to process this one
			{
			&process_data(\%ufields) if ($ufields{id} ne '');
			undef %ufields;
# Pull in the old u-file (if it's there), as it makes life easier for us
			my ($pwd,$fullname) = &db_get_case($config{index},$config{participant},$$href{id});
			$oldu = $en->u_read("$qt_root/$config{participant}/web/u$pwd.pl");
#
# This is a patch that might just work, if the u-file is not present,
# it probably means that the participant is archived, so by skipping
# it we might save our bacon without the need for a whole bunch of
# work.
#
			if ((!$oldu) && ($pwd ne '')) {	 
				warn $en->err;
				$e->W("Participant $pwd $fullname is archived, skipping");
				next;
			}
			foreach my $key (keys %{$oldu})
				{$ufields{$key} = $$oldu{$key};}
			
# Adjust the boss index for existing participants
# This allows for the case where a boss is added after the fact.
# We can't tell when a boss is removed or replaced, so we give
# the participant multiple bosses
# Scan through for match on boss id
			$bossix = getbossix($$href{bossid});
# Now start calculating stuff				
			$ufields{send_emails} = $config{send_emails} unless ($opt_noemails);
			$currid = $$href{id};
			if ($bossix > 0) 
				{
				foreach my $key (@cms2boss)
					{
					my $bkey = qq{$key$bossix};
					$ufields{$bkey} = $$href{$key};
					}
				}
			foreach my $key (@cms2pwi)
				{
				$ufields{$key} = $$href{$key};
				}
	# Now do custom fixing:
			if ($ufields{cms_status} =~ /[CS]/i)
				{
				if ($$href{startdate}) 
					{
					my $date = &ParseDate($$href{startdate});
					$$href{startdate} = UnixDate($date,"%m/%d/20%y");
					$ufields{startdate} = $$href{startdate};
					$ufields{batchname} = "$$href{locationcode}.".UnixDate($date,"%m.%d.%y");
					}
				}
			else
				{
				$ufields{batchname} = $$href{locationcode};			# This will be either HOLD or CANCEL
				}
			check_batch(\%ufields);
	# Participant
			$ufields{gender} = (uc($$href{sex}) eq 'M') ? '1' : '2';
			@selflist = @{$config{selflist}};
			push @selflist,'MAP026';
	# 'New' participant does Q8 and Q9. Poss. values of 'FLAG' are A/B/N/O/F
			$ufields{new} = ($ufields{flag} =~ /[ABN]/i);
			push @selflist,@{$config{newlist}} if ($ufields{new});
	# Exec: !??? Keying off the exec name is risky here, but it's from a DB, so maybe not so bad (unless names change)
			$ufields{execphone} = $exec2phone{$ufields{execname}};
			$ufields{execemail} = $exec2email{$ufields{execname}};
			$ufields{execfax} = $exec2fax{$ufields{execname}};
	# Admin: !??? Keying off the admin name is risky here, but it's from a DB, so maybe not so bad (unless names change)
			$ufields{adminphone} = $admin2phone{$ufields{adminname}};
			$ufields{adminemail} = $admin2email{$ufields{adminname}};
			$ufields{adminfax}   = $admin2fax{$ufields{adminname}};
			$ufields{returnfax} = $locid2fax{$ufields{locationcode}};
	# Convert Participant "FLAG" to New
	# Get workshop date, convert to a display format, and calculate day1/day2 and due/reminder1/2 dates
			if (($ufields{cms_status} =~ /[CS]/i) && ($$href{startdate}) )
				{
				my $datestr = $$href{startdate};
				$ufields{workshopdate} = format_wsdate($datestr);
				$datestr =~ s/\/20(\d\d)/\/$1/;
	#			print "Parsing date: [$datestr], startdate=$ufields{startdate}\n";
				my $date = &ParseDate($datestr);
				$ufields{day1} = UnixDate($date,"%A");
				my $date2=&Date_NextWorkDay($date,"1");
				$ufields{day2} = UnixDate($date2,"%A");
				my $date0=&Date_GetPrev($date,undef,2,"6:00");
				$ufields{dayprior} = UnixDate($date0,"%A");
#				my $due=&DateCalc($date,"-3w");
#				$ufields{duedate} = UnixDate($due,"%m/%d/20%y");
# This is the new way to do this:
				$ufields{duedate} = calc_duedate($datestr,'today',"%m/%d/20%y");
#??? Pretty sure that remdate1 and remdate2 are not used anywhere
#				my $due=&DateCalc($date,"-2w");
#				$ufields{remdate1} = UnixDate($due,"%m/%d/20%y");
#				my $due=&DateCalc($date,"-1w");
#				$ufields{remdate2} = UnixDate($due,"%m/%d/20%y");
# Invitedate calculation is kinda OK, presuming we are in plenty of time to do everything
				my $invitedate=&DateCalc($date,"-6w");
				$ufields{invitedate} = UnixDate($invitedate,"%m/%d/20%y");
				my $chargedate=&DateCalc($date,"-5d");
				$ufields{meals_charge_date} = UnixDate($chargedate,"%m/%d/20%y");
				}
			}
		}
# At the end of the loop, there will still be data in memory to deal with:
	&process_data(\%ufields) if ($ufields{id} ne '');
	undef %ufields;
	}

1;
