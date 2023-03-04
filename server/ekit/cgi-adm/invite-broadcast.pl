#!/usr/bin/perl
#$Id: invite-broadcast.pl,v 1.4 2004-03-29 06:42:19 triton Exp $
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
my %args = $q->args;
my $SID= $args{SID};
$args{UID} = $ENV{REMOTE_USER};

# print $q->header,$q->start_html,$q->dumper ($q),$q->dumper($args);
# exit;
unless ($SID){
	print $q->noSID;
	exit;
}

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);


my $start = join "\n",$q->header,$q->start_html(-title=>"Uploading $SID broadcast files",-style=>$q->style);
# print $start,$q->dumper(\%args);
my $ret = $sec->invite_upload_broadcast (%args,dbh=>$dbh);  #need the dbh to check the number of batches in the email_work table
if ($ret->{deny}){
	print $start,$lf->sbox('Error'),$ret->{deny},$lf->ebox,$q->end_html;
	exit;
}

print $start,$ret->{page},$q->end_html;
