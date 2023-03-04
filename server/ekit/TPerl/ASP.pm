#!/usr/bin/perl
#$Id: ASP.pm,v 1.71 2011-09-22 23:33:24 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
#our $copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Andrew Creer
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# ASP.pm - utility methods for Self service surveys
#
#Copyright Triton Technology 2002
package TPerl::ASP;
use strict;
use Carp qw(confess croak);
use Data::Dumper;
use TPerl::DBEasy;
use FileHandle;
use File::Path;
use File::Basename;
use TPerl::Survey;
use TPerl::Parser;
use TPerl::CmdLine;
use Time::Local;
use IO::Scalar;
use Email::Valid;
use TPerl::TritonConfig;
use TPerl::Sender;

=head1 SYNOPSIS

This is mainly the Database manipulation for the 
ASP project.  It also uses some of the methods in 
TPerl::Survey to manipulate the files system for a job

 ## you need a database for this stuff.
 use strict;
 my $dbh = dbh TPerl::MyDB (db=>'ib');
 my $asp = new TPerl::ASP (dbh=>$dbh);
 

=head1 DESCRIPTION 

Here are the functions you can use.

=cut

####Package Globals:

my $vhostroot_root ='/home/vhosts';

sub new{
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	my $dbh = $args{dbh};
	foreach (qw(dbh)){
		confess "$_ is a required parameter" unless $args{$_};
	}
	$self->{_dbh} = $dbh;
	$self->{_db_err} = undef;
	return $self;
}

sub dbh {
	my $self = shift;
	return $self->{_dbh};
}
sub db_err {
	my $self = shift;
	# print "db_err args ".Dumper \@_;
	return $self->{_db_err} = $_[0] if $_[0];
	return $self->{_db_err};
}
sub err { my $s = shift; $s->{_err} = $_[0] if @_;return $s->{_err};}

=head2 is_asp_job

 my $job = is_asp_job(SID=>'GOOSE123') or 
  print "Could not find job in database";

If the SID is database, this will return a reference to a hash if the fields in
the ASP tables, JOB and VHOST.  It returns undef otherwise.

=cut

sub is_asp_job {
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID};
	confess "SID is required" unless $SID;
	my $dbh = $self->dbh;
	
	my @tables = $dbh->tables;
	return undef unless grep 'JOB' eq $_,@tables;
	my $sql = 'select * from JOB,VHOST where JOB.VID = VHOST.VID and JOB.SID=?';
	my $ret =  $dbh->selectall_arrayref ($sql,{Slice=>{}},$SID) or 
		die Dumper {sql=>$sql,params=>$SID,err=>$dbh->errstr};
	return $ret->[0];

}

=head2 email_work

Co-ordinating sending batches of email is not so tricky.  A batch is defined by
a file on the server.  The first row is the headings, and each row after that
is one email to be sent.  

Once the file is in place, certain actions can be queued.  The EMAIL_WORK table
is this queue.  Each row has an insert time, a start time, and end time, emails
sent, a names file, a type (invite, reminder, resend), an error, a PLEASE
STOP,an in progress, and a priority,  

This is the basis of the cron job that scans the email_work table.
It scans the table finds the next job to process, sets the improgress 
flag does a prepare and then a send, and then sets the end_epoch when 
its finished.  

=cut 

sub email_work {
	my $self = shift;
	my %args = @_;

	my $err = $args{err} || new TPerl::Error;
	my $debug = $args{debug};
	my $show_only = $args{show_only};
	my $dbh = $self->dbh;
	my $scriptsDir = getConfig('scriptsDir') or die "Could not get 'scriptsDir' from getConfig";

	# lets exit if there is a batch in progress.

	my $prog_sql = 'select * from email_work where in_progress = 1';
	my $prog_rows = $dbh->selectall_arrayref($prog_sql,{Slice=>{}}) or return {err=>$dbh->errstr,sql=>$prog_sql};
	if (my $prog_count = @$prog_rows){
		# there is a 
		$err->D("There is $prog_count batches is progress") if $debug;
		return undef;
	}

	# get the rows to be acted on
	my $sql = 'select * from EMAIL_WORK ,VHOST,JOB
		WHERE 
			EMAIL_WORK.SID = JOB.SID and
			JOB.VID = VHOST.VID and
			start_epoch < ? and 
			(in_progress != 1 or in_progress is NULL) and
			(please_stop != 1 or please_stop is NULL) and
			end_epoch is NULL 
		ORDER BY PRIORITY,START_EPOCH';
	my @params = (timelocal(localtime));
	my $rows = $dbh->selectall_arrayref($sql,{Slice=>{}},@params) or return {err=>$dbh->errstr,sql=>$sql};
	if ($show_only){
		print scalar (@$rows).  ' Rows ' .Dumper $rows;
		return undef;
	}
	unless (@$rows){
		# $err->D("Nothing to do") if $debug;
	}
	foreach my $row (@$rows){
		# print Dumper $row;
		$err->D("In Progress for EWID '$row->{EWID}'") if $debug;
		my $inprogress_sql = 'update EMAIL_WORK set IN_PROGRESS = ? where EWID = ?';
		my @inprogress_param = (1,$row->{EWID});
		$dbh->do($inprogress_sql,{},@inprogress_param) or return {err=>$dbh->errstr,
				msg=>"Could not set IN_PROGRESS for EWID '$row->{EWID}'",
				sql=>$inprogress_sql,params=>\@inprogress_param};
		# $err->D("Sending the email") if $debug;
		my $base = basename $row->{NAMES_FILE};
		my $remind = " -remind " if $row->{WORK_TYPE} == 2;
		### Prepare
		my $options = " $remind -V=$row->{VID} -E=$row->{EWID} -plain=$row->{PLAIN_TMPLT} -html=$row->{HTML_TMPLT} -list=$row->{NAMES_FILE} ";
		my $prep_cmd = 
			"perl aspinvite.pl $options -prepare $row->{SID}";
		my $prep ;
		if ($row->{PREPARED}){
			$prep = execute TPerl::CmdLine(cmd=>q{perl -e 'print "fake command"'});
		}else{
			$prep = execute TPerl::CmdLine (cmd=>$prep_cmd,dir=>$scriptsDir);
		}
		my $aspinvite_error = undef;
		if ($prep->success){
			$err->D($prep->output) if $debug;
			my $send_cmd =
				"perl aspinvite.pl $options $row->{SID}";
			###Update the batch table 
			my $bf = $self->batch_fields();
			my $batch_sql = 'update BATCH set status =?, MODIFIED_EPOCH=? where SID=? and BID=?';
			my $new_batch_stat;
			if ($bf->{STATUS} && $row->{BID}){
				$new_batch_stat = 8;
				$new_batch_stat = 10 if $remind;
				my $batch_params = [$new_batch_stat,timelocal(localtime),$row->{SID},$row->{BID}];
				$dbh->do($batch_sql,{},@$batch_params) or 
					return {dbh->$dbh,sql=>$batch_sql,params=>$batch_params};
			}
			my $send = execute TPerl::CmdLine (dir=>$scriptsDir,cmd=>$send_cmd);
			if ($send->success){
				$err->D($send->output) if $debug;
				if ($bf->{STATUS} && $row->{BID}){
					$new_batch_stat = 9;
					$new_batch_stat = 11 if $remind;
					my $batch_params = [$new_batch_stat,timelocal(localtime),$row->{SID},$row->{BID}];
					$dbh->do($batch_sql,{},@$batch_params) or 
						return {dbh->$dbh,sql=>$batch_sql,params=>$batch_params};
				}
			}else{
				$err->E("Could not send EWID '$row->{EWID}'\n".$send->output."\n");
				$aspinvite_error = "Sending Error\n".$send->output;
			}
		}else{
			$err->E("Could not prepare EWID '$row->{EWID}'\n".$prep->output."\n");
			$aspinvite_error = "Prepare Error\n".$prep->output;
		}
		$err->D("Finished EWID '$row->{EWID}'") if $debug;
		if ($aspinvite_error){
			my $ez = new TPerl::DBEasy;
			my $fields = $ez->fields(table=>'EMAIL_WORK',dbh=>$dbh,);
			# return $fields->{ERROR};
			# lets send an email if this happens.
			my $template = q{
This is the aspmailer program. I have encountered errors in attempting
to send out emails for batch [%batch%]. No emails have been sent for this
batch. You will need to correct the problem and reload the batch.
Details of the errors encountered follow:

SID=[%SID%]
Batch=[%batch%]

[%err%] };

			my $ts = new TPerl::Sender(plain=> $template);
			my $data = {
				SID=>$row->{SID},
				batch=>$row->{BID},
				err=>$aspinvite_error,
				subject=>"Automated mailer error for survey: [%SID%], Batch [%batch%]",
				bcc=>'ac@market-research.com,mikkel@market-research.com',
				to=>$row->{EMAIL},
				from_name=>'Survey Support',
				from_email=>$row->{EMAIL},
			};
			if (my $sent = $ts->send(data=>$data,nohtml=>1)){
				$sent->do_event(dbh=>$dbh);
				$err->I($sent->info);
			}else{
				$err->E("Could not send mail to $row->{EMAIL}".Dumper($ts->err));
			}



			my $err_len = $fields->{ERROR}->{DBI}->{PRECISION};
			$aspinvite_error = substr ($aspinvite_error,0,$err_len);

			my $sql = 'update EMAIL_WORK set IN_PROGRESS=?,ERROR=?,END_EPOCH=? where EWID = ?';
			my @param = (0,$aspinvite_error,timelocal(localtime),$row->{EWID});

			$dbh->do($sql,{},@param) or return {err=>$dbh->errstr,params=>\@param,
				sql=>$sql,msg=>"Could not set EWID '$row->{EWID}' Error"};
		}else{
			my $fin_sql = 'update EMAIL_WORK set IN_PROGRESS=?, END_EPOCH=? where EWID = ?';
			my @fin_param = (0,timelocal(localtime),$row->{EWID});
			$dbh->do($fin_sql,{},@fin_param) or return {err=>$dbh->errstr,params=>\@fin_param,
				sql=>$fin_sql,msg=>"Could not set EWID '$row->{EWID}' to finished"};
		}

		# lets only start one batch each minute
		last;
	}
	return undef;
}

=head2 mk_job mk_vhost rm_job

Some of the database tables reflect the filesystem.  So These methods do more
then just TPerl::DBEasy->row_manip.  We use the fields functions below to make
sure sensible things get put into the database

 my %vals = (VHOSTROOT=>'/home/worlds/gonzo',
 			SEVERROOT=>'/usr/local/apache',
			VDOMAIN=>'gonzo.triton-tech.com');
 my $err = $asp->mk_vhost ( vals=>\%vals);

 my %vals = (SID=>'GOOOSE123',VID=>1,
 	EMAIL=>'ac@market-research.com');
 my $err = $asp->mk_job(vals=>$vals);
 my $err = $asp->rm_job(SID=>'GOOSE123',VID=>1);

=cut

sub mk_vhost {
	my $self = shift;
	my %args = @_;
	my $vals = $args{vals};

	my $vroot = $vals->{VHOSTROOT};
	my $sroot = $vals->{SERVERROOT};
	my $domain = $vals->{VDOMAIN};

	# programmer help
	my $err = undef;
	foreach (qw(VHOSTROOT SERVERROOT VDOMAIN)){
		confess "$_ is a required val" unless $vals->{$_};
	}

	my $dbh = $self->dbh;
	my $table = 'VHOST';
	unless ($vals->{VID}) {
		my $sql = "select max (VID) from $table";
		if (my $res = $dbh->selectall_arrayref($sql)){
			$vals->{VID} ||= $res->[0]->[0] +1;
		}else{
			return {err=>$dbh->errstr,sql=>$sql};
		}
	}
	my $ez = new TPerl::DBEasy;
	$err = $ez->row_manip(dbh=>$dbh,vals=>$vals,action=>'insert',fields=>$self->vhost_fields,table=>$table);
	return $err if $err;
	my @errs = ();
	push @errs,"SERVERROOT '$sroot' does not exist" unless -e $sroot;
	unless (-e $vroot){
		push @errs,"cannot create VHOSTROOT '$vroot':$!" unless mkpath $vroot;
	}
	unless (my @addresses = gethostbyname ($domain)){ 
		push @errs,"cannot resolve VDOMAIN '$domain'";
	}
	my $cmd = new TPerl::CmdLine;
	unless (-e "$vroot/cvs"){
		my $cvs = $cmd->execute (cmd=>"cvs -d $vroot/cvs init");
		push @errs,$cvs->output unless $cvs->success;
	}
	if (@errs){
		#clean up database.  unlikeley to fail cause the insert just worked.
		my $remove_err = $ez->row_manip(dbh=>$dbh,action=>'delete',vals=>$vals,
			keys=>['VID'], table=>$table);
		$err->{remove} = $remove_err;
		$err->{err} = \@errs;
		return $err;
	}
	return undef;
}


sub mk_job {
	my $self = shift;
	my %args = @_;
	my $vals = $args{vals};

	$vals->{SID} = uc($vals->{SID}) if $vals->{SID};
	my $SID = $vals->{SID};
	my $email = $vals->{EMAIL};
	my $vid = $vals->{VID};

	my $fields = $args{fields} || $self->job_fields;

	# programmer help
	foreach (qw(SID EMAIL VID)){
		confess "$_ is a required val" unless defined $vals->{$_};
	}
	my $dbh = $self->dbh;
	my $sql = 'select * from VHOST where vid=?';
	my $vhost;
	if (my $res = $dbh->selectall_hashref($sql,'VID',{},$vid)){
		if ($vhost = $res->{$vid}){
		}else{
			return {err=>"No VHost $vid"};
		}
	}
	my $ez = new TPerl::DBEasy;
	my $dberr = $ez->row_manip(dbh=>$dbh,vals=>$vals,action=>'insert',table=>'JOB',fields=>$fields);
	return $dberr if $dberr;
	my $s = new TPerl::Survey (SID=>$SID,TritonRoot=>"$vhost->{VHOSTROOT}/triton",
		doc_root=>$vhost->{DOCUMENTROOT} );
	my $dirs = $s->dirs (mk=>1);
	my $links = $s->links(mk=>1);
	my $tables = $s->tables (mk=>1,dbh=>$dbh);
	my @errors = ();
	foreach my $th ($dirs,$links,$tables){
		# print Dumper $th;
		foreach my $elem (@$th){
			push @errors,$elem 
				unless $elem->{e};
		}
	}
	my $SID_file = join ('/',$s->TR,$s->SID,'config',sprintf ("%s.txt",$s->SID));
	unless (-e $SID_file){
		if (my $fh = new FileHandle ("> $SID_file")){ 
			my $blank = join "\n",
				qq{+survey_name=Under construction},
				qq{+window_title=XXX101 - Under construction},
				'+one_at_a_time=1',
				'+from_name=info@market-research.com',
				"+from_email=$email",
				'Q A. Welcome !',
				q{+instr=We are currently working on this survey. As soon as we have it finished we'll invite you to do it properly. Right now you can proceed at your own risk},
				'+qtype=instruction',;
			print $fh $blank;
		}else{
			push @errors,"Could not touch $SID_file:$!";
		}
	}
	my $pout = undef;
	my $pfh = new IO::Scalar \$pout;
	my $parser = new TPerl::Parser (err_fh=>$pfh);
	$parser->parse (file=>$SID_file);
	$parser->engine_files(dir=>join ('/',$s->TR,$s->SID,'config'),SID=>$s->SID);

	my $output = undef;
	my $scriptsDir = getConfig('scriptsDir') or die "Could not get 'scriptsDir' from getConfig";
	eval {$output = $s->survey2DHTML(world=>$scriptsDir);};
	push @errors,"Survey2DHTML in $scriptsDir failed:$@" if $@;
	if (@errors){
		$self->rm_job(VID=>$vid,SID=>$SID);
		return {survey_errors=>\@errors};
	}else{
		return undef;
	}
}
sub rm_job {
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID};
	my $vid = $args{VID};
	my $leave_fs = $args{leave_fs};

	# programmer help
	foreach (qw(SID VID)){
		confess "$_ is a required parameter" unless $args{$_};
	}
	my $dbh = $self->dbh;
	my $sql = 'select * from VHOST where vid=?';
	my $vhost;
	if (my $res = $dbh->selectall_hashref($sql,'VID',{},$vid)){
		if ($vhost = $res->{$vid}){
		}else{
			return {err=>"No VHost $vid"};
		}
	}
	### Survey stuff.
	my $s = new TPerl::Survey (SID=>$SID,TritonRoot=>"$vhost->{VHOSTROOT}/triton",
		doc_root=>$vhost->{DOCUMENTROOT} );
	my @errors = ();
	my @deletes = qw (links tables);
	push @deletes, 'dirs' unless $leave_fs;
	# die 'deletes '.Dumper \@deletes;
	foreach my $th (@deletes){
		my $elements = $s->$th (rm=>1,dbh=>$dbh);
		foreach my $elem (@$elements){
			# print Dumper $elem;
			push @errors,"Error removing '$elem->{pretty}':$elem->{err}" if $elem->{e};
		}
	}
	return \@errors if @errors;
	## database stuff
	my $ez = new TPerl::DBEasy;
	my $err = $ez->row_manip(dbh=>$dbh,action=>'delete',table=>'JOB',keys=>[qw(SID VID)],
		vals=>{SID=>$SID,VID=>$vid});
	return $err if $err;
	return undef;
}

=head2 *fields 

Fields functions See TPerl::DBEasy for why you might need
these.  Here we do some custom_info for different purposes
ie you don't want to edit the SID once you've made a job.

 my $jfields = $asp->job_fields();
 my $jfileds = $asp->job_fields(edit=>1);
 my $vfields = $asp->vhost_fields();
 my $emwfields = $asp->email_work_fields();

=cut

sub email_work_fields {
	my $self = shift;
	my %args = @_;
	my $hide = $args{hide} ||[];
	my $dbh = $self->dbh;
	my $table = 'EMAIL_WORK';
	my $ez = new TPerl::DBEasy;
	my %custom_info =();
	#### Hidden EPOCHS can be funny....
	# do hidden first
	$custom_info{$_} = $ez->field(type=>'hidden') foreach (@$hide);
	foreach my $f (qw(INSERT_EPOCH START_EPOCH END_EPOCH)){
		$custom_info{$f} = $ez->field(type=>'epoch');
		if  (grep /^$f$/i,@$hide){
			$custom_info{$f}->{cgi}->{func}='hidden';
		}
	}
	foreach my $f (qw(PLEASE_STOP IN_PROGRESS PREPARED)){
		unless (grep /^$f$/i,@$hide){
			$custom_info{$f} = $ez->field(type=>'yesno');
		}
	}
	my $fields = $ez->fields (dbh=>$dbh,table=>$table,dbi_info=>1,%custom_info);
	my %work_types = (1,'Mailout',2,'Reminder');
	$fields->{WORK_TYPE}->{cgi}->{func}='popup_menu';
	$fields->{WORK_TYPE}->{cgi}->{args} = {-labels=>\%work_types,-values=>[keys %work_types]};
	my %priorities = (1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10);
	$fields->{PRIORITY}->{cgi}->{func}='popup_menu';
	$fields->{PRIORITY}->{cgi}->{args} = {-labels=>\%priorities,-values=>[sort {$b<=>$a} keys %priorities]};
	unless (grep /^SID$/i,@$hide){
		$fields->{SID}->{cgi}->{func} = 'radio_group';
		$fields->{SID}->{value_sql}->{sql} = 'select SID,SID from JOB';
	}
	return $fields;
}
sub vhost_fields {
	my $self = shift;

	my $dbh = $self->dbh;
	my $table = 'VHOST';
	my $ez = new TPerl::DBEasy;
	my $fields = $ez->fields (dbh=>$dbh,table=>$table,dbi_info=>1);
	$fields->{VDOMAIN}->{pretty} = 'Domain Name';
	$fields->{SERVERROOT}->{pretty} = 'Apache SeverRoot Directory';
	$fields->{VHOSTROOT}->{pretty} = 'VHost Root Directory';
	$fields->{DOCUMENTROOT}->{pretty} = 'Document Root Directory';
# 	$fields->{VDOMAIN}->{pre_validate}->{ref} = 
# 		sub { 	my $dom = shift;
# 				return $dom unless $dom;
# 				local $SIG{__DIE__} = sub {};
# 				my @add = gethostbyname($dom);
# 				if (@add){
# 					check that the host resolves to this machine.... or die
# 				}else{
# 					die "cannot resolve domain '$dom' get a sysadmin to create it first\n" ;
# 				}
# 				###all is well
# 				return $dom
# 		};
	$fields->{SERVERROOT}->{pre_validate}->{ref} = 
        sub {   my $dir= shift;
                return $dir unless $dir;
                local $SIG{__DIE__} = sub {};
                die "Directory '$dir' must already exist\n" unless -e $dir;
                return $dir;
        };
	$fields->{$_}->{pre_validate}->{ref} = 
		sub { 	my $dir= shift;
				return $dir unless $dir;
				local $SIG{__DIE__} = sub {};
				die "cannot contain CHANGE_ME\n" if $dir =~/CHANGE_ME/i;
				return $dir if -e $dir;
				die "Could not create dir '$dir' \n" unless mkpath ($dir,0);
				return $dir;
		} foreach qw( DOCUMENTROOT TRITONROOT CVSROOT CGI_MR SCRIPTS TEMPLATES);
	$fields->{VHOSTROOT}->{pre_validate}->{ref} = 
		sub{ 	my $dir = shift;
				local $SIG{__DIE__} = sub {};
				return $dir unless $dir;
				$dir =~ s/^\s*(.*?)\s*$/$1/;
				die "This directory must begin with $vhostroot_root\n" unless $dir =~ /^$vhostroot_root/;
				die "cannot contain CHANGE_ME\n" if $dir =~/CHANGE_ME/i;
				die "This cannot be just '$vhostroot_root'\n" if $dir =~ /^$vhostroot_root$/;
				unless (-e $dir){
					die "Could not create $dir:$!" unless mkpath ($dir);
				}
				return $dir;
		};
	return $fields;
}


sub job_fields {
	my $self = shift;
	my %args = @_;
	my $edit = $args{edit};


	my $dbh = $self->dbh;
	my $table = 'JOB';
	my $ez = new TPerl::DBEasy;
	my %custom_info = ();
	$custom_info{VID} = $ez->field(type=>'hidden');
	$custom_info{SID} = $ez->field(type=>'hidden') if $edit;
	my $fields = $ez->fields (dbh=>$dbh,table=>$table,dbi_info=>1,%custom_info);
	$fields->{EMAIL}->{pre_validate}->{ref} = 
		sub {
			my $val = shift;
			local $SIG{__DIE__} = sub {};
			die "Missing or invalid email address\n" unless  Email::Valid->address ($val);
			return $val;
		};
	unless ($edit){
		$fields->{SID}->{pretty} = 'SID';
		$fields->{SID}->{pre_validate}->{ref} = 
			sub {	
				my ($val,$field,$dbh) = @_;
				local $SIG{__DIE__} = sub {};
				my $sql = "select $field from $table where $field = ?";
				if (my $res = $dbh->selectall_arrayref($sql,{},$val)){
					if (scalar (@$res)>0){
						die "'$val' already exists\n";
					}else{
						# die "everything is all right\n";
						return $val;
					}
				}else{
					die "database trouble checking unique $field:".dbh->errstr."\n";
				}
			};
		$fields->{SID}->{pre_validate}->{extra_args} = ['SID',$dbh];
	}
	return $fields;
}
sub batch_status_labels {
	my $self = shift;
	return {
		''=>'', # or _none_..
		1=>'Uploaded',
		2=>'Confirmed',
		3=>'Being Filtered',
		4=>'Filtered',
		5=>'Being Prepared',
		6=>'Prepared',
		7=>'Sheduled',
		8=>'Being Sent',
		9=>'Sent',
		10=>'Being Reminded',
		11=>'Reminded',
		12=>'Deleted',
	};
}
sub batch_fields {
	my $self  = shift;
	my %args=@_;
	my $dbh = $self->dbh;
	my $table = 'BATCH';
	my $ez = new TPerl::DBEasy;
	my %custom_info = ();
	$custom_info{BID} = $ez->field(type=>'hidden');
	$custom_info{SID} = $ez->field(type=>'hidden');
	my $fields = $ez->fields (dbh=>$dbh,table=>$table,dbi_info=>1,%custom_info);
	$fields->{STATUS}->{cgi}->{func} = 'popup_menu',
	my $labs = $self->batch_status_labels;
	my $vals = [sort {$a<=>$b} keys %$labs];
	$fields->{STATUS}->{cgi}->{args} = {-default=>'',-values=>$vals,-labels=>$labs};
	$fields->{BID}->{pretty} = 'Batch No';
	$fields->{UPLOADED_BY}->{cgi}->{func}='popup_menu';
	$fields->{UPLOADED_BY}->{value_sql}->{sql} = 'select UID,UID from TUSER';
	$fields->{TAG}->{pretty} = 'Tag';
	$fields->{ORIG_NAME}->{pretty} = 'Uploaded file name';
	return $fields;
}
sub import_batch_fields {
	my $self  = shift;
	my %args=@_;
	my $dbh = $self->dbh;
	my $table = 'IMPORT_BATCH';
	my $ez = new TPerl::DBEasy;
	my %custom_info = ();
	$custom_info{BATCH_ID} = $ez->field(type=>'hidden');
	$custom_info{SID} = $ez->field(type=>'hidden');
	foreach my $f (qw(CLEAN_EPOCH UPLOAD_EPOCH DELETE_EPOCH)){
		$custom_info{$f} = $ez->field(type=>'epoch');
	}
	my $fields = $ez->fields (dbh=>$dbh,table=>$table,dbi_info=>1,%custom_info);
	$fields->{BATCH_ID}->{pretty} = 'Batch No';
	$fields->{DELETE_EPOCH}->{pretty} = 'Delete Time';
	$fields->{CLEAN_EPOCH}->{pretty} = 'Clean Time';
	$fields->{UPLOAD_EPOCH}->{pretty} = 'Upload Time';
	$fields->{UPLOADED_BY}->{cgi}->{func}='popup_menu';
	$fields->{UPLOADED_BY}->{value_sql}->{sql} = 'select UID,UID from TUSER';
	return $fields;
}

sub _table_sql{
	my $self = shift;
	my $table = shift;

	my $clients = q{CREATE TABLE CLIENT(
		CLID    	INTEGER 		NOT NULL,
		CLNAME  	VARCHAR (20) 	NOT NULL ,
		PRIMARY KEY (CLID))};

	my $vhost = q{CREATE TABLE VHOST (
		VID			INTEGER 		NOT NULL,
		VDOMAIN		VARCHAR	(50)  	NOT NULL,
		DEF_EMAIL		VARCHAR(50)		NOT NULL,
		VHOSTROOT	VARCHAR (70) 	NOT NULL,
		SERVERROOT	VARCHAR (70) 	NOT NULL,
		DOCUMENTROOT VARCHAR (70)	NOT NULL,
		TRITONROOT	 VARCHAR (70)	NOT NULL,
		CVSROOT	 	VARCHAR (70)	NOT NULL,
		CGI_MR		VARCHAR (70)	NOT NULL,
		SCRIPTS		VARCHAR (70)	NOT NULL,
		TEMPLATES	VARCHAR(70) 	NOT NULL,
		PRIMARY KEY (VID))};

	my $contract = q{ CREATE TABLE CONTRACT (
		COID		INTEGER			NOT NULL,
		CLID		INTEGER 		NOT NULL,
		VID			INTEGER 		NOT NULL,
		START_EPOCH	INTEGER			NOT NULL,
		END_EPOCH	INTEGER			NOT NULL,
		EMAILS		INTEGER 		NOT NULL,
		DATA_FETCH	INTEGER			NOT NULL,
		ALLOWED_JOBS INTEGER		NOT NULL,
		FOREIGN KEY (CLID) 			REFERENCES CLIENT(CLID),
		FOREIGN KEY (VID) 			REFERENCES VHOST(VID),
		PRIMARY KEY (COID) ) };

	my $users = q{CREATE TABLE TUSER (
		UID 		VARCHAR (20) 	NOT NULL,
		PWD 		VARCHAR (20) 	NOT NULL,
		FIRSTNAME	VARCHAR (50),
		LASTNAME	VARCHAR (50),
		CLID 		INTEGER 		NOT NULL,
		FOREIGN KEY (CLID) 			REFERENCES CLIENT(CLID),
		PRIMARY KEY (UID)) };

	my $vaccess = q{CREATE TABLE VACCESS (
		VID			INTEGER 		NOT NULL,
		UID			VARCHAR(20)		NOT NULL,
		J_CREATE	INTEGER			NOT NULL,
		J_READ		INTEGER			NOT NULL,
		J_USE		INTEGER			NOT NULL,
		J_DELETE	INTEGER			NOT NULL,
		FOREIGN KEY (VID) 			REFERENCES VHOST (VID),
		FOREIGN KEY (UID) 			REFERENCES TUSER (UID),
		PRIMARY KEY (VID,UID))};

	my $jobs = q{CREATE TABLE JOB (        
		SID 		VARCHAR (16)	NOT NULL,
		VID			INTEGER			NOT NULL,
		EMAIL 		VARCHAR(50)		NOT NULL,
		FOREIGN KEY (VID) 			REFERENCES VHOST (VID),
		PRIMARY KEY (SID))};
	
	my $db = getdbConfig ('EngineDB');
	my $ERROR = q{ERROR VARCHAR(1000)};
	$ERROR = q{ERROR TEXT} if $db eq 'mysql';

	my $email_work =qq{CREATE TABLE EMAIL_WORK (
		EWID		INTEGER			NOT NULL,
		SID         VARCHAR (16)    NOT NULL,
		WORK_TYPE	INTEGER			NOT NULL,
		INSERT_EPOCH INTEGER		NOT NULL,
		BID			INTEGER			NOT NULL,
		START_EPOCH INTEGER,
		END_EPOCH	INTEGER,
		SENT		 INTEGER,
		PRIORITY	INTEGER,
		NAMES_FILE	VARCHAR (100)	NOT NULL,
		PLAIN_TMPLT	VARCHAR (100),
		HTML_TMPLT	VARCHAR (100),
		PLEASE_STOP INTEGER,
		IN_PROGRESS	INTEGER,
		PREPARED	INTEGER,
		$ERROR,
# ??? This foreign key causes problems with upgrading the table, as old data may not conform to this rule....
		FOREIGN KEY (BID,SID)			REFERENCES BATCH (BID,SID),
		PRIMARY KEY (EWID) )};
		# FOREIGN KEY (SID)			REFERENCES JOB (SID),

	my $batches = q{CREATE TABLE BATCH (
		TITLE		VARCHAR(100) 	NOT NULL,
		SID			VARCHAR(16)		NOT NULL,
		BID			INTEGER			NOT NULL,
		UPLOADED_BY	VARCHAR(20)		NOT NULL,
		ORIG_NAME	VARCHAR(100) 	NOT NULL,
		GOOD		INTEGER			NOT NULL,
		BAD			INTEGER			NOT NULL,
		UPLOAD_EPOCH INTEGER		NOT NULL,
		NAMES_FILE	VARCHAR(100)	NOT NULL,
		STATUS		INTEGER,			
		MODIFIED_EPOCH	INTEGER,
		CLEAN_EPOCH	INTEGER,
		DELETE_EPOCH INTEGER,
		TAG			VARCHAR(20),
		PRIMARY KEY	(BID,SID) )};

	my $sql;
	$sql =  $clients if $table=~ /^CLIENT$/i;
	$sql =  $vhost if $table=~ /^VHOST$/i;
	$sql =  $contract if $table=~ /^CONTRACT$/i;
	$sql =  $users if $table =~ /^TUSER$/i;
	$sql =  $vaccess if $table =~ /^VACCESS$/i;
	$sql =  $jobs if $table =~ /^JOB$/i;
	$sql =  $email_work if $table =~ /^EMAIL_WORK$/i;
	$sql =  $batches if $table =~ /^BATCH$/i;
	$sql =~ s/#.*//;
	return $sql;
}


=head2 tables

When Making Tables
the order is important because of the foreign keys etc...
naturaly drop reverses its list so you can use the same one.

 my $list = $asp->table_create_list;
 my $err = undef;
 die Dumper $err if $err = $asp->tables( create=>$list, drop=>$list);
 
 # if you wanna just check the tables are there.
 die Dumper $err if $err = $asp->tables( create=>$list);

=cut


sub tables {
	my $self = shift;
	my %args = @_;
	my $dbh = $self->dbh;
	my $make = $args{create} || [];
	my $drop = $args{drop} || [];
	my $fh = $args{fh} || \*STDOUT;

#     foreach (qw(dbh)){
# 		return "'$_' is a required param" unless $args{$_};
# 	}
	confess "database handle '$dbh' is not a DBI::db" unless ref $dbh eq 'DBI::db';
	my @tables =  $dbh->tables ;
	s/^\W*.*?\W*?\./$1/ foreach @tables;	# Strip dbname (mysql does that to us)
	s/^\W*(.*?)\W$/$1/ foreach @tables;		# Strip quotes off
	return "Could not get table list:".$dbh->errstr if $dbh->errstr;
	my @sql = ();
	foreach my $dr (@$drop){
		unshift @sql,"DROP TABLE $dr" if grep /^$dr$/,@tables;
	}
    foreach my $mk (@$make){
        my $sql = $self->_table_sql($mk) or return "no sql for table '$mk'";
        if (grep /^$mk$/,@tables){
            push @sql ,$sql if grep /^$mk$/,@$drop;
        }else{
            push @sql ,$sql;
        }
    }
    foreach my $sql (@sql){
        print $fh "doing $sql\n";
        $dbh->do($sql) or return {err=>$dbh->errstr,sql=>$sql};
		return {err=>$dbh->errstr,sql=>$sql} if $dbh->errstr;
	}
}

sub table_create_list {	
	my $self = shift;
	return [qw(CLIENT VHOST CONTRACT TUSER VACCESS JOB BATCH EMAIL_WORK)];
}

=head2 tables2file

this will dump the database to a file of insert statements.

=cut

sub tables2file {
	my $self = shift;
	my %args = @_;
	my $fh = $args{fh};
	my $dbh = $args{dbh};
	my $ez = new TPerl::DBEasy;
	my $list = $self->table_create_list;
	foreach  (@$list){
		my $err = $ez->table2file(dbh=>$dbh,fh=>$fh,table=>$_);
		return $err if $err;
	}
	return undef;
}

sub batch_list {	
	my $self = shift;
	my %args = @_;

	# gets the batch info from the batch table.
	# can be affected by the batches in the SID table,
	# limit or add.
	
	my $SID = $args{SID};
	my $table_only = $args{table_only};
	my $include_table = 1;
	$include_table = $args{include_table} if exists($args{include_table});

	$self->err( "No SID supplied") && return undef unless $SID;

	my $dbh = $self->dbh;
	my $bsql = 'select * from BATCH where SID = ?';
	
	my $batches = $dbh->selectall_hashref($bsql,'BID',{},$SID);
	unless ($batches){
		$self->err({sql=>$bsql,dbh=>$dbh,params=>[$SID]});
		return undef;
	}
	return $batches unless $include_table || $table_only;

	my $tsql = "select BATCHNO,count(PWD),min(TS) from $SID group by BATCHNO";
	my $tbatches = $dbh->selectall_hashref($tsql,'BATCHNO',{}) ;
	$self->err({sql=>$tsql,dbh=>$dbh}) and return undef unless $tbatches;
	#die Dumper $tbatches;
	if ($include_table){
		$batches->{$_} ||= {
			GOOD=>$tbatches->{$_}->{COUNT},
			TITLE=>"Batch $_",
			SID=>$SID,
			UPLOAD_EPOCH=>$tbatches->{$_}->{MIN},
			} foreach keys %$tbatches;
	}
	if ($table_only){
		my @bnos = keys %$batches;
		foreach my $bno (@bnos){
			delete $batches->{$bno} unless $tbatches->{$bno};
		}
	}
	return $batches;
}

# This looks for limbo batches.  
# they are undeleted in the batch table, but not in the email work table.

sub limbo_batches {
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID};
	my $dbh = $args{dbh} || $self->dbh;
	my $who = $args{who};

	my $em_sql = 'select * from EMAIL_WORK where SID=?';
	my $emw_batches = $dbh->selectall_hashref($em_sql,'BID',{},$SID);
	unless ($emw_batches){
		$self->err({sql=>$em_sql,dbh=>$dbh,params=>[$SID]});
		return undef;
	}

	my $sql = 'select * from BATCH where SID = ? and DELETE_EPOCH is null and (STATUS <2 or STATUS is null) ';	#and STATUS <2';
	my $params = [$SID];
	if ($who){
		$sql .= ' and uploaded_by=? ';
		push @$params,$who;
	}
	my $batches = $dbh->selectall_arrayref($sql,{Slice=>{}},@$params);
	# die Dumper ({sql=>$sql,parmas=>$params,batches=>$batches});
	if ($batches){
		my $res = [];
		foreach my $batch (@$batches){
			push @$res,$batch unless $emw_batches->{$batch->{BID}};
		}
		return $res;
	}else{
		$self->err({$sql=>$sql,dbh=>$dbh,params=>$params});
		return undef;
	}
}

1;
