#!/usr/bin/perl
#Copyright Horizon Research 2002
#$Id: aspremind.pl,v 1.7 2005-12-05 04:46:30 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::MyDB;
use TPerl::LookFeel;
use File::Basename;
use Data::Dumper;
use TPerl::DBEasy;
use File::Slurp;
use TPerl::Dump;
use TPerl::TritonConfig;

=head 1 SYNOPSIS

Batches of files are on the server.  We want to send reminders
Use the batches table to only allow reminders to 
batches since the last aspdbclear.pl (which clears all the 
non testing data from the database.)

=cut

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;

my %args = $q->args;
my $SID= $args{SID};
unless ($SID){
	print $q->noSID;
	exit;
}
my $uid = $ENV{REMOTE_USER};



# database connections and ASP objects
my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);
my $s = new TPerl::Survey ($SID);
my $i = new TPerl::Survey::Inviter($s);
my ($pl,$ht) = $i->reminders;

my $htact = $ht->active_files;

if (my $preview = $args{preview}){
	#Just display preview and exit
	$q->mydie ("Reminder $preview does not exist") unless $htact->{$preview};
 	my $cont = read_file ($htact->{$preview}->{file}) or $q->mydie ("Could not open Reminder $preview:$!");
 	print $q->header,$cont;
	exit;
}
## use the edit_security to see if they have W access to this job.
my $esec = $sec->edit_security ($uid,$SID);
my $start = join "\n",$q->header,$q->start_html(-title=>"$SID Reminders",-style=>$q->style);
print $start;
if ($esec->{err}){
	print $lf->sbox('Error'),$esec->{err},$lf->ebox,$q->end_html;
	exit;
}

# print $q->dumper($ht->active_files);
{
	# do file preview and count
	my $prev = join ' | ',
		map qq{<a href="$ENV{SCRIPT_NAME}?SID=$SID&preview=$_" target="_new">Reminder $_</a>},
		sort { $a <=> $b} keys %$htact;
	$prev ||= "No Reminder versions uploaded";
	print join "\n",
		$lf->sbox('Reminder Preview'),
		$prev,
		$lf->ebox;
}

# print $q->dumper (\%args);
### the hash with the keys being the reminders to schedule.
my $remind = {};
foreach my $arg (keys %args){
	next unless my ($num) = $arg =~/^file(\d+)$/;
	$remind->{$num}++ if $args{$arg};
}

## Get the info batch info
my $bsql = 'select  * from batch where SID=?  and (delete_epoch <?  or delete_epoch is null) order by BID DESC';

my @bp = ($SID,1);
my $batches = $dbh->selectall_hashref($bsql,'BID',{},@bp);
unless ($batches){
	print $q->dberr(sql=>$bsql,dbh=>$dbh,params=>\@bp),$q->end_html;
	exit;
}
if (%$remind){
	my $version = $args{version};
	my $ez = new TPerl::DBEasy;
	my $fld = $asp->email_work_fields;
	my $plain = $pl->active_files->{$version}->{file};
	my $html = $ht->active_files->{$version}->{file};
	unless (-e $plain && -e $html){
		print $q->err("Files $html and $plain must both exist"),$q->end_html;
		exit;
	}
	# $q->mydie ("plain=$plain<BR>html=$html");
	print $lf->stbox(['Reminders']);
	foreach my $n (keys %$remind){
		my $b = $batches->{$n};
		my $nid = $ez->next_ids(table=>'EMAIL_WORK',keys=>['EWID'],dbh=>$dbh)->[0];
		my $row = {NAMES_FILE=>$b->{NAMES_FILE},WORK_TYPE=>2,INSERT_EPOCH=>'now',START_EPOCH=>'now',
			BID=>$n,
			HTML_TMPLT=>$html,PLAIN_TMPLT=>$plain,SID=>$SID,EWID=>$nid};
		if (my $er = $ez->row_manip(table=>'EMAIL_WORK',dbh=>$dbh,action=>'insert',vals=>$row,fields=>$fld)){
			print $q->err($q->dumper($er)),$q->end_html;
			exit;
		}
		print $lf->trow(["Sending batch $n"]);
	}
	print $lf->etbox;
}

unless (%$batches){
	print $lf->sbox('No Batches at all'),$lf->ebox,$q->end_html;
	exit;
}
##Get email_work info
my $esql = 'select * from email_work where SID=? order by START_EPOCH DESC';
my $emwks = $dbh->selectall_arrayref ($esql,{Slice=>{}},$SID);
unless ($emwks){
	print $q->dberr(sql=>$esql,dbh=>$dbh,params=>[$SID]),$q->end_html;
	exit;
}

## process email_work
my $em = {};
foreach my $r (@$emwks){
	push @{$em->{$r->{NAMES_FILE}}->{$r->{WORK_TYPE}}->{em}},$r;
	$em->{$r->{NAMES_FILE}}->{$r->{WORK_TYPE}}->{cnt}++;
}

## make a hash with the form item in if we are able to remind this batch
my $remindables = {};
foreach my $n (keys %$batches){
	my $b = $batches->{$n};
	if ($b->{CLEAN_EPOCH} <1 ){
		$remindables->{$n} = $q->radio_group(-default=>0,-name=>"file$n",-values=>[0,1],-labels=>{0=>'No',1=>'Yes'},-override=>1);
	}
}

my $ez = new TPerl::DBEasy;
print $q->startform (-action=>$ENV{SCRIPT_NAME},-method=>'POST'), $q->hidden(-name=>'SID',-default=>$SID,-force=>1) if %$remindables;
print $lf->stbox(['Batch','Emails','Last Invite','Reminders Sent','Last Reminder','Action']);
foreach my $bnum (sort {$b<=>$a} keys %$batches){
	my $b = $batches->{$bnum};
	my $linv = $ez->epoch2text($em->{$b->{NAMES_FILE}}->{1}->{em}->[-1]->{START_EPOCH}) if $em->{$b->{NAMES_FILE}}->{1};
	next unless $linv;
	my $lrem = $ez->epoch2text($em->{$b->{NAMES_FILE}}->{2}->{em}->[-1]->{START_EPOCH}) if $em->{$b->{NAMES_FILE}}->{2};
	$lrem ||='&nbsp;';
	my $rcnt = $em->{$b->{NAMES_FILE}}->{2}->{cnt} if $em->{$b->{NAMES_FILE}}->{2};
	$rcnt ||= '0';
	print $lf->trow([$bnum,$b->{GOOD},$linv,$rcnt,$lrem,$remindables->{$bnum}]);
}
print $lf->etbox();

		my $rem_vals = [sort {$a <=> $b} keys %$htact];
		my $rem_lab = {};
		$rem_lab->{$_} = "Reminder $_" foreach @$rem_vals;

print 	join "\n",
		$q->popup_menu(-name=>'version',-values=>$rem_vals,-labels=>$rem_lab),
		'<BR>',
		$q->submit(-name=>'submit',-value=>'Send'),
		$q->endform if %$remindables;
