#!/usr/bin/perl
#$Id: filter_csv.pl,v 2.2 2005-05-10 02:54:31 triton Exp $
use strict;
use File::Path;
use TPerl::TritonConfig;
use TPerl::MyDB;
use TPerl::Error;
use TPerl::Event;
use Config::IniFiles;
use TPerl::CmdLine;
use TPerl::ASP;

my $e = new TPerl::Error (ts=>1);
my $troot = getConfig('TritonRoot');
my $whoru = 'system';
my $dbh = dbh TPerl::MyDB(attrs=>{PrintError=>0,RaiseError=>0}) or 
	$e->F ("could not connect to database :".DBI->errstr);
my $ev = new TPerl::Event(dbh=>$dbh);
my $ez = new TPerl::DBEasy(dbh=>$dbh);

my ($SID,$batchno);
{   
    ##Check if there is anything to do, and then update the batch table 
    my $sql = 'select * from BATCH where status=2 order by UPLOAD_EPOCH ASC';
    if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}})){
        if (@$res == 0){
            # $e->I("Quitting Nothing to do");
            exit;
        }
        $SID = $res->[0]->{SID} or
            $e->F("Could not get SID from this record".Dumper $res->[0]);
        $batchno = $res->[0]->{BID} or
            $e->F("Could not get batchno from this record".Dumper $res->[0]);
    }else{
        $e->F({sql=>$sql,dbh=>$dbh});
    }

}
{   
    ##Check if anyone is in 'BEING FILTERED' status and quit if they are.
    my $sql = 'select count(*) from BATCH where status =3';
    if (my $res = $dbh->selectall_arrayref($sql)){
        if ($res->[0]->[0] >0){
            $e->I("Quitting. Someone else is being prepared");
            exit;
        }
    }else{
        $e->F({sql=>$sql,dbh=>$dbh});
    }
}

### The filter command will have 4 args added to its command line.
# These are src dest SID batchno
my $filter = 'filter_default.pl';
my $end = 'csv';

my $fdir = join '/',$troot,$SID,'filtered';
mkpath ($fdir,1) unless -d $fdir;

$e->I("Starting filtering for batch $batchno for $SID");
my $lfn = join '/',$troot,'log',"filter_csv-$SID-batch-$batchno.log";
my $lfh = new FileHandle (">> $lfn") or $e->F("Could not open '$lfn':$!");
$e->fh([$lfh,\*STDOUT]);

my $scriptsDir = getConfig('scriptsDir') or $e->F("Could not get scriptsDir from getConfig");

# Lets get the packet (binfo) about this file and see which upload_csv.ini file to open..
my $pktdir = join '/',$troot,$SID,'binfo';
$e->F("pkt dir does not exist") unless -d $pktdir;
my $pkt_ini_fn = join '/',$pktdir,"$batchno.ini";
$e->F("Ini file $pkt_ini_fn does not exist") unless -f $pkt_ini_fn;
my $pkt_ini = new Config::IniFiles (-file=>$pkt_ini_fn);
$e->F("Could not open '$pkt_ini_fn' as an ini file") unless $pkt_ini;

my $format = $pkt_ini->val('args','format');
my $inifn = join '/',$troot,$SID,'config','upload_csv.ini';

my $upinifile = join '/',$troot,$SID,'config','upload.ini';
if (-f $upinifile && $format){
	my $upini = new Config::IniFiles (-file=>$upinifile) ||
		$e->F("Could not open $upinifile' as an ini file");
	my $sect = "format-$format";
	if (my $file = $upini->val($sect,'file')){
		$inifn = join '/',$troot,$SID,'config',$file
	}else{
		$e->F("Missing [$sect] file= from '$upinifile'");
	}
}
$e->I("Looking for filter info from '$inifn'");
$e->F("ini file '$inifn' does not exist") unless -e $inifn;
my $ini = new Config::IniFiles(-file=>$inifn) || 
	$e->F("Could not open '$inifn' as an ini file");
if (my $new_filter = $ini->val('main','filter')){
	$e->I("Using '$new_filter' instead of $filter");
	$filter = $new_filter;
}
$e->I("Using filter '$filter'");
my $src = join '/',$troot,$SID,'incdir',"batch_$batchno.$end";
my $dst = join '/',$fdir,"batch_$batchno.$end";
my $cmd = qq{perl $filter $src $dst $SID $batchno};
my $exec = execute TPerl::CmdLine (cmd=>$cmd,dir=>$scriptsDir);
if ($exec->success){
	# Update the database etc.
	$e->I("Finished Filtering.  Update the database.");
	my $asp = new TPerl::ASP(dbh=>$dbh);
	my $fields = $asp->batch_fields;
	my $row = {BID=>$batchno,SID=>$SID,MODIFIED_EPOCH=>'now',STATUS=>4};
	foreach (keys %$fields){
		delete $fields->{$_} unless exists $row->{$_};
	}
	$e->F($_) if $_ = $ez->row_manip(vals=>$row,fields=>$fields,action=>'update',
		keys=>['SID','BID'],table=>'BATCH');
					
}else{
	$e->E("It did not work:".$exec->output);
}

