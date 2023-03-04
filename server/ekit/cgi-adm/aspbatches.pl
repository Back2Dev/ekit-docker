#!/usr/bin/perl
#$Id: aspbatches.pl,v 1.6 2004-08-03 05:06:52 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::MyDB;
use TPerl::LookFeel;
use File::Basename;
use List::Util qw (max min);
use TPerl::TritonConfig;

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;

my %args = $q->args;
my $SID= $args{SID};
my $schedule = $args{schedule};
my $history = $args{history};
my $help = $args{help};
my $reminder = $args{reminder};

my $uid = $ENV{REMOTE_USER};
unless ($SID){
	print $q->noSID;
	exit;
}

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);

my $esec = $sec->edit_security ($uid,$SID);
my $start = join "\n",$q->header,$q->start_html(-title=>"$SID Batches",-style=>$q->style, -class=>"body");
if ($esec->{err}){
	print $start,$q->err($esec->{err});
	exit;
}
my $sql = 'select * from email_work where SID =? order by START_EPOCH';
if (my $dbew = $dbh->selectall_arrayref ($sql,{Slice=>{}},$SID)){
	$args{esec} = $esec;
	$args{dbew} = $dbew;
	$start.= join ("\n",
		qq{\n<table><tr ><td WIDTH="200" VALIGN="top">},
		menu(%args),
		qq{\n</td><td  VALIGN="top">},
	);
	if ($history){
		$start.= history(%args);
	}elsif ($reminder){
		$start.= reminder(%args);
	}else{
		$start.= summary(%args);
	}
	$start.= join "\n",qq{\n</td></tr>},qq{</table>};
	print $start,$q->end_html;
}else{
	print $q->dberr(sql=>$sql,dbh=>$dbh,params=>[$SID]);
}
sub reminder {
	return 'reminder';
}

sub summary {
	my %args = @_;
	my $dbew = $args{dbew};
	my $esec = $args{esec};
	my $SID = $args{SID};
	my $job = $esec->{job};
	my $s = new TPerl::Survey(SID=>$SID,TritonRoot=>$job->{TRITONROOT});
	my $i = new TPerl::Survey::Inviter($s);
	my $batches = $i->broadcast->active_files;
	
	my $count = {}; # lookup the number of entries by batch and then worktype
	my $sent = {}; # lookup sent count by batch then worktype
	foreach my $ew (@$dbew){
			$count->{$ew->{NAMES_FILE}}->{$ew->{WORK_TYPE}}++;
			$sent->{$ew->{NAMES_FILE}}->{$ew->{WORK_TYPE}} += $ew->{SENT};
	}

	# display the stuff.
	my $wts ={1=>'Invite',2=>'Reminder'};
	my @head = ('Batch','Emails');
	push @head, (
			# "$wts->{$_}s scheduled",
			"$wts->{$_}s sent"
			) foreach sort keys %$wts;
	my $page = $lf->stbox (\@head) ;

	foreach my $bnum (sort {$b <=> $a} keys %$batches){
			my $batch = $batches->{$bnum};
			my $file = $batch->{file};
			my $lines = max($batch->{lines} -1,0);
			my $batchlink = qq{<a href="batchdownload.html?SID=$SID&batch=$bnum">$bnum</a>};
			my @row = ($bnum,$lines);

			foreach my $wt (sort keys %$wts){
					my $cnt = $count->{$file}->{$wt} ||'0';
					my $snt = $sent->{$file}->{$wt} || '0';
					# push @row,$cnt;
					push @row,$snt;
			}
			$page.= $lf->trow(\@row) ;
	}
	$page.= $lf->etbox ;
	return $page;
}
sub history {
	my %args = @_;
	my $dbew = $args{dbew};
	my $esec = $args{esec};
	my $SID = $args{SID};
	my $work_type=$args{work_type};
	my $limit = $args{limit} || 10;

	my $job = $esec->{job};
	my @params = ($SID);

	my $sql = 'select * from EMAIL_WORK where SID = ?  order by START_EPOCH DESC';
	if ($work_type){
			$sql = 'select * from EMAIL_WORK where SID = ? and work_type = ? order by START_EPOCH DESC';
			push @params,$work_type;
	}
	my $html;
	my $page = $args{next} if $args{submit} =~ /next/i;
	$page = $args{previous} if $args{submit} =~ /prev/i;
	$page = $args{page} if $args{submit} =~ /go/i;

	my $ez = new TPerl::DBEasy;
	my $fields = $asp->email_work_fields();
	$fields->{START_EPOCH}->{pretty} = 'Start';
	$fields->{END_EPOCH}->{pretty} = 'End';
	$fields->{NAMES_FILE}->{pretty} = 'Batch';
	$fields->{NAMES_FILE}->{order} = -4;
	$fields->{PLEASE_STOP}->{pretty} = 'On Hold';
	$fields->{STATUS}->{pretty} = 'Status';
	$fields->{STATUS}->{order} = 100;
	$fields->{STATUS}->{code}->{ref} = 
			sub { 
					my $er = shift;
					my $end = shift;
					my $plsstp = shift;
					return "<PRE>$er</PRE>" if $er;
					return 'Finished' if $end;
					return 'Stopped' if $plsstp;
					return 'In Progress';
			};
	$fields->{STATUS}->{code}->{names} = [qw(ERROR END_EPOCH PLEASE_STOP)];

	$fields->{$_}->{code}->{ref} = \&basename foreach qw(NAMES_FILE HTML_TMPLT PLAIN_TMPLT);
	$fields->{NAMES_FILE}->{code}->{ref} = 
			sub {
					my $val = shift;
					my $label = basename $val;
					$label = $1 if $val =~ /(\d+)$/;
					return $label;
					return qq{<a href="$ENV{SCRIPT_NAME}?SID=$SID&batch=$label">$label</a>};
			};
	delete $fields->{$_} foreach qw(EWID SID HTML_TMPLT PLAIN_TMPLT PLEASE_STOP INSERT_EPOCH END_EPOCH ERROR PRIORITY IN_PROGRESS);
	my $res = $ez->lister(limit=>$limit,sql=>$sql,dbh=>$dbh,page=>$page,
			fields=>$fields,look=>$lf,params=>\@params,form=>1,form_hidden=>{SID=>$SID,history=>1} );
	my $wts = {1=>'Invitation',2=>'Reminder'};
	if ($res->{err}){
			$html.= $q->dumper($res);
	}else{
			if ($res->{count} == 0){
					$html.='<p>No Data</p>' ;
			}else{
					$html.= join "\n",@{$res->{html}} ;
					$html.= join "\n",@{$res->{form}} ;
			}
	}
	return $html;
}
sub menu {
	my %args = @_;
	my $dbew = $args{dbew};
	my $esec = $args{esec};
	my $SID = $args{SID};
	my $job = $esec->{job};
	my $s = new TPerl::Survey(SID=>$SID,TritonRoot=>$job->{TRITONROOT});
	my $i = new TPerl::Survey::Inviter($s);
	my $batches = $i->broadcast->active_files;

	my $num_batches = scalar (keys %$batches) || 0;
	my $num_ews = scalar (@$dbew) || 0;

	my $lf = new TPerl::LookFeel (twidth=>200);
	my $page = undef;
	$page .= $lf->sbox ($SID);
	my $ba = $num_batches==1 ? 'batch' : 'batches';
	$page .= qq{<p>$num_batches $ba </p> } ;
	$page.= $lf->ebox ;
	my $hrefbase = $ENV{SCRIPT_NAME}."?SID=$SID";
	my $sbase = $hrefbase.'&schedule=1';

	$page.= join ("\n\t",
			$lf->sbox ('Batches'),
			'<p>',
	#       qq{<BR><a href="$hrefbase&work_type=1">Invitations</a>},
	#       qq{<BR><a href="$hrefbase&work_type=2">Reminders</a></li>},
			# qq{<a href="$hrefbase&help=1">Help</a>},
	);
	$page.=	qq{<a href="$hrefbase">List of uploaded batches</a>} if $num_batches;
	$page.= qq{\n\t<br><a href="$hrefbase&history=1">History</a>} if $num_ews;
	# $page.=	qq{\n\t<br><a href="$hrefbase&reminder=1">Send Reminders</a>} if $num_batches;
	$page.= join ("\n\t",
			'</p>',
			$lf->ebox ,
	);
	return $page;
}
