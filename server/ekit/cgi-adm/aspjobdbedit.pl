#!/usr/bin/perl
#Copyright 2002 Triton Technology
#$Id: aspjobdbedit.pl,v 1.3 2004-03-29 06:42:19 triton Exp $
use strict;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::Dump;
use TPerl::TritonConfig;
use TPerl::DBEasy;
use TPerl::LookFeel;


my $q = new TPerl::CGI;
my %args = $q->args;
my $SID = $args{SID};

unless ($SID){
	print $q->noSID ;
	exit;
}
my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);

my $start = join "\n",$q->header,$q->start_html(-style=>$q->style,-title=>"$SID database edit");

my $esec = $sec->edit_security($ENV{REMOTE_USER},$SID);
if (my $msg = $esec->{err}){
	print $start,$q->err($msg);
	exit;
}


my $ez = new TPerl::DBEasy;
my $lf = new TPerl::LookFeel;
my $fields = $asp->job_fields (edit=>1);

my $edit = $args{edit};
### Process the form.
my $db_err;
my $sucess_update = 0;
if ($edit==2){
	$db_err = $ez->row_manip(fields=>$fields,table=>'JOB',dbh=>$dbh,
				action=>'update',keys=>['SID'],vals=>\%args);
	# print $start,$q->dumper ($db_err);
	unless ($db_err){
		# update the security cache....
		$esec = $sec->edit_security($ENV{REMOTE_USER},$SID);
		$sucess_update=1;

	}
}

### display the form
my $job = $esec->{job};
if ($db_err){
	print join "\n",
		$start,
		$lf->sbox ('Please fix these errors'),
		$ez->form(fields=>$fields,row=>\%args,edit=>2,valid=>$db_err->{validate}),
		$lf->ebox,
		$q->end_html;
}else{
	my $msg = '<p>Changes made sucessfully</p>' if $sucess_update;
	print join "\n",
		$start,
		$lf->sbox("Editing $SID"),
		$msg,
		$ez->form(fields=>$fields,row=>$job,edit=>2),
		$lf->ebox,
		$q->end_html;
}

