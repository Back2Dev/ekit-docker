#!/usr/bin/perl
# $Id: map_cms_par_upload.pl,v 1.31 2012-09-06 03:28:02 triton Exp $
# Script to read participant/workshop data from the CMS system and xfer it to the eKit Server.
# It uploads it to [par_upload_target] (in the server.ini file), which simply accepts the 
# upload and saves the file
#
# The 2nd half of script runs on eKit Server: scripts/pwikit_cms_par_import.pl, which
# will run as a cron job on a regular basis to do the logic of importing the data
# and then working out which actions are necessary.
#
use strict;
use DBI;
use Date::Manip;							#perl2exe
use Getopt::Long;							#perl2exe
use HTTP::Request::Common;					#perl2exe
use LWP::UserAgent;							#perl2exe
use Data::Dumper;							#perl2exe

use TPerl::Error;		  					#perl2exe
use TPerl::TSV;								#perl2exe
use TPerl::MyDB;							#perl2exe
use TPerl::Dump;							#perl2exe
use TPerl::MAP;								#perl2exe

# Documentation
my $doc = <<DOC;
This script relies on certain views being present in the database that it connects to:

	VW_PARTICIPANT	- Workshop participant and Boss
	VW_LOCATION		- Workshop location 
	VW_EXEC			- map Executive
	VW_ADMIN		- map Administrator
	VW_WORKSHOP		- Workshop 

A table is also used (EKIT_PAR_UPLOAD) to administer information on the last time the database was
queried (to allow incremental updates).

These views can either installed in either 1) the CMS database itself, or 2) in a separate database.
For case 1), a special database user should be created that only has read access to these views, and
	write access to the administration table (EKIT_PAR_UPLOAD).
For case 2), a database user is created in the separate database, with read access to these views, and
	write access to the administration table (EKIT_PAR_UPLOAD). The views are created to extract their 
	data from the CMS database itself.
These techniques are roughly equivalent in terms of security level, but a paranoid systems administrator
may prefer option 2), as it does not need any changes to the CMS database itself.

DOC

#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

our $qt_root;
our $dbt;
our %config;
our $msdbh;
our $rowcnt = 0;
our ($upload_status,$upload_error,$download_status,$download_error);
require 'TPerl/qt-libdb.pl';				#perl2exe
require 'TPerl/360-lib.pl';					#perl2exe
require 'TPerl/pwikit_cfg.pl';				#perl2exe
$|=1;

my %tables = (
				participant => {
								table => 'VW_PARTICIPANT',
								sql   => 'select * from VW_PARTICIPANT WHERE LAST_UPDATE_DT>? ORDER BY LAST_UPDATE_DT,ID',
								idsql => 'select * from VW_PARTICIPANT WHERE ID IN ($idlist) ORDER BY LAST_UPDATE_DT,ID',
								date  => 'LAST_UPDATE_DT',
								id    => 'ID',
								from  => '6 month ago',
								},
				location => {
								table => 'VW_LOCATION',
								sql   => 'select * from VW_LOCATION WHERE last_update_dt>dateadd(millisecond,1,?) ORDER BY last_update_dt,ID',
								date  => 'LAST_UPDATE_DT',
# MSSQL Doesn't like non integer ID's being put into an integer field, so we can't rely on that field
# unless we redefine ID as a string, but that brings it's own problems ???
#								noid  => 1,		# Right now this flag works, we therefore just use the LAST_UPDATE_DT field only
# I fixed it with the View on the SQL Server end, I extracted the unique number from the "HTL000001" id column.
								id    => 'ID',
								},
				exec => {
								table => 'VW_EXEC',
								sql   => 'select * from VW_EXEC WHERE last_update_dt>dateadd(millisecond,1,?) ORDER BY last_update_dt,ID',
								idsql   => 'select * from VW_EXEC WHERE ID IN ($idlist) ORDER BY last_update_dt,ID',
								date  => 'LAST_UPDATE_DT',
								id    => 'ID',
								},
				admin => {
								table => 'VW_ADMIN',
								sql   => 'select * from VW_ADMIN WHERE last_update_dt>dateadd(millisecond,1,?) ORDER BY last_update_dt,ID',
								idsql   => 'select * from VW_ADMIN WHERE ID IN ($idlist) ORDER BY last_update_dt,ID',
								date  => 'LAST_UPDATE_DT',
								id    => 'ID',
								},
				workshop => {
								table => 'VW_WORKSHOP',
								sql   => 'select * from VW_WORKSHOP WHERE last_update_dt>dateadd(millisecond,1,?) ORDER BY last_update_dt,ID',
								idsql   => 'select * from VW_WORKSHOP WHERE ID IN ($idlist) ORDER BY last_update_dt,ID',
								date  => 'LAST_UPDATE_DT',
								id    => 'ID',
								from  => '6 months ago',
								},
			);
# This is used when downloading data from the eKit database to the local copy on CMS
my %column_map = (
				UID	=> 'UID',
				PWD	=> 'PWD',
				CNT	=> 'CNT',
				ISREADY	=> 'ISREADY',
				Q1	=> 'Q1',
				Q2	=> 'Q2',
				Q3	=> 'Q3',
				Q4	=> 'Q4',
				Q5	=> 'Q5',
				Q6	=> 'Q6',
				Q7	=> 'Q7',
				Q8	=> 'Q8',
				Q9	=> 'Q9',
				Q10A	=> 'Q10A',
				Q10	=> 'Q10',
				Q11	=> 'Q11',
				Q12	=> 'Q12',
				Q18	=> 'Q18',
				FULLNAME	=> 'FULLNAME',
				BATCHNO	=> 'BATCHNO',
				EXECNAME	=> 'EXECNAME',
				LOCID	=> 'LOCID',
				LOCNAME	=> 'LOCNAME',
				WSID	=> 'WSID',
				WSDATE_D	=> 'WSDATE_D',
				DUEDATE_D	=> 'DUEDATE_D',
				NBOSS	=> 'NBOSS',
				NPEER	=> 'NPEER',
				CREDIT_CARD_HOLDER	=> 'par_credit_card_holder',
				CCT_ID	=> 'par_cct_id',
				CREDIT_CARD_NO	=> 'CREDIT_CARD_NO',
				CREDIT_CARD_REC	=> 'par_credit_card_no',
				CREDIT_EXP_DATE	=> 'par_credit_exp_date',
				EARLY_ARRIVAL	=> 'par_early_arrival',
				EARLY_ARRIVAL_DATE	=> 'par_early_arrival_date',
				EARLY_ARRIVAL_TIME	=> 'par_early_arrival_time',
				WITH_GUEST	=> 'par_with_guest',
				GUEST_DINNER_DAY1	=> 'par_guest_dinner_day1',
				GUEST_DINNER_DAY2	=> 'par_guest_dinner_day2',
				DIETARY_RESTRICT	=> 'par_dietary_restrict',
				REVISED_FULLNAME	=> 'REVISED_FULLNAME',
				OCCUPANCY	=> 'par_rty_id',
				LAST_UPDATE_TS	=> 'LAST_UPDATE_TS',
				);

my %room_type = (
				"One Person"				=> 'rty000000001',
				"Two (1 bed)"		 		=> 'rty000000002',
				"Meals Only"				=> 'rty000000003', 
				"No Lodging"				=> 'rty000000003', 
				"Two (2 bed)"		 		=> 'rty000000004',
				);
my %card_type = (
				'Amex' 			=> 'cct000000001',
				'Visa' 			=> 'cct000000002',
				'Mastercard' 	=> 'cct000000003',
				'Discover' 		=> 'cct000000004',
				'Diners' 		=> 'cct000000005',
				);


our($opt_d,$opt_h,$opt_v,$opt_t,$opt_limit,
		$opt_only,
		$opt_table,
		$opt_file,
		$opt_reset,
		$opt_status,
		$opt_noaction,
		$opt_upload,
		$opt_download,
		$opt_hotel,
		$opt_id,
		);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			'limit=i' => \$opt_limit,
			'only=i' => \$opt_only,
			'table=s' => \$opt_table,
			'file=s' => \$opt_file,
			'id=s' => \$opt_id,
			status => \$opt_status,
			reset => \$opt_reset,
			noaction => \$opt_noaction,
			upload => \$opt_upload,
			download => \$opt_download,
			hotel => \$opt_hotel,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/map_cms_par_upload.pl,v 1.31 2012-09-06 03:28:02 triton Exp $'."\n";
	exit 0;
	}
my $SID = 'PARTICIPANT';
my $e = new TPerl::Error;
my $m = new TPerl::MAP;
my $when = localtime();

$opt_limit = 100 if (!$opt_limit);
# NB SQL Code to create VW_PARTICIPANT and EKIT_PAR_UPLOAD now lives in sql/map_cms_create_views.sql

our ($last_updated,$last_id);

my $target = getConfig('par_upload_target');
my $target_p = $target;
$target_p =~ s/\/\/\w+:\S+?\@/\/\//ig;				# Hide the user/password in the report
if ($opt_status)
	{
	reconnect();
	my $sql = "SELECT * from EKIT_PAR_UPLOAD ORDER BY TABLENAME";
	my $th = $msdbh->prepare($sql) or die DBI->errstr;
	print " Query sql=$sql params=()\n" if ($opt_d);
	my $num = 0;
	if ($th->execute())
		{
		while (my $href = $th->fetchrow_hashref)
			{
			next if ($opt_table && ($opt_table ne $$href{TABLENAME}));
			$e->I(" Status of table $$href{TABLENAME}: id=$$href{PAR_LAST_ID}, mod=$$href{PAR_LAST_DT}, uploaded $$href{WHEN_DT}");
			$num++;
			}
		$th->finish;
		}
	$e->I("No upload data found") if (!$num);
	}
else	
	{
	$e->F("You must specify one of -download or -upload or -hotel if you want some action here") if (!$opt_download && !$opt_upload && !$opt_hotel);
	$e->I("Starting $0 at $when");
	if ($opt_upload)
		{
		foreach my $item (keys %tables)
			{
			next if ($opt_table && ($opt_table ne $item));
			reconnect();
			my $seq = 1;
			my $sql = "SELECT MAX(ID) as SEQ from EKIT_PAR_UPLOAD WHERE TABLENAME=?";
			my $th = $msdbh->prepare($sql) or die DBI->errstr;
			print " Query sql=$sql params=($item)\n" if ($opt_d);
			if ($th->execute($item))
				{
				while (my $href = $th->fetchrow_hashref)
					{
					$seq = $$href{SEQ};
					}
				$th->finish;
				}
			$seq = 1 if ($seq eq '');
			print "++++++++++++ [$item] at seq=$seq ++++++++++++++\n" if ($opt_t);
		#
		# Can't seem to work out why it locks up unless we re-establish the connection before doing another query
		#
			reconnect();
			if ($opt_reset)
				{
				$e->I(" Resetting table [$item]");
				my $sql = qq{DELETE from EKIT_PAR_UPLOAD WHERE TABLENAME=?};
				my $th = $msdbh->prepare($sql) or die DBI->errstr;
				print " Query sql=$sql params=($item)\n" if ($opt_d);
				$th->execute($item) or die DBI->errstr;
				}
			else
				{
				my $filename = qq{$qt_root/$SID/data/cms_${item}_$seq.txt};
				my @cmsdata;
				if ($opt_id)
					{
					@cmsdata = &read_cms_db_byid($filename,$item,$opt_id);
					}
				else
					{
					@cmsdata = &read_cms_db($filename,$item,$tables{$item}{from});
					}
				if ($rowcnt > 0)
					{
					if (!$opt_noaction)
						{
						$e->I(" Uploading [$item] to $target_p");
						my $response = upload_par_file($filename,$seq,$target,$item,$tables{$item}{noid},$opt_id);
						if ($upload_status ne '200')
							{
							$e->E(" File upload [$item] failed: $upload_status [$upload_error]");
							}
						else
							{
#
# A Status return of 200 is not the entire story, look at the response to see what happened
#
							$response =~ s/\r//g;
							my @info;
							foreach my $line (split(/\n/,$response))
								{
								if ($line =~ /(\[\w+\].*)$/i)
									{
									push @info,$1;
									$e->I("Remote response: $info[$#info]");
									}
								}
							$e->I(" Uploaded $rowcnt [$item] records to $target_p");
							}
						}
					else
						{$e->I(" File upload skipped ($rowcnt records)");}
					}
				else
					{
					$e->I(" No data selected for [$item] this time around");
					}
				}
			}
		}
	if ($opt_download)
		{
		$target = getConfig('par_download_target');
		reconnect();
		my $max_update = 0;
		my $sql = qq{select max(LAST_UPDATE_TS) as MAX_LAST_UPDATE_TS from EKIT_PWI_STATUS};
		my $th = $msdbh->prepare($sql) or die DBI->errstr;
		print " Query sql=$sql \n" if ($opt_d);
		if ($th->execute())
			{
			while (my $href = $th->fetchrow_hashref)
				{
				$max_update = $$href{MAX_LAST_UPDATE_TS};
				}
			$th->finish;
			$max_update = 0 if ($max_update eq '');
			}
		$sql = qq{SELECT * FROM PWI_STATUS WHERE LAST_UPDATE_TS>$max_update};
		my  $ua = LWP::UserAgent->new;
		$when = localtime();
		my $lastwhen = localtime($max_update);
		#$ua->credentials('www.triton-tech.com', '', "mikkel", 'Nautilus!');
		#       authorization_basic => ['mikkel', 'Nautilus!'],
		#$ua->authorization_basic('mikkel', 'Nautilus!');
		die "Fatal error: No 'par_download_target=' specified in server.ini\n" if ($target eq '');
		my $title = "Automated download from $max_update ($lastwhen)";
		my $mytarget = $target;
		$mytarget =~ s/\/\/.*?:.*?@/\/\//ig;
		$e->I(qq{$title, url=$mytarget, sql=$sql});
		my $stuff = $ua->request(POST $target, 
		       Content_Type => 'form-data',
		       Content      => [
								title => $title,
								sql => $sql,
								]);
		$e->I("HTTP status $$stuff{_rc} $$stuff{_msg}") if ($opt_d);	
		$e->F("HTTP Error $$stuff{_rc} $$stuff{_msg}") if ($$stuff{_rc} != 200);	
#		print Dumper \$stuff if ($opt_d);
		reconnect();
		my $buf = $$stuff{_content};
		$buf =~ s/\r//g;
		my @lines = split(/\n/,$buf);
		my $line = 0;
		my @cols;
		foreach my $row (@lines)
			{
			my %hash;
			last if ($row =~ /END OF FILE/i);
			@cols = split(/\t/,$row) if ($line == 0);
			if ($line > 0)
				{
				my @columns;
				my @vals;
				my @data = split(/\t/,$row);
				for (my $i=0;$i<$#cols;$i++)
					{
					next if ($data[$i] eq '');
					next if (!$column_map{$cols[$i]});			# NB presence of column is used to determine if we want it at this stage 
					$hash{$cols[$i]} = $data[$i];
					push @columns,$cols[$i];
					push @vals,$data[$i];
					}
# Do we need to jam in another one ?
				if ($hash{EARLY_ARRIVAL} =~ /Y/i)						# Special procesing for early arrival - need to set the date
					{
					my $day_prior = &DateCalc(&ParseDate($hash{WSDATE_D}),"-1d");
					if (grep(/EARLY_ARRIVAL_DATE/i,@columns)) {
						for(my $i=0;$i<length(@columns);$i++){
							@vals[$i] = UnixDate($day_prior,"20%y-%m-%d") if ($columns[$i] =~ /EARLY_ARRIVAL_DATE/i);
						}
					} else {
						push @columns,'EARLY_ARRIVAL_DATE';
						push @vals,UnixDate($day_prior,"20%y-%m-%d");;
					}
					}
				$e->I("$hash{FULLNAME} $hash{LOCID} $hash{WSDATE_D}");
				my $clist = join(",",@columns);
				my $plist = $clist;
				$plist =~ s/\w+/?/g;
# Delete any previous data for this UID
				my $sql = qq{DELETE FROM EKIT_PWI_STATUS WHERE UID=?};
				my $msth = $msdbh->prepare($sql) or die DBI->errstr;
				print " Del sql=$sql params=($hash{UID})\n" if ($opt_d);
				$msth->execute($hash{UID});
# Insert the new data
				my $sql = qq{INSERT INTO EKIT_PWI_STATUS ($clist) VALUES ($plist)};
				my $msth = $msdbh->prepare($sql) or die DBI->errstr;
				print " Insert sql=$sql params=(".join(",",@vals).")\n" if ($opt_d);
				$msth->execute(@vals);
				}
			$line++;
			}
		$line-- if ($line>0);	# Subtract the header line from the count
		$e->I("Saved $line records to EKIT_PWI_STATUS");
#
# Make a record of it in the download activity log:
#
		reconnect();
		my $sql = "INSERT INTO EKIT_PAR_DOWNLOAD (RECORDS,TITLE,HTTP_STATUS,HTTP_BYTES,HTTP_MESSAGE,HTTP_BODY,TABLENAME) VALUES (?,?,?,?,?,?,?)";
		my $msth = $msdbh->prepare($sql);
		my $len = $$stuff{_request}{_headers}{"content-length"};
		$download_status = $$stuff{_rc};
#		print " ".$$stuff{_content}."\n" if ($opt_d);
		if ($download_status ne '200')		# If something went wrong, we don't record the last WSDATE and ID
			{
			$download_error = $$stuff{_msg};
			}
		my $contents = substr($$stuff{_content},0,250);
		my @params = ($line,"Download >$max_update ($lastwhen)",$$stuff{_rc},$len,$$stuff{_msg},$contents,'PWI_STATUS');
#		print " Insert sql=$sql params=".join(",",@params)."\n" if ($opt_d);
		$msth->execute(@params);
		$msth->finish;
		}
# Update the CMS itself with hotel booking information
	if ($opt_hotel)
		{
		reconnect();
		my $max_update = 0;
		my $last_dt = 0;
		my $sql = qq{select max(LAST_UPDATE_TS) as MAX_LAST_UPDATE_TS from EKIT_PAR_HOTEL};
		my $th = $msdbh->prepare($sql) or die DBI->errstr;
		print " Query sql=$sql \n" if ($opt_d);
		if ($th->execute())
			{
			while (my $href = $th->fetchrow_hashref)
				{
				$max_update = $$href{MAX_LAST_UPDATE_TS};
				}
			$th->finish;
			$max_update = 0 if ($max_update eq '');
			}
		reconnect();
		my $line = 0;
		my $sql = "SELECT * from EKIT_PWI_STATUS where Q18=1 and LAST_UPDATE_TS>?";	
		my @params = ($max_update);
		print " Query sql=$sql params=".join(",",@params)."\n" if ($opt_d);
		my $th = $msdbh->prepare($sql) or die DBI->errstr;
		if ($th->execute(@params))
			{
			my $h = $th->fetchall_hashref("UID");
			$th->finish;
#			print Dumper $h;
			foreach my $uid (keys %{$h})
				{
				reconnect();
				my $sql= qq{select max(par_id) from participant inner join customer on par_cst_id=cst_id where  cst_ref_no=?};
				my @params = ($$h{$uid}{UID});
				my $th = $msdbh->prepare($sql) or die DBI->errstr;
				print " Query sql=$sql params=".join(",",@params)."\n" if ($opt_d);
				$th->execute(@params) ||die "SQL Error\n";
				my ($parid) = $th->fetchrow_array();
				$th->finish;
				if (!$parid)
					{
					$e->E("Could not find participant $uid $$h{$uid}{FULLNAME}");
					}
				else
					{
					my @params = ();
					my $sql = qq{update participant set };
					foreach my $fld (keys %column_map)
						{
						next if (!($column_map{$fld} =~ /^par_/i));			# Only par_* targets are updated in the participant table
						my $val = $$h{$uid}{$fld};
#
# Fixups:
# 
						print "oldval=$val\n" if ($opt_d);
						$val = $room_type{$val} if ($column_map{$fld} =~ /par_rty_id/i);		# Room type
						$val = $card_type{$val} if ($column_map{$fld} =~ /par_cct_id/i);		# Card type
						$val = $m->map_dec($val) if ($column_map{$fld} =~ /par_credit_card_no/i);		# Decode card no
						print qq{$fld=$val\n} if ($opt_d);
						next if ($val eq '');
						$sql .= qq{$column_map{$fld} = ?,};
						push @params,$val;
						}
					next if ($#params == -1);
					chop($sql);												# Strip the last comma
					reconnect();
					$e->I(qq{$$h{$uid}{UID} $$h{$uid}{FULLNAME}});
					$sql .= qq{ where par_id=?};
					push @params,$parid;
					print " UPDATE sql=$sql params=".join(",",@params)."\n" if ($opt_d);
					my $th = $msdbh->prepare($sql) or die DBI->errstr;
					$th->execute(@params) or die DBI->errstr;
					$last_dt = $$h{$uid}{LAST_UPDATE_TS} if ($$h{$uid}{LAST_UPDATE_TS} > $last_dt);
					$line++;
					}
				}
			}
		reconnect();
#
# Make a record of it in the hotel booking activity log:
#
		if ($line)
			{
			reconnect();
			my $sql = "INSERT INTO EKIT_PAR_HOTEL (RECORDS,TITLE,LAST_UPDATE_TS) VALUES (?,?,?)";
			my $msth = $msdbh->prepare($sql);
			my $fromwhen = localtime($max_update);
			my $lastwhen = localtime($last_dt);
			my @params = ($line,"Updated from $max_update ($fromwhen)",$last_dt);
			print " Insert sql=$sql params=".join(",",@params)."\n" if ($opt_d);
			$msth->execute(@params);
			$msth->finish;
			$e->I("Updated $line PARTICIPANT records with hotel booking information");
			}
		}
	}
#
# Now we are done, and can definitely disconnect
#
$msdbh->disconnect;

#--------------------------------------------------------------------------------------
#
# Mainline starts here
#
#--------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------
#
# Subroutines:
#
#-------------------------------------------------------------------------------------

	
sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if $msg;
	print <<USAGE;
Usage: $0 [-version] [-debug] [-help] [-limit=n] [-file=filename]
	-help Display help
	-debug		- Display debugging information
	-version 	- Display version no
	-trace		- Display program trace info
	-limit=n 	- Limits number of records to be process this pass
	-file=		- Read from Tab separated file instead of from SQL Server database	
	-only=		- Do it for this ID only
	-table=		- Only do it for this table
	-reset		- reset administration (for all, or just table if specified)
	-status		- Report on status of each table
	-noaction	- Don't do the upload/download, but do everything else
	-download   - Download data (status/hotel booking)
	-upload     - Upload data (all, or by table)
	-hotel      - process hotel booking data
	-id=        - Select id (or list of id's) instead of normal selection process
USAGE
	exit 0;
	}

sub read_cms_db
	{
	my $filename = shift;
	my $itemname = shift;
	my $from = shift || "3 year ago";

	my $y1=&ParseDate($from);					# Don't go too far back :)
	$last_updated = UnixDate($y1,"20%y-%m-%d");
	$last_id = '';
	$rowcnt = 0;
	
#SELECT convert(varchar,PAR_LAST_DT,20) as LAST,LAST_ID 
	my $sql = <<SQL;
SELECT 
	convert(varchar,PAR_LAST_DT,20) as 		LAST,
	PAR_LAST_ID
from EKIT_PAR_UPLOAD 
	WHERE 
		PAR_LAST_DT=(SELECT MAX(PAR_LAST_DT) FROM EKIT_PAR_UPLOAD WHERE TABLENAME=?)
SQL
	my $th = $msdbh->prepare($sql) or die DBI->errstr;
	print " Query sql=$sql params=($itemname)\n" if ($opt_d);
	if ($th->execute($itemname))
		{
		while (my $href = $th->fetchrow_hashref)
			{
			$last_updated = $$href{LAST} if ($$href{LAST} ne '');
			$last_id = $$href{PAR_LAST_ID};
			}
		$th->finish;
		}
	$when = $last_updated;
#	$when =~ s/\s*\d+:\d+:\d+\s*//g;
#    $last_id = 1 if ($last_id eq '');
	$e->I("Starting [$itemname] after $when, ID=$last_id");
#
# Can't seem to work out why it locks up unless we re-establish the connection before doing another query
#
	reconnect();

	# Are we filtering the requests ?
#	my $where;
#	$where .= qq{ STARTDATE>'$last_updated' };
#	$where = qq{id=$opt_only} if ($opt_only);
	if ($when =~ /(\d+)\/(\d+)\/(\d+) (.*)/)
		{
		$when = qq{$3-$2-$1 $4};
		}
	my $sql = $tables{$itemname}{sql};
	print " Query sql=$sql params=($when)\n" if ($opt_d);
	my $msth = $msdbh->prepare($sql) or die DBI->errstr;
	my @localdata = ();
	if ($msth->execute($when))
		{
		open (CMS,">$filename") || die "Error $! encountered while writing to file $filename\n";
		my $id = '';
		while (my $href = $msth->fetchrow_hashref)
			{
#
# Can we stop yet ?
#
		    my $can_stop = (($id ne $$href{$tables{$itemname}{id}}) && ($last_updated ne $$href{$tables{$itemname}{date}})) ? 1 : 0;
		    if ($opt_d)
		     	{
		    	print " can_stop=$can_stop, cnt=$rowcnt of $opt_limit";
		    	print " date=$$href{$tables{$itemname}{date}}, last_updated=$last_updated";
		    	print " ID=$$href{$tables{$itemname}{id}} ($id)\n";
		    	}
		    last if ($can_stop && (($rowcnt >= $opt_limit) && $opt_limit));
#
# Are we skipping stuff ?
#
			next if (($rowcnt == 0)
					&& ($last_updated eq $$href{$tables{$itemname}{date}})		# Make sure we don't double up on processing
					&& (($last_id >= $$href{$tables{$itemname}{id}}) && $tables{$itemname}{id}));
	
			if ($rowcnt == 0)
				{
				print CMS join("\t",keys %$href)."\n";
				$id = $$href{$tables{$itemname}{id}};
				}
			print "." if ($opt_t);
			print CMS join("\t",values %$href)."\n";
		    push @localdata,$href;
		    $last_updated = $$href{$tables{$itemname}{date}} if ($$href{$tables{$itemname}{date}} ne '');
		    $last_id = $$href{$tables{$itemname}{id}};
		    $id = $$href{$tables{$itemname}{id}};
		    $rowcnt++;
		    }
		print "\n" if ($opt_t);
		$msth->finish;
		close(CMS);
		unlink $filename if ($rowcnt == 0);		# Be tidy with files - kill them if empty
		}
	reconnect();
	@localdata;
	}

#
# This is a cut down version that fetches specific id's
#
sub read_cms_db_byid
	{
	my $filename = shift;
	my $itemname = shift;
	my $idlist = shift;

	$e->I("Starting [$itemname] for ID's=$idlist");

	$idlist =~ s/,/','/ig;
	$idlist = "'$idlist'";
	print "idlist=$idlist\n";
	my $sql = eval("qq{$tables{$itemname}{idsql}}");
	print " Query sql=$sql \n" if ($opt_d);
	my $msth = $msdbh->prepare($sql) or die DBI->errstr;
	my @localdata = ();
	if ($msth->execute)
		{
		open (CMS,">$filename") || die "Error $! encountered while writing to file $filename\n";
		my $id = '';
		while (my $href = $msth->fetchrow_hashref)
			{
		    if ($opt_d)
		     	{
		    	print " cnt=$rowcnt of $opt_limit";
		    	print " ID=$$href{$tables{$itemname}{id}} ($id)\n";
		    	}
		    last if (($rowcnt >= $opt_limit) && $opt_limit);
	
			if ($rowcnt == 0)
				{
				print CMS join("\t",keys %$href)."\n";
				}
			print "." if ($opt_t);
			print CMS join("\t",values %$href)."\n";
		    push @localdata,$href;
		    $rowcnt++;
		    }
		print "\n" if ($opt_t);
		$msth->finish;
		close(CMS);
		unlink $filename if ($rowcnt == 0);		# Be tidy with files - kill them if empty
		}
	reconnect();
	@localdata;
	}

sub upload_par_file
	{
	my $filename = shift;
	my $seq = shift;
	my $target_url = shift;
	my $prefix = shift;
	my $noid = shift;
	my $idlist = shift;
	
	my  $ua = LWP::UserAgent->new;
	$when = localtime();
	#$ua->credentials('www.triton-tech.com', '', "mikkel", 'Nautilus!');
	#       authorization_basic => ['mikkel', 'Nautilus!'],
	#$ua->authorization_basic('mikkel', 'Nautilus!');
	die "Fatal error: No 'par_upload_target=' specified in server.ini\n" if ($target_url eq '');
	my $stuff = $ua->request(POST $target_url, 
	       Content_Type => 'form-data',
	       Content      => [
	       					filename => [$filename], 
							SID => $SID,
							title => "Automated upload $seq $when",
							prefix => "uploaded_$prefix",
							]);
	
	print Dumper \$stuff if ($opt_d);
#
# Make a record of it in the upload activity file:
	if (!$idlist)
		{
		my $sql = "INSERT INTO EKIT_PAR_UPLOAD (RECORDS,TITLE,HTTP_STATUS,HTTP_BYTES,HTTP_MESSAGE,HTTP_BODY,FILENAME,PAR_LAST_DT,PAR_LAST_ID,TABLENAME) VALUES (?,?,?,?,?,?,?,?,?,?)";
		my $msth = $msdbh->prepare($sql);
		my $len = $$stuff{_request}{_headers}{"content-length"};
		$upload_status = $$stuff{_rc};
	# ???
	# Should also check the response that came back in the message too, because even though the HTTP
	# request 'worked', the CGI upload script may have found a problem and reported failure
	#
		print " ".$$stuff{_content}."\n" if ($opt_d);
		if ($upload_status ne '200')		# If something went wrong, we don't record the last WSDATE and ID
			{
			$upload_error = $$stuff{_msg};
			$last_updated = '1980-10-1';
			$last_id = '0';
			}
		print " last_updated=$last_updated\n" if ($opt_d);
		my $when = $last_updated;
		if ($when =~ /(\d+)\/(\d+)\/(\d+) (.*)/)
			{
			$when = qq{$3-$2-$1 $4};
			}
		my $contents = substr($$stuff{_content},0,250);
		$last_id = 0 if ($noid);
		my @params = ($rowcnt,"Upload $seq $when",$$stuff{_rc},$len,$$stuff{_msg},$contents,$filename,$when,$last_id,$prefix);
		print " Insert sql=$sql params=".join(",",@params)."\n" if ($opt_d);
		$msth->execute(@params);
		$msth->finish;
		print " Last updated=$last_updated (id=$last_id)\n" if ($opt_t);
		}
	$$stuff{_content};
	}

sub reconnect
	{
	if ($msdbh)
		{
		$msdbh->disconnect;
		undef $msdbh;
		}
	if (!$msdbh)
		{
		$msdbh = dbh TPerl::MyDB(db=>'mssql') or die ("Could not connect to database :".TPerl::MyDB->err);
		print "==> Connected to CMS DB OK\n" if ($opt_d);
		}
	} 
