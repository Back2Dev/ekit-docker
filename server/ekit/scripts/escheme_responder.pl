#!/usr/bin/perl
#Copyright Triton Technology 2002
#$Id: escheme_responder.pl,v 1.3 2006-03-21 23:47:32 triton Exp $

###This program gets run as the mail user.  test it as such..

BEGIN {
	# need to be in the dir we are run from  to TPerl::TritonConfig.pm will work.
	use FindBin;
	chdir "$FindBin::Bin";
}

$!++; #unbuffer STDOUT
use strict;
use lib "$FindBin::Bin";
use Data::Dumper;
use Mail::SpamAssassin;
use Mail::Audit;
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
use TPerl::DoNotSend;
use TPerl::Engine;
use TPerl::TransactionList;

my $debug = 0;
my $dbh = dbh TPerl::MyDB (attr=>{RaiseError=>0,PrintError=>0}) 
	or die "Could not connect to database:". TPerl::MyDB->err();
my $troot = getConfig('TritonRoot');

my $forward = undef; # forward to this address, just or just log.
my $SID = undef; # can be got from command line in non asp jobs, otherwise look in the message.
my $leave_subject = undef;
my $send_on = 1;

my $mailauditloglevel = 0;
my $use_mail_date=1;

GetOptions (
	'forward:s'=>\$forward,
	'SID:s'=>\$SID,
	'leave_subject+'=>\$leave_subject,
	'loglevel:i'=>\$mailauditloglevel,
	'send_on!'=>\$send_on,
	'use_mail_date!'=>\$use_mail_date,
	'debug!'=>\$debug,
);
my $err = new TPerl::Error(ts=>1);

### The maildirs is a list of places to try and save the mail.  later we work back up the list
# to find one we can actually write to (we are the mail user sometimes).

my @maildirs = ('/tmp/mailbox',"$troot/mailbox");

#### This subclasses Mail::Internet with subclasses MIME::Entity
# See those manpages for all their useful methods.
my $mail = new Mail::Audit (noexit=>1,emergency=>"$maildirs[-1]/mail_audit_emergency",loglevel=>$mailauditloglevel);

### in asp mode we should provide a host, either numeric VID or an demo.asp4me.com 
# we add things to maildirs here.

$err->D("add $troot/$SID/mailbox to maildirs") if $debug;
push @maildirs,"$troot/$SID/mailbox" if $SID;

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


$event{who} = "escheme_respond";
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
	$err->I("unsubscribe to $file");
	$mail->accept ($file);
	$event{code} = $ev->number('MAIL_UNSUBSCRIBE');
	my $dns = new TPerl::DoNotSend(dbh=>$dbh);
	my $dns_msg = $dns->add(email=>$event{email},SID=>$SID,pwd=>$pwd);
	$err->D($dns_msg) if $debug;
	$err->E("Could add to DoNotSend") unless $dns_msg;
	if ($pwd && $SID){
        my $sql = "select * from $SID where PWD = ?";
        if (my $r = $dbh->selectrow_hashref($sql,{},$pwd)){
			my $en = new TPerl::Engine;
            my $fn = '';
            my $seq = '';
            if ($seq = $r->{SEQ}){
                $fn = join '/',$troot,$SID,'web',"D$seq.pl";
                unless (-e $fn){
                    $err->E("Database seq dfile '$fn' does not exist");
                    $fn = '';
                }
            }
            unless ($fn){
                # Need to create a dfile.
                if (my $resp = $en->qt_new($SID)){
                    $seq = $resp->{seqno};
                    $fn = join '/',$troot,$SID,'web',"D$seq.pl";
                	my $ufn = join '/',$troot,$SID,'web',"u$pwd.pl";
					$en->u2resp($ufn,$resp);
					$resp->{token} ||= $pwd;
					$resp->{id} ||= $r->{UID};
                    if ($en->qt_save($fn,$resp)){
                        $err->I("Created '$fn' for pwd $pwd id $r->{UID}");
                    }else{
                        $err->E("Could not save '$fn':".$en->err);
                        $fn = '';
                    }
                }else{
                    $err->E("Could not make new resp hash".$en->err());
                }
            }
            if ($fn){
                my $resp = $en->qt_read($fn);
                my $trl = new TPerl::TransactionList();
                my $new_fn = $en->qt_edit_to_temp(file=>$fn,change=>{status=>1});
                $dbh->begin_work;
                $trl->push_item(
                    pretty=>"Status to 1 in '$fn'",
                    orig=>$fn,
                    edit=>$new_fn,
                    err=>($new_fn?'':$en->err)
                )unless $resp->{status} ==1;
                $trl->push_item(
                    pretty=>"update $SID seq=$seq, status=1 for pwd '$pwd'",
                    sql=>"update $SID set STAT=?, SEQ=? where PWD=?",
                    params=>[1,$seq,$pwd],
                    dbh=>$dbh,
                )unless ($r->{SEQ} eq $seq) and ($r->{STAT}==1);
                $trl->dbh_do;
                $trl->commit_files;
                if (my $errs = $trl->errs()){
                    $trl->dbh_rollback_messages($dbh->rollback);
                    $trl->rollback_files;
                    my $probs = $trl->msg_summary(list=>$errs);
                    my $rb_stat = $trl->msg_summary(rollback=>1);
                    if (my $rb_errs = $trl->rollback_errs){
                        $err->E("These problems occured:\n$probs\n Additional probs while rolling back:\n$rb_stat");
                    }else{
                        $err->E("These problems occured:\n$probs\n but everything was rolled back OK:\n$rb_stat");
                    }
                }else{
                    $err->I("Success:\n\t".$trl->msg_summary(join=>"\n\t"));
                    $dbh->commit;
                }
            }else{
                $err->E("No dfile editing was done");
            }
        }else{
            $err->E("DataBaseError:$_") if $_ = $dbh->errstr;
            $err->E("No $SID database record for pwd $pwd");

        }
	}else{
		$err->E("Could not update '$SID' table. passwd($pwd)");
	}
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
