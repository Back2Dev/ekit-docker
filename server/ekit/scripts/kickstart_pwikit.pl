#!/usr/bin/perl
#$Id: kickstart_pwikit.pl,v 1.2 2006-07-11 11:46:37 triton Exp $
#
# use this to make/repair/upgrade things that a pwikit thing needs.
#
use strict;
use TPerl::TritonConfig;
use TPerl::CmdLine;
use TPerl::MyDB;
use TPerl::DBEasy;
use Data::Dumper;
use File::Path;

sub eod { #Execute or die...
	my $cmd = shift;
	my $dir = shift;
	my $exec = execute TPerl::CmdLine(cmd=>$cmd,dir=>$dir);
	die $exec->output unless $exec->success;
	print $exec->stdout;
	print $exec->stderr;
}


my $hroot = getConfig('HostRoot') or die "Could not get 'HostRoot' from getConfig";
my $troot = getConfig('TritonRoot') or die "Could not get 'TritonRoot' from getConfig";

eod ('perl scripts/map_tables.pl',$hroot);

# pwikit symlink.
if ( -e "$hroot/htdocs/pwikit"){
	print "Leaving '$hroot/htdocs/pwikit' exists\n";
}else{
	print "creating '$hroot/htdocs/pwikit'\n";
	eod ("ln -s ../triton/pwikit/html htdocs/pwikit",$hroot);
}

my $dbh = dbh TPerl::MyDB (attr=>{RaiseError=>1,PrintError=>0});
my $ez = new TPerl::DBEasy(dbh=>$dbh);

# Populate the tables so that listall works.
my $def_table_vals = {
	PWI_ADMIN=>{
		ADMIN_KV=>1, ADMIN_ID=>1, ADMIN_NAME=>'Admin Creer',
		ADMIN_EMAIL=>'ac@market-research.com',
		ADMIN_PHONE=>'1800-ph-AdminCreer',
		ADMIN_FAX=>'1800-fx-AdminCreer'
	},
	PWI_BATCH=>{
		BAT_KV=>1, BAT_NO=>1,
		BAT_NAME=>'Testing Batch', BAT_STATUS=>1,
	},
	PWI_EXEC=>{
		EXEC_KV=>1, EXEC_NAME=>'Exec Creer',
		EXEC_EMAIL=>'andrewcreer@fastmail.fm',
		EXEC_PHONE=>'1800-ph-ExecCreer', EXEC_FAX=>'1800-fx-ExecCreer',
	},
	PWI_LOCATION=>{
		LOC_KV=>1,LOC_ID=>1,LOC_NAME=>'Seddon',LOC_FAX=>'1800-fx-location',
		LOC_DISPLAY=>'The Seddon house of Management',
		LOC_CODE=>121,
	},
	PWI_WORKSHOP=>{
		WS_KV=>1,WS_ID=>1,WS_LOCREF=>1,WS_STATUSREF=>1,WS_DUEDATE=>'2006-05-25',WS_DUEDATE=>'2006-05-29',
		WS_REMDATE1=>'2006-05-26',WS_REMDATE2=>2006-05-28
	},
	PWI_WSSTATUS=>[
		{WSS_KV=>1,WSS_NUM=>1,WSS_STATUS=>'Open'},
		{WSS_KV=>2,WSS_NUM=>2,WSS_STATUS=>'Closing'},
		{WSS_KV=>3,WSS_NUM=>3,WSS_STATUS=>'Closed'},
		{WSS_KV=>4,WSS_NUM=>4,WSS_STATUS=>'Cancelled'},
	]
};
foreach my $tab (keys %$def_table_vals){
	if ((my $num = $dbh->selectrow_hashref("select COUNT(*) as COUNT from $tab")->{COUNT}) != 0){
		print "Leaving $tab $num record(s)\n";
	}else{
		print "Inserting into $tab\n";
		my $vals = $def_table_vals->{$tab};
		$vals = [$def_table_vals->{$tab}] if ref ($def_table_vals->{$tab}) eq 'HASH';
		foreach my $val (@$vals){
			die Dumper $_ if 
				$_ = $ez->row_manip(action=>'insert',table=>$tab,vals=>$val);
		}
	}
}

unless (-f "$hroot/htdocs/admin/style.css"){
	mkpath ("$hroot/htdocs/admin/",1);
	my $cmd = "cp triton/pwikit/html/style.css $hroot/htdocs/admin/";
	print "$cmd\n";
	eod ($cmd,$hroot);
}

eod ('perl scripts/escheme_tables.pl',$hroot);

my $sql = 'select count(*) as COUNT from EMAIL_STATUS';
if ((my $num = $dbh->selectrow_hashref("select COUNT(*) as COUNT from EMAIL_SCHEME")->{COUNT}) != 0){
	print "Leaving $num EMAIL_SCHEME records\n";
}else{
	print "No ESCHEME_STATUS records. copy a dump of a working escheme database\n";
	print "Getting rid of tearoffs with\n";
	print "vim +g/_STATUS/del +wq db_dump_escheme\n";
}
