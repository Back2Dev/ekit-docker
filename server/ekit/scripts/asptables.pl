#!/user/bin/perl
#$Id: asptables.pl,v 1.19 2011-08-10 01:35:20 triton Exp $
use strict;
use FileHandle;
use Getopt::Long;
use Data::Dumper;
use Cwd;

use POSIX qw(strftime);
use TPerl::ASP;
use TPerl::MyDB;
use TPerl::Error;
use TPerl::TritonConfig;

my $dump = 0;
my $read = 0;
my $dump_file = 'aspdump';
my $drop = 0;
my $create = 0;
my $db = undef; # get EngineDB database
my $help = 0;
my $tpeople = 0;

GetOptions (
	'dump+'=>\$dump,
	'read+'=>\$read,
	'file:s'=>\$dump_file,
	'create+'=>\$create,
	'drop+'=>\$drop,
	'db:s'=>\$db,
	'help+'=>\$help,
	'tpeople+'=>\$tpeople,
) or die "Bad Options";
if ($help){
print qq{Usage: $0 [options]
	where the options include
	dump
	drop
	create
	read
	ib
	file=
	help
	tpeople
	db=
};
	exit 0;
}

my $dbh = dbh TPerl::MyDB(db=>$db) or die "canna connect to db '$db'";
my $asp = new TPerl::ASP(dbh=>$dbh);
my $tables = $asp->table_create_list;
if ($dump){
	my $fh = new FileHandle ("> $dump_file") or die "canna open dump file for writing:$!";
	die "table4file error:$_" if $_ = $asp->tables2file(fh=>$fh,dbh=>$dbh);
}
my %args = ();
$args{create} = $tables if $create;
$args{drop} = $tables if $drop;
if (%args){
	my $nul = new FileHandle ("> /dev/null") or die "canna open '/dev/null'";
	$args{fh} = $nul;
	# print Dumper \%args;
	die "Table Error:".Dumper($_) if $_ = $asp->tables(%args);
}
if ($read){
	my $fh = new FileHandle ("< $dump_file") or die "canna open $dump_file:$!";
	my @errors = ();
	while (<$fh>){
		chomp;
		print "sql=$_\n";
		$dbh->do ($_) or push @errors, {sql=>$_,err=>$dbh->errstr};
	}
	if (@errors){
		printf "%s errors occured", scalar @errors;
		print Dumper \@errors;
		printf "%s errors occured", scalar @errors;
	}
}
my $client_name = 'Triton';

my $rtdb = 'rt';

my $ez = new TPerl::DBEasy (dbh=>$dbh);
my $e = new TPerl::Error;
my $troot = getConfig("TritonRoot") or $e->F("Could not get TritonRoot");

if ($tpeople){
	# my @internal_people = qw(ac mikkel cesa jmuska skye mzheng lauren mwang criley colleen mfeely jello);
	my $internal_people = getTritonPeople();
	$e->F("No result from getTritonPeople") unless @$internal_people;
	$e->I("Add $client_name people to $db");
	#add a vhost if there is not one
	my $cgimr = getConfig('cgimrDir') or $e->F("Need cgimrDir from TritonConfig");
	my $scripts = getConfig('scriptsDir') or $e->F("Need scriptsDir from TritonConfig");
	my $hroot = getConfig('HostRoot') or $e->F("Need HostRoot from TritonConfig");
	my $vdomain = getConfig('FQDN') or $e->F("Need FQDN from TritonConfig");
	
	$e->W("If the vhost insert fails, specify a domain for this host with the --domain flag") unless $vdomain;
	my $vh_vals = {VHOSTROOT=>$hroot,DEF_EMAIL=>'ac@market-reseearch.com',
		CVSROOT=>join('/',$hroot,'cvs'),
		CGI_MR=>$cgimr,
		SCRIPTS=>$scripts,
		DEF_EMAIL=>'ac@market-research.com',
		VDOMAIN=>$vdomain,
		TEMPLATES=>join('/',$troot,'templates'),
		DOCUMENTROOT=>join('/',$hroot,'htdocs'),
		SERVERROOT=>'/usr/local/apache',
		TRITONROOT=>$troot,
		};

	get_record(ez=>$ez,err=>$e,table=>'VHOST',params=>{VID=>'%'},like=>1,keys=>['VID'],vals=>$vh_vals);

	my $cl = get_record (err=>$e,table=>'CLIENT',ez=>$ez,params=>{CLNAME=>"%$client_name%"},like=>1,keys=>['CLID'],vals=>{CLNAME=>$client_name});
	$e->I("Using client $cl->{CLNAME} (id=$cl->{CLID})");
	my $vhs = $dbh->selectall_arrayref('select * from VHOST',{Slice=>{}}) or
		$e->E("Could not get vhost list:".$dbh->errstr);
	foreach my $vh (@$vhs){
		my $co_vals = {CLID=>$cl->{CLID},VID=>$vh->{VID},START_EPOCH=>strftime('%Y %m %d',localtime(time-24*3600)),
			END_EPOCH=>strftime('%Y %m %d',localtime(time+10*356.25*24*3600)),EMAILS=>1,DATA_FETCH=>1,ALLOWED_JOBS=>1};
		my $cl = get_record (ez=>$ez,err=>$e,table=>'CONTRACT',params=>{CLID=>$cl->{CLID},VID=>$vh->{VID}},keys=>['COID'],vals=>$co_vals);
	}
	$e->I("About to try connection to rt database");
	my $rtdbh = dbh TPerl::MyDB (db=>$rtdb,debug=>0) or $e->E("Could not connect to RT database:".TPerl::MyDB->err);
	foreach my $uid (@$internal_people){
		my $rt_recs;
		if ($rtdbh){
			$rt_recs = $rtdbh->selectall_arrayref('select * from users where user_id=?',{Slice=>{}},$uid);
			if (@$rt_recs != 1){
				$e->E(sprintf "Skipping $uid. There are %s rt records",@$rt_recs);
				next;
			}
		}else{
			print "Could not get through to rt db.  Please enter password for '$uid'\n";
			my $pwd = <STDIN>;
			$rt_recs->[0]->{PASSWORD} = chomp ($pwd);
		}
		my $rt = $rt_recs->[0];
		my $vals = {UID=>$uid,PWD=>$rt->{PASSWORD}};
		my @names = split /\s/,$rt->{REAL_NAME};
		$vals->{FIRSTNAME} = $names[0];
		$vals->{LASTNAME} = $names[-1];
		$vals->{CLID} = $cl->{CLID};
		$e->I("Checking $vals->{UID}");
		my $ui = get_record(err=>$e,table=>'TUSER',ez=>$ez,params=>{UID=>$uid},vals=>$vals);
		foreach my $vh (@$vhs){
			my $va_vals = {UID=>$ui->{UID},VID=>$vh->{VID}};
			$va_vals->{$_} =1 foreach qw (J_CREATE        J_READ  J_USE   J_DELETE);
			get_record (ez=>$ez,err=>$e,table=>'VACCESS',params=>{UID=>$ui->{UID},VID=>$vh->{VID}},vals=>$va_vals);
		}
	}
}

sub get_record {
	my %args = @_;
	my $table = $args{table};
	my $vals = $args{vals};
	my $keys = $args{keys};
	my $ez = $args{ez};
	my $like = $args{like};
	my $params = $args{params};

	my $recurse = $args{recurse};


	my $sql = "select * from $table where ";
	if ($like){
		$sql .= join ' and ',map " $_ like ? ",keys %$params;
	}else{
		$sql .= join ' and ',map " $_ = ? ",keys %$params;
	}
	my $ps = [values %$params];
	# print "sql=$sql ". Dumper $ps;
	my $count = $ez->dbh->selectall_arrayref($sql,{Slice=>{}},@$ps) or
		$e->F("Problem with $sql ".Dumper ($ps).$ez->dbh->errstr);
	return $count->[0] if @$count > 0;

	$e->I("Creating a $table with ". join ',',map "$_=$vals->{$_}",keys %$vals);
	if ($keys){
		my $key_vals = $ez->next_ids(table=>$table,keys=>$keys);
		foreach my $knum (0..$#$keys){
			$vals->{$keys->[$knum]} = $key_vals->[$knum] unless exists $vals->{$keys->[$knum]};
		}
	}
	if (my $err = $ez->row_manip(table=>$table,action=>'insert',vals=>$vals)){
		$e->F("Could not insert a into $table ". Dumper $err );
	}
	$e->F("Tried to many times") if $recurse >1;
	return get_record(%args,recurse=>$recurse+1);
}

