#!/usr/bin/perl 
#$Id: aspjobcreate.pl,v 1.5 2011-07-29 21:37:58 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

use TPerl::CGI;
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::Dump;
use TPerl::TritonConfig;
use TPerl::LookFeel;

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);
my $q = new TPerl::CGI;
my %args = $q->Vars;
my $uid = $ENV{REMOTE_USER};
my $lf = new TPerl::LookFeel;
$lf->twidth ('');

my $SID;
if ($args{SID}) {
	$SID = $args{SID};
} else {
	$SID = "";
}

my $header = $q->header;
my $html = $q->start_html (-title=>"Creating $SID",-style=>$q->style );

#my $start = join "\n",
#	$q->header,
#	$q->start_html (-title=>"Creating $SID",-style=>$q->style ),'';
	
my $start = join("\n",$header,$html);

my $ret = $sec->create($ENV{REMOTE_USER},%args);
if (my $msg = $ret->{deny}){
    print $start,$q->err($msg);
}elsif ($ret->{form}){
	print join "\n",$start,$lf->sbox('Create'),$ret->{form},$lf->ebox;
}elsif ($ret->{success}){
    print $q->dir_redirect();
	exit;
}else{
    die Dumper $ret;
}
print $q->end_html;


