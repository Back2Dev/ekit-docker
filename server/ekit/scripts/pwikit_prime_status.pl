#!/usr/bin/perl
# $Id: pwikit_prime_status.pl,v 1.14 2013-05-13 23:25:12 triton Exp $
#
# Script to prime PWI Kit status pages.
#
# By Mike King
#
#	$Header: /au/apps/alltriton/cvs/scripts/pwikit_prime_status.pl,v 1.14 2013-05-13 23:25:12 triton Exp $
#
#----------------------------------------------------------------------
#
use strict;
use Getopt::Long;							#perl2exe
use TPerl::TritonConfig;    				#perl2exe
use Date::Manip;							#perl2exe
use Proc::ProcessTable;

our (%cnt,%ufields,%config,$qt_root,%resp,$dbt);
require 'TPerl/qt-libdb.pl';				#perl2exe
require 'TPerl/360-lib.pl';					#perl2exe
require 'TPerl/pwikit_cfg.pl';				#perl2exe


#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");
  

sub die_usage
	{
	print <<USAGE;
Usage: $0 [-version] [-debug] [-help] [-trace] [-all] [-only=xxx] [-seq=999]
	-help     Display help
	-version  Display version no
	-trace    Display program trace information
	-debug    Display debugging information (more detailed)
	-all      Do all participants
	-only=    Do only for participant id=
	-seq=     Do only for this seqno
USAGE
	exit 0;
	}

#-----------------------------------------------------------
#
# Main line starts here
#
#-----------------------------------------------------------
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_all,$opt_only,$opt_seq);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			all=> \$opt_all,
			'only=s' => \$opt_only,
			'seq=s' => \$opt_seq,
			version => \$opt_v,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwikit_prime_status.pl,v 1.14 2013-05-13 23:25:12 triton Exp $'."\n";
	exit 0;
	}
#my $qt_root = '/triton';
my %files = ();
my %warn = ();
&get_root;

my %sid2q = (
		MAP001  => 'Q1',
		MAP002  => 'Q2',
		MAP003  => 'Q3',
		MAP004  => 'Q4',
		MAP005  => 'Q5',
		MAP006  => 'Q6',
		MAP007  => 'Q7',
		MAP008  => 'Q8',
		MAP009  => 'Q9',
		MAP010  => 'Q10',
		MAP010A => 'Q10A',
		MAP011  => 'Q11',
		MAP012  => 'Q12',
		MAP018  => 'Q18',
		MAP026  => 'Q26',
		);
my %lookup = (
			ext_cardname		=> 'CREDIT_CARD_HOLDER',
			ext_cardtype        => 'CCT_ID',
			ext_cardno_enc		=> 'CREDIT_CARD_REC',
			ext_cardexpiry   	=> 'CREDIT_EXP_DATE',
			ext_early     		=> 'EARLY_ARRIVAL',
			ext_arrivaltime		=> 'EARLY_ARRIVAL_TIME',
			ext_guest        	=> 'WITH_GUEST',
			ext_day1guest 		=> 'GUEST_DINNER_DAY1',
			ext_day2guest 		=> 'GUEST_DINNER_DAY2',
			ext_dietnotes  		=> 'DIETARY_RESTRICT',
			ext_revisedfullname	=> 'REVISED_FULLNAME',
			ext_occupancy		=> 'OCCUPANCY',
			
			###???
			#ext_early_arrival_date	=> 'PAR_EARLY_ARRIVAL_DATE',
			);			
#
# Have a look at the process list, and make sure we are the only copy of this running
#
my $t = new Proc::ProcessTable;
my $myname = $0;
foreach my $p ( @{$t->table} ){
    my $pid = $p->pid;
    next if ($pid == $$);   # Skip myself
    if (($p->cmndline =~ /$myname/i)
    && ($p->cmndline =~ /perl/) 
    && ($p->cmndline =~ /$opt_seq/)) {
		my $cmndline = $p->cmndline;
#		print "Duplicate process: $opt_seq '$0' '$cmndline'\n";
        exit(1);
    }
}

&db_conn;
#
# ??? If we comment this out, we need to create a status record for each person when
# we do the kickoff thing
#
sub add2cache
	{
	my $hashref = shift;
	my $sql = shift;
	my $th = &db_do($sql);
	while (my @row = $th->fetchrow_array)
		{
#			print "Adding $row[0]\n";
		$$hashref{uc($row[0])}++;
		}
	$th->finish;	
	}
	
sub fixem
	{
	foreach my $key (keys %cnt) 
		{		
		delete $cnt{$key} if (!$cnt{$key});
		$cnt{$key} =~ s/^yes$/Y/i;
		$cnt{$key} =~ s/^no$/N/i;
		}
	}

sub update_it
	{
	my $id = shift;
#
# Assume we have the last one in memory, and flush the info we have:
#
	my $amready = (($cnt{Q10} >= 3) && ($cnt{Q1} == 1) && ($cnt{Q11} == 1) && ($cnt{Q12} == 1) && ($cnt{Q18} == 1)) ? 1 : 0;
	$cnt{isready} = $amready;
	$cnt{last_update_ts} = time();
	fixem;
	&db_save_extras_uid($config{status},$id,\%cnt);
#
# Also update the STOP_FLAG in the primary records for Participant/Boss/Peer: 
#
	my $onhold = ($ufields{cms_status} =~ /[CIX]/i) ? 1 : 0;
	my %stuff;
	$stuff{STOP_FLAG} = $amready || $onhold;
	&db_save_extras_uid($config{participant},$id,\%stuff);
# We issue the stop flag for all bosses, as we have enough responses now 
#	for the participant to do the workshop. I guess we are kind to them :)
	&db_save_extras_uid($config{boss},$id,\%stuff);
# We update the STOP_FLAG for Peers as well, even though the scheme does not use this flag
	&db_save_extras_uid($config{peer},$id,\%stuff);
	}	
	
my %locations = ();
my %workshops = ();
my %execs = ();
my %admins = ();

add2cache(\%locations,"select DISTINCT LOC_ID AS LOCID FROM PWI_LOCATION ORDER BY LOC_ID");
add2cache(\%workshops,"select DISTINCT WS_STARTDATE AS WSDATE FROM PWI_WORKSHOP ORDER BY WS_STARTDATE");
add2cache(\%execs,"select DISTINCT EXEC_NAME AS EXECNAME FROM PWI_EXEC ORDER BY EXEC_NAME");
add2cache(\%admins,"select DISTINCT ADMIN_NAME FROM PWI_ADMIN ORDER BY ADMIN_NAME");
if ($opt_all)
	{
	my $sql =  "delete from PWI_STATUS";
	&db_do($sql);
	$sql  = "insert into PWI_STATUS (uid,batchno,fullname) select distinct uid,batchno,fullname from MAP_CASES";
	$sql .= " where rolename='Self'";
	&db_do($sql);
	}
my $where = ($opt_only eq '') ? '' : "WHERE uid='$opt_only'";
my $SID;
if ($opt_seq ne '')
	{
	$SID = shift;
	my $sql = "SELECT UID,PWD FROM $SID where seq=?";
	my $th = &db_do($sql,$opt_seq);
	if (my @row = $th->fetchrow_array)
		{
		$where = "WHERE uid='$row[0]'";	
	}
	else
		{die "Fatal error: could not find record with seq=$opt_seq in $SID\n";}
	}
my $sql = "SELECT UID,PWD,SID FROM MAP_CASES $where ORDER BY UID,SID";
my $th = &db_do($sql);
my $tbl_ary_ref = $th->fetchall_arrayref;
$th->finish;
$dbt=1 if ($opt_t);
my $uid = 'BLANK';
my $pwd = '';
my $sid = '';
foreach my $aref (@${tbl_ary_ref})
	{
	my $nuid;
	($nuid,$pwd,$sid) = @{$aref};
	if ($nuid ne $uid)
		{
		if ($uid ne 'BLANK')		
			{
			update_it($uid);
			}
		$uid = $nuid;
		undef %cnt;
		}
	if ($sid eq $config{participant})
		{
		undef %ufields;
		my $ufile = "$qt_root/$config{participant}/web/u$pwd.pl";
#		print "Requiring file $ufile\n";
		my_require ("$ufile",0);
		$cnt{PWD} = $pwd;
		$cnt{CMS_FLAG} = $ufields{flag};
		$cnt{CMS_STATUS} = $ufields{cms_status};
		$cnt{LOCNAME} = $ufields{location};
		$cnt{LOCID} = uc($ufields{locationcode});
		$cnt{LOCID} = trim($cnt{LOCID});
		print "[W] location code [$cnt{LOCID}] is not in the database (id=$uid)\n" if (!$locations{$cnt{LOCID}}) && $opt_t;
		$cnt{EXECNAME} = $ufields{execname};
		$cnt{EXECNAME} =~ s/Tom Hawkins/Thomas Hawkins/i;
		$cnt{EXECNAME} =~ s/Thamas Hawkins/Thomas Hawkins/i;
		$cnt{EXECNAME} =~ s/F. Stanton Sipes/Stan Sipes/i;
		$cnt{EXECNAME} =~ s/Mike Stanko/Michael Stanko/i;
		$cnt{EXECNAME} =~ s/Edward Masters/Ed Masters/i;
		$cnt{EXECNAME} =~ s/Denny/Dennis/i;
		$cnt{EXECNAME} =~ s/^Terry$/Terry Ahern/i;
		print "[W] exec [$cnt{EXECNAME}] is not in the database (id=$uid)\n" if (!$execs{uc($cnt{EXECNAME})}) && $opt_t;
		print "[W] admin [$ufields{adminname}] is not in the database (id=$uid)\n" if (!$admins{uc($ufields{adminname})}) && $opt_t;
		$cnt{WSDATE_D} = '';
        $cnt{WSDATE} = $ufields{workshopdate};
#        $cnt{WSDATE} = $ufields{startdate} if ($cnt{WSDATE} eq '') && ($ufields{startdate} ne '');
        $cnt{WSDATE} = $1 if ($cnt{WSDATE} =~ /^\s*(\d+\/\d+\/\d+)/);
		my $date = &ParseDate($cnt{WSDATE});
		if ($date eq '')
			{
			print "WSDATE trying to fix WSDATE: $cnt{WSDATE} " if ($opt_t);
			$cnt{WSDATE} =~ s/Janaury/January/g;
			$cnt{WSDATE} =~ s/Apirl/April/g;
#			$cnt{WSDATE} =~ s/Hello, //g;
			$cnt{WSDATE} =~ s/\s*\-\s*\d+//;			# Try to get rid of date range 
			$cnt{WSDATE} =~ s/\s*\-\s*\D+\s+\d+//;			# Try to get rid of date range 
			$cnt{WSDATE} =~ s/\s+to.*$//;			# Try to get rid of date range 
			$date = &ParseDate($cnt{WSDATE});
			print "$cnt{WSDATE} => $date\n" if ($opt_t);
			}
		$cnt{WSDATE} = UnixDate($date,"20%y-%m-%d") if ($date ne '');
		$cnt{WSDATE_D} = UnixDate($date,"20%y-%m-%d") if ($date ne '');
# Do the same for DUEDATE
		$cnt{DUEDATE_D} = '';
		$cnt{DUEDATE} = $ufields{duedate};
		my $date = &ParseDate($cnt{DUEDATE});
		if ($date eq '')
			{
			print "DUEDATE trying to fix DUEDATE: $cnt{DUEDATE} " if ($opt_t);
			$cnt{DUEDATE} =~ s/Janaury/January/g;
			$cnt{DUEDATE} =~ s/Apirl/April/g;
#			$cnt{DUEDATE} =~ s/Hello, //g;
			$cnt{WSDATE} =~ s/\s*\-\s*\d+//;			# Try to get rid of date range 
			$cnt{DUEDATE} =~ s/\s*\-\s*\D+\s+\d+//;			# Try to get rid of date range 
			$cnt{DUEDATE} =~ s/\s*to.*$//;			# Try to get rid of date range 
			$date = &ParseDate($cnt{DUEDATE});
			print "$cnt{DUEDATE} => $date\n" if ($opt_t);
			}
		$cnt{DUEDATE} = UnixDate($date,"20%y-%m-%d") if ($date ne '');
		$cnt{DUEDATE_D} = UnixDate($date,"20%y-%m-%d") if ($date ne '');
		$cnt{FULLNAME} = qq{$ufields{id} $ufields{fullname}};
#
# Count the number of bosses:
#
		$cnt{NBOSS} = 0;
		for (my $i=1;$i<=$config{nboss};$i++)
			{
			my $bem = $ufields{"bossemail$i"};
#			print "$i $bem\n";
			$cnt{NBOSS}++ if ($ufields{"bossemail$i"} ne "");
			}
#
# Count the number of Peers:
#
		$cnt{NPEER} = 0;
		for (my $i=1;$i<=$config{npeer};$i++)
			{
			$cnt{NPEER}++ if ($ufields{"peeremail$i"} ne "");
			}
		}
	my $q = $sid2q{$sid};
	if ($q eq '')
		{
		print "Warning: Missing SID in local lookup table for $sid: ignoring\n" if ($warn{$sid} eq '');
		$warn{$sid}++;
		}
	else
		{
		my $sql = "SELECT STAT,SEQ,1 as APPROVED FROM $sid where SEQ>0 and UID=? and PWD=?"; 
		$sql = "SELECT STAT,SEQ,APPROVED FROM $sid where SEQ>0 and UID=? and PWD=?" if ($sid eq $config{peer});
		my $th = &db_do($sql,$uid,$pwd);
		my @statrow = $th->fetchrow();
		print "q=$q, sid=$sid, status=$statrow[0]\n" if ($opt_t);
		$cnt{$q} += 0;
#		$cnt{peer}++ if (($statrow[0] eq '4') && ($sid eq $config{peer}));
#		if (($statrow[0] eq '4') && ($statrow[2] eq '1'))
		if ($statrow[2] eq '1')		# Approved flag is all that counts here

			{
			$cnt{$q}++ ;
			$cnt{cnt}++ ;
			}
		if (($sid eq $config{hotel}) && ($statrow[1] ne ''))		# Is it Hotel booking with responses ?
			{
			my $dfile = "$qt_root/$sid/web/D$statrow[1].pl";
			print "Requiring file $dfile\n" if ($opt_t);
			my_require($dfile,1);
			foreach my $key (keys %lookup)
				{
				$cnt{$lookup{$key}} = $resp{$key};
				}
			if ($cnt{EARLY_ARRIVAL} =~ /^y/i)
				{
				my $adate = &ParseDate($cnt{WSDATE_D});
				my $adate = &DateCalc($adate,"-1d");
				$cnt{EARLY_ARRIVAL_DATE} = UnixDate($adate,"20%y-%m-%d");
				}
#			print "EARLY_ARRIVAL=$cnt{EARLY_ARRIVAL} ($cnt{EARLY_ARRIVAL_DATE} $cnt{WSDATE_D})\n";
			}
		$th->finish;
		}
	}
&update_it($uid);
&db_disc;
print "Finishing $SID\n" if ($opt_t);
#
# Here's a bit of a retro-fit... Look to see if this needs to be verbatims jammed together...
#
if ($SID eq 'MAP010') {
	my $cmd = qq{perl ../scripts/pwikit.jam.pl $uid};
	print "Running command [$cmd]\n" if ($opt_t);
	my $res = `$cmd`;
	print "... $res \n" if ($opt_t);
}
#
# Return true just in case we need it
#
1;
