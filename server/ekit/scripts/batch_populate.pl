#!/usr/bin/perl
#$Id: batch_populate.pl,v 2.7 2011-09-07 10:01:30 triton Exp $
use strict;
use Data::Dumper;
use Getopt::Long;
use FileHandle;
use POSIX;
use Spreadsheet::WriteExcel::Big;

use TPerl::MyDB;
# use TPerl::qtdb;
use TPerl::Error;
use TPerl::TritonConfig;
use TPerl::ASP;
use TPerl::Template;
use TPerl::Engine;
use TPerl::DBEasy;


my $e = new TPerl::Error;

my $do_insert = 0;
my $do_batch_file = 0;
my $overwrite_existing_batch_file = 0;
my $bid = undef;
my $pwds = 1;
my $title = undef;
my $url = 'http://<%fqdn%>/survey/start/<%SID%>/<%password%>';
my $fqdn = getConfig('FQDN') || $e->F("Could not get FQDN from getConfig");

GetOptions (
	'insert!'=>\$do_insert,
	'file'=>\$do_batch_file,
	'batch_no:i'=>\$bid,
	'overwrite!'=>\$overwrite_existing_batch_file,
	'passwords:i'=>\$pwds,
	'title:s'=>\$title,
	'url:s'=>\$url,
	'fqdn:s'=>\$fqdn,
) or usage ("Bad options");

my $SID = shift;
usage ("No SID on command line") unless $SID;

sub usage {
	my $msg = shift;
	print qq{$msg
 Usage $0 [options] SID
  --passwords=N   insert N passwords into the table
  --insert	do the insert
  --batch_no N  use batch nuber N
  --file	write the batch file to incoming dir
  --overwrite	overwrite existing batch file.
  --title="Batch Title"
};
exit;
}

usage ("perhaps you should use --insert or --file or both") unless $do_batch_file || $do_insert;

my $dbh = dbh TPerl::MyDB () or $e->F( "Could not connect to db");
# Get max bid.
unless ($bid){
	my $sql = "select MAX (BATCHNO) from $SID";
	my $res = $dbh->selectall_arrayref($sql);
	# print Dumper $res;
	my $ans = $res->[0]->[0];
	$bid = $ans;
	$bid = $ans+1 if $do_insert;
	$bid = 100 unless $ans;
	# print "bid=$bid do_insert=$do_insert\n";
}

my $troot = getConfig('TritonRoot');
my $ext = 'xls';
$ext = 'csv' if ($do_insert);
my $fn = join '/',$troot,$SID,'incdir',"batch_$bid.$ext";

if ($do_insert){
	$e->I( "Putting $pwds passwords into $SID as batch $bid");
	# $e->F("$pwds passwords is above the limit of 60,000") if $pwds >60000;
	my $fh = new FileHandle ("> $fn") || $e->F("Could not open $fn");
	my $qtdb = new TPerl::Engine(dbh=>$dbh);
	foreach my $i (1..$pwds){
		my $pwd = $qtdb->db_getnextpwd($SID);
		die($qtdb->err) if (!$pwd);				# Trap errors properly
#		print "pwd=$pwd\n";
		my $uid = '';
		if ($qtdb->db_save_pwd_full($SID,$uid,$pwd,'Sir/Madam',0,$bid,'')){
			$e->I( "Added $SID $pwd $bid $uid $i") if $pwds<21;
#			print $fh "$pwd\n";
		}else{
			die "problem with $SID $pwd $bid $uid $i".$qtdb->err;
		}
	}
	close $fh;
	my $ez = new TPerl::DBEasy(dbh=>$dbh);
	my $asp = new TPerl::ASP(dbh=>$dbh);
	$title||="Batch $bid ($pwds passwords) ".strftime('%b %d %Y',localtime);
	my $row = {TITLE=>$title,SID=>$SID,BID=>$bid,UPLOADED_BY=>$ENV{USER} || $0,
		ORIG_NAME=>'none',GOOD=>$pwds,BAD=>0,NAMES_FILE=>$fn,
		UPLOAD_EPOCH=>'now'};
	my $fields = $asp->batch_fields;
	$e->E(Dumper($_)) if $_ = $ez->row_manip(table=>'BATCH',action=>'insert',vals=>$row,fields=>$fields);

}
if ($do_batch_file){
	$e->I("Generating file for batch $bid");
	unless ($overwrite_existing_batch_file){
		$e->F("Use --overwrite flag to overwrite extisting batch $bid file $fn") if -e $fn;
	}
	my $sql = "select * from $SID where batchno=$bid";
	my $sth = $dbh->prepare($sql) or $e->F("Could not prepare $sql:".$dbh->errstr);
	$sth->execute() or $e->F("Could not execute $sql:".$dbh->errstr);
	my $count = 0;
	my $workbook = new Spreadsheet::WriteExcel::Big ($fn) || $e->F("Could not open '$fn':$!");
	my $worksheet = $workbook->add_worksheet();
	my $tt = new TPerl::Template(template=>$url);
	my $data = {fqdn=>$fqdn,sid=>$SID};
	my $pos = 0;
	my $header = {};
	my $en = new TPerl::Engine(SID=>$SID);
	while (my $rec = $sth->fetchrow_hashref){
		my $ufn = join '/',$troot,$SID,'web',"u$rec->{PWD}.pl";
		if (-e $ufn){
			if (my $u = $en->u_read($ufn) ){
				# work out this later.
				# $e->F($tt->err) unless $tt->check_subs($data);
				# my $url_fill = $tt->process($data) || $e->F("process error:".$tt->err);
				foreach my $k (keys %$u){
					$header->{$k} = $pos++ unless exists $header->{$k};
					my $p = $header->{$k};
					my $res = $worksheet->write($count+1,$p,$u->{$k});
					if ($res){
						$e->E("Could not write to Spreadsheet");
						$e->E("Row $count out of bounds:") if $res ==-2;
						last;
					}
				}
			}else{
				$e->E($en->err);
			}
		}else{
			# don't care if it does not exist.
		}
		$count++;
	}
	$worksheet->write(0,$header->{$_},$_) foreach keys %$header;
	$workbook->close();
	if ($count){
		$e->I("$count entries written to '$fn'");
	}else{
		unlink $fn;
		$e->I("No entries for batch $bid");
	}
}

