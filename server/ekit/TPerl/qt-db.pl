#!/usr/bin/perl
## $Id: qt-db.pl,v 2.13 2012-08-14 22:25:24 triton Exp $
#
# Library for Triton database access
#
use DBI;
#
#---------------------------------------------------------------------------
#
# Event code definitions:
#
use constant EVENT_UNKNOWN => 0;
# Email related stuff
use constant EVENT_SEND_BATCH			=> 13;
use constant EVENT_DELETE_BATCH			=> 14;
use constant EVENT_DEL_RECIPIENT		=> 15;
use constant EVENT_PREP_BATCH			=> 17;
use constant EVENT_ADD_RECIPIENT		=> 18;
use constant EVENT_RESET_RECIPIENT		=> 19;
use constant EVENT_SEND_EMAIL			=> 20;
use constant EVENT_SEND_REMINDER		=> 21;
use constant EVENT_SEND_FAX				=> 22;
use constant EVENT_REJECT_RECIPIENT		=> 23;
use constant EVENT_PREP_REMINDER		=> 24;
# Survey related stuff                   
use constant EVENT_SURVEY_START			=> 33;
use constant EVENT_SURVEY_SAVE			=> 34;
use constant EVENT_SURVEY_RESUME		=> 35;
use constant EVENT_SURVEY_FINISH		=> 36;
use constant EVENT_SURVEY_TERMINATE		=> 37;
# File upload stuff                      
use constant EVENT_FILE_UPLOAD			=> 65;
use constant EVENT_FILE_EXTRA_INFO		=> 66;
# Internal database operations           
use constant EVENT_DB_CREATE_TABLE		=> 129;
use constant EVENT_DB_DROP_TABLE		=> 130;
use constant EVENT_DB_EMPTY_TABLE		=> 131;
use constant EVENT_DB_ALTER_TABLE		=> 132;

#
#---------------------------------------------------------------------------
#
# SQL Table creation statements
#
#$dbt = 1;

my $SQL_CREATE_EVENTLOG = <<SQL;
CREATE TABLE EVENTLOG (
	SID VARCHAR(10) NOT NULL,
	TS INTEGER NOT NULL, 
	EVENT_CODE INTEGER NOT NULL,
	SEVERITY CHAR(1) NOT NULL,
	WHO VARCHAR(10) NOT NULL,
	CAPTION VARCHAR(200),
	BROWSER     VARCHAR(12),
	BROWSER_VER VARCHAR(8),
	OS          VARCHAR(12),
	OS_VER      VARCHAR(8),
	IPADDR      VARCHAR(15),
	PWD         VARCHAR(12),
	EMAIL       VARCHAR(80),
    YR  		INTEGER ,
    MON 		INTEGER ,
    MDAY		INTEGER ,
    HR  		INTEGER ,
    MINS		INTEGER
	)
SQL

my $SQL_CREATE_SURVEY = <<SQL;
	CREATE TABLE SURVEY (
		KEYVAL INTEGER NOT NULL PRIMARY KEY, 
		SID VARCHAR(10),
		STAT INTEGER,
		START INTEGER,
		CLOSE INTEGER)
SQL

my $SQL_CREATE_REMINDER = <<SQL;
	create TABLE REMINDER
	( KEYVAL INTEGER NOT NULL PRIMARY KEY,
	SURVEY_REF INTEGER NOT NULL,
	ABS_TS INTEGER,
	DELTA_TIME INTEGER,
	FILENAME VARCHAR(50),
	STAT INTEGER NOT NULL
	)
SQL

my $SQL_CREATE_EMAIL_SEQ = <<SQL;
	CREATE TABLE EMAIL_SEQ (
		TS INTEGER NOT NULL, 
		SEQ BIGINT)
SQL

my $SQL_CREATE_EMAIL_LOG = <<SQL;
	CREATE TABLE EMAIL_LOG (
		TS INTEGER NOT NULL, 
		TSS TIMESTAMP, 
		RTYPE VARCHAR(2),
		SID VARCHAR(10), 
		PWD VARCHAR(12), 
		IPADDR VARCHAR(40),
		IPNAME VARCHAR(50),
		USER_AGENT VARCHAR(60))
SQL

my $SQL_CREATE_UFIELD = <<SQL;
	CREATE TABLE UFIELD (
		KEYVAL INTEGER NOT NULL PRIMARY KEY,
		SURVEY_REF INTEGER NOT NULL,
		SID VARCHAR(10), 
		FNAME VARCHAR(15), 
		FTYPE VARCHAR(10),
		FLEN INTEGER)
SQL
#---------------------------------------------------------------------------
#
# Add event to log
#
# Example: 
# &db_add_info_event('NCM110',1,'mikkel','Created new user',[$pwd]);
#
sub db_add_info_event
	{
	&db_add_event('I',@_);
	}
sub db_add_warn_event
	{
	&db_add_event('W',@_);
	}
sub db_add_error_event
	{
	&db_add_event('E',@_);
	}
sub db_add_fatal_event
	{
	&db_add_event('F',@_);
	}
#---------------------------------------------------------------------------
#
# Don't call this one directly...
#
sub db_add_event
	{
	my $severity = shift;
	die "Eventlog: no severity code specified" if ($severity eq '');
	my $sid = shift;
	die "Eventlog: no survey ID specified" if ($sid eq '');
	my $ts = time();
	my ($sec,$mins,$hr,$mday,$mon,$yr,$wday,$yday,$isdst) = localtime($ts);
	$yr += 1900;
	$mon++;
	my $event_code = shift;
	die "Eventlog: no event code specified" if ($event_code eq '');
	my $who = shift;
	die "Eventlog: no name specified" if ($who eq '');
	my $caption = shift;
	my $pwd = shift;
#	$caption =~ s/\\'/'/g;		# Force Escaped quotes => Single
#	$caption =~ s/''/'/g;		# Force double quotes => Single
#	$caption =~ s/'/''/g;		# Force single quotes => Double
#	$caption =~ s/\\/\//g;		# Force back-slash => forward slash

	die "Eventlog: no caption specified" if ($caption eq '');
#
# OK we're ready !
#
	my @params = ($sid,$ts,$event_code,$severity,$pwd,$who,$caption,$hr,$mins,$mon,$mday,$yr);
	my $table = ($sid ne 'NA') ? "${sid}_E" : "EVENTLOG";
	my $sql = "INSERT INTO $table (SID,TS,EVENT_CODE,SEVERITY,PWD,WHO,CAPTION,HR,MINS,MON,MDAY,YR) ";
	$sql .= "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";
	&db_do($sql,@params);
	}
#---------------------------------------------------------------------------
#
# Connect to database
#
sub db_conn
	{
	my $db = shift;
	my $ret = 1;
	if ($db_isib)
		{
		if ($db_odbc)
			{
			print "Connecting to triton database using ODBC\n" if ($dbt);
			if (!($dbh = DBI->connect("dbi:ODBC:$odbc_db_file","$odbc_db_user","odbc_db_password")))
				{
				&my_die ("Cannot connect to IB/ODBC database: $DBI::errstr\n");
				$ret = 0;
				}
			}
		else
			{
			print "Connecting to triton.gdb\n" if ($dbt);
			if (!($dbh = DBI->connect("dbi:InterBase:database=$ib_db_file","$ib_db_user","$ib_db_password")))
				{
				&my_die ("Cannot connect to IB database: $DBI::errstr\n");
				$ret = 0;
				}
			}
		}
	else
		{
		print "Connecting to triton database using MySql: $mysql_db_file, user=$mysql_db_user\n" if ($dbt);
		if (!($dbh = DBI->connect("dbi:mysql:database=$mysql_db_file","$mysql_db_user","$mysql_db_password",{ PrintError => 0, RaiseError => 0, FetchHashKeyName => 'NAME_uc' })))
			{
			&my_die ("Cannot connect to MySQL database ($mysql_db_file) : $DBI::err $DBI::errstr\n");
			$ret = 0;
			}
		}
#
# Make sure key tables exist in database
#
	&db_base_tables;
	$ret;
	}
#---------------------------------------------------------------------------
#
# Connect a second cursor for iteration work
#
sub db_conn2
	{
	my $ret = 1;
	if ($db_isib)
		{
		print "Connecting to triton.gdb\n" if ($dbt);
		if (!($dbh2 = DBI->connect("dbi:InterBase:database=$ib_db_file","$ib_db_user","$ib_db_password")))
			{
			&my_die ("Cannot connect to database: $DBI::errstr\n");
			$ret = 0;
			}
		}
	else
		{
		if (!($dbh2 = DBI->connect("dbi:mysql:database=$mysql_db_file","$mysql_db_user","$mysql_db_password",{ PrintError => 0, RaiseError => 0, FetchHashKeyName => 'NAME_uc'})))
			{
			&my_die ("Cannot connect to database: $DBI::errstr\n");
			$ret = 0;
			}
		}
	$ret;
	}
#---------------------------------------------------------------------------
#
# Create tables in database
#
sub db_base_tables
	{
	&db_mk_table("EVENTLOG",$SQL_CREATE_EVENTLOG);
	&db_mk_table("UFIELD",$SQL_CREATE_UFIELD);
	}

sub db_remk_table
	{
	my $tablename = uc(shift);
	my $cresql = shift;
	if ($db_isib)			# Interbase specific stuff
		{
		my $sql = "SELECT RDB\$RELATION_NAME FROM RDB\$RELATIONS WHERE RDB\$RELATION_NAME='$tablename'";
		&db_do($sql);
		my @row;
		@row = $th->fetchrow_array();
		$th->finish;
		if ($row[0] ne '')
			{
			my $dropsql = "DROP TABLE $tablename";
			&db_do($dropsql);
			}
		&db_do($cresql);
		&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: $tablename");
		}
	else
		{
		my $sql = "SHOW TABLES";			# MySQL specific stuff
		&db_do($sql);
		my $found = 0;
		while (my @row = $th->fetchrow_array())
			{
			$found = 1 if (lc($row[0]) eq lc($tablename));		# MySQL table names are case insensitive.
			}
		$th->finish;
		if ($found)
			{
			my $dropsql = "DROP TABLE $tablename";
			&db_do($dropsql);
			}
		&db_do($cresql);
		&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: $tablename");
		}
	}
	
sub db_mk_table
	{
	my $tablename = uc(shift);
	my $cresql = shift;
	if ($db_isib)			# Interbase specific stuff
		{
		my $sql = "SELECT RDB\$RELATION_NAME FROM RDB\$RELATIONS WHERE RDB\$RELATION_NAME='$tablename'";
		&db_do($sql);
		my @row;
		@row = $th->fetchrow_array();
		$th->finish;
		if ($row[0] eq '')
			{
			&db_do($cresql);
			&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: $tablename");
			}
		}
	else
		{
		my $sql = "SHOW TABLES";			# MySQL specific stuff
		&db_do($sql);
		my $found = 0;
		while (my @row = $th->fetchrow_array())
			{
			$found = 1 if (lc($row[0]) eq lc($tablename));		# MySQL table names are case insensitive.
			}
		$th->finish;
		if (!$found)
			{
			&db_do($cresql);
			&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: $tablename");
			}
		}
	}
#---------------------------------------------------------------------------
#
# Execute a SQL statement
#
sub db_do
	{
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = shift;
	my @params = @_;
#	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	print "Preparing SQL statement[$mysub]: [$sql]".join(",",@params)."\n" if ($dbt);
	$th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th->execute(@params) || die "Cannot execute SQL statement: $DBI::errstr\n";
	$th;
	}

sub db_do_new
	{
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = shift;
	my @params = @_;
	print "Preparing SQL statement[$mysub]: [$sql]".join(",",@params)."\n" if ($dbt);
	$th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th->execute(@params) || die "Cannot execute SQL statement: $DBI::errstr $sql\n";
	$th;
	}
#
# Same as above, just uses another handle, so we can iterate on both cursors
#
sub db_do2
	{
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = shift;
	my @params = @_;
	print "Preparing SQL statement[$mysub]: [$sql]".join(",",@params)."\n" if ($dbt);
	$th2 = $dbh2->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th2->execute(@params) || die "Cannot execute SQL statement: $DBI::errstr\n";
	$th2;
	}
#---------------------------------------------------------------------------
#
# Raw 'GET ME SOME DATA' command 
#
sub db_sql_get
	{
	my $sql = shift;
	&db_do($sql);
	my @row = $th->fetchrow_array();
	@row;						# Just pass back whatever we get 
	}
	
#---------------------------------------------------------------------------
#
# Prepare SQL statement
#
sub db_prep
	{
	print "Preparing SQL statement\n" if ($dbt);
	$th = $dbh->prepare("SELECT * FROM NCM108") || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th->execute || die "Cannot execute SQL statement: $DBI::errstr\n";
	}
#---------------------------------------------------------------------------
#
# Fetch data
#
sub db_fetch
	{
	my $loopcnt = 0;
	my @row;
	while (my @row = $th->fetchrow_array())
		{
		print "Row: @row\n" if ($dbt);
		$loopcnt++;
		if ($loopcnt > 500)
			{
			print "Fetched 500 rows, aborting\n";
			last;
			}
		}
	$th->finish;
	}
#---------------------------------------------------------------------------
#
# Disconnect from database
#
sub db_disc
	{
	$dbh->disconnect || warn "Error disconnecting from database: $DBI::errstr\n";
	undef $dbh;
	}
sub db_disc2
	{
	$dbh2->disconnect || warn "Error disconnecting from database: $DBI::errstr\n";
	undef $dbh2;
	}
#---------------------------------------------------------------------------
#
# Case details
#
sub db_add_invite
	{
	my $job = uc(shift);		# Get the job name here
	$job .= "_CASES" if (!($job =~ /_CASES/i));
	my $case = shift;
	my $sid = shift;
	my $uid = shift;
	my $pwd = shift;
	my $fullname = shift;
	my $role = shift;
	my $batchno = shift;
	my $sort_order = shift;
	my $sql = "INSERT INTO ${job} (CASENAME, SID, UID, PWD, FULLNAME, ROLENAME, BATCHNO, SORT_ORDER) ";
	$sql .= 'VALUES (?,?,?,?,?,?,?,?)';
	&db_do_new($sql,$case,$sid,$uid,$pwd,$fullname,$role,$batchno,$sort_order);
	}
#
# Delete invitation record
#
sub db_del_invite
	{
	my $job = uc(shift);		# Get the job name here
	$job .= "_CASES" if (!($job =~ /_CASES/i));
	my $sid = shift;
	my $uid = shift;
	my $pwd = shift;
	my $sql = "DELETE FROM ${job} WHERE SID=? AND uid=? AND pwd=?";
	&db_do_new($sql,$sid,$uid,$pwd);
	}
#
# Get Case details
#
sub db_get_case
	{
	my $job = uc(shift);		# Get the job name here
	$job .= "_CASES" if (!($job =~ /_CASES/i));
	my $sid = shift;
	my $uid = shift;
	my $sql = "SELECT PWD,FULLNAME FROM ${job} WHERE SID=? AND UID=?";
	&db_do_new($sql,$sid,$uid);
	my @row;
	@row = $th->fetchrow_array();
	$th->finish;	# Be defensive
	my $pwd = $row[0];
	my $fullname = $row[1];
	($pwd,$fullname);
	}

#		$pwd = &db_case_id_name_role('map','MAP010',$id,$name,'KP');
sub db_case_id_name_role
	{
	my $job = uc(shift);		# Get the job name here
	$job .= "_CASES" if (!($job =~ /_CASES/i));
	my $sid = shift;
	my $id = shift;
	my $name = shift;
	my $role = shift;
	my $sql = "SELECT PWD FROM ${job} WHERE SID=? AND uid=? AND FULLNAME=? AND ROLENAME=?";
	&db_do_new($sql,$sid,$id,$name,$role);
	my @row;
	@row = $th->fetchrow_array();
	$th->finish;	# Be defensive
	my $pwd = $row[0];
	$pwd;
	}

sub db_case_update_names
	{
	my $job = uc(shift);		# Get the job name here
	my $uid = shift;
	$job .= "_CASES" if (!($job =~ /_CASES/i));
	my $sql = qq{select SID,PWD,FULLNAME from $job where UID=?};
	&db_do_new($sql,$uid);
	my %sids = ();
	my %fnames = ();
	while (my @row = $th->fetchrow_array())
		{
		$sids{$row[0]} = $row[1];	# Save the password
		$fnames{$row[0]} = $row[2];	# Save the full name
		}
	$th->finish();
	foreach my $sid (keys %sids)
		{
		my $sql = "UPDATE $sid set fullname=? where uid=? and pwd=?";
		&db_do_new($sql,$fnames{$sid},$uid,$sids{$sid});
		$th->finish();
		}
	}

#---------------------------------------------------------------------------
#
# Update status value
#
sub db_set_status
	{
	my $sid = shift;
	my $uid = shift;
	my $pwd = shift;
	my $stat = shift;
	my $seq = shift;
	my $no_uid = shift;

	$seq = undef if ($seq eq '');
	
	my $evt = EVENT_SURVEY_START;
	$evt = EVENT_SURVEY_TERMINATE if ($stat == 2);
	$evt = EVENT_SURVEY_FINISH if ($stat == 4);
	&db_add_info_event($sid,$evt,'user',"Set status=$stat for id=$uid, pwd=$pwd",$pwd);
	my @params = ($pwd);
	my $where = "WHERE PWD=? ";
	if (!$no_uid)
		{
		$where .= " AND  UID=?";
		push @params,$uid; 
		}
	my $sql = "SELECT PWD FROM $sid $where";
	&db_do_new($sql,@params);
	my @row;
	@row = $th->fetchrow_array();
	$th->finish;
	if ($row[0] ne '')
		{
		my $sql = "UPDATE $sid SET STAT=?,SEQ=? $where";
		my @params = ($stat,$seq,$pwd);
		push @params,$uid if (!$no_uid);
		&db_do_new($sql,@params);
		}
	else
		{
#		my $sql = "INSERT INTO $sid (UID,PWD,STAT,SEQ) VALUES ('$uid','$pwd',0,$seq)";
		$uid = '' if (!defined $uid);	# Stop it from being null
		my $sql = "INSERT INTO $sid (UID,PWD,STAT,SEQ) VALUES (?,?,?,?)";
		&db_do_new($sql,$uid,$pwd,$stat,$seq);
		}
	}
#---------------------------------------------------------------------------
#
# Set database status for Ivor record:-
#
sub db_set_ivor_status
	{
	my $sid = shift;
	my $seq = shift;
	my $stat = shift;
	my $int_no = shift;
	
	my $sql = "UPDATE ${sid}_CASE SET STAT=?,IVSTAT=? WHERE SEQ=?";
	my @params = ($stat);
# PROBABLY NEED TO TRANSLATE THESE STRINGS...
	my %status_names = (
					1 => 'Refused',
					2 => 'Terminated',
					3 => 'In Progress',
					4 => 'Self-edit',
					5 => 'Edit/Review',
					6 => 'Re-contact',
					7 => 'Final',
					8 => 'Deleted',
					);
	my $ivstat = 'UNKNOWN';
	$ivstat = $status_names{$stat} if ($status_names{$stat} ne '');
	die ("Missing seqno in db_set_ivor_status (sid=$sid, status=$stat\n") if ($seq eq '');
	push @params,$ivstat;
	if ($int_no ne '')
		{
		push @params,$int_no;
		$sql = "UPDATE ${sid}_CASE SET STAT=?,IVSTAT=?,INT_NO=? WHERE SEQ=?";
		}
	push @params,$seq;
	&db_do($sql,@params);
	}

#
# Get database status for Ivor record:-
#
sub db_get_ivor_status
	{
	my $sid = shift;
	my $fam_pers = shift;
	
	my $sql = "SELECT IVSTAT,FAM_PERS,INT_NO,SEQ,STARTTIME,ENDTIME,VER,CNT FROM ${sid}_CASE WHERE FAM_PERS=? ORDER BY ENDTIME";
	my @params = ($fam_pers);
	die ("Missing fam_no/id_no in db_get_ivor_status (sid=$sid)\n") if ($fam_pers eq '');
	&db_do($sql,@params);
	}

	
#---------------------------------------------------------------------------
#
# Add a new password
#
sub db_add_pwd
	{
	my $sid = shift;
	my $pwd = shift;
	my $batch_no = shift;
	my $email = shift;
	my $fullname = shift;
	my $uid=shift;
#	
# Protect our own ass by making sure the fullname is clean !
#
	$fullname =~ s/\\'/'/g;		# Force Escaped quotes => Single
	$fullname =~ s/''/'/g;		# Force double quotes => Single
	$fullname =~ s/'/''/g;		# Force single quotes => Double
	$email =~ s/\\'/'/g;		# Force Escaped quotes => Single
	$email =~ s/''/'/g;		# Force double quotes => Single
	$email =~ s/'/''/g;		# Force single quotes => Double
	my $sql = "SELECT PWD FROM $sid WHERE PWD=?";
	&db_do_new($sql,$pwd);
	my @row;
	@row = $th->fetchrow_array();
	$th->finish;
	if ($row[0] eq '')
		{
		&db_add_info_event($sid,EVENT_ADD_RECIPIENT,'system',"Adding password $pwd",$pwd);
		my $sql = "INSERT INTO $sid (PWD,UID,STAT,BATCHNO,EMAIL,FULLNAME,TS) VALUES (?,?,?,?,?,?,?)";
		$uid = '' if (!defined $uid);	# Stop it from being null
		&db_do_new($sql,$pwd,$uid,0,$batch_no,$email,$fullname,time());
		}
	else
		{
		&db_add_info_event($sid,EVENT_RESET_RECIPIENT,'system',"Reset status for $pwd ",$pwd);
		my $sql = "UPDATE $sid SET uid=?,STAT=0,BATCHNO=?,email=?,fullname=? WHERE PWD=?";
		&db_do_new($sql,$uid,$batch_no,$email,$fullname,$pwd);
		}
	}
#---------------------------------------------------------------------------
#
# Delete by id
#
sub db_reverse_id
	{
	my $sid = shift;
	my $uid = shift;
#	
# Short and sweet, like most terminations are
#
	if ($uid ne '')
		{
		&db_add_info_event($sid,EVENT_DEL_RECIPIENT,'system',"Deleting id $uid");
		my $sql = "DELETE FROM $sid WHERE UID=?";
		&db_do_new($sql,$uid);
		}
	}

#---------------------------------------------------------------------------
#
# Save new password to database
#
sub db_save_pwd
	{
	my $sid = shift;
	my $uid = shift;
	my $pwd = shift;
	my $sql = "SELECT PWD FROM $sid WHERE PWD=? AND UID=?";
	&db_do_new($sql,$pwd,$uid);
	my @row = $th->fetchrow_array();
	$th->finish;
	if ($row[0] eq '')
		{
		$uid = '' if (!defined $uid);	# Stop it from being null
		$sql = "INSERT INTO $sid (UID,PWD,STAT,REMINDERS) VALUES (?,?,?,?)";
		&db_do_new($sql,$uid,$pwd,0,0);
		}
	else
		{
		print "Error: User/Password $uid/$pwd already exists for survey: $sid \n";
		}
	}
#---------------------------------------------------------------------------
#
# Save all password details (inc name)
#
sub db_save_pwd_full
	{
	my $sid = shift;
	my $uid = shift;
	my $pwd = shift;
	my $fullname = shift;
	my $delta = shift;
	my $bat = shift;
	$bat = 0 if ($bat eq '');
	my $em = shift;
	my $tim = time();
	my $expires = $tim + $delta;
# I don't think we need to do this any more, as the DBI should do it for us.
	$fullname =~ s/\\'/'/g;		# Force Escaped quotes => Single
	$fullname =~ s/''/'/g;		# Force double quotes => Single
	$fullname =~ s/'/''/g;		# Force single quotes => Double
	$uid = '' if (!defined $uid);	# Stop it from being null
	my $sql = "INSERT INTO $sid (UID,PWD,STAT,FULLNAME,TS,EXPIRES,REMINDERS,BATCHNO,EMAIL) ";
	$sql .= ' VALUES (?,?,?,?,?,?,?,?,?)';
	&db_do_new($sql,$uid,$pwd,0,$fullname,$tim,$expires,0,$bat,$em);
	}
#---------------------------------------------------------------------------
#
# Save extra info
#
sub db_save_extras
	{
	my $sid = shift;
	my $pwd = shift;
	my $extras = shift;			# This parameter is a reference to a hash containing the data to be updated
	my @params = ();
	my $vals = "";
	my $i = 0;
	foreach my $field (keys %{$extras})
		{
		$vals .= "," if ($i++ > 0);
		push @params,$$extras{$field};
		$vals .= "$field = ?";
		}
	my $sql = qq{UPDATE $sid SET $vals WHERE PWD='$pwd'};
	&db_do_new($sql,@params);
	}

sub db_save_extras_uid
	{
	my $sid = shift;
	my $uid = shift;
	my $extras = shift;
	my @params = ();
	my $vals = "";
	my $i = 0;
	foreach my $field (keys %{$extras})
		{
		$vals .= "," if ($i++ > 0);
		push @params,$$extras{$field};
		$vals .= "$field = ?";
		}
	my $sql = qq{UPDATE $sid SET $vals WHERE UID='$uid'};
	&db_do_new($sql,@params);
	}
#---------------------------------------------------------------------------
#
# Get the next unique password
#
sub db_getnextpwd
	{
	my $sid = shift;
	&db_new_survey($sid);
	my $unique = 0;
	my $loopcnt = 0;
	my $newpwd = '';
	while (!$unique)
		{
		$newpwd = &pw_generate;                   # What the user must type in
		my $sql = "SELECT COUNT(*) FROM $sid WHERE PWD=?";
		&db_do_new($sql,$newpwd);
		while (my @row = $th->fetchrow_array())
			{
			$unique = 1 if ($row[0] eq "0");
			}
		$th->finish;
		$loopcnt++;
		if ($loopcnt > 100)
			{
			$newpwd = 'FAILED TO FIND UNIQUE PASSWORD';
			last;
			}
		}
	$newpwd;
	}

#---------------------------------------------------------------------------
#
# return the next email sequence number
#
sub db_get_email_seq
	{
	my $ts = time();
	my $sql = "SELECT * FROM EMAIL_SEQ ";
	&db_do($sql);
	my @row;
	@row = $th->fetchrow_array();
	$th->finish;
	my $seq = 0;
	if ($row[1] eq '') 
		{
		$seq = 100;
		$ts = 0;
		$sql = "INSERT INTO EMAIL_SEQ VALUES(?,?)";
		&db_do_new($sql,$ts,$seq);
		}
	else
		{
		$ts = $row[0];
		$seq = $row[1];
		}
	($ts,$seq);
	}

#---------------------------------------------------------------------------
#
# Create a new table for a email read logs
#
sub db_new_emaillog
	{
	if ($db_isib)			# Interbase specific stuff
		{
		my $sql = "SELECT RDB\$RELATION_NAME FROM RDB\$RELATIONS WHERE RDB\$RELATION_NAME='EMAIL_LOG'";
		&db_do($sql);
		my @row;
		@row = $th->fetchrow_array();
		$th->finish;
		if ($row[0] eq '')
			{
			my $sql = $SQL_CREATE_EMAIL_LOG;
	
			&db_do($sql);
			}
		$sql = "SELECT RDB\$RELATION_NAME FROM RDB\$RELATIONS WHERE RDB\$RELATION_NAME='EMAIL_SEQ'";
		&db_do($sql);
		@row = $th->fetchrow_array();
		$th->finish;
		if ($row[0] eq '')
			{
			my $sql = $SQL_CREATE_EMAIL_SEQ;
			&db_do($sql);
			}
		}
	else
		{
		my $sql = "SHOW TABLES";			# MySQL specific stuff
		&db_do($sql);
		my $found_seq = 0;
		my $found_log = 0;
		while (my @row = $th->fetchrow_array())
			{
			$found_seq = 1 if ($row[0] eq "EMAIL_SEQ");
			$found_log = 1 if ($row[0] eq "EMAIL_LOG");
			}
		$th->finish;
		&db_do($SQL_CREATE_EMAIL_SEQ) if (!$found_seq);
		&db_do($SQL_CREATE_EMAIL_LOG) if (!$found_log);
		}
	}
#---------------------------------------------------------------------------
#
#
# Add user fields for a survey
#
sub db_add_ufields
	{
	my $sid = shift;
#	
	my $sql = "SELECT FNAME,FTYPE,FLEN FROM UFIELD WHERE SID=?";
	&db_do_new($sql,$sid);
#
	my @cmds = ();
	while (my @row = $th->fetchrow_array())
		{
		my $type = ($row[1] eq 'VARCHAR') ? "$row[1]($row[2])" : $row[1] ;
		my $altersql = "ALTER TABLE $sid ADD $row[0] $type";
		push (@cmds,$altersql);
		}
	$th->finish;
#
# We have pulled out the ALTER commands, let them fly now !
#
	foreach $sql (@cmds)
		{
		&db_do($sql);
		}
	}
#---------------------------------------------------------------------------
#
# Create a new table for a survey
#
sub db_new_survey
	{
	my $sid = uc(shift);
	my $cresql = <<SQL;
		CREATE TABLE $sid (
			PWD VARCHAR(12) NOT NULL PRIMARY KEY,
			UID VARCHAR(50),
			stat INTEGER,
			FULLNAME VARCHAR(60),
			TS INTEGER, 
			EXPIRES INTEGER,
			SEQ INTEGER, 
			REMINDERS INTEGER, 
			EMAIL VARCHAR(80), 
			BATCHNO INTEGER  
			)
SQL
	my $cre_evt_sql = <<SQL;
        CREATE TABLE ${sid}_E (
            SID                             VARCHAR(10) Not Null ,
            TS                              INTEGER Not Null ,
            EVENT_CODE                      INTEGER Not Null ,
            SEVERITY                        CHAR(1) Not Null ,
            WHO                             VARCHAR(10) Not Null ,
            CAPTION                         VARCHAR(200) ,
            BROWSER                         VARCHAR(12) ,
            BROWSER_VER                     VARCHAR(8) ,
            OS                              VARCHAR(12) ,
            OS_VER                          VARCHAR(8) ,
            IPADDR                          VARCHAR(15) ,
            PWD                             VARCHAR(12) ,
            EMAIL                           VARCHAR(80) ,
            YR                              INTEGER ,
            MON                             INTEGER ,
            MDAY                            INTEGER ,
            HR                              INTEGER ,
            MINS                            INTEGER
        )
SQL
	if ($db_isib)			# Interbase specific stuff
		{
		my $sql = "SELECT RDB\$RELATION_NAME FROM RDB\$RELATIONS WHERE RDB\$RELATION_NAME='$sid'";
		&db_do($sql);
		my @row;
		@row = $th->fetchrow_array();
		$th->finish;
		if ($row[0] eq '')
			{
			&db_do($cresql);
			&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: $sid");
			&db_add_ufields($sid);
			}
		$sql = "SELECT RDB\$RELATION_NAME FROM RDB\$RELATIONS WHERE RDB\$RELATION_NAME='${sid}_E'";
		&db_do($sql);
		@row = $th->fetchrow_array();
		$th->finish;
		if ($row[0] eq '')
			{
			&db_do($cre_evt_sql);
			&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: ${sid}_E");
			}
		}
	else
		{
		my $sql = "SHOW TABLES";			# MySQL specific stuff
		&db_do($sql);
		my $found = 0;
		while (my @row = $th->fetchrow_array())
			{
			$found = 1 if (lc($row[0]) eq lc($sid));		# MySQL table names are case insensitive.
			}
		$th->finish;
		if (!$found)
			{
			&db_do($cresql);
			&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: $sid");
			&db_add_ufields($sid);
			}
		&db_do($sql);
		$found = 0;
		while (my @row = $th->fetchrow_array())
			{
			$found = 1 if (lc($row[0]) eq lc("${sid}_E"));		# MySQL table names are case insensitive.
			}
		$th->finish;
		if (!$found)
			{
			&db_do($cre_evt_sql);
			&db_add_info_event('NA',EVENT_DB_CREATE_TABLE,'system',"Created new table: ${sid}_E");
			}
		}
	}
#---------------------------------------------------------------------------
#
# Create a new table for cases
#
sub db_new_case
	{
	my $job = shift;		# Get the job name here
	$job .= "_CASES" if (!($job =~ /_CASES/i));
	my $tablename = uc($job);
	my $cresql = "CREATE TABLE $tablename (CASENAME VARCHAR(12) NOT NULL, SID VARCHAR(10) NOT NULL,UID VARCHAR(50), PWD VARCHAR(12),FULLNAME VARCHAR(40), ROLENAME VARCHAR(20) NOT NULL, BATCHNO INTEGER, SORT_ORDER INTEGER)";
	if ($db_isib)			# Interbase specific stuff
		{
		my $sql = "SELECT RDB\$RELATION_NAME FROM RDB\$RELATIONS WHERE RDB\$RELATION_NAME='$tablename'";
		&db_do($sql);
		my @row;
		@row = $th->fetchrow_array();
		$th->finish;
		if ($row[0] eq '')
			{
			&db_do($cresql);
			}
		}
	else
		{
		my $sql = "SHOW TABLES";			# MySQL specific stuff
		&db_do($sql);
		my $found = 0;
		while (my @row = $th->fetchrow_array())
			{
			$found = 1 if ($row[0] =~ /$tablename/i);
			}
		$th->finish;
		if (!$found)
			{
			&db_do($cresql);
			}
		}
	}
#---------------------------------------------------------------------------
#
# 	Check to see if user exists
#
sub db_user_exists
	{
	my $sid = shift;
	my $id = shift;
	my $res = 0;
	
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = "SELECT UID FROM $sid WHERE UID='$id'";
	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	my $th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th->execute || die "Cannot execute SQL statement: $DBI::errstr\n";
	my @row;
	if (@row = $th->fetchrow_array())
		{
		$res = ($row[0] eq $id);
		}
	$th->finish;
	$res;
	}
#---------------------------------------------------------------------------
#
# 	Check to see if this name exists
#
sub db_name_exists
	{
	my $sid = shift;
	my $name = shift;
	my $res = 0;
	
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = "SELECT FULLNAME FROM $sid WHERE FULLNAME='$name'";
	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	my $th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th->execute || die "Cannot execute SQL statement: $DBI::errstr\n";
	my @row;
	if (@row = $th->fetchrow_array())
		{
		$res = ($row[0] eq $name);
		}
	$th->finish;
	$res;
	}
#---------------------------------------------------------------------------
#
# 	Check to see if user exists
#
sub db_pwd_exists
	{
	my $sid = shift;
	my $pwd = shift;
	my $res = 0;
	
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = "SELECT PWD FROM $sid WHERE PWD='$pwd'";
	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	my $th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th->execute || die "Cannot execute SQL statement: $DBI::errstr\n";
	my @row;
	if (@row = $th->fetchrow_array())
		{
		$res = ($row[0] eq $pwd);
		}
	$th->finish;
	$res;
	}
#---------------------------------------------------------------------------
#
#	Get token status from file
#
sub db_get_user_status
	{
	my $sid = shift;
	my $id = shift;
	my $pwd = shift;
	my $no_uid = shift;

	my $stat = '';

	&db_conn2;						# Use second connection to avoid cursor contention
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[2] if ($mysub eq '');
	die "Missing sid in call to db_get_user_status / $mysub" if ($sid eq '');
	my $sql = "SELECT STAT FROM $sid WHERE PWD=?";
	my @params = ($pwd);
	if (!$no_uid)
		{
		$sql .= " AND  UID=?";
		push @params,$id; 
		}
	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	my $thh = $dbh2->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$thh->execute(@params) || die "Cannot execute SQL statement: $DBI::errstr\n";
	my @row;
	if (@row = $thh->fetchrow_array())
		{
		$stat = $row[0];
		}
	$thh->finish;
	&db_disc2;
	print "Returning status=$stat\n" if ($dbt);
	$stat;
	}

#---------------------------------------------------------------------------
#
#	Get user database record
#
sub db_get_user_data
	{
	my $sid = shift;
	my $id = shift;
	my $pwd = shift;
	my $no_uid = shift;


	&db_conn2;						# Use second connection to avoid cursor contention
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[2] if ($mysub eq '');
	die "Missing sid in call to db_get_user_data / $mysub" if ($sid eq '');
	my $sql = "SELECT * FROM $sid WHERE PWD=?";
	my @params = ($pwd);
	if (!$no_uid)
		{
		$sql .= " AND  UID=?";
		push @params,$id; 
		}
	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	my $thh = $dbh2->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$thh->execute(@params) || die "Cannot execute SQL statement: $DBI::errstr\n";
	my $res = $thh->fetchrow_hashref();
	$thh->finish;
	&db_disc2;
	print "Returning database record for $sid/$id/$pwd\n" if ($dbt);
	$res;
	}

#---------------------------------------------------------------------------
#
#	Get token seqno from file
#
sub db_get_user_seq
	{
	my $sid = shift;
	my $id = shift;
	my $pwd = shift;
	my $no_uid = shift;

	my $seq = 0;

	&db_conn2;
	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = "SELECT SEQ FROM $sid WHERE PWD=?";
	my @params = ($pwd);
	if (!$no_uid)
		{
		$sql .= " AND  UID=?";
		push @params,$id; 
		}
	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	my $thh = $dbh2->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$thh->execute(@params) || die "Cannot execute SQL statement: $DBI::errstr\n";
	my @row;
	if (@row = $thh->fetchrow_array())
		{
		$seq = $row[0];
		}
	$thh->finish;
	&db_disc2;
	print "Returning seq=$seq\n" if ($dbt);
	$seq;
	}
	
#---------------------------------------------------------------------------
#
# return the email address
#
sub db_get_user_email
	{
	my $sid = shift;
	my $pwd = shift;
	my $id = shift;

	my $mysub = (caller(1))[3];
	$mysub = (caller(0))[3] if ($mysub eq '');
	my $sql = "SELECT EMAIL FROM $sid WHERE UID='$id' AND PWD='$pwd'";
	print "Preparing SQL statement[$mysub]: [$sql]\n" if ($dbt);
	my $th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
	print "Executing SQL statement\n" if ($dbt);
	$th->execute || die "Cannot execute SQL statement: $DBI::errstr\n";
	my @row;
	my $email = '';
	if (@row = $th->fetchrow_array())
		{
		$email = $row[0];
		}
	$th->finish;
	print "Returning email=$email\n" if ($dbt);
	$email;
	}



#---------------------------------------------------------------------------
# 
# This routine is deprecated (it should be - it's empty !!
#
sub db_qt_save_tokens
	{
# Nothing to do here now !
	}
1;
