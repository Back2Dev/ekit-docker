#!/usr/bin/perl
# $Id: pwicms_kickoff.pl,v 1.15 2012-11-07 00:26:27 triton Exp $
# Script to read participant/workshop data from the CMS system and process it
#
use strict;
use DBI;
use Date::Manip;							#perl2exe
use Getopt::Long;							#perl2exe
use TPerl::Error;		  					#perl2exe
use TPerl::TSV;								#perl2exe
use TPerl::MyDB;								#perl2exe

# Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

our $qt_root;
our $dbt;
our %config;
require 'TPerl/qt-libdb.pl';
require 'TPerl/360-lib.pl';
require 'TPerl/pwikit_cfg.pl';
$|=1;

eval("sub get_custom_new	{}");
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_limit,$opt_scan,$opt_complete,$opt_scheduled,
		$opt_reschedule,
		$opt_days,
		$opt_ahead,
		$opt_noemails,
		$opt_only,
		$opt_file,
		);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			'scan=i' => \$opt_scan,
			'limit=i' => \$opt_limit,
			'complete' => \$opt_complete,
			'scheduled' => \$opt_scheduled,
			'reschedule' => \$opt_reschedule,
			'days=i' => \$opt_days,
			'ahead=i' => \$opt_ahead,
			noemails => \$opt_noemails,
			'only=i' => \$opt_only,
			'file=s' => \$opt_file,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwicms_kickoff.pl,v 1.15 2012-11-07 00:26:27 triton Exp $'."\n";
	exit 0;
	}
$opt_days = 14 if (!$opt_days);
$opt_ahead = 42 if (!$opt_ahead);
our @selflist = @{$config{selflist}};

my $uploadsql = <<SQL;
    DROP TABLE EKIT_PAR_UPLOAD;
    CREATE TABLE EKIT_PAR_UPLOAD
        (
        ID            uniqueidentifier,
        CREATED_TS    INTEGER,
        RECORDS       INTEGER,
        TITLE         varchar(50),
        HTTP_STATUS   INTEGER,
        HTTP_BYTES    INTEGER,
        HTTP_MESSAGE  VARCHAR(500),
        FILENAME      varchar(50),
    
        PRIMARY KEY (ID)
        );
SQL

my $viewsql = <<SQL;
drop view vw_participant
create view VW_PARTICIPANT AS
  select 	
	cst1.cst_ref_no as 			id, 
	cst1.cst_salutation 		as salutation,
	cst1.cst_fname as 			firstname, 
	cst1.cst_lname as 			lastname,
	cst1.cst_sex as 			sex,
	cst1.cst_title as 			title,
	cst1.cst_email as 			email,
	com_name as 				company,
	par_status as 				cms_status, 

	boss.cst_fname as 			bossfirstname, 
	boss.cst_lname as 			bosslastname, 
	boss.cst_email as 			bossemail,

	wsh_start_date as 			startdate, 
	cst1.cst_last_update_dt as 	cst_last_update_dt,
	par_last_update_dt as 		par_last_update_dt,
	c.emp_fname + ' ' + c.emp_lname as 
								execname,
	htl_map_id as 				locationcode, 
	htl_name as 				location, 
	htl_address 				locationaddress,
	htl_city 					locationcity, 
	htl.sta_postal_abbrev as 	locationstate, 
    htr_package_rate as 		hotelrate

  from customer as cst1
	inner join customer_contact on cst1.cst_id = csc_cst_id and csc_end_date is null
	inner join customer_manager on cst1.cst_id = csm_cst_customer_id 
	inner join customer as boss on csm_cst_manager_id = boss.cst_id 
	inner join participant as a on cst1.cst_id = a.par_cst_id
	  and a.par_id = (select max(b.par_id)
				from participant as b
				where a.par_cst_id = b.par_cst_id)
	inner join company_classification on a.par_cls_id = cls_id
	inner join company on cst1.cst_com_id = com_id
	inner join workshop on a.par_wsh_id = wsh_id
	inner join hotel on wsh_htl_id = htl_id
	inner join employee as c on csc_eid_id = c.emp_eid_id
	  and c.emp_rev_id = (select max(d.emp_rev_id)
				from employee as d
				where c.emp_eid_id = d.emp_eid_id)
	inner join state_or_province as htl on htl_sta_id = htl.sta_id
    inner join hotel_rate on htl_id = htr_htl_id
    inner join rate_type on (htr_rty_id = rty_id
      and rty_id = 'rty000000001' 
      and htr_valid_from < wsh_start_Date
      and htr_valid_to > wsh_start_Date
      and htl_is_active = 'Y')
    
SQL

our @cmsdata = ();
if ($opt_file eq '')
	{
	@cmsdata = &read_cms_db;
	}
else
	{
	fatal("CMS Data file: $opt_file does not exist") unless -e $opt_file;
	my $tsv = new TPerl::TSV (file=>$opt_file);
	while (my $row = $tsv->row)
		{
		push @cmsdata,$row;
		}
	}

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
            
            'execname', 
            
			'cms_status',
			
			'startdate',
			'location',
			'locationcode',
			'locationaddress',
			'locationcity',
			'locationstate',
			'hotelrate',
			
			);

#
# List of boss field names from the query that we will process':
#
my @cms2boss = (
			'bossemail',
			'bosslastname',
			'bossfirstname',
			);	
#--------------------------------------------------------------------------------------
#
# Mainline starts here
#
#--------------------------------------------------------------------------------------
# First up, connect to our local database and cache the admin and exec tables:
print "Connecting to local database...";
our $dbh = dbh TPerl::MyDB() or die ("Could not connect to database :".DBI->errstr);
print "Connected OK\n";
my %admin2email = ();
my %admin2phone = ();
my %admin2fax = ();
my $sql = "SELECT ADMIN_NAME,ADMIN_EMAIL,ADMIN_PHONE,ADMIN_FAX from PWI_ADMIN";
my $th = &db_do($sql);
while (my @row = $th->fetchrow())
	{
	$admin2email{$row[0]} = $row[1];
	$admin2phone{$row[0]} = $row[2];
	$admin2fax{$row[0]} = $row[3];
	}
$th->finish;

my %exec2email = ();
my %exec2phone = ();
my %exec2fax = ();
my $sql = "SELECT EXEC_NAME,EXEC_EMAIL,EXEC_PHONE,EXEC_FAX from PWI_EXEC";
my $th = &db_do($sql);
while (my @row = $th->fetchrow())
	{
	$exec2email{$row[0]} = $row[1];
	$exec2phone{$row[0]} = $row[2];
	$exec2fax{$row[0]} = $row[3];
	}
$th->finish;

my %locid2fax = ();
my $sql = "SELECT LOC_ID,LOC_FAX FROM PWI_LOCATION WHERE LOC_ACTIVE=1";
my $th = &db_do($sql);
while (my @row = $th->fetchrow())
	{
	$locid2fax{$row[0]} = $row[1];
	}
$th->finish;
print "Cached admin and exec records OK\n";

my $nprocessed = 0;
my $currid = '';
our %ufields = ();
my $bossix = 1;

foreach my $href (@cmsdata)
    {
#	print join("\t",values %$href)."\n";
#
# Convert the data into our internal format:
#
	die "Record is missing id \n" if ($$href{id} eq '');
	if ($currid eq $$href{id})	# New record, or continuation ?
		{
		foreach my $key (@cms2boss)
			{
			my $bkey = qq{${key}$bossix};
			$ufields{$bkey} = $$href{$key};
			}
		$bossix++;
		}
	else
		{
		$bossix = 1;
		&process_data(\%ufields) if ($ufields{id} ne '');
		undef %ufields;
		$ufields{send_emails} = $config{send_emails} unless ($opt_noemails);
		my $date = &ParseDate($$href{startdate});
		$$href{startdate} = UnixDate($date,"%m/%d/20%y");
		$currid = $$href{id};
		foreach my $key (@cms2boss)
			{
			my $bkey = qq{{$key}$bossix};
			$ufields{$bkey} = $$href{$key};
			}
		$bossix++;
		foreach my $key (@cms2pwi)
			{
			$ufields{$key} = $$href{$key};
			}
# Now do custom fixing:
# Participant
		$ufields{gender} = (uc($$href{sex}) eq 'M') ? '1' : '2';

# Exec: !??? Keying off the exec name is risky here
		$ufields{execphone} = $exec2phone{$ufields{execname}};
		$ufields{execemail} = $exec2email{$ufields{execname}};
		$ufields{execfax} = $exec2fax{$ufields{execname}};
# Admin: !??? Keying off the admin name is risky here
		$ufields{adminphone} = $admin2phone{$ufields{adminname}};
		$ufields{adminemail} = $admin2email{$ufields{adminname}};
		$ufields{adminfax}   = $admin2fax{$ufields{adminname}};
		$ufields{returnfax} = $locid2fax{$ufields{locationcode}};
# Get workshop date, convert to a display format, and calculate day1/day2 and due/reminder1/2 dates
		my $datestr = $$href{startdate};
		$ufields{workshopdate} = format_wsdate($datestr);
		$datestr =~ s/\/20(\d\d)/\/$1/;
#		print "Parsing date: [$datestr]\n";
		my $date = &ParseDate($datestr);
		$ufields{day1} = UnixDate($date,"%A");
		my $date2=&Date_NextWorkDay($date,"1");
		$ufields{day2} = UnixDate($date2,"%A");
		my $date0=&Date_GetPrev($date,undef,2,"6:00");
		$ufields{dayprior} = UnixDate($date0,"%A");
		my $due=&DateCalc($date,"-3w");
		$ufields{duedate} = UnixDate($due,"%B %d, 20%y");
		my $due=&DateCalc($date,"-2w");
		$ufields{remdate1} = UnixDate($due,"%m/%d/20%y");
		my $due=&DateCalc($date,"-1w");
		$ufields{remdate2} = UnixDate($due,"%m/%d/20%y");
		}
	}
#print "Closing up...\n";
&process_data(\%ufields) if ($ufields{id} ne '');		# Catch the last one too
&db_disc;

#-------------------------------------------------------------------------------------
#
# Subroutines:
#
#-------------------------------------------------------------------------------------

sub process_data
	{
	if (($opt_limit) && ($nprocessed >= $opt_limit))
		{
		print "!";
		return 0;
		}
	$nprocessed++;
	print ".";
	my $uref = shift;
	print "Processing id=$$uref{id} $$uref{firstname} $$uref{lastname}\n";
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
	if (&db_user_exists($config{master},$$uref{id}))
		{
# User is already in the system, check and see if anything has changed:
		print "[I] ID $$uref{id} exists already\n";
		}
	else
		{
		print "[I] ID $$uref{id} is new\n";
		&new_participant($uref);
		}
	}

sub get_custom_new	{}
	
sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if $msg;
	print <<USAGE;
Usage: $0 [-version] [-debug] [-help] [scan=n] [-limit=n] [-scheduled | -complete | -reschedule] [-days=n] [-noemails] [-file=filename]
	-help Display help
	-version - Display version no
	-scan=n - Limits number of records to be scanned this pass
	-limit=n - Limits number of records to be process this pass
	-scheduled - Only look at participants that are Scheduled to attend
	-complete - Only look at participants that have completed the workshop
	-reschedule - Only look at participants that have been Re-scheduled 
	-days=n - Look for participants in workshops starting n days from now (default=14)
	-ahead=n - Max days ahead for participants in workshops (default=42 [6 weeks])
	-noemails - Don't send emails
	-file=filename - read from Tab separated file instead of from SQL Server database	
USAGE
	exit 0;
	}

sub read_cms_db
	{
	my $msdbh = dbh TPerl::MyDB(db=>'mssql') or die ("Could not connect to database :".DBI->errstr);
	print "Connected to CMS DB OK\n";
	# Are we filtering the requests ?
	my $where = qq{startdate>getdate()+$opt_days};
	$where .= qq{ and startdate<getdate()+$opt_ahead} if ($opt_ahead);
	$where .= qq{ AND par_status='C'} if ($opt_complete);
	$where .= qq{ AND par_status='R'} if ($opt_reschedule);
	$where .= qq{ AND par_status='S'} if ($opt_scheduled);
	$where = qq{id=$opt_only} if ($opt_only);
	my $sql = <<SQL;
	select * from VW_PARTICIPANT
		WHERE 
		$where
		ORDER BY ID
SQL
	print "mssql=$sql\n" if ($opt_t);
	my $msth = $msdbh->prepare($sql);
	my @localdata = ();
	$msth->execute;
	my $rowcnt = 0;
	open (CMS,">cmsdata.txt") || die "Error $! encountered while writing to file cmsdata.txt\n";
	while (my $href = $msth->fetchrow_hashref)
		{
		if ($rowcnt == 0)
			{
			print CMS join("\t",keys %$href)."\n";
			}
		print CMS join("\t",values %$href)."\n";
	    push @localdata,$href;
	    $rowcnt++;
	    last if ($rowcnt >= $opt_scan) && $opt_scan;
	    }
	$msth->finish;
	$msdbh->disconnect;
	close(CMS);
	@localdata;
	}
