#!/usr/bin/perl
#$Id: invite-prototype.pl,v 1.2 2004-03-29 06:42:19 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::MyDB;
use TPerl::LookFeel;
use TPerl::TritonConfig;

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;
my %args = $q->Vars;
my $SID= $args{SID};
$args{UID} = $ENV{REMOTE_USER};

unless ($SID){
	print $q->noSID;
	exit;
}

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);

my $ret = $sec->invite_upload (%args,phase=>1);

my $start = join "\n",$q->header,$q->start_html(-title=>"Uploading $SID prototype files",-style=>$q->style);

if ($ret->{deny}){
	print $start,$lf->sbox('Error'),$ret->{deny},$lf->ebox,$q->end_html;
	exit;
}
print $start,$ret->{page},$q->end_html;
