#Copyright Triton Technology 2002
#$Id: MAP.pm,v 1.63 2012-11-19 23:14:29 triton Exp $
package TPerl::MAP;
use strict;
use Carp qw (confess);
use Data::Dumper;
use File::Temp;
use File::Slurp;
use File::Temp qw(tempfile);
use FileHandle;

use TPerl::TritonConfig qw (getConfig);
use TPerl::MyDB;
use TPerl::Object;
use TPerl::CmdLine;
use TPerl::TableManip;
use TPerl::DBEasy;

our @ISA = qw (TPerl::TableManip);

#
# Miscellaneous stuff to create temp tables (for speed)
#
my @jobtables = (qw{MAP101 MAP001 MAP002 MAP003 MAP004 MAP005 MAP006 MAP007 MAP008 MAP009 MAP010A MAP010 MAP011 MAP012 MAP018 MAP026});
my $sql = <<SQL;
  CREATE TABLE PWI_WSDATES (WSDATE VARCHAR(20),WSDATE_D DATE);
  CREATE TABLE PWI_EXECS (EXECNAME VARCHAR(60));
  CREATE TABLE PWI_LOCS (LOCID VARCHAR(12));
  delete FROM PWI_WSDATES;
  INSERT INTO PWI_WSDATES select DISTINCT WSDATE,WSDATE_D FROM PWI_STATUS;
  delete FROM PWI_LOCS;
  INSERT INTO PWI_LOCS select DISTINCT LOCID FROM PWI_STATUS;
  delete FROM PWI_EXECS;
  INSERT INTO PWI_EXECS select DISTINCT EXECNAME FROM PWI_STATUS;
insert into PWI_WSSTATUS values(1,1,'Open');
insert into PWI_WSSTATUS values(2,2,'Closing');
insert into PWI_WSSTATUS values(3,3,'Closed');
insert into PWI_WSSTATUS values(4,4,'Cancelled');
SQL


## These 2 are required by TPerl::TableManip;
sub table_create_list {
	my @wstables = qw(MAP_CASES PWI_ADMIN PWI_EXEC PWI_LOCATION PWI_BATCH PWI_WORKSHOP PWI_WSSTATUS PWI_STATUS 
    		PWI_UPLOAD_ADMIN PWI_UPLOAD_EXEC PWI_UPLOAD_LOCATION PWI_UPLOAD_WORKSHOP PWI_UPLOAD_PARTICIPANT);
    my @eventtables = @jobtables;
    map {$_ .= "_E"} @eventtables;
    return [@wstables, @jobtables, @eventtables];
}

sub table_sql {
	my $self = shift;
	my $table = shift;

	my $tables = {
		PWI_UPLOAD_PARTICIPANT => qq{     CREATE TABLE PWI_UPLOAD_PARTICIPANT (
	        ID                 INTEGER NOT NULL,
	        SALUTATION         VARCHAR(25),
	        LASTNAME           VARCHAR(25),
	        FIRSTNAME          VARCHAR(25),
	        TITLE              VARCHAR(50),
	        COMPANY            VARCHAR(70),
	        EMAIL              VARCHAR(50),
	        SEX                CHAR(1),
	        PAR_LAST_UPDATE_DT TIMESTAMP,
	        PAR_SEND_EKIT_DT	TIMESTAMP,
	        CST_LAST_UPDATE_DT TIMESTAMP,
	        LAST_UPDATE_DT	   TIMESTAMP,

	
	        BOSSLASTNAME       VARCHAR(25),
	        BOSSFIRSTNAME      VARCHAR(25),
	        BOSSID             INTEGER,
	        BOSSEMAIL          VARCHAR(50),
			BOSS_LAST_UPDATE_DT	TIMESTAMP,
	
	        CMS_STATUS         CHAR(1),
	
	        STARTDATE          TIMESTAMP,
	        LOCATIONCODE       VARCHAR(6),
	        LOCATION           VARCHAR(30),
	        LOCATIONADDRESS    VARCHAR(50),
	        LOCATIONSTATE      VARCHAR(30),
	        LOCATIONCITY       VARCHAR(25),
	        HOTELRATE          FLOAT,
	
	        EXECNAME           VARCHAR(25),
	        EXECEMAIL          VARCHAR(50),
	        WORKSHOP_LEADER_NAME varchar(50),
	        WORKSHOP_LEADER_INITIALS varchar(6),
	        ADMIN_ID           integer,
	        FLAG			   VARCHAR(2),
	        BATCHNO            INTEGER,
	        IMPORT_DT          TIMESTAMP
	        )},

		MAP_CASES=> qq{ CREATE TABLE MAP_CASES (
			CASENAME                        VARCHAR(12) Not Null ,
			SID                             VARCHAR(8) Not Null ,
			UID                             VARCHAR(50) ,
			PWD                             VARCHAR(12) ,
			FULLNAME                        VARCHAR(40) ,
			ROLENAME                        VARCHAR(20) Not Null,
			BATCHNO                         INTEGER,
			SORT_ORDER                      INTEGER 
			)},

		PWI_UPLOAD_ADMIN=> qq{ CREATE TABLE PWI_UPLOAD_ADMIN (
	/* Common columns */
	        ID            		INTEGER NOT NULL,
	        BATCHNO				INTEGER,
	        IMPORT_DT			TIMESTAMP,
	/* Custom columns */
	        EMP_CLOSE_DATE		DATETIME,
	        INITIALS			VARCHAR(6),
	        LAST_UPDATE_DT		DATETIME,
	        EMAIL				VARCHAR(50),
	        ADMIN_NAME			VARCHAR(80)
	        )},

		PWI_UPLOAD_EXEC=> qq{ CREATE TABLE PWI_UPLOAD_EXEC (
	/* Common columns */
	        ID            		INTEGER NOT NULL,
	        BATCHNO				INTEGER,
	        IMPORT_DT			TIMESTAMP,
	/* Custom columns */
	        EMP_CLOSE_DATE		DATETIME,
	        INITIALS			VARCHAR(6),
	        LAST_UPDATE_DT		DATETIME,
	        EMAIL				VARCHAR(50),
	        FULLNAME			VARCHAR(80),
	        JOB_DESC			VARCHAR(80)
	        )},

		PWI_UPLOAD_LOCATION=> qq{ CREATE TABLE PWI_UPLOAD_LOCATION
	        (
	/* Common columns */
	        ID            		INTEGER NOT NULL,
	        BATCHNO				INTEGER,
	        IMPORT_DT			TIMESTAMP,
	/* Custom columns */
			LOC_CODE			VARCHAR(12),
			NAME				VARCHAR(50),
			NAME_LONG			VARCHAR(80),
			CHECKIN				VARCHAR(15),
			RES_PHONE			VARCHAR(20),
			CITY				VARCHAR(25),
			FAX					VARCHAR(20),
			EMAIL				VARCHAR(50),
			ADDRESS				VARCHAR(50),
			ACTIVE_FLAG			VARCHAR(2),
			ADMIN_FAX			VARCHAR(20),
			ADMIN_PHONE			VARCHAR(20),
			ZIP					VARCHAR(15),
			STATE				VARCHAR(6),
			LAST_UPDATE_DT		DATETIME,
			STATE_LONG			VARCHAR(20),
			PHONE				VARCHAR(20)
			)},

		PWI_UPLOAD_WORKSHOP=> qq{ CREATE TABLE PWI_UPLOAD_WORKSHOP
	        (
	/* Common columns */
	        ID            		INTEGER NOT NULL,
	        BATCHNO				INTEGER,
	        IMPORT_DT			TIMESTAMP,
	/* Custom columns */
			LAST_UPDATE_DT 		DATETIME,
			LOC_CODE			VARCHAR(8),
			ADMIN_NAME			VARCHAR(80),
			WSDATE				DATETIME
			)},

		PWI_ADMIN=> qq{ CREATE TABLE PWI_ADMIN (
			ADMIN_KV     INTEGER not NULL PRIMARY KEY,
			ADMIN_ID     VARCHAR(12) not NULL ,
			ADMIN_NAME   VARCHAR(50) not NULL ,
			ADMIN_EMAIL  VARCHAR(100) not NULL ,
			ADMIN_PHONE  VARCHAR(30) ,
			ADMIN_FAX    VARCHAR(30)
			)},

		PWI_EXEC=> qq{CREATE TABLE PWI_EXEC (
			EXEC_KV     INTEGER not NULL PRIMARY KEY,
			EXEC_ID     VARCHAR(12) not NULL ,
			EXEC_NAME   VARCHAR(50) not NULL ,
			EXEC_EMAIL  VARCHAR(100) not NULL ,
			EXEC_PHONE  VARCHAR(30),
			EXEC_FAX    VARCHAR(30)
			)},

		PWI_LOCATION => qq{	CREATE TABLE PWI_LOCATION (
			LOC_KV     INTEGER not NULL PRIMARY KEY,
			LOC_ID     INTEGER not null,
			LOC_CODE   VARCHAR(12) not NULL UNIQUE,
			LOC_NAME   VARCHAR(50) not NULL ,
			LOC_DISPLAY VARCHAR(80),
			LOC_ACTIVE VARCHAR(2) DEFAULT 'Y',
			LOC_FAX    VARCHAR(30),
			ADMIN_PHONE VARCHAR(20),
			ADMIN_FAX VARCHAR(20)
			)},

		PWI_BATCH => qq{CREATE TABLE PWI_BATCH(
			BAT_KV     INTEGER not NULL PRIMARY KEY,
			BAT_NO     INTEGER not NULL,
			BAT_NAME   VARCHAR(50) not null,
			BAT_STATUS INTEGER not NULL
			)},

		PWI_WORKSHOP => qq{CREATE TABLE PWI_WORKSHOP(
			WS_KV     INTEGER not NULL PRIMARY KEY,
			WS_ID     VARCHAR(20) not NULL UNIQUE,
			WS_LOCREF INTEGER not NULL,
			WS_STATUSREF INTEGER DEFAULT '1' not NULL,
			WS_DUEDATE DATE,
			WS_STARTDATE DATE,
			WS_REMDATE1  DATE,
			WS_REMDATE2  DATE,
			WS_TITLE     VARCHAR(20)
			)},
	
		PWI_WSSTATUS => qq{CREATE TABLE PWI_WSSTATUS (
			WSS_KV     INTEGER not NULL PRIMARY KEY,
			WSS_NUM     INTEGER not NULL ,
			WSS_STATUS   VARCHAR(15) not NULL
			)},

		PWI_STATUS => qq{CREATE TABLE PWI_STATUS(
			UID VARCHAR(50) NOT NULL PRIMARY KEY,
			PWD VARCHAR(15),
			CNT INTEGER,
			ISREADY INTEGER,
			SELFREADY INTEGER,
			BOSSREADY INTEGER,
			PEERREADY INTEGER,
			Q1 INTEGER,
			Q2 INTEGER,
			Q3 INTEGER,
			Q4 INTEGER,
			Q5 INTEGER,
			Q6 INTEGER,
			Q7 INTEGER,
			Q8 INTEGER,
			Q9 INTEGER,
			Q10A INTEGER,
			Q10 INTEGER,
			Q11 INTEGER,
			Q12 INTEGER,
			Q18 INTEGER,
			FULLNAME VARCHAR(60),
			BATCHNO INTEGER,
			EXECNAME VARCHAR(60),
			LOCID VARCHAR(12),
			LOCNAME VARCHAR(60),
			CMS_FLAG VARCHAR(2),
			CMS_STATUS VARCHAR(2),
			WSID VARCHAR(25),
			WSDATE VARCHAR(30),
			WSDATE_D DATE,
			DUEDATE VARCHAR(30),
			DUEDATE_D DATE,
			NBOSS INTEGER,
			NPEER INTEGER,
/* Added for hotel booking */
			CREDIT_CARD_HOLDER VARCHAR(40),
			CCT_ID VARCHAR(12),
			CREDIT_CARD_NO VARCHAR(20),
			CREDIT_CARD_REC VARCHAR(20),
			CREDIT_EXP_DATE VARCHAR(15),
			EARLY_ARRIVAL VARCHAR(2),
			EARLY_ARRIVAL_DATE DATETIME,
			EARLY_ARRIVAL_TIME VARCHAR(10),
			WITH_GUEST VARCHAR(2),
			GUEST_DINNER_DAY1 VARCHAR(2),
			GUEST_DINNER_DAY2 VARCHAR(2),
			DIETARY_RESTRICT VARCHAR(255),
			REVISED_FULLNAME VARCHAR(80),
			OCCUPANCY VARCHAR(10),
			LAST_UPDATE_TS INTEGER
			)},
		PWI_CCARD => qq{CREATE TABLE PWI_CCARD (
			CC_UID              VARCHAR(50) not NULL PRIMARY KEY,
			CC_CARDNO           VARCHAR(50),
			CC_CARDNO_OBSCURE   VARCHAR(50),
			CC_NAME             VARCHAR(50),
			CC_TYPE             VARCHAR(15),
			CC_EXPIRES          VARCHAR(50),
			CC_MODIFIED         INTEGER
			)},
	};
#
# Now add in the job tables for each of the forms... it means when we do a "perl map_tables.pl -dump", then we get all the job tables too.
# We also need to do a "perl asptables.pl -dump" to get the core engine database tables dumped out (to a file called "aspdump")
#
foreach my $SID (@jobtables)
	{
	$tables->{$SID} = <<SQL;			# SQL Code lifted from qt-db.pl, STOP_FLAG is MAP specific, nor actually email scheme specific
		CREATE TABLE $SID (
			PWD VARCHAR(12) NOT NULL PRIMARY KEY,
			UID VARCHAR(50),
			stat INTEGER,
			FULLNAME VARCHAR(60),
			TS INTEGER, 
			EXPIRES INTEGER,
			SEQ INTEGER, 
			REMINDERS INTEGER, 
			EMAIL VARCHAR(80), 
			BATCHNO INTEGER,
			STOP_FLAG INTEGER
			)
SQL
	$tables->{"${SID}_E"} = <<SQL;
        CREATE TABLE ${SID}_E (
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
	}

    my $sql = $tables->{$table};
    $sql =~ s/#.*//;
    return $sql;
}



### This function gets data from the database and dfiles.
sub excel_data_file 
	{
	my $self = shift;
	my %args = @_;
	my $id = $args{id};
	my $dbh = $args{dbh};
	my $troot = $args{troot};
	my $tok2dfile = $args{token2dfile};
	my $debug = $args{debug};
	my $err = $args{err};

	my @copy_these = qw{id fullname company workshopdate duedate returnfax survey_id};
#
# Check on compulsory arguments.
#
	foreach (qw (id dbh token2dfile)){
		return {id=>$id,err=>"No $_ supplied"} unless $args{$_};
	}
#
# Check the database has the right tables...
# MYSQL on Windoze reports table names as lower case, so we do a case insensitive search here
#
	my @clean_tables = $dbh->tables;
    s/^[`'"].*?[`'"]\.// foreach @clean_tables;			# Get rid of database name
	s/^[`'"](.*?)[`'"]$/\1/ foreach @clean_tables;		# Get rid of quotes
	return {id=>$id,err=>"MAP_CASES table does not exist".join(",",@clean_tables)} unless
		grep /MAP_CASES/i,@clean_tables;

# Get all the MAP_CASES connected with $id in the self, peers, and boss survey
	my $sql = q{select * from MAP_CASES where UID = ? and (SID = ? or SID=? or SID=?) ORDER BY SID};
	my @params = ($id,'MAP002','MAP010','MAP012');
	my $sth = $dbh->prepare ($sql) or
		return {id=>$id,err=>'DB Trouble: '.$dbh->errstr};
	$sth->execute (@params) or
		return {id=>$id,err=>'DB Trouble: '.$dbh->errstr};

	print "Doing an excel datafile for id '$id'  data in '$troot'\n" if $debug;
# These things neeed to be set
    my $consultant = undef;
    my $leader = undef;
    my $participant = undef;
    my $ws_date = undef;
    my $company = undef;
    my $res_types = {};
    my $ws_leader = undef;
    my $targetname = $id;
    my $data = [[]];
    my $written_data = {};

# Hang on to boss and peer data till we work out how many of each there are.
    my $boss_data = {};
    my $peer_data = {};
    my $found_in_db = 0;
    my $completes = 0;
	my @wqlist = qw(_Q1 _Q2 _Q3 _Q4 _Q5 _Q6 _Q7 _Q8 _Q9);		# List of written question nos
    while (my $data_row = $sth->fetchrow_hashref){
		$data_row->{$_} =~ s/^\s*(.*?)\s*$/$1/ foreach keys %$data_row;
		$participant = $data_row->{FULLNAME} if !$participant;				# Pick up a name Justin Case
       	$found_in_db++;
        if (my $resp = $tok2dfile->{$data_row->{SID}}->{$data_row->{PWD}}){
        	$completes++;
            print "Found complete data for $data_row->{FULLNAME} ($data_row->{ROLENAME})\n" if $debug;
            my @r_data = ();
            my @written_data = ();
			if ($data_row->{SID} eq 'MAP010'){
# MAP010 has 18 data points that go at the end of the data.
				$r_data[31] = undef;
				push @r_data,mysplit("===",$resp->{_Q10});
# Hang on to the written responses for MAP010 - for the consolidated written response doc
				foreach (@wqlist,@copy_these){
					$written_data->{$data_row->{PWD}}{$_} = $resp->{$_};
				}
			} else {
# MAP002 and  MAP012 have 50 bits of data
				foreach (qw(_Q1 _Q2 _Q3 _Q4 _Q5 _Q6 _Q7 _Q8 )){
					push @r_data,mysplit("===",$resp->{$_});
				}
			}
            printf " - The data is @r_data (%s elements)\n",scalar(@r_data) if $debug;
            if ($data_row->{SID} eq 'MAP002'){
                $company = $resp->{company};
                $participant = $resp->{fullname};
                $targetname = qq{$resp->{lastname},$resp->{firstname}-$resp->{id}};
				$targetname =~ s/\s+//g;
                $consultant = $resp->{execname};
                $ws_leader = '';		# Better than 'some goose'
                $ws_date = $resp->{workshopdate};
                #self data goes in column 0.
                $data->[0] = \@r_data;
            }elsif ($data_row->{SID} eq 'MAP012'){
# Bosses
                $boss_data->{$data_row->{PWD}}->{data} = \@r_data;
                $boss_data->{$data_row->{PWD}}->{name} = $resp->{who};
				my @names = split(/\s+/,$resp->{who});
				my $initial = '';
				foreach my $x (@names)
					{
					$initial .= uc(substr($x,0,1));
					}
                $boss_data->{$data_row->{PWD}}->{initial} = $initial;
#				print "$initial ($resp->{who})\n";
            }elsif ($data_row->{SID} eq 'MAP010'){
# Peers.
                $peer_data->{$data_row->{PWD}} = \@r_data;
            }else{
            }
        }else{
            print "No Complete data for $data_row->{FULLNAME} in $data_row->{SID} with token $data_row->{PWD}\n" if $debug;
			$err->W("$data_row->{FULLNAME} survey not started, skipping");
            if ($data_row->{SID} eq 'MAP012'){			# Need to count bosses who have not completed yet
# Bosses
                $boss_data->{$data_row->{PWD}}->{data} = [];
                $boss_data->{$data_row->{PWD}}->{name} = $data_row->{FULLNAME};
				my @names = split(/\s+/,$data_row->{FULLNAME});
				my $initial = '';
				foreach my $x (@names)
					{
					$initial .= uc(substr($x,0,1));
					}
                $boss_data->{$data_row->{PWD}}->{initial} = $initial;
#				print "$initial ($resp->{who})\n";
            }
        }
    }
   	print "Found $found_in_db rows with \n'$sql' and \n(@params)\n" if $debug;

    # now make the data file
    # put the boss data in first and count the bosses
    my $col = 1;
    my $b_list = [];
    foreach my $boss_id (keys %$boss_data){
        push @$b_list,{name=>$boss_data->{$boss_id}->{name},initial=>$boss_data->{$boss_id}->{initial}};
        $data->[$col]= $boss_data->{$boss_id}->{data};
        $col++;
    }
    my $bosses = $col-1;
# Then put the peer data in
    foreach my $peer_id (keys %$peer_data){
		print "peer $col\n" if $debug;
        $data->[$col] = $peer_data->{$peer_id};
        $col++;
    }
# ??? This calculation is screwy....
	my $peers = $col - $bosses - 1;
	my ($fh,$file) = tempfile;
	close $fh;
	$fh = new FileHandle ("> $file") or die "Could not open $file $!";
    make_data_file (data=>$data,
		dfh=>$fh,
        participant=>$participant,
        bosses=>$b_list,
        consultant=>$consultant,
        ws_date=>$ws_date,
        ws_leader=>$ws_leader,
        company=>$company);
    close $fh;
# 
# Create the file to contain the written responses
#
	my $hr = {};
	my $goop = " {\\par} ";
	foreach my $q (@wqlist){
		$hr->{$q} = join $goop, map {$written_data->{$_}{$q} if ($written_data->{$_}{$q} =~ /\S+/)} (keys %{$written_data});
	}
	foreach my $q (@copy_these){
		foreach (keys %{$written_data}) {
			$hr->{$q} =  $written_data->{$_}{$q} if ($written_data->{$_}{$q} =~ /\S+/);
		}
	}
	$hr->{survey_id} = 'MAP010A';		# Hard wired
	$hr->{seqno} = $hr->{id};			# Play it safe
	my $buf = Dumper $hr;
	$buf =~ s/\$VAR1 = \{/%resp = (/ig;
	$buf =~ s/\};/);/ig;
	$buf .= qq{\n1;\n};
	write_file($args{written},$buf);
	return {id=>$id,bosses=>$bosses,peers=>$peers,file=>$file,completes=>$completes,participant=>$participant,targetname=>$targetname,};
}

# This bit does the excel formatting
sub make_data_file {
        # this should count as documentation
        # #fake some peer data
        # my $data =[];
        # #  $data is an array of arrays.  the first index is the column, and the second is the row.
        # foreach my $col (0..16){
        #   foreach my $row (0..49){
        #       $data->[$col]->[$row] = ($col % 10) +1;
        #   }
        # }
        # make_data_file (data=>$data,
        #               bosses=>[{name=>'Mike King',initial=>'MK'},{name=>'Ian Cesa',initial=>'IC'}],
        #               consultant=>'Dave Mancerella',ws_date=>'2-4 August 2000',
        #               ws_leader=>'Yev Bilotsky',participant=>'Andrew Creer',
        #               company=>'VirtualImage');

    my %args = @_;
#   print "make_data_file ".Dumper \%args;
    my $dfh = $args{dfh} || *STDOUT;
    my $data = $args{data};
    my $bosses = $args{bosses};
    my $consultant = $args{consultant};
    my $ws_leader = $args{ws_leader};
    my $ws_date = $args{ws_date};
    my $participant = $args{participant};
    my $company = $args{company};


    printf $dfh qq{# Excel datafiller produced on %s \n},scalar(localtime);
    print $dfh qq{C1 $participant\n};
    print $dfh qq{C2 $company\n};
    print $dfh qq{C3 $ws_date\n};
    print $dfh qq{C4 $ws_leader\n};
    print $dfh qq{C5 $consultant\n};

    my @boss_loc = qw (H1 H2 H3 H4 K1 K2 K3 K4);
    foreach my $i (0..$#$bosses){
        print $dfh "$boss_loc[$i*2] $bosses->[$i]->{initial}\n";
        print $dfh "$boss_loc[$i*2+1] $bosses->[$i]->{name}\n";
    }
    my $scol = 3 ;#ie C
    my $srow = 7; #ie C7 where the data starts
    # first col is self, the next 0 to 3 are bosses and then peers
    my $cols = 17;  #the data is in a 16x49 matrix.
    my $rows = 50;

    foreach my $col (0..$cols-1){
        foreach my $row (0..$rows-1){
            my $cell = chr(64+$scol+$col).($srow+$row);
			if ((defined $data->[$col]->[$row]) && ($data->[$col]->[$row] ne '')){
				my $score = $data->[$col]->[$row] + 1;		# Adjust bcos engine stores it as a zero
				print $dfh "$cell $score\n";
			}
        }
    }
	close $dfh;
}

sub token2dfile {
	my $self = shift;
    my %args = @_;
    my $troot = $args{troot};
    my $jobs= $args{jobs};

#   we need to be able to look up the latest complete Dfile
#   using the token.  This does the trick

    # until we run out of memory, put the resp hash into the ret hash
    # later just store the file name and use a modified hash...

    my $ret = {};

    foreach my $j (@$jobs){
        foreach my $dfile (read_dir ("$troot/$j/web")){
            next unless $dfile =~ /^D\d+\.pl$/;
            #print "dfile=$troot/$j/web/$dfile\n";
            if (my $df = dfile TPerl::Object (file=>"$troot/$j/web/$dfile")){
                my $tok = $df->{resp}->{token};
                if ($df->{resp}->{status} >= 3 ){
                    if ($ret->{$j}->{$tok}){
                        $ret->{$j}->{$tok} = $df->{resp} if
                            $df->{resp}->{modified} > $ret->{$j}->{$tok}->{modified};
                    }else{
                        $ret->{$j}->{$tok} = $df->{resp};
                    }
                }else{
                     #print "dfile $dfile stat not 4". Dumper $df->{resp};
                }
            }
        }
    }
    return $ret;
}
# this makes the map_cases table into a text file.  see
# http://community.borland.com/article/0,1410,25158,00.html

sub map_cases2txt {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{dbh} || $self->dbh;
	my $file = $args{file};

	my $ext_table = 'MAP_CASES_EXT';

	foreach (qw(file)){
		return "$_ not supplied" unless $args{$_};
	}
	my $fh = new FileHandle ("> $file") or return "no write access to $file";
	close $fh;
	unlink $file;
	my @clean_tables = $dbh->tables;
    s/^[`'"].*?[`'"]\.// foreach @clean_tables;       # Get rid of database name
	s/^[`'"](.*?)[`'"]$/\1/ foreach @clean_tables;		# Get rid of quotes

	if (grep $ext_table eq $_,@clean_tables){
		my $sql = "drop table $ext_table";
		return "DB trouble with '$sql':". $dbh->errstr unless
			 $dbh->do ($sql);
	}

	# need to execute these sqls.
	#these sqls can be done from perl
	my @sql = (qq{create table $ext_table external file '$file' ( CASENAME CHAR (12),
						SID CHAR (8) ,UID CHAR (50),
						PWD CHAR (12), FULLNAME CHAR (40),
						ROLENAME CHAR(20) )},
					 "insert into $ext_table select CASENAME, SID,UID,
						PWD,FULLNAME,ROLENAME from MAP_CASES",
					"drop table $ext_table",
					"commit",
				);
	foreach my $sql (@sql){
		$dbh->do($sql);
		return "DB trouble with '$sql':". $dbh->errstr if $dbh->errstr;
	}
	#success
	return undef;
}

sub txt2map_cases {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{dbh} || $self->dbh;
	my $file = $args{file};

	my $ext_table = 'MAP_CASES_EXT';

	foreach (qw(file)){
		return "$_ not supplied" unless $args{$_};
	}
	return "Could not read $file" unless -r $file;

	my @sql = ();  #sqls to be executed....

	#drop ext table if it exists
	my @clean_tables = $dbh->tables;
    s/^[`'"].*?[`'"]\.// foreach @clean_tables;       # Get rid of database name
	s/^[`'"](.*?)[`'"]$/\1/ foreach @clean_tables;		# Get rid of quotes
	push @sql,"drop table $ext_table" if grep $ext_table eq $_,@clean_tables;

	# create map cases if necessary..
	push @sql,$self->table_sql('MAP_CASES') unless grep $_ eq 'MAP_CASES',@clean_tables;

	push @sql, (qq{create table $ext_table external file '$file' ( CASENAME CHAR (12),
						SID CHAR (8) ,UID CHAR (50),
						PWD CHAR (12), FULLNAME CHAR (40),
						ROLENAME CHAR(20) )},
		"delete from map_cases",
		"insert into MAP_CASES select CASENAME, SID,UID, PWD,FULLNAME,ROLENAME from $ext_table",
		"drop table $ext_table",);

	### Then do the sqls.
	foreach my $sql (@sql){
		$dbh->do($sql);
		return "DB trouble with '$sql':". $dbh->errstr if $dbh->errstr;
			# defined $dbh->do ($sql);
	}
	#success
	return undef;

}
#
# Gnarly little sucker that we need bcos regexp's don't work 
# (ie don't return a full array) if there is no data in there at all
#
sub mysplit
	{
	my $re = shift;
	my $x = shift;

	if ($x =~ /$re$/)					# Check at the end 
		{
		my @y = split /$re/,"$x ";		# Add a space to make the split work
		$y[$#y] = '';					# Then nuke it to cover our tracks
		@y;
		}
	else
		{
		split /$re/,$x;
		}
	}
# sub _ext_table_from_file{
# 	#must use isql from the command line to create external file tables.
# 	my $self = shift;
# 	my %args = @_;
# 	my $file = $args{file};
# 	my $ext_table = $args{ext_table};
#
# 	my $sql = qq{create table $ext_table external file '$file' ( CASENAME CHAR (12),
# 						SID CHAR (8) ,UID CHAR (50),
# 						PWD CHAR (12), FULLNAME CHAR (40),
# 						ROLENAME CHAR(20) )};
# 	my ($tfh,$tfile) = tempfile;
# 	print $tfh "$sql;\n";
# 	close $tfh;
# 	my $cmd = "/opt/interbase/bin/isql -u sysdba -p masterkey -i $tfile /opt/interbase/triton.gdb";
# 	my $exec = execute TPerl::CmdLine (cmd=>$cmd);
# 	print Dumper $exec;
# 	if ($exec->success){
# 		unlink $tfile;
# 		return undef;
# 	}else{
# 		return "trouble with $sql:".$exec->output;
# 	}
# }
#

# Now we write some code to do the bits of an eventlog viewer.
sub pwikit_eventlog_bits {
	my $self = shift;
	
	my %args = @_;

	my $defaults = {
		# The names of the search box fields.
		sb_uid_name		=>	'id',
		sb_pwd_name		=>	'pwd',
		sb_name_name 	=>	'name',
		sb_peer_name	=>	'peer',
		sb_boss_name	=>	'boss',
		eventview		=>	'pwikit',
	};

	my $config = $args{_config} || {};
	foreach (keys %$defaults){ $config->{$_} = $defaults->{$_} unless exists $config->{$_}; }

	my $role2SID = $config->{role2SID} || confess ("No 'role2SID' in _config hash");
	my $ev = $config->{ev} || confess ("No TPerl::Event  'ev' in _config hash");
	my $index_table = $config->{index_table} || confess ("No 'index_table' in _config hash");


	## Build the sql from the search box args.
	my $search_sql = "select distinct(uid),fullname,rolename,PWD from $index_table";
	# my $search_sql = "select uid,fullname,rolename from $config{index}";
	my @wheres = ();
	my @qms = ();
	if ($args{id}){
		push @wheres,'UID=?';
		push @qms,$args{id};
	}
	if ($args{$config->{sb_pwd_name}}){
		push @wheres, '(upper(PWD) like upper(?))';
		push @qms,("%$args{$config->{sb_pwd_name}}%");
	}
	if ($args{$config->{sb_name_name}}){
		push @wheres, '(upper(FULLNAME) like upper(?) and upper(ROLENAME) = ?)';
		push @qms,("%$args{$config->{sb_name_name}}%",'SELF');
	}
	if ($args{$config->{sb_peer_name}}){
		push @wheres, '(upper(FULLNAME) like upper(?) and upper(ROLENAME) = ?)';
		push @qms,("%$args{$config->{sb_peer_name}}%",'PEER');
	}
	if ($args{$config->{sb_boss_name}}){
		push @wheres, '(upper(FULLNAME) like upper(?) and upper(ROLENAME) = ?)';
		push @qms,("%$args{$config->{sb_boss_name}}%",'BOSS');
	}

	$search_sql .= ' WHERE ' .join ' or ',@wheres if @wheres;
	$search_sql .= ' ORDER BY SORT_ORDER ';

	my $dbh = $self->dbh || return undef;
	# Get the rows, and the fields.  Add in a field for each type of event we find.
	# Now get the rows.
	my $sth = $dbh->prepare($search_sql) || 
		($self->err({sql=>$search_sql,params=>\@qms,dbh=>$dbh}) && return undef);
	$sth->execute(@qms) || ($self->err({sql=>$search_sql,params=>\@qms,dbh=>$dbh}) && return undef);
	my $ez = new TPerl::DBEasy(dbh=>$dbh);
	my $fields = $ez->fields(sth=>$sth);
	my $rows = $sth->fetchall_arrayref({}) || ($self->err({sql=>$search_sql,dbh=>$dbh,parmas=>\@qms}) && return undef);
	# foreach row, add the events
	
	my $view = $ev->view(name=>$config->{eventview});
	my $view_warning ;
	unless ($view){
		($self->err($ev->err) && return undef) if ref ($ev->err);
		$view_warning = "This report would look better if there was an EventView called '$config->{eventview}':".$ev->err;
	}
	
	my $view_order = {};
	{
		my $names = $ev->names;
		my $max_order = 0;
		$view ||= $ev->events;
		foreach my $ec (@$view){
			$view_order->{$ec} = ++$max_order;
			$fields->{"EVENT_$ec"} = {
				name=>"EVENT_$ec",
				order=>20+$view_order->{$ec},
				pretty=>$names->{$ec},
			};
		}
		$fields->{EVENT_OTHER} ||={
			name=>'EVENT_OTHER',
			pretty=>'Other Events',
			order=>++$max_order+20,
		};
		# Make a field that will display the link to the eventlog.
		$fields->{EVENT_TOTAL} = {
			name=>'EVENT_TOTAL',pretty=>'Events:',order=>20,
		};
	}
	
	foreach my $r (@$rows){
		my $SID = $role2SID->{lc($r->{ROLENAME})};
		my $evc = $ev->event_count(SID=>$SID,pwd=>$r->{PWD});
		my $event_total;
		my $other_total;
		foreach my $ec (keys %$evc){
			if ($view_order->{$ec}){
				$r->{"EVENT_$ec"} = $evc->{$ec}->{EV_COUNT};
			}else{
				$other_total+=$evc->{$ec}->{EV_COUNT};
			}
			$event_total+=$evc->{$ec}->{EV_COUNT};
		}
		$r->{SID} = $SID;
		$r->{EVENT_TOTAL}=$event_total;
		$r->{EVENT_OTHER}=$other_total;
	}

	my $search_states = {};
	# foreach my $s (qw(sb_uid_name sb_uid_name sb_name_name sb_peer_name sb_boss_name)){
	foreach my $s (keys %$defaults){
		$search_states->{$config->{$s}} = $args{$config->{$s}} if $args{$config->{$s}} ne '';
	}
	
	my $ret = {
		states	=>	$search_states,
		
		# Need to display the rows
		rows			=>	$rows,
		fields			=>	$fields,
		view_warning	=>	$view_warning,
	};

	# Need to build the search box.
	$ret->{$_} = $config->{$_} foreach keys %$defaults;
	return $ret;

}
#
# Subroutines to encode/decode credit card numbers for storage.
# It's not really encryption, it's more like obfuscation.
# We generate a random digit, and then stick that at the front of the number. 
# We then add it to each digit in turn, subtracting 10 if the result is 10 or 
# more. Decoding is simply a matter of stripping off the first digit, and then 
# subtracting it from each number in turn.
#
sub map_enc
	{
	my $self = shift;
	my $cc = shift;
	my $r = 0;
	while ($r == 0)
		{
		$r = int(rand(10));		# Get a random number
		}
	my @xx = unpack("AAAAAAAAAAAAAAAA",$cc);
	my $result = $r;
	for (my $i=0;$i<=$#xx;$i++)
		{
		next if $xx[$i] eq '';			# Stop if we run out of digits
		my $x = ($xx[$i]+$r) % 10;
		$result .= $x;
		}
	$result;
	}
	
sub map_dec
	{
	my $self = shift;
	my $ec = shift;
	my @xx = unpack("AAAAAAAAAAAAAAAAA",$ec);
	my $result;
	my $r = $xx[0];
	for (my $i=1;$i<=$#xx;$i++)
		{
		next if $xx[$i] eq '';			# Stop if we run out of digits
		my $x = ($xx[$i]+10-$r) % 10;
		$result .= $x;
		}
	$result;
	}

# We need to report recent (bad) email events to Tim, and also have a web page
# to display them Here we do some sql to union some tables and sort and then
# return the result.  Actually we get the recs from each table and sort them in
# perl, cause firebird does not deal with orderby outside a union contruct..
# # perl -MTPerl::MAP -MTPerl::DBEasy -e 'print TPerl::DBEasy->lister_wrap(rows=>TPerl::MAP->recent_events(days=>1,codes=>[32,80]));'|elinks -force-html -dump
sub recent_events {
    my $self  = shift;
    my %args  = @_;
    my $secs  = 24 * 3600 * $args{days} || confess "'days' is a required arg";
    my $codes = $args{codes} || [];
    $codes = [$codes] unless ref($codes) eq 'ARRAY';
    my $SIDS = [qw(MAP001 MAP010 MAP011)];

    my $dbh   = $self->dbh;
    my $now   = TPerl::DBEasy->text2epoch('now');
    my @recs  = ();
    my $where = "where TS > ?";
    $where .= " and EVENT_CODE in (" . join( ',', @$codes ) . ")" if @$codes;
    foreach my $SID (@$SIDS) {
        my $sql = "select * from ${SID}_E $where order by TS";
        my $ros =
          $dbh->selectall_arrayref( $sql,
            { RaiseError => 1, PrintError => 1, Slice => {} },
            $now -$secs ) || die $dbh->errstr()." sql=$sql";
        push @recs, @$ros;
    }
    return [sort { $b->{TS} <=> $a->{TS} } @recs];
}
### This function jams together all the written responses for a participant and builds the consolidated rtf file.
sub jam_written 
	{
	my $self = shift;
	my %args = @_;
	my $id = $args{id};
	my $dbh = $args{dbh};
	my $troot = $args{troot};
	my $tok2dfile = $args{token2dfile};
	my $debug = $args{debug};
	my $err = $args{err};

    my $participant = undef;
    my $ws_date = undef;
    my $company = undef;
    my $res_types = {};
    my $ws_leader = undef;
    my $targetname = $id;
    my $data = [[]];
    my $written_data = {};
	my @copy_these = qw{id fullname company workshopdate duedate returnfax survey_id};
#
# Check on compulsory arguments.
#
	foreach (qw (id dbh token2dfile)){
		return {id=>$id,err=>"No $_ supplied"} unless $args{$_};
	}
#
# Check the database has the right tables...
# MYSQL on Windoze reports table names as lower case, so we do a case insensitive search here
#
	my @clean_tables = $dbh->tables;
    s/^[`'"].*?[`'"]\.// foreach @clean_tables;			# Get rid of database name
	s/^[`'"](.*?)[`'"]$/\1/ foreach @clean_tables;		# Get rid of quotes
	return {id=>$id,err=>"MAP_CASES table does not exist".join(",",@clean_tables)} unless
		grep /MAP_CASES/i,@clean_tables;

# Get all the MAP_CASES connected with $id in the self, peers, and boss survey
	my $sql = q{select * from MAP_CASES where UID = ? and (SID=? or SID=?) ORDER BY SID};
	my @params = ($id,'MAP001','MAP010');
	my $sth = $dbh->prepare ($sql) or
		return {id=>$id,err=>'DB Trouble: '.$dbh->errstr};
	$sth->execute (@params) or
		return {id=>$id,err=>'DB Trouble: '.$dbh->errstr};

	print "Doing a jam_written datafile for id '$id'  data in '$troot'\n" if $debug;
# These things neeed to be set
    my $data = [[]];
    my $written_data = {};

# Hang on to boss and peer data till we work out how many of each there are.
    my $found_in_db = 0;
    my $completes = 0;
	my @wqlist = qw(_Q1 _Q2 _Q3 _Q4 _Q5 _Q6 _Q7 _Q8 _Q9 _Q10 _Q11 _Q12 _Q13);		# List of written question nos
    while (my $data_row = $sth->fetchrow_hashref){
		$data_row->{$_} =~ s/^\s*(.*?)\s*$/$1/ foreach keys %$data_row;
       	$found_in_db++;
        if (my $resp = $tok2dfile->{$data_row->{SID}}->{$data_row->{PWD}}){
        	$completes++;
            print "Found complete data for $data_row->{FULLNAME} ($data_row->{ROLENAME})\n" if $debug;
            my @r_data = ();
            my @written_data = ();
            if ($data_row->{SID} eq 'MAP001'){
                $company = $resp->{company};
                $participant = $resp->{fullname};
                $targetname = qq{$resp->{lastname},$resp->{firstname}-$resp->{id}};
				$targetname =~ s/\s+//g;
			} else {
				foreach (@wqlist,@copy_these){
					$written_data->{$data_row->{PWD}}{$_} = $resp->{$_};
				}
			}
        }else{
            print "No Complete data for $data_row->{FULLNAME} in $data_row->{SID} with token $data_row->{PWD}\n" if $debug;
			$err->W("$data_row->{FULLNAME} survey not started, skipping");
        }
    }
   	print "Found $found_in_db rows with \n'$sql' and \n(@params)\n" if $debug;

# 
# Create the file to contain the written responses
#
	my $hr = {};
	my $goop = " {\\par} ";
	foreach my $q (@wqlist){
		$hr->{$q} = join $goop, map {$written_data->{$_}{$q} if ($written_data->{$_}{$q} =~ /\S+/)} (keys %{$written_data});
	}
	foreach my $q (@copy_these){
		foreach (keys %{$written_data}) {
			$hr->{$q} =  $written_data->{$_}{$q} if ($written_data->{$_}{$q} =~ /\S+/);
		}
	}
	$hr->{survey_id} = 'MAP010A';		# Hard wired
	$hr->{seqno} = $hr->{id};			# Play it safe
	$hr->{modified_s} = localtime();
	$hr->{status} = 4;
	my $buf = Dumper $hr;
	$buf =~ s/\$VAR1 = \{/%resp = (/ig;
	$buf =~ s/\};/);/ig;
	$buf .= qq{\n1;\n};
	write_file($args{written},$buf);
	return {id=>$id,completes=>$completes,participant=>$participant,targetname=>$targetname,};
}

1;
