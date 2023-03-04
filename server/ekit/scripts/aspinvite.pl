#!/usr/bin/perl
#Copyright Triton Technology 2002
# $Id: aspinvite.pl,v 1.25 2009-03-31 12:04:01 triton Exp $
# 
# invite.pl
#
# Script to send out email survey invitations
#
use strict;
use Data::Dumper;
use TPerl::Error;
use Email::Valid;
use Getopt::Long;
use Data::Dumper;
use File::Slurp;
use TPerl::Event;
use Data::Dump qw(dump);
use TPerl::ConfigIniFiles;
use TPerl::DoNotSend;
use TPerl::TSV;
use TPerl::MyDB;
use TPerl::TritonConfig;
use TPerl::Sender;
use TPerl::Upload;
use File::Basename;
use TPerl::Hash;

sub usage {
	my $msg = shift;
	print qq{Usage $0 [options] SID
 where options include
  --list		name of the address list to use
  --plain		name of plain version of email
  --html		name of html version of file
	(note these files can be given relative to the config dir
	numbers will have 'broadcast' 'type-plain' and 'type-html'
	prepended, where type is 'invite' or 'reminder' depending on the 
	reminder flag
  --reminder 	is this a reminder
  --preview		if a reminder, ignore the status of recipients
  --EWID 		which record in the EMAIL_WORK table should we update
  --just 1234   just send to one PWD.
};
	exit;
}
sub update_ufile {
	my $file = shift;
	my $hsh = shift;
	return "No File sent" unless $file;
	my $type = ref $hsh;
	return "Second param must be a hashref not $type" unless $type eq 'HASH';
	my $fh = new FileHandle ("> $file") or return "Could not open ufile $file:$!";
	printf $fh "# Ufile made %s\n",scalar(localtime);
	print $fh "# Data for $hsh->{password}\n";
	my $dumped = dump ($hsh);
	$dumped =~ s/^\s*{/(/;
	$dumped =~ s/}\s*$/)/;
	print $fh "%ufields=\n$dumped;\n\n1;\n";
	return undef;
}

# We are no longer using params.ini.

# these come from the command line...
my $throttle = 0;	## Are we going to slow down email sending?
my $reminder = 0;	## is this a reminder
my $plain = undef;  ## The PLAIN version of the email
my $html = undef;	## The HTML version
my $list = undef;	## Which list are we sending to
my $EWID = undef;	## Which EMAIL_WORK entry do we update
my $VID = undef;	## 
my $debug = 0;		## Show what is going on
my $prepare = 0;	## Prepare (ie prime the database using the lists.
my $cont_after = undef;	
my $preview = 0;	## if doing a reminder do not check status, send anyway
my $help = 0;
my $just = [];		## Just do these passwords

# Now we are (also) using the .hdr file for this stuff.
my $subject    = undef;
my $sponsor    = undef;
my $from_user  = undef;
my $from_email = undef;
my $from_name  = undef;
my $dofax      = undef;
my $sleep      = undef;

my $e = new TPerl::Error;

my $smtp_host = getConfig('smtp_server');
$smtp_host = getConfig('smtp_host') unless defined $smtp_host;
$e->F('No smtp_server defined in server.ini') if ( $smtp_host eq '' );


GetOptions (
	'help!'=>\$help,
	'preview!'=>\$preview,
	'plain:s'=>\$plain,
	'html:s'=>\$html,
	'reminder!'=>\$reminder,
	'throttle:i'=>\$throttle,
	'list=s'=>\$list,
	'EWID=i'=>\$EWID,
	'VID=i'=>\$VID,
	'debug+'=>\$debug,
	'prepare+'=>\$prepare,
	'cont_after:s'=>\$cont_after,
	'just:s'=>$just,
) or $e->F("Bad Command line options -h for help");

usage ("") if $help;

### get the SID from the command line.
my $SID = shift;
$e->F("No SID found") unless $SID;

if ($prepare && $reminder){
	$e->I("prepare and remind means nothing to do");
	exit ;
}

# make some handy dirs 
my $troot = getConfig('TritonRoot');
my $config_dir = join ('/',$troot,$SID,'config');
my $etemplate_dir = join ('/',$troot,$SID,'etemplate');
my $broadcast_dir = join ('/',$troot,$SID,'broadcast');
my $oldbroadcast_dir = join ('/',$troot,$SID,'config');
my $data_dir = join ('/',$troot,$SID,'web');

# check the params
# Not having an EWID is not so bad if not coming from the email work table.
# $e->F("no EWID supplied\n") unless defined $EWID;

$e->F("no list file supplied\n") unless $list;
if ($list =~ /^\d+$/){
	$list = "broadcast$list";
	$e->I("Using broadcast file $list");
}

#set defaults for plain and html versions
# Makes running from commandline easier.
if ($reminder){
	$plain = "reminder$plain.txt" if $plain =~ /^\d+$/;
	$html = "reminder$html.html" if $html =~ /^\d+$/;
	$plain ||= 'reminder1.txt';
	$html ||= 'reminder1.html';
}else{
	$plain = "invite$plain.txt" if $plain =~ /^\d+$/;
	$html = "invite$html.html" if $html =~ /^\d+$/;
	$plain ||= 'invite.txt';
	$html ||= 'invite.html';
}

$e->F("'preview' does not make sense unless 'reminder' is on") if $preview and !$reminder;
$e->I("Sending reminder to all, regardless of status") if $preview and $reminder and $debug;

# This breaks making upload_csv.pl work again, as the new dirs don't need to be there.
# foreach my $dir ($troot, $config_dir , $etemplate_dir,$broadcast_dir,$data_dir ){
# 	$e->F("Cannot find directory $dir") unless -d $dir;
# }

my $nohtml = 1 unless $plain;
my $noplain = 1 unless $html;

foreach ($list){
	next unless $_;
	next if -e $_;
	my $try = "$broadcast_dir/$_";
	my $next_try = "$oldbroadcast_dir/$_";
	if (-e $try){
		$_ = $try;
	}elsif (-e $next_try){
		$_ = $next_try;
	}else{
		$e->F("neither '$_' or '$try' or '$next_try' exist");
	}
}

my $host_row = undef;    # if we have a VID host_row is the db info
                         # can be overwritten by vhost entry in params.ini


# $e->F("no way of finding vhost:no VID supplied OR no vhost in $inifile\n") unless $VID || $prepare || $host_row->{VDOMAIN};

my $rejects = slurp_rejects("$config_dir/reject.txt") if -e "$config_dir/reject.txt";

my $dbh = dbh TPerl::MyDB;

my $tsv = new TPerl::TSV(file=>$list,nocase=>1);
$tsv->header || $e->F("Could not get header from '$list'".$tsv->err);

my $ev = new TPerl::Event (dbh=>$dbh);

my $dns = new TPerl::DoNotSend(dbh=>$dbh);

my $PREP_BATCH = $ev->number('Prep Batch') or $e->F("no number for event 'Prep Batch'");
my $SEND_BATCH = $ev->number('Send Batch') or $e->F("no number for event 'Send Batch'");
my $SEND_EMAIL = $ev->number('Send Email') or $e->F("no number for event 'Send Email'");
my $REJECT_REC = $ev->number('Reject Recip') or $e->F("no number for event 'Reject Recip'");
my $MAIL_UNDELIVERABLE =  $ev->number('Mail Undeliverable') or $e->F("no number for event 'Mail Undeliverable'");


# get the hostname etc for use in the invite.
unless ($VID){
	$e->I("Assuming a VID of 1")if $debug; # assuming there is only one vhost in each vhost....
	$VID=1
}
if ($VID){
	if (my $res = $dbh->selectall_arrayref ('select * from vhost where vid=?',{Slice=>{}},$VID)){
		# print Dumper $res;
		$host_row = $res->[0];
	}else{
		$e->F("db error with select * from vhost where vid=? ".$dbh->errstr);
	}
}

my %line = ();

my $sql = 'update EMAIL_WORK set SENT = 0 where SENT is NULL';
$e->F("update of EWID=$EWID failed ".$dbh->errstr) unless
	$dbh->do($sql);

# once we get here, E are email sender errors, I are sends, and W are rejects
# perhaps we should have a clean error object, if it becomes possible to get here 
# without a fatal error.
## Lets log the sending to a new logfile.
my $list_bn = basename($list);
my ($batchno) = $list_bn =~ /(\d+)$/;
my $lfn_batchno = $batchno ||  $list_bn;
my $lfn = join '/',$troot,'log',"aspinvite-$SID-batch-$lfn_batchno.log";
my $lfh = new FileHandle (">> $lfn") or $e->F("Could not open '$lfn':$!");
$e->fh($lfh);
$e->ts(1);
my $html_bn = basename($html);                                
my $pretty_type = 'email';
$pretty_type = 'reminder' if $reminder;

$e->D("Logging $pretty_type activity for batch $batchno $list_bn to $html_bn");
if ($prepare){
	$ev->I(SID=>$SID,code=>$PREP_BATCH,msg=>"Preparing batch $list",who=>'inviteasp');
}else{
	$ev->I(SID=>$SID,code=>$SEND_BATCH,msg=>"Sending batch $batchno $list_bn to $html_bn",who=>'inviteasp');
}

my $count = 0;
my $remind_skip_count = 0;

my $continuing = 1;
$continuing = 0 if ($cont_after);

my $just_hash = {};
$just_hash->{$_}++ foreach @$just;
$e->I("Sending to just '@$just'");

my $pretty_from = '';

my $tsender = new TPerl::Sender(SID=>$SID,nohtml=>$nohtml,noplain=>$noplain);
foreach ($html,$plain){
	if (my $ret = $tsender->deparse_file($_)){
		$tsender->name($ret->{name});
		$tsender->lang($ret->{lang}) if $ret->{lang};
		last;
	}else{
		# Lets assume that we are using the old upload_csv.pl
		$tsender->plain(read_file($plain)) if $plain;
		$tsender->html(read_file($html)) if $html;
		# And now we need to get the params.ini stuff.
		my $headers = {};
		tie %$headers, 'TPerl::Hash';
		my $inifile = join '/',$troot,$SID,'config','params.ini';
		my  $ini = new Config::IniFiles(-file=>$inifile) or $e->F("Cannot read as ini file: $inifile");
		my $slist = ['main'];
		unshift @$slist,'reminder' if $reminder and $ini->SectionExists('reminder');
		# $e->D( "Looking for in $inifile for these sections ".Dumper $slist) if $debug;
		foreach my $sect (@$slist){
			$headers->{subject} ||= $ini->val($sect, 'subject');
			$headers->{from_name} ||= $ini->val($sect, 'sponsor');
			$headers->{from_name} ||= $ini->val($sect, 'from_name');
			$headers->{from_email} ||= $ini->val($sect, 'fromemail');
		}
		$tsender->headers($headers);

		# $e->F($tsender->err);
	}
}

while (my $line = $tsv->row){
	my $to = $line->{EMAIL};
	my $password = $line->{PASSWORD};
	my $uid = $line->{UID} || '';
	my $fullname = $line->{FULLNAME} || "$line->{FIRSTNAME} $line->{LASTNAME}";
	if (!$continuing){
		if (uc($password) eq uc($cont_after)){
			$e->I("Continuing work after finding password $password");
			$continuing++;
		}
		next;
	}
	if (@$just){
		next unless $just_hash->{$password};
	}

	my @reject_reasons= ();
	push @reject_reasons, "rejected by reject_file" if $rejects->{$to};
	push @reject_reasons, "rejected by recstatus" if $line{recstatus} ;
	push @reject_reasons, "rejected by Email::Valid" unless Email::Valid->address($to);
	my $dns_msg = $dns->exists($to);
	push @reject_reasons, "rejected by DoNotSend list id:$dns_msg->{DNS_ID}" if $dns_msg;

	if (@reject_reasons){	
		my $msg = "Rejecting $to '$fullname' " . join " and " ,@reject_reasons;
		$e->W($msg);
		$ev->I(SID=>$SID,who=>'aspinvite',msg=>$msg,code=>'REJECT_REC',email=>$to,pwd=>$password);
	}else{
		my $send_this_line = 1;
		if ($reminder && !$preview){
			my $sql = "select STAT from $SID where PWD=?";
			my $vals = $dbh->selectcol_arrayref($sql,{},$password) or $e->F("Could not do $sql with $password");
			if (@$vals==1){
				my $stat = $vals->[0];
				# if your refused or terminated you should not get a reminder
				$send_this_line = 0 unless grep $_ eq $stat,0,3;
			}else{
				$send_this_line = 0;
			}
		}
		if ($send_this_line){
			$line->{to} = $line->{EMAIL};
			$line->{uid} = $line->{UID};
			if (my $res = $tsender->send(data=>$line)){
				$count++;
				my $extra = "Batch $batchno";
				$extra .= " As a reminder" if $reminder;
				$res->do_event(password=>$password,dbh=>$dbh,extra=>$extra);
				$e->I($res->info);
				if ($EWID){
					my $sql = 'update EMAIL_WORK set SENT = SENT+1 where EWID = ?';
					$e->F("update of EWID=$EWID failed ".$dbh->err_str) unless
						$dbh->do($sql,{},$EWID);
				}
				if ($throttle && $sleep){
					sleep ($sleep) unless $count % $throttle
				}
			}else{
				my $err_msg = $e->fmterr($tsender->err);
				$e->E("$to '$fullname' sending error :$err_msg");
				$ev->I(SID=>$SID,code=>$MAIL_UNDELIVERABLE,msg=>$err_msg, email=>$to,pwd=>$password,who=>'aspinvite');
			}
		}else{
			$remind_skip_count++;
			# print "not asking ".Dumper \%line;
		}
	}
}
$e->I("$count emails sent");
$e->I("$remind_skip_count recipients do not need reminding") if $reminder && !$preview;
if ($EWID){
	my $sql = q{update EMAIL_WORK set ERROR = '' where EWID = ?};
	$e->F("update of EWID=$EWID failed ".$dbh->err_str) unless
		$dbh->do($sql,{},$EWID);
}

my $notify_template ='aspinvite_notify';
my $notify = new TPerl::Sender(name=>$notify_template,SID=>$SID);
my $notify_data = {emails_sent=>$count};
if (-e $notify->filenames('header')){
	my $up = new TPerl::Upload (troot=>$troot,SID=>$SID);
	my $binfo = join '/',$up->packet_dir,"$batchno.ini";
	if (my $bini = my_new TPerl::ConfigIniFiles(file=>$binfo)){
		$notify_data->{$_} = $bini->val('main',$_) foreach $bini->Parameters('main');
		$notify_data->{$_} = $bini->val('args',$_) foreach $bini->Parameters('args');
	}else{
		$e->E("Trouble with batch ini file:$@");
	}
	if (my $stat = $notify->send(data=>$notify_data)){
		$e->I($stat->info);
		$stat->do_event(dbh=>$dbh);
	}else{
		$e->F("Could not send $notify_template email:".$e->fmterr($notify->err));
	}
}else{
	$e->I("notification template '$notify_template' files do not exist");
}

sub slurp_rejects
	{
	my $filename = shift;
	my %rejects = ();

	foreach  (read_file ($filename)){
		next unless $_;
		next if /^\s*#/;
		s/\r//g;
		s/^\s*(.*?)\s*$/$1/;
		$rejects{$_}++ if Email::Valid->address($_);
	}
	return \%rejects;
	}


