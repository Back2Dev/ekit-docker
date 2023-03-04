#
# Copyright Triton Technology 2002
# $Id: Security.pm,v 1.29 2011-05-06 18:04:20 triton Exp $
#
package TPerl::ASP::Security;
use strict;
use Data::Dumper;
use TPerl::MyDB;
use Carp qw (confess);
use TPerl::DBEasy;
use TPerl::LookFeel;
use File::Slurp;
use TPerl::Survey;
use TPerl::Survey::Inviter;
use CGI;
use File::Copy;
use File::Basename;
use Email::Valid;
use List::Util qw(max);
use TPerl::TritonConfig;

=head1 SYNOPSIS

This is the security stuff for the ASP.  It used to be in Mason components.

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto ||$proto;
	my $self = {};
	bless $self,$class;
	
	my $asp = shift;
	confess "First parameter must be a TPerl::ASP" unless ref $asp eq 'TPerl::ASP';
	$self->{asp} = $asp;
	return $self
}

sub asp { my $self = shift; return $self->{asp} }

sub client {
	#return info about client.
	my $self = shift;
	my $uid = shift;
	confess "First Param must be a user name" unless $uid;
	my $sql = 'select * from CLIENT,TUSER where TUSER.CLID = CLIENT.CLID and uid=?';
	my $dbh = $self->asp->dbh;
	if (my $res = $dbh->selectall_hashref ($sql,'UID',{},$uid)){
		if (my $client = $res->{$uid}){
			return $client;
		}else{
			confess "User '$uid' not in TUSER table";
			return undef;
		}
	}else{
		$self->asp->db_err ({sql=>$sql,params=>[$uid],err=>$dbh->errstr } );
		return undef;
	}
}
sub vhosts {
	my $self = shift;
	my %args = @_;

	my $CLID = $args{CLID};
	my $UID = $args{UID};

	confess ("one of UID or CLID must be set") unless $CLID || $UID;
	confess ("one of UID or CLID must be set") if $CLID && $UID;
	my $dbh = $self->asp->dbh;

	if ($UID){
		my $sql = "select * from VACCESS,VHOST where VACCESS.VID = VHOST.VID and VACCESS.UID=?";
		my $param = [$UID];
		if (my $res = $dbh->selectall_hashref($sql,'VID',{},@$param)){
			return $res;
		}else{
			$self->asp->db_err ({sql=>$sql,params=>$param,err=>$dbh->errstr } );
			# $m->comp ( 'dberr.mc',dbh=>$dbh,sql=>$sql,params=>$param);
			return undef;
		}
	}else{
		my $sql = "select * from VHOST,CONTRACT where CONTRACT.VID = VHOST.VID and CONTRACT.CLID=?";
		my $param = [$CLID];
		if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}},@$param)){
			my $contracts = {};
			my $now = text2epoch TPerl::DBEasy ('now');
			# my $now = timelocal(localtime);
			while (my $row = shift @$res){
				my $active = undef;
				$active =  1 if $row->{START_EPOCH}<$now && $row->{END_EPOCH}>$now;
				$row->{ACTIVE_CONTRACT} = $active;
				push @{$contracts->{$row->{VID}}},$row;
			}
			return $contracts;
		}else{
			$self->asp->db_err ({sql=>$sql,params=>$param,err=>$dbh->errstr } );
			# $m->comp ( 'dberr.mc',dbh=>$dbh,sql=>$sql,params=>$param);
			return undef;
		}
	}
}
sub jobs {
	my $self = shift;
	my $uid =shift ;
	
	confess "First Param must be a user name" unless $uid;
	my $dbh = $self->asp->dbh;

	my $sql = 'select * from VHOST,VACCESS,JOB
		WHERE       JOB.VID = VHOST.VID
			AND     VACCESS.VID = VHOST.VID
			AND     VACCESS.UID = ?';

	my $params = [$uid];

	if (my $sth = $dbh->prepare ($sql)){
		if ($sth->execute(@$params)){
			my %hash = ();
			while (my $row = $sth->fetchrow_hashref){
				$hash{$row->{VID}}->{$row->{SID}} = $row;
			}
			# $m->comp ('/Dumper.mc',thing=> \%hash,what=>'jobs hash in jobs.mc');
			return \%hash;
		}else{
			$self->asp->db_err ({sql=>$sql,params=>$params,err=>$dbh->errstr } );
			return undef;
		}
	}else{
		$self->asp->db_err ({sql=>$sql,params=>$params,err=>$dbh->errstr } );
		return undef;
	}
}

sub read_security {
	my $self = shift;
	my $uid = shift;
	confess "First Param must be a user name" unless $uid;
	my %args = @_;
	# print "read_sec ".Dumper \%args;
	my $client = $args{client} || $self->client($uid);
	# confess "error getting client\n". Dumper ($self->asp->db_err) ;
	# confess "client not set\n". Dumper ($self->asp->db_err) unless $client;

	my $contract = $args{contract}|| $self->vhosts(CLID=>$client->{CLID});
	my $vaccess = $args{vaccess} || $self->vhosts(UID=>$uid);
	my $jobs = $args{jobs} || $self->jobs ($uid);

	# active contract to vaccess
	foreach my $vid (keys %$vaccess){
		my $vaccess = $vaccess->{$vid};
		my $active = grep $_->{ACTIVE_CONTRACT},@{$contract->{$vid}};
		$vaccess->{ACTIVE_CONTRACT} = $active;
	}

	my $vids = {};
	#active contract to jobs...
	foreach my $vid (keys %$jobs){
		my $active = grep $_->{ACTIVE_CONTRACT},@{$contract->{$vid}};
		foreach my $SID (keys %{$jobs->{$vid}}){
			my $job = $jobs->{$vid}->{$SID};
			$job->{ACTIVE_CONTRACT} = $active;
			$vids->{$SID} = $vid;
		}
	}
	return { contracts=>$contract,vaccesses=>$vaccess, 
		jobs=>$jobs,client=>$client,vids=>$vids };
}
sub edit_security {
	my $self = shift;
	my $uid = shift || confess 'first param must be uid';
	my $SID = shift || confess 'second param must be SID';
	my %args = @_;
	my $rsec = $args{rsec} || $self->read_security($uid);
	my $VID = $rsec->{vids}->{$SID};

	my ($err,$job);
	if ($SID){
		if ($job = $rsec->{jobs}->{$VID}->{$SID}){
			if ($job->{ACTIVE_CONTRACT}){
				if ($job->{J_USE}){
				}else{
					$err= "You do not have USE rights on job '$SID' on host '$job->{VDOMAIN} ($VID)'";
				}
			}else{
				$err = "No Active Contract covering job '$SID' on host '$job->{VDOMAIN} ($VID)'";
			}
		}else{
			my $server = "on this server ($ENV{SERVER_NAME})" if $ENV{SERVER_NAME};
			my $hint = "<BR>You should use the Designer to create new jobs (option ASP Deploy)" if $ENV{SERVER_NAME};
			$err= "$SID does not exist $server $hint";
		}
	}else{
		$err= "You must supply an SID";
	}
	return {job=>$job,err=>$err,rsec=>$rsec};
}

sub create {
	my $self = shift;
	my $uid = shift;
	confess "First Param must be a user name" unless $uid;

	my %ARGS = @_;

	my $new = $ARGS{new};
	my $VID = $ARGS{VID};
	my $SID = $ARGS{SID};
	my $target = $ARGS{target};
	my $action = $ARGS{action};

	my $security = $ARGS{rsec} || $self->read_security($uid);
	my $client = $security->{client};

	my $ret = {};

	if ($VID){
		my $vacces = $security->{vaccesses}->{$VID};
		if ($vacces){
		# $m->comp ('/Dumper.mc',thing=> $vacces);
			if ($vacces->{J_CREATE} && $vacces->{ACTIVE_CONTRACT}){
				my $dbh = $self->asp->dbh;
				my $ez = new TPerl::DBEasy;
				my $asp = $self->asp;
				my $fields = $asp->job_fields ();
				$ARGS{EMAIL}||='Change this to your email address';
				if ($new ==1){
					$ret->{form} = $ez->form(fields=>$fields,row=>\%ARGS,new=>2,target=>$target,action=>$action);
				}elsif ($new==2){
					my $err = $asp->mk_job (vals=>\%ARGS,fields=>$fields);
					if ($err){
						if ($err->{validate}){
							$ret->{form} = $ez->form(fields=>$fields, valid=>$err->{validate},
								row=>\%ARGS,new=>2,heading=>'Job Creation Error',target=>$target,action=>$action);
						}else{ $ret->{err} = $err; }
					}else{ $ret->{success} = 1; }
				}else{ $ret->{deny} = 'new needs to be 1 or 2'; }
			}else{ $ret->{deny} = "Cannot create  JOBS on '$vacces->{VDOMAIN}'"; }
		}else{ $ret->{deny} = "Cannot create JOB '$SID' in VID '$VID'"; }
	}else{ $ret->{deny} = 'No Creating without a VID'; }

	return $ret;
}
# sub edit {
# 	my $self = shift;
# 	my %args = @_;
# 	my $edit=$args{edit} || 1;
# 	my $do_upload=$args{do_upload} || 1;
# 	my $do_download=$args{do_download} || 1;
# 	my $do_textarea=$args{do_textarea} || 1;
# 	my $do_dbform=$args{do_dbform} || 1;
# 	my $chat=$args{chat} || 1;
# 	my $SID=$args{SID} || undef;
# 	my $VID=$args{VID} || undef;
# 	my $textfile=$args{textfile} || undef;
# 	my $poutrows=$args{poutrows} || undef;
# 	my $textarea_action=$args{textarea_action} || $ENV{SCRIPT_NAME};
# 	my $textarea_target=$args{textarea_target} || '_self';
# 	my $success_box=$args{} || 1;
# 
# 	my $security = $self->read_security($uid);
# 
# 	return {err=>$security->{err}} if $security->{err};
# 	return {};
# 
# }

sub confirm_broadcast_send {
	my $self = shift;
	my %args = @_;

	my $file = $args {file};
	my $pretty_file = $args{pretty_file};
	my $email_col = $args{email_col} || 'email';  # this is the column in the uploaded file to do Email::Valid on
	my $invite_date = $args{invite_date};
	my $reminder1_date = $args{reminder1_date};
	my $reminder2_date = $args{reminder2_date};
	my $SID = $args{SID} || confess 'SID is a required parameter';
	my $VID = $args{VID};
	my $html_template = $args{html_template};
	my $plain_template = $args{plain_template};
	my $BID = $args{BID};
	my $nobuttons = $args{nobuttons};
	my $dbh = $args{dbh};
	my $prepared = $args{prepared};

	my $s = new TPerl::Survey ($SID);
	my $i = new TPerl::Survey::Inviter($s);

	
	my $info = $i->examine_batch_file ($file);

	$pretty_file ||= basename $file;
	my $lf = new TPerl::LookFeel;
	my $page; ## the text.  some of it should go in an err....
	my $q = new TPerl::CGI ('');
	# $page .= $q->dumper ($info);
	if (my $err = $info->{err}){
		$page.=$q->err($err);
	}else{
		## Update the database...
		my $ez = new TPerl::DBEasy;
		my ($filnum) = $file =~ /(\d+)$/;
		my $row = {GOOD=>$info->{good},SID=>$SID,BID=>$filnum};
		my $fields = $self->asp->batch_fields;
		foreach (keys %$fields){
			delete $fields->{$_} unless defined $row->{$_};
		}
		if (my $uperr = $ez->row_manip (action=>'update',table=>'BATCH',vals=>$row,fields=>$fields,
				dbh=>$dbh,keys=>[qw(SID BID)])){
			$page .= 'update error<PRE>'.Dumper ($uperr).'</PRE>';
		}

		$page.= join "\n",
			$lf->sbox  ("Status of $pretty_file"),
			"$info->{good} good email addresses";
		$page .= join("\n",
			'<p>Send or Delete?',
			$q->startform (-action=>"http://$ENV{HTTP_HOST}".dirname($ENV{REQUEST_URI}).'/aspsendbatch.pl',-method=>'POST'),
			$q->hidden(-name=>'invite_date',-value=>$invite_date),
			$q->hidden(-name=>'reminder1_date',-value=>$reminder1_date),
			$q->hidden(-name=>'reminder2_date',-value=>$reminder2_date),
			$q->hidden(-name=>'VID',-value=>$VID),
			$q->hidden(-name=>'html_template',-value=>$html_template),
			$q->hidden(-name=>'plain_template',-value=>$plain_template),
			$q->hidden(-name=>'SID',-value=>$SID),
			$q->hidden(-name=>'BID',-value=>$BID),
			$q->hidden(-name=>'file',-value=>$file),
			$q->hidden(-name=>'PREPARED',-value=>1),
			$q->submit(-value=>'Send',-name=>'send'),
			$q->submit(-value=>'Delete',-name=>'delete'),
			$q->endform) unless $nobuttons;
		$page .= $lf->ebox;
	}
	return {page=>$page};
}

sub invite_upload_broadcast {
	## similar to below except that we force a new number for each upload, rather than allowing batch replacement.
	# prolly ought to abstract the unzipping stuff

	# 30/7/2002 enter the batch table, caching stuff about batches.
	
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID};
	my $uid = $args{UID};
	my $dbh = $args{dbh} || confess 'dbh is a required param';
	my $debug = $args{debug};
	my $nobuttons = $args{nobuttons};
	my $asp = $self->asp;

	my $q = new TPerl::CGI('');
	my $esec = $args{esec} || $self->edit_security($uid,$SID);
	return {deny=>$esec->{err}} if $esec->{err};

	my $page = undef;
    my $VID = $esec->{rsec}->{vids}->{$SID};
    my $job = $esec->{job};
    my $s = new TPerl::Survey (SID=>$SID,TritonRoot=>$job->{TRITONROOT});
    my $i = new TPerl::Survey::Inviter ($s);
    my $config = $i->config;
    # $m->comp ('/Dumper.mc',thing=>$job,what=>'JOB');

    ### ini file stuff.  this ought to go into TPerl::Survey::Inviter...
    unless (-e  $config->file){
        my $fhh = new FileHandle ("> ".$config->file);
        close $fhh;
    }
	# $page.= $q->dumper(\%args);
	my $name;
    foreach my $arg (keys %args){
        $name = $arg if $arg =~ /^broadcast(\d*)$/
		# $i->save_upload($args{
    }
	# $page.="\n<BR>name=$name";
    if (ref $args{$name} eq 'Fh'){
        my $invite = 0; ## this will be true if we sucessfully unzip a file.
        my $file =''; # this is where we saved it.
        ### workout what to call this broadcast file.
		# Use batchno.txt you goose.
		my $ending;
		{
			my $fn = join '/',$s->TR,$s->SID,'config','batchno.txt';
			unless (-e $fn){
				overwrite_file $fn,(100) or die "Could not create $fn:$!";
			}
			my $text = read_file $fn;
			($ending) = $text =~ /(\d+)/s;
			# die "text=$text|end=$ending";
			overwrite_file ($fn,$ending+1) or die "Could not write $fn:$!";
		}
        my $config_dir = join ('/',$s->TR,$s->SID,'config');
        # $page.= "\n<BR>ending=$ending");
        $file = "$config_dir/broadcast$ending";
        my $zipped = join '/',$config_dir,'temp.gz';
        my $unzipped = $zipped;
        $unzipped =~ s/\.gz$//;
        unlink $unzipped if -e $unzipped;
        if (copy $args{$name},$zipped){
			# $page.="\n<BR>copied $name to $zipped" if $debug;
            my $exec = TPerl::CmdLine->execute (cmd=>"gunzip $zipped");
            if ($exec->success){
                $page.="\n<BR>unzipped $zipped to $unzipped" if $debug;
                if (copy $unzipped,$file){
                    $page.= "\n<BR>copied $unzipped to $file" if $debug;
                    $invite++;
                }else{
                    $page.="\n<BR>Could not copy $unzipped to $file";
                }
            }else{
                $page.="\n<BR>failed unzipping $zipped" if $debug;
                $page.= $q->dumper ($exec) if $debug;
                my $stderr = $exec->stderr;
                $page.= "unzip error :$stderr"  unless $stderr =~ /not in gzip format/;
                if (copy $zipped, $file){
                    $page.=    "\n<BR>copied $zipped to $file" if $debug;
                    $invite++;
                }else{
                    $page.=    "\n<BR>Couldn't copy $zipped to $file:$!";
                }
            }
        }else{
            $page.="\n<BR>Could not copy uploaded file to $zipped";
        }
		if ($invite){
			# update the batches table
			my $ez = new TPerl::DBEasy;
			my $fields = $asp->batch_fields;
			delete $fields->{$_} foreach qw (DELETE_EPOCH CLEAN_EPOCH);
			my $zero = $ez->epoch2text(0);
			my $row = {NAMES_FILE=>$file,UPLOAD_EPOCH=>'now',BID=>$ending,SID=>$SID,
				GOOD=>0,BAD=>0,
				ORIG_NAME=>'_none_',
				TITLE=>"Inviter Batch $ending",
				UPLOADED_BY=>$ENV{REMOTE_USER},
				};
			if (my $inserr = $ez->row_manip(table=>'BATCH',action=>'insert',vals=>$row,
					fields=>$fields,dbh=>$dbh)){
				$page.= '<PRE>'.Dumper ($inserr).'</PRE>';
			}else{
				my $ret = $self->confirm_broadcast_send (dbh=>$dbh,file=>$file,SID=>$SID,VID=>$VID,nobuttons=>$nobuttons );
				$page.=$ret->{page};
			}
		}
    }else{
        #####FORM writing stuff
        my $action = "http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}";
        $page.=join ("\n",
            $q->start_multipart_form(-action=>$action,-method=>'POST'),
            $q->hidden(-name=>'VID',-value=>$VID),
            $q->hidden(-name=>'SID',-value=>$SID),
            $q->filefield (-name=>'broadcast'),
            '<p>',
            $q->submit(-name=>'submit',-value=>'Upload'),
            $q->endform,
            '</p>'
        );
    }
	return {page=>$page};
}

sub invite_upload {

	my $self = shift;
	my %args = @_;
	my $SID = $args{SID} || confess 'No SID sent';
	my $uid = $args{UID} || confess 'UID is a required parameter of invite_upload';

	my $esec = $args{esec} || $self->edit_security($uid,$SID);
	my $phase = $args{phase} || 1;
	my $debug = $args{debug} || 0;
	my $invites = $args{invites} || 1;
	my $batches = $args{batches} || 1;
	my $reminders = $args{reminders} || 1;
	my $lf= $args{lf} || new TPerl::LookFeel;

	return {deny=>$esec->{err}} if $esec->{err};

	my $scriptsDir = getConfig('scriptsDir') or die "Could not get 'scriptsDir' from getConfig";

	my $q = new TPerl::CGI ('');
	my $page ; # the stuff that gets printed later
	# $page.= $q->dumper ($esec);
    my $VID = $esec->{rsec}->{vids}->{$SID};
    my $job = $esec->{job};
    # $m->comp ('/Dumper.mc',thing=>$job,what=>'JOB');
    my $s = new TPerl::Survey (SID=>$SID,TritonRoot=>$job->{TRITONROOT});
    my $i = new TPerl::Survey::Inviter ($s);

    ### Some TPerl::Survey::Inviter::File objects
    ##These tell us what files exist on the filesystem and whether to allow
    ## multilpe versions, whether to put tabs in them etc

    my ($plain_inv,$html_inv) = $i->invites;
    my ($plain_rem,$html_rem) = $i->reminders;
    my $config = $i->config;
    my $pilot = $i->pilot;
    my $proto = $i->prototype;
    my $broadcast = $i->broadcast;

    # which of the above objects to handle in each phase.
    # this also maps the form variable to a filename.
    # the keys in the files hash are the form var names.
    my %files = ();
    my $button = '';    # the button text
    my %atleast = ();  # the min number of fields in the form for multi types.
    if ($phase ==1){
        ##proto
        $files{prototype}=$proto;
        $files{config}=$config;
        $files{plain_inv}=$plain_inv;
        $files{html_inv}=$html_inv;
        $atleast{html_inv} = $invites;
        $atleast{plain_inv} = $invites;
        $files{html_rem}=$html_rem;
        $files{plain_rem}=$plain_rem;
        $atleast{html_rem} = $reminders;
        $atleast{plain_rem} = $reminders;
        $atleast{prototype} = 1;
        $button = 'Preview Email';
    }elsif ($phase==2){
        $files{pilot}=$pilot;
        $files{config}=$config;
        $files{plain_inv}=$plain_inv;
        $files{html_inv}=$html_inv;
        $atleast{html_inv} = $invites;
        $atleast{plain_inv} = $invites;
        $files{plain_rem}=$plain_rem;
        $files{html_rem}=$html_rem;
        $atleast{html_rem} = $reminders;
        $atleast{plain_rem} = $reminders;
        $atleast{pilot} = 1;
        $button = 'Test Email';
    }elsif ($phase==3){
        $files{broadcast}=$broadcast;
        $button = 'Upload Real Names';
        $atleast{broadcast} = $batches;
    }else{
        $page .= "\n<H2>phase must be 1 2 or 3";
        %files = ();
    }
    my $p = new TPerl::Parser;
    my $cvserr = $p->cvs_import (module=>"config/$SID",dir=>join ('/',$s->TR,$SID,'config'),cvsroot=>$job->{CVSROOT});
    $page.="\n<br>CVS import error $cvserr"  if $cvserr;

    my $invite = 0;  ### if some files were updated, do  something
	if ($debug){
		$page .= '<p>The keys are the form names. the values are what we expect and what to do with them...</p>';
		$page .= $q->dumper (\%files);
	}
    ##### What to accept and save and try to gunzip on the server.
    foreach my $param (keys %files){
        my @matching_args = grep /^$param$/,keys %args;
        @matching_args = grep /^$param\d+$/,keys %args if $files{$param}->multi;
        # $m->comp ('/Dumper.mc',thing=> \@matching_args,what=>"args matching $param");
        foreach my $arg (@matching_args){
            my ($ending) = $arg=~ /(\d+)$/;
            my $file = $files{$param}->file.$ending;
            if (ref $args{$arg} eq 'Fh'){
                $page.="\n<BR>field $arg is a file upload to $file" if $debug;
                my $zipped = join ('/',$s->TR,$s->SID,'config','temp.gz');
                my $unzipped = $zipped;
                $unzipped =~ s/\.gz$//;
                unlink $unzipped if -e $unzipped;
                if (copy $args{$arg},$zipped){
                    $page.= "\n<BR>copied $arg to $zipped" if $debug;
                    my $exec = TPerl::CmdLine->execute (cmd=>"gunzip $zipped");
                    if ($exec->success){
                        $page.= "\n<BR>unzipped $zipped to $unzipped" if $debug;
                        if (copy $unzipped,$file){
                            $page.=  "\n<BR>copied $unzipped to $file"if $debug;
                            $invite++;
                        }else{
                            $page.= "\n<BR>Could not copy $unzipped to $file";
                        }
                    }else{
                        $page.= "\n<BR>failed unzipping $zipped" if $debug;
                        $page.=  $q->dumper ($exec) if $debug;
                        my $stderr = $exec->stderr;
                        $page.=  "unzip error :$stderr"  unless $stderr =~ /not in gzip format/;
                        if (copy $zipped, $file){
                            $page.=     "\n<BR>copied $zipped to $file"if $debug;
                            $invite++;
                        }else{
                            $page.=     "\n<BR>Couldn't copy $zipped to $file:$!";
                        }
                    }
                }else{
                    $page.= "\n<BR>Could not copy uploaded file to $zipped";
                }
            }else{
                if ((my $cont = $args{$arg}) && $phase != 3 ){;
                    if (my $t = $files{$param}->tabs){
                        $t = quotemeta ($t);
                        $cont =~ s/$t/\t/g;
                    }
                    if ($cont){
                        if (write_file ($file,$cont)){
                            $invite++;
                            # $page.= "\n<BR>Wrote $file";
                        }else{
                            $page.= "\b<BR>Could not write $file";
                        }
                    }else{
                        unlink $file if defined $args{$arg};
                    }
                }
            }
            if ($phase == 3 && $invite){
                # $m->comp ( 'check_uploaded_file.mc',file=>$file );
            }
        }
    }
    if ($invite){
        if ($phase==1 || $phase==2){
            my $names= basename ($proto->file) if $phase ==1;
            $names= basename ($pilot->file) if $phase ==2;
            my $options = "-list=$names  -plain=invitation-plain1 -html=invitation-html1 -V=$VID -E=0";
            my @cmds = (
                {cmd=>"perl aspinvite.pl $SID $options -prepare ",pretty=>'Prepared'},
                {cmd=>"perl aspinvite.pl $SID $options ",pretty=>'Sent'},
            );
            # $m->comp ('/Dumper.mc',thing=> \@cmds,what=>'commands');
            foreach my $cmd (@cmds){
                my $exec = execute TPerl::CmdLine (cmd=>$cmd->{cmd},dir=>$scriptsDir);
                if ($exec->success){
					next if $cmd->{cmd} =~ /prepare/i;
                    $page.= $lf->sbox ("Email results") ;
					my $out = $exec->stdout;
					$out =~ s/\n/<BR>/gs;
                    $page.= $out . $lf->ebox;
                }else{
                    $page.= $lf->sbox("$cmd->{pretty} Email Error ") ;
                    $page.= join "\n",'<PRE>',$exec->stdout,$exec->stderr,'</PRE>' ;
                    $page.= join "\n",'<!--',$exec->cmd,'>' ;
					$page.= $lf->ebox;
                    last;
                }
            }
        }else{
            #$page.= "\n<br>now the link to the control page"  ;
        }
    }else{
        #####FORM writing stuff

        $page.= join ("\n",
            $q->start_multipart_form(-action=>$ENV{SCRIPT_NAME},-method=>'POST'),
            $q->hidden(-name=>'VID',-value=>$VID),
            $q->hidden(-name=>'SID',-value=>$SID),
            # '<BR>FORM WRITING STUFF',
        );
        foreach my $param (sort {$files{$a}->order <=> $files{$b}->order} keys %files){
            my $param2file=$files{$param}->active_files (atleast=>$atleast{$param});
			if ($debug){
				$page .= '<p>files for $param.  These are the files that we found on the filestsystem</p>';
            	$page.= $q->dumper ($param2file);
			}
            foreach my $number (sort {$a <=> $b} keys %$param2file){
                my $file = $param2file->{$number}->{file};
                my $name = $param;
                $name.=$number if $files{$param}->multi;
                if ($files{$param}->upload){
                    $page.= join ("\n","<h3>$name</h3>",$q->filefield(-name=>$name,-default=>$file));
                }else{
                    $page.= "\n<BR>reading file $file" if $debug;
                    my $cont = undef;
                    $cont = join ('',read_file($file)) if -e $file;
                    my $tabs = '';
                    if (my $t = $files{$param}->tabs){
                        $tabs = "Tab Char=$t<BR>";
                        $cont =~ s/\t/$t/g;
                    }
                    $page.= join ("\n",
                        "<h3>$name</h3><p>",
                        $tabs,
                        $q->textarea(-rows=>5,columns=>70,-name=>$name, -default=>$cont,),
                        '</P>',
                    );
                }
            }
        }

        my $message = undef;
        $message = 'It takes a few seconds to crank over sendmail' if $phase==1 || $phase==2;
        $page.= join ("\n",
            '<p>',
            $q->submit(-name=>'submit',-value=>$button),
            $message,
            $q->endform,
            '</p>'
        );
    }


	return {page=>$page};
}
sub survey_text {
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID} || confess 'No SID sent';
	my $uid = $args{UID} || confess 'UID is a required parameter of survey_text()';
	my $VID = $args{VID};
	my $SIMPLE_TABS = $args{simple_tabs};
	my $textfile = $args{textfile};
	my $do_textarea=$args{do_textarea} || 1;
	my $action=$args{action} || $ENV{SCRIPT_NAME};
	my $target=$args{target} || '_self';
	my $rsec = $args{rsec};
	my $parse = $args{parse};
	my $lf = $args{lf} || new TPerl::LookFeel;
	my $poutrows =$args{poutrows};
	my $success_box = $args{success_box};
	my $esec =  $self->edit_security($uid,$SID,rsec=>$rsec);
	return {deny=>$esec->{err}} if $esec->{err};

	my $scriptsDir = getConfig('scriptsDir') or die "Could not get 'scriptsDir' from getConfig";

	my $job = $esec->{job};
    my $s= new TPerl::Survey (SID=>$SID,TritonRoot=>$job->{TRITONROOT});
    my $p_output = undef;
    my $pout_fh = new IO::Scalar \$p_output;
    my $parser = new TPerl::Parser (err_fh=>$pout_fh);
    my $file = $parser->parser_filename (SID=>$SID,survey=>$s);
	my $ret = {};
	my $q = new TPerl::CGI ('');

    if ($do_textarea){
        my $default = join('',read_file($file)) if -e $file;
		# print "def=$default\n";
		$default =~ s/\r\r//gs;
		$ret->{textform} = join "\n",
			$lf->sbox("$SID Survey File")."\n",
            $q->startform (-name=>'designer',-action=>$action,-method=>'POST',-target=>$target),
            $q->textarea (-name=>'textfile',-rows=>25,-columns=>50,-default=>$default),
            $q->hidden (-name=>'SID',-value=>$SID),
            $q->hidden (-name=>'VID',-value=>$VID),
            '<BR><BR>',
            'Compiler options:<br>',
            '<input type=\'checkbox\' name=\'simple_tabs\' checked>Simple tabs - all data columns follow standard name rule<BR>', 
            '<BR><BR>',
            $q->submit (-name=>'submit',-value=>'Save'),
            $q->endform,
        	$lf->ebox,'<BR>';

    }
	if (defined $textfile){
		if (-w $file){
			write_file $file,$textfile;
			$parse=1;
		}else{
			$ret->{err} = "Could not update '$file':$!";
		}
	}
	
    if ($parse){
        if (my $cvs_err = $parser->cvs_import(cvsroot=>$job->{CVSROOT},files=>[$file])){
            $ret->{err} .= "\n<BR> cvs import error <PRE>$cvs_err</PRE>";
        }
		my $qfiles_exec = execute TPerl::CmdLine(join_output=>1,dir=>$scriptsDir,cmd=>"perl qfiles.pl $SID");
		if ($SIMPLE_TABS) {
			$qfiles_exec = execute TPerl::CmdLine(join_output=>1,dir=>$scriptsDir,cmd=>"perl qfiles.pl $SID -simple_tabs ");
       	} else {
       		$qfiles_exec = execute TPerl::CmdLine(join_output=>1,dir=>$scriptsDir,cmd=>"perl qfiles.pl $SID ");
      	}
        # $parser->parse(file=>$file);
        # my $dir = join ('/',$s->TR,$s->SID,'config');
        # $parser->engine_files (dir=>$dir,SID=>$SID,troot=>$s->TR);
		# $parser->variable_usage ();
        my $cmdline = $s->survey2DHTML(world=>$scriptsDir,debug=>0);
        unless ($cmdline->success){
			$ret->{err} = join "\n",
            	"<BR>survey2DHTML error in world '$scriptsDir'",
            	$q->dumper ($cmdline)
        }
		$p_output = $qfiles_exec->stdout;
		$p_output =~ s/\n/<BR>\n/gs;
        my $suc = join "\n",'<BR>', $q->textarea (-name=>'status',-value=>'Success') if $success_box;
        $ret->{parser} = join "\n",(
			'<br>',
            $lf->sbox ('Parser Output'),
			qq{<SPAN ALIGN="LEFT">},
			$p_output,
			qq{</SPAN>},
            $suc,
            $lf->ebox,
            qq{\n<p class="options"><center><A HREF="http://$job->{VDOMAIN}/$SID/main.htm" target="_blank">Preview</A></center></P>},
        );
    }
	return $ret;
}

1;
