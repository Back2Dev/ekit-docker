#!/usr/bin/perl
#$Id: aspsendbatch.pl,v 1.16 2004-12-15 06:24:07 triton Exp $
#
# Copyright Triton Information Technology 2004
#
# Script to confirm to action an uploaded batch 
#
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::MyDB;
use TPerl::LookFeel;
use File::Basename;
use Data::Dumper;
use TPerl::TritonConfig;

=head1 SYNOPSIS

This is called if the ASP uploads only one batch file.
It is the singular of aspsendbatches.pl

=cut

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;
my %args = $q->args;
my $SID= $args{SID};
my $file = $args{file};
my $send = $args{send};
my $delete = $args{delete};
my $uid = $ENV{REMOTE_USER};
my $BID = $args{BID};
my $pretty = basename $file if $file;
my ($bnum) = $file =~ /(\d+)$/;

unless ($SID){
	print $q->noSID;
	exit;
}

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);

my $esec = $sec->edit_security ($uid,$SID);
$q->mydie ($esec->{err}) if $esec->{err};

my $new_rows = [];  # need to see what was done.
if (-e $file){
	my $job = $esec->{job};
	my $s = new TPerl::Survey (SID=>$SID,TritonRoot=>$job->{TRITONROOT});
	my $i = new TPerl::Survey::Inviter($s);
	my $ez = new TPerl::DBEasy;
	if ($delete){
		print $q->redirect("aspbatchreverse.pl?SID=$SID&BID=$bnum");
		exit;
	}elsif ($send){
		my $wt = 1; 			#wt=1 means invite
		my $when =  $args{invite_date};
		$when = "now" if ($when eq '');
		my ($plain_1,$html_1) = $i->invites;
		my $versions = {${wt}=>{plain=>$plain_1->active_files,html=>$html_1->active_files}};

		my $errs = [];
#
		print "Scheduled invitation to be sent : $when<br>\n";
		my $fields = $asp->email_work_fields;
		my $row = {};
		$row->{PREPARED} = $args{PREPARED};
		$row->{NAMES_FILE} = $file;
		$row->{PLAIN_TMPLT} = $versions->{$wt}->{plain}->{1}->{file};
		$row->{PLAIN_TMPLT} = $args{plain_template}
							if ($args{plain_template} ne '');
		$row->{HTML_TMPLT} = $versions->{$wt}->{html}->{1}->{file};
		$row->{HTML_TMPLT} = $args{html_template}
							if ($args{html_template} ne '');
		$row->{START_EPOCH} = $when;
		$row->{INSERT_EPOCH} = 'now';
		$row->{PRIORITY} = 5;
		$row->{BID} = $BID;
		$row->{SID} = $SID;
		$row->{WORK_TYPE} = $wt;
		$row->{EWID} = $ez->next_ids(table=>'EMAIL_WORK',keys=>['EWID'],dbh=>$dbh)->[0];
		if (my $err = $ez->row_manip(fields=>$fields,dbh=>$dbh,action=>'insert',table=>'EMAIL_WORK',vals=>$row,keys=>['EWID'])){
			push @$errs,$err;
		}else{
			push @$new_rows,$row;
		}
		my ($plain_1,$html_1) = $i->reminders;
		$wt++;												# Move on to do the same for reminders
		my $versions = {${wt}=>{plain=>$plain_1->active_files,html=>$html_1->active_files}};
# ??? At this point we should detect if the reminder files actually exist, because the sub active_files fails silently, 
# and the expected structure is horribly empty at this point.
		my $remno = 1;
		foreach my $thing (qw{reminder1 reminder2}){
			my $when =  $args{"${thing}_date"};
			next if ($when eq '');							# Skip reminders if scheduled date is blank 
			print "Scheduled $thing to be sent: $when<br>\n";
			my $fields = $asp->email_work_fields;
			my $row = {};
			$row->{PREPARED} = 1;  ## remimders are always prepared...
			$row->{NAMES_FILE} = $file;
			$row->{PLAIN_TMPLT} = $versions->{$wt}->{plain}->{$remno}->{file};
			$row->{HTML_TMPLT} = $versions->{$wt}->{html}->{$remno}->{file};
			$row->{START_EPOCH} = $when;
			$row->{INSERT_EPOCH} = 'now';
			$row->{PRIORITY} = 5;
			$row->{BID} = $BID;
			$row->{SID} = $SID;
			$row->{WORK_TYPE} = $wt;
			$row->{EWID} = $ez->next_ids(table=>'EMAIL_WORK',keys=>['EWID'],dbh=>$dbh)->[0];
			if (my $err = $ez->row_manip(fields=>$fields,dbh=>$dbh,action=>'insert',table=>'EMAIL_WORK',vals=>$row,keys=>['EWID'])){
				push @$errs,$err;
			}else{
				push @$new_rows,$row;
			}
			$remno++;
		}
	my $title = "Confirmation of uploaded batch";
	my $bsql = "select * from BATCH where BID=$bnum and SID=?";
	my $binfo = {BID=>$bnum};
	if (my $res = $dbh->selectall_arrayref($bsql,{Slice=>{}},$SID)){
		$binfo = $res->[0];
	}else{
		push @$errs,{sql=>$bsql,dbh=>$dbh};
	}
	my $err_box = join "\n",
		$lf->sbox("ERRORS OCCURED"),
		map ($q->dumper($_),@$errs),
		$lf->ebox if @$errs;
	
	my ($inv_summ,$rem1_summ,$rem2_summ);
	if (my $row = $new_rows->[0]){
		$inv_summ = qq{<BR>Email Scheduled: $row->{START_EPOCH}}
	}
	if (my $row = $new_rows->[1]){
		$rem1_summ= qq{<BR>Reminder 1 Scheduled: $row->{START_EPOCH}}
	}
	if (my $row = $new_rows->[2]){
		$rem2_summ= qq{<BR>Reminder 2 Scheduled: $row->{START_EPOCH}}
	}
	
	print join "\n",
		$q->header,
		$q->start_html(-title=>$title,-style=>{src=>"/$SID/style.css"}),
		$err_box,
		$lf->sbox($title),
		qq{<BR>Batch number: $binfo->{BID}},
		qq{<BR>Uploaded by: $binfo->{UPLOADED_BY}},
		qq{<BR>Uploaded Date: }.$ez->epoch2text($binfo->{UPLOAD_EPOCH}),
		qq{<BR>Names uploaded: $binfo->{GOOD}},
		qq{<BR>Rejects: $binfo->{BAD}},
		'<BR>',
		$inv_summ,
		$rem1_summ,
		$rem2_summ,
		$lf->ebox,
		$q->end_html;
# Problem with the re-direct is, can't see any  output now... I'd much rather get some confirmation of what has been done here.
#print $q->redirect ("aspbatchlist.pl?SID=$SID");
	}else{
		# $m->out( "\n<BR>Nothing to do");
	}
}else{
	$q->mydie ("File '$pretty' does not exist");
	# print $start,$q->err("File '$pretty' does not exist"),$q->end_html;
}
