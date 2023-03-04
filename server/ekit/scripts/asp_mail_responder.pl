#!/usr/bin/perl
#Copyright Triton Technology 2002
#$Id: asp_mail_responder.pl,v 1.26 2012-01-14 08:34:29 triton Exp $

###This program gets run as the mail user.  test it as such..

BEGIN {
	# need to be in the dir we are run from  to TPerl::TritonConfig.pm will work.
	use FindBin;
	chdir "$FindBin::Bin";
}

$!++;
use strict;
use FindBin;
use lib "$FindBin::Bin";
use Data::Dumper;
use Mail::SpamAssassin;
use Mail::Audit;
use TPerl::ASP;
use TPerl::TritonConfig qw (getConfig);
use TPerl::MyDB;
use TPerl::Error;
use File::Path;
use Getopt::Long;
use Email::Valid;
use TPerl::Responder;
use TPerl::Event;
use TPerl::DBEasy;
use TPerl::Dump;
use Mail::Sender;


### When I first wrote this I was going to just pipe email messages at it, and it was going to be able to find out which 
# vhost it ran on.  

my $debug = 0;
my $db = '';#'ib';
my $dbh = dbh TPerl::MyDB (db=>$db,attr=>{RaiseError=>0,PrintError=>0}) or die "Could not connect to database '$db':". TPerl::MyDB->err();
my $troot = getConfig('TritonRoot');

my $host = undef; # host is used to lookup a vdomain in the database.. THis sets ASP mode
my $forward = undef; # in non asp mode forward to this address, otherwise set this from the database
my $SID = undef; # can be got from command line in non asp jobs, otherwise the database sets it
my $leave_subject = undef;
my $send_on = 1;

my $mailauditloglevel = 0;
my $use_mail_date=0;

GetOptions (
	'host:s'=>\$host,
	'forward:s'=>\$forward,
	'SID:s'=>\$SID,
	'leave_subject+'=>\$leave_subject,
	'loglevel:i'=>\$mailauditloglevel,
	'send_on!'=>\$send_on,
	'use_mail_date!'=>\$use_mail_date,
	'debug!'=>\$debug,
);
my $err = new TPerl::Error;

### The maildirs is a list of places to try and save the mail.  later we work back up the list
# to find one we can actually write to.

my @maildirs = ('/tmp/mailbox',"$troot/mailbox");



#### This subclasses Mail::Internet with subclasses MIME::Entity
# See those manpages for all their useful methods.
my $mail = new Mail::Audit (noexit=>1,emergency=>"$maildirs[-1]/mail_audit_emergency",loglevel=>$mailauditloglevel);

# print Dumper $mail;
# print 'mime version '.$mail->get('MIME-Version') . "\n";

### in asp mode we should provide a host, either numeric VID or an demo.asp4me.com 
# we add things to maildirs here.
#

if ($host){
	$err->D("In ASP Mode") if $debug;
	my $sql = 'select * from vhost,job where VDOMAIN = ? and vhost.vid = job.vid';
	my $res = {};
	my $hostroot = undef;
	my $host_email = undef;
	if ($res = $dbh->selectall_hashref($sql,'SID',{},$host)){
		# print Dumper $res;
		my $first_sid = (keys (%$res))[0];
		$hostroot = $res->{$first_sid}->{VHOSTROOT};
		$troot = $res->{$first_sid}->{TRITONROOT};
		$host_email = $res->{$first_sid}->{DEF_EMAIL};
	}else{
		$err->E( "db error with $sql:".$dbh->errstr);
	}
	print "hostroot=$hostroot\n" if $debug;
	unless ($hostroot){
		my $hsql = 'select * from vhost where upper (VDOMAIN) =?';
		if (my $hres = $dbh->selectall_arrayref($hsql,{Slice=>1},uc($host))){
			# print Dumper $hres;
			if ($hostroot = $hres->[0]->{VHOSTROOT}){
				$err->D("Adding '$hostroot/mailbox' to maildir") if $debug;
				push @maildirs,"$hostroot/mailbox";
			}
		}else{
			$err->E( "db error with $hsql:".$dbh->errstr);
		}
	}

	## now host should be set to a domain
	# use the $host 
	# to get the SID from any of the to, cc, bcc addresses in the email.
	# once we have an SID, hit the db to get the forwarding address
	my @to = ();
	push @to, split (/,/,$mail->$_) foreach qw (to cc bcc);
	
	my @valid = ();
	foreach (@to){
		my $addr = Email::Valid->address($_);
		push @valid,$addr if $addr;
	}
	my @SIDS = ();
	push @SIDS,$SID if $SID;
	foreach (@valid){
		if (my ($s) = /\@(.*?)\.$host$/){
			push @SIDS,uc $s;
		}
	}
	my @forward = split /,/,$forward;
	foreach my $s (@SIDS){
		push @forward,$res->{$s}->{EMAIL} if $res->{$s};
		print "looking for $s EMAIL ".Dumper $res->{$s};
	}
	$forward = join ',',@forward;
	if (@SIDS){
		$SID = $SIDS[0];
		if ($hostroot){
			$err->I("add $hostroot/$SIDS[0]/mailbox to maildir");
			push @maildirs, "$hostroot/$SIDS[0]/mailbox";
			$err->I("add $troot/$SIDS[0]/mailbox to maildir");
			push @maildirs, "$troot/$SIDS[0]/mailbox";
		}else{
			$err->I("add $maildirs[-1]/$SIDS[0]/mailbox to maildirs");
			push @maildirs, "$maildirs[-1]/$SIDS[0]/mailbox";
		}
	}
# 	print "host=$host\n";
# 	print 'all to addresses '.Dumper \@to;
# 	print 'all valid addresses '. Dumper \@valid;
# 	print 'all SIDS '. Dumper \@SIDS;
# 	print "forward=$forward\n";
# 	exit;
	$forward ||= $host_email;
}else{
	$err->D("not in ASP mode") if $debug;
	$err->D("add $troot/$SID/mailbox to maildirs") if $debug;
	push @maildirs,"$troot/$SID/mailbox";
}

my $resp = new TPerl::Responder;
my %event = ();# args for the call to the event logger.  See man TPerl::Event;
# look for password
	my ($msg_sid,$pwd,$code)=$resp->passwd(ent=>$mail);
	$event{pwd} = $pwd;
	$err->D("msgsid=$msg_sid|pwd=$pwd|code=$code") if $debug;
	# exit;
# if $SID is not set already use the one from the message (if possible)
unless ($SID){
	if ($msg_sid){
		$SID = $msg_sid;
		$err->I("added $troot/$SID/mailbox to maildirs from $SID from inside messgae") if $debug;
		push @maildirs,"$troot/$SID/mailbox";
	}
}

# Now get the forward address from the JOB table if possible;
if (!$forward and $SID){
	my $sql = 'select EMAIL from JOB where SID=?';
	if (my $res = $dbh->selectall_arrayref($sql,{},$SID)){
		$forward = $res->[0]->[0];
		$err->I("Got forwarding address '$forward' from $SID entry in job table");
	}else{
		$err->D("Could not find forward address using '$sql' and '$SID':".$dbh->errstr) if $debug;
	}
}

####now see which mail dir we are able to write to.
# print Dumper \@maildirs;
# print "forward=$forward\n";
# exit;
my $maildir = undef;
foreach my $try (reverse @maildirs){
	$err->D("Trying $try as a maildir") if $debug;
	if (-e $try){
		$err->D("$try exists") if $debug;
		if (-w $try){
			$err->D("$try is writable") if $debug;
			$maildir = $try;
			last;
		}else{
			$err->D("$try is not writable") if $debug;
			next;
		}
	}else{
		eval {mkpath ($try) ;};
		if ($@){
			$err->E("could not make $try");
			next;
		}else{
			$err->E("made $try");
			$maildir = $try;
			last;
		}
	}
}

my $ev = new TPerl::Event (dbh=>$dbh);


$event{who} = "asp_respond";
$event{email} = Email::Valid->address($mail->head->get('From'));
$event{SID} = $SID;

if ($use_mail_date){
	$event{epoch} = text2epoch TPerl::DBEasy ($mail->head->get('Date'));
}else{
	$event{epoch} = text2epoch TPerl::DBEasy ('now');
}
	
my ($ooo,$bounce,$unsubscibe);
$event{msg} = $mail->head->get('Subject') || 'Could not get a subject';

if (0){
	# dummy op makes it easier to cut and paste to change the order of the elsif s.
}elsif ($bounce = $resp->bounce (ent=>$mail)){
	my $file ="";
	if ($bounce->{warn}){
		$file = "$maildir/warnbox" ;
		$event{code} = $ev->number('MAIL_WARNING');
		$event{msg} = $bounce->{msg} || 'Warning';
	}else{
		$file = "$maildir/bouncebox";
		$event{code} = $ev->number('MAIL_RETURN');
		$event{msg} = $bounce->{msg} || 'Return Mail';
	}
	$err->I("bounce ($event{code}) ($event{msg}) to $file");
	$mail->accept ($file);
}elsif ($unsubscibe = $resp->unsubscribe (ent=>$mail)){
	my $file = "$maildir/unsubscribebox";
	$err->I("unsucsriibe to $file");
	$mail->accept ($file);
	$event{code} = $ev->number('MAIL_UNSUBSCRIBE');
}elsif ($ooo = $resp->OOO (ent=>$mail)){
	my $file = "$maildir/OOObox";
	$err->I("OOO to $file");
	$mail->accept ($file);
	$event{code} = $ev->number('MAIL_OOO');
}else{
	# now check for spam
 	my $spamtest = new Mail::SpamAssassin;
	my $text = $mail->as_string;
	my $spam_mail = $spamtest->parse($text);
 	my $status = $spamtest->check ($spam_mail);
	if ($status->is_spam){
		my $file = "$maildir/spambox";
		$err->I( "Spam to $file");
		# $err->I("get_report  ".$status->get_report);
		$mail->accept ($file);
		$event{code} = $ev->number('MAIL_SPAM');
	}else{
		my $not_act = 'No actually-';
		$not_act = '' if $send_on;
		$err->I("${not_act}Resending to $forward");
		my $sub = $mail->head->get('Subject');
		$mail->head->replace('Subject:',"$SID $sub" ) unless $leave_subject;
		if ( $forward and $send_on ){
			my $suc=$mail->resend ($forward);
			$err->E("Resend failed") unless $suc;
		}
		my $file = "$maildir/goodbox";
		$err->I("Mail to $file");
		$mail->accept ($file);
		$event{code} = $ev->number('MAIL_FORWARD');
	}
}

##### Now update the database
$ev->chk_eventlog();

my $error = $ev->I(%event);
if ($error){
	### write to the maildir in a missed_log file.
	my $file = "$maildir/missed_log";
	my $missed = new TPerl::Dump (file=>$file,touch=>1);
	my $thing = $missed->getnlock || [];
	push @$thing,{error=>$error,event=>\%event};
	$missed->putnunlock($thing);
	$err->I("put Event logging error into $file");
}
