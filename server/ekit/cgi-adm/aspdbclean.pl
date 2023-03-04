#!/usr/bin/perl 
#$Id: aspdbclean.pl,v 1.5 2011-07-29 21:38:55 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::ASP::Security;
use Data::Dumper;
use File::Basename;
use TPerl::TritonConfig;

=head1

This removes all the entries from the database prior to 
doing a new batch.  Leaves the testing accounts in.

updates the batch table.

=cut


my $q = new TPerl::CGI;
my $uid = $ENV{REMOTE_USER};

my %args = $q->args;
my $SID = $args{SID};
my $keep_rex = qr /^\d+$/;
unless ($SID){
	print $q->noSID ;
	exit;
}
my $delete = $args{delete};

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);
my $lf = new TPerl::LookFeel;

my  $start = $q->header. $q->start_html (-title=>"Editing Job $SID",-style=>{src=>dirname($ENV{SCRIPT_NAME}).'/style.css'});

my $esec = $sec->edit_security($uid,$SID);
if (my $deny = $esec->{err}){
	print join "\n",$start,$q->err($deny),$q->end_html;
	exit;
}
unless (grep $_ eq $SID,$dbh->tables){
	print join "\n",$start,$q->err("No $SID table in database $db"),$q->end_html;
	exit;
}
if ($delete ==2){
	#really do it
	my $sql = "delete from $SID where PWD not like ? and pwd not like ?";
	print $start;
	if (my $count = $dbh->do($sql,{},'1%','2%')){
		print join "\n",$lf->sbox('Success'),"Deleted non test data",$lf->ebox,$q->end_html;
		my $ez = new TPerl::DBEasy;
		my $now = $ez->text2epoch('now');
		my $bsql = 'update batch set CLEAN_EPOCH= ? where SID=? and CLEAN_EPOCH < ?';
		my @p = ($ez->text2epoch('now'),$SID,1);
		if (my $cnt= $dbh->do($bsql,{},@p)){
			# print "$cnt rows updated";
		}else{
			print join "\n", $q->dberr(sql=>$bsql,dbh=>$dbh,params=>\@p),$q->end_html;
		}
	}else{
		print join "\n", $q->dberr(sql=>$sql,dbh=>$dbh),$q->end_html;
	}
}elsif ($delete == 1){
	print join "\n",
		$start,
		$lf->sbox('No'),
		q{I don't want to do it either},
		$lf->ebox,
		$q->end_html;
}else{
	#do the form
	print join "\n",
		$start,
		$lf->sbox("Really Clear $SID table"),
		$q->start_form (-action=>$ENV{SCRIPT_NAME},-method=>'POST'),
		$q->hidden(-name=>'SID',-type=>'hidden',-value=>$SID),
		$q->radio_group(-name=>'delete',-values=>[1,2],-labels=>{1=>'No',2,'Yes'}),
		'<BR>',
		$q->submit(-name=>'submit',-value=>'Do It'),
		$q->end_form,
		$lf->ebox,
		$q->end_html;
	;
}
