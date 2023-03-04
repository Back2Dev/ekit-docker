#!/usr/bin/perl
# $Id: pwikit_cms_refdata_import.pl,v 1.18 2012-09-06 03:02:25 triton Exp $
# Script to read participant/workshop data from the CMS system and process it
#
# Script to read reference data from the CMS system and xfer it to the eKit Server
#
# 1st half of script runs on CMS Server: map_cms_par_upload.pl

use strict;
use DBI;
use Date::Manip;							#perl2exe
use Getopt::Long;							#perl2exe
use Data::Dumper;							#perl2exe

use TPerl::Error;		  					#perl2exe
use TPerl::TSV;								#perl2exe
use TPerl::MyDB;							#perl2exe
#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

our $qt_root;
our $dbt;
our %config;
require 'TPerl/qt-libdb.pl';
require 'TPerl/360-lib.pl';
require 'TPerl/pwikit_cfg.pl';
$| = 1;

our($opt_d,$opt_h,$opt_v,$opt_t,$opt_limit,
		$opt_redo,
		$opt_table,
		$opt_file,
		$opt_delete,
		$opt_status,
		$opt_reset,
		);
GetOptions (
			help => \$opt_h,
			debug => \$opt_d,
			trace => \$opt_t,
			version => \$opt_v,
			'redo=i' => \$opt_redo,
			'limit=i' => \$opt_limit,
			'table=s' => \$opt_table,
			'file=s' => \$opt_file,
			delete => \$opt_delete,
			status => \$opt_status,
			reset => \$opt_reset,
			) or die_usage ( "Bad command line options" );
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwikit_cms_refdata_import.pl,v 1.18 2012-09-06 03:02:25 triton Exp $'."\n";
	exit 0;
	}
$dbt = 1 if ($opt_d);
my %xlate = (
			ADMIN => {
					target => 'PWI_ADMIN',
					target_pk => 'ADMIN_KV',
					fldmap =>	{
							ID 			=> 'ADMIN_ID',
							ADMIN_NAME	=> 'ADMIN_NAME',
							EMAIL 		=> 'ADMIN_EMAIL',
							},
#					regexp => { mapconsulting => 'mappwi', },
					},
			EXEC => {
					target => 'PWI_EXEC',
					target_pk => 'EXEC_KV',
					fldmap =>	{
							ID 			=> 'EXEC_ID',
							FULLNAME	=> 'EXEC_NAME',
							EMAIL 		=> 'EXEC_EMAIL',
							},
#					regexp => { mapconsulting => 'mappwi', },
					},
			WORKSHOP => {
					target => 'PWI_WORKSHOP',
					target_pk => 'WS_KV',
					fldmap =>	{
							ID 			=> 'WS_ID',
							WSDATE		=> 'WS_STARTDATE',
							},
					lookup =>	{
							loc_kv =>	{
										dest 	=> 'WS_LOCREF',												# Put the value in this field (ie PWI_WORKSHOP.fieldname)
										sql 	=> 'SELECT LOC_KV as PARAM from PWI_LOCATION WHERE LOC_CODE =?',		# Use this sql to get the value
										param	=> 'LOC_CODE',												# Use this value as a parameter to the SQL
										},
							loc_name =>	{
										dest 	=> 'WS_TITLE',												# Put the value in this field (ie PWI_WORKSHOP.fieldname)
										sql 	=> 'SELECT LOC_CODE as PARAM from PWI_LOCATION WHERE LOC_CODE =?',		# Use this sql to get the value
										param	=> 'LOC_CODE',												# Use this value as a parameter to the SQL
										evalme	=> ' $$uref{WSDATE}',
										},
								},
					mayupdate =>	{
							loc_kv =>	{
										selsql => 
										dest 	=> 'WS_LOCREF',												# Put the value in this field (ie PWI_WORKSHOP.fieldname)
										sql 	=> 'SELECT LOC_KV as PARAM from PWI_LOCATION WHERE LOC_CODE =?',		# Use this sql to get the value
										param	=> 'LOC_CODE',												# Use this value as a parameter to the SQL
										},
									},
					},
			LOCATION => {
					target => 'PWI_LOCATION',
					target_pk => 'LOC_KV',
					fldmap =>	{
							ID			=> 'LOC_ID',
							LOC_CODE	=> 'LOC_CODE',
							NAME		=> 'LOC_NAME',
							NAME_LONG	=> 'LOC_DISPLAY',
							FAX			=> 'LOC_FAX',
							ACTIVE		=> 'LOC_ACTIVE',
							ADMIN_PHONE => 'ADMIN_PHONE',
							ADMIN_FAX => 'ADMIN_FAX',
							},
					},
			);


#--------------------------------------------------------------------------------------
#
# Mainline starts here
#
#--------------------------------------------------------------------------------------
# First up, connect to our local database 
our $dbh = dbh TPerl::MyDB() or die ("Could not connect to database :".DBI->errstr);
our $dbh2 = dbh TPerl::MyDB() or die ("Could not connect to database :".DBI->errstr);

my $e = new TPerl::Error;
my $when = localtime();
$e->I("Starting $0 at $when");

my $nprocessed;
my $currid = '';
my $bossix = 1;
our @cmsdata;
my $SID = 'PARTICIPANT';
my @tables = (qw{admin exec location workshop});
@tables = ($opt_table) if ($opt_table);
if ($opt_reset)
	{
	$| = 1;
	my $what = ($opt_table) ? $opt_table : 'ALL';
	print "Are you sure you want to delete $what reference data ? ([n]/y):";
	my $ans = getc();
	if ($ans =~ /^y/i)
		{
		foreach my $table (@tables)
			{
			my $tablename = uc($table);
			my $sql = "DELETE FROM PWI_UPLOAD_$tablename";
			my $th = &db_do($sql);
			$th->finish;
			}
		print "Done.\n";
		}
	else {print "Not done.\n";}
	}
elsif ($opt_status)
	{
	foreach my $table (@tables)
		{
		my $tablename = uc($table);
		my $sql = "SELECT COUNT(*) as CNT FROM $xlate{$tablename}{target}";
		my $th = &db_do($sql);
		my ($rcnt) = $th->fetchrow();
		$th->finish;

		my $sql = "SELECT MIN(BATCHNO) AS MINB,MAX(BATCHNO) as MAXB FROM PWI_UPLOAD_$tablename";
		my $th = &db_do($sql);
		my ($minb,$maxb) = $th->fetchrow();
		$th->finish;

		my $sql = "SELECT MAX(LAST_UPDATE_DT) as MAXWHEN, MAX(ID) as MAXID,MIN(ID) as MINID FROM PWI_UPLOAD_$tablename";
		my $th = &db_do($sql);
		my ($whenb,$maxid,$minid) = $th->fetchrow();
		$th->finish;

		print "$tablename: $rcnt records, uploaded in batches $minb => $maxb, id's=$minid-$maxid (last record modified at $whenb)\n";
		}
	}
else
	{
	foreach my $table (@tables)
		{
		$nprocessed = 0;
		my $tablename = uc($table);
		print "Reference Table: $tablename\n" if ($opt_t);
	#
	# Determine which batch we are dealing with, or if we are just slurping everything we have
	#
		my $sql = "SELECT MAX(BATCHNO) FROM PWI_UPLOAD_$tablename";
		my $th = &db_do($sql);
		my @row = $th->fetchrow();
		$th->finish;
		my $frombatch = (@row) ? $row[0] : '100';
		my @upfiles = ();
		my $datadir;
		if ($opt_file)
			{
			push @upfiles,$opt_file;
			}
		else
			{
			$datadir = "${qt_root}/$SID/data";
			die ("Error $! while opening directory $datadir\n") if (! opendir(DDIR,"$datadir"));
			@upfiles = grep (/^uploaded_${table}_\d+\.txt$/i,readdir(DDIR));
			closedir(DDIR);
			}
	#
	# Process the files:
	#
		foreach my $upf (@upfiles)
			{
			my $upfile =  qq{$datadir/$upf};
			$e->F("Dodgy file name encountered: $upf") if !($upf =~ /(\d+)\.txt/i);
			my $bno = $1;
			next if (($bno <= $frombatch) && ($opt_redo != $bno));
			print "File=$upf\n" if ($opt_t);
		#
		# Suck the file in, and stack it up as hashes to iterate through
		#
			our @cmsdata = ();
			#e->F("CMS Data file name (missing batchno): $upfile does not exist") unless -e $upfile;
			my $tsv = new TPerl::TSV (file=>$upfile);
			my $sql = "DELETE FROM PWI_UPLOAD_$tablename where BATCHNO=?";
			&db_do($sql,$bno);
			while (my $row = $tsv->row)
				{
				$$row{BATCHNO} = $bno;
				$$row{IMPORT_DT} = UnixDate('today',"%Y-%m-%d %H:%M:%S");
	#			my $flist = join(",",keys %$row);
				my @values = ();
				my (@ph,@fl);
				map {if (trim($$row{$_})){push @values,trim($$row{$_});push @ph,"?";push @fl,$_;}} keys %$row;
				my $flist = join ",",@fl;
				my $vlist = join ",",@ph;
				my $sql = "INSERT INTO PWI_UPLOAD_$tablename ($flist) VALUES ($vlist)";
				&db_do($sql,@values);
				}
		#
		# Now fetch the data back and dispatch it:
		#
			print "Processing PWI_$tablename \n" if ($opt_t);
			my $sql = "SELECT * FROM PWI_UPLOAD_$tablename WHERE BATCHNO=?";
			my $th = &db_do($sql,$bno);
			my $rowcnt = 0;
			while (my $href = $th->fetchrow_hashref())
				{
				print "Data=".join(",",values(%$href))."\n" if ($opt_d);
				process($tablename,$href);
				$rowcnt++;
				}
			$th->finish;
			$e->I("PWI_$tablename: Imported $nprocessed records (of $rowcnt) from file: $upf");
			}
		}
	}
&db_disc;
&db_disc2;

#-------------------------------------------------------------------------------------
#
# Subroutines:
#
#-------------------------------------------------------------------------------------

sub process
	{
	if (($opt_limit) && ($nprocessed >= $opt_limit))
		{
#		print "!" if ($opt_t);
		return 0;
		}
	$nprocessed++;
	print "." if ($opt_t);
	my $tname = shift;
	my $uref = shift;
	foreach my $key (sort keys %{$uref})
		{
		$$uref{$key} =~ s/\s\s+/ /g;			# Kill multiple spaces
		$$uref{$key} = trim($$uref{$key});		# Trim leading and trailing spaces
#		print "	$key=[$$uref{$key}]\n";
		}
#
# Now let's get serious about this: we have everything together in this %uref hash, 
# so let's see what we need to do with it:
#
#	print Dumper %xlate;
	my $target = $xlate{$tname}{target};
	my $idfield = $xlate{$tname}{fldmap}{ID};
	if ($opt_delete)
		{
		my $sql = qq{DELETE FROM $target where $idfield=?};	# Do we need to clear it out first ?
		my $th2 = &db_do2($sql,$$uref{ID});
		$th2->finish;
		}
	my $sql = qq{SELECT * FROM $target where $idfield=?};	# Does it exist already ?
	my $th2 = &db_do2($sql,$$uref{ID});
	my $rowcnt = 0;
	if (my $href = $th2->fetchrow_hashref())
		{
		$th2->finish;
		$e->I("$tname ID $$uref{ID} exists already");
		my @flist;
		my @vlist;
		foreach my $col (keys %{$xlate{$tname}{fldmap}})
			{
			my $destcol = $xlate{$tname}{fldmap}{$col};
			$$uref{$col} =~ s/(\d+-\d+-\d+) .*/$1/g if ($destcol =~ /DATE$/i);
			if ($xlate{$tname}{regexp})		# Need to fix the data with a regexp?
				{
				foreach my $regexp (keys %{$xlate{$tname}{regexp}})
					{
					$$uref{$col} =~ s/$regexp/$xlate{$tname}{regexp}{$regexp}/ig;
					}
				}
			if ($$uref{$col} ne $$href{$destcol})
				{
				print "Column $destcol changed, $$href{$destcol} => $$uref{$col}\n" if ($opt_d);
				push @flist,$destcol;
				push @vlist,$$uref{$col};
				}
			}
		if (@flist)
			{
			my $sql = qq{UPDATE $target SET }; 
			$sql .= join("=?,",@flist);
			$sql .= "=? WHERE $idfield=?";
			&db_do2($sql,(@vlist,$$uref{ID}));
			}
		else
			{
			print "No changes to record\n" if ($opt_t);
			}
		}
	else
		{
		$e->I("$target ID $$uref{ID} is new");
		my @fields;
		my @values;
		my $sql = "SELECT MAX($xlate{$tname}{target_pk}) AS MAXID FROM $target";
		my $th2 = &db_do2($sql);
		my $href = $th2->fetchrow_hashref();
		push @fields,$xlate{$tname}{target_pk};
		push @values,$$href{MAXID}+1;
		$th2->finish;
		foreach my $col (keys %{$xlate{$tname}{fldmap}})
			{
			my $destcol = $xlate{$tname}{fldmap}{$col};
			$$uref{$col} =~ s/(\d+-\d+-\d+) .*/$1/g if ($destcol =~ /DATE$/i);
			print "Column $destcol = $$uref{$col}\n" if ($opt_d);
			push @fields,$destcol;
			push @values,$$uref{$col};
			}
		if ($xlate{$tname}{lookup})
			{
			foreach my $lu (keys %{$xlate{$tname}{lookup}})
				{
				my $sql = $xlate{$tname}{lookup}{$lu}{sql};
				my $param = $$uref{$xlate{$tname}{lookup}{$lu}{param}};
				my $th2 = &db_do2($sql,$param);
				my $href = $th2->fetchrow_hashref();
				if (!$$href{PARAM})
					{
					$e->E("Lookup not found for $xlate{$tname}{lookup}{$lu}{param}='$param' (sql='$xlate{$tname}{lookup}{$lu}{sql}')");
					next;
					}
				push @fields,$xlate{$tname}{lookup}{$lu}{dest};
				push @values,$$href{PARAM};
				if ($xlate{$tname}{lookup}{$lu}{evalme})
					{
					print qq{eval='$xlate{$tname}{lookup}{$lu}{evalme}'\n} if ($opt_t);
					$values[$#values] .= eval('qq{'.$xlate{$tname}{lookup}{$lu}{evalme}.'}');
					print "now $lu='$values[$#values]' \n" if ($opt_t);
					}
				$th2->finish;
				}
			}
		my @ph = ();
		map {push @ph,"?";} @fields;
		my $flist = join ",",@fields;
		my $vlist = join ",",@ph;
		my $sql = qq{INSERT INTO $target ($flist) VALUES ($vlist) }; 
		&db_do2($sql,@values);
		}	
# This bit of code is probably redundant for the moment, but might be useful later
	if ($xlate{$tname}{update})
		{
		foreach my $lu (keys %{$xlate{$tname}{update}})
			{
			my $sql = $xlate{$tname}{update}{$lu}{sql};
			my @params;
			push @params,$$uref{$xlate{$tname}{update}{$lu}{param}} if ($$uref{$xlate{$tname}{update}{$lu}{param}});
			my $th2 = &db_do2($sql,@params);
			$th2->finish;
			}
		}
	}

	
sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if $msg;
	print <<USAGE;
Usage: $0 [-version] [-debug] [-help] [-limit=n] [-file=filename] [-redo=batchno] [-table=table]
    -debug          Show debug information (more detailed debugging output)
    -file=          Read from Tab separated file (normally finds file by default)
    -help           Display help (this mesage)
    -limit=         Only do <n> records
    -redo=          Re-do this batch
    -reset          reset table or all tables (ie delete data). Cannot be undone !!!
    -status			Display status of tables
    -table=         Just look at this table only
    -trace          Show trace information (high level debugging output)
    -version        Display version no
USAGE
	exit 0;
	}



1;
