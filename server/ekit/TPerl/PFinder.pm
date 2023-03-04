package TPerl::PFinder;
#$Id: PFinder.pm,v 1.26 2007-02-12 23:44:18 triton Exp $
# put some of the useful bits of the pfinder in here, so you can use them elsewhere.
use strict;
use TPerl::TSV;
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::DBEasy;
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::Event;
use TPerl::TritonConfig;
use File::Copy;
use TPerl::Engine;
use TPerl::TransactionList;
use Config::IniFiles;
use TPerl::DoNotSend;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;
    my %args = @_;
    # confess "dbh is required param" unless $args{dbh};
    $self->{dbh} = $args{dbh};
    $self->{look} = $args{look};
    $self->{cgi} = $args{cgi};
    $self->{SID} = $args{SID};
    return $self;
}

sub err { my $self = shift;$self->{err}=$_[0] if @_;return $self->{err}; }

sub look { my $self = shift; return $self->{look} || new TPerl::LookFeel; }
sub cgi { my $self = shift; return $self->{cgi} || new TPerl::CGI(''); }
sub SID { my $self = shift; return $self->{SID}; }

sub dbh { 
	my $self = shift; 
	$self->{dbh} ||= dbh TPerl::MyDB();
	return $self->{dbh};
}

sub status_labels {
	my $self = shift;
	return  {
		0=>'Ready',
		2=>'Terminated',
		1=>'Refused',
		3=>'Incomplete',
		4=>'Complete'
	};
}

sub left {
 # The left frame is the search box.
	my $self = shift;
	my %args = @_;

	my $target=$args{target} || 'right1';
	my $action =$args{action} || "$ENV{SCRIPT_NAME}/right1";
	my $q = $self->cgi;
	my $dbh = $self->dbh;
	my $SID = $self->SID;
	my $lf = $self->look;

	my $asp = new TPerl::ASP(dbh=>$dbh);
	my $ez = new TPerl::DBEasy (dbh=>$dbh);
	
    my $fields = $ez->fields (table=>$SID);
	$fields->{STAT}->{pretty}='Status';
	$fields->{PWD}->{pretty}='Password';
	$fields->{UID}->{pretty}='Unique Identifier';
	$fields->{SEQ}->{pretty}='Sequence Number';
	$fields->{BATCHNO}->{pretty}='Batch';
	delete $fields->{PWD}->{js};

	
	my $batchlist = $asp->batch_list(SID=>$SID,table_only=>1);
	return $q->err($asp->err) unless $batchlist;
	my $batchno_vals = [sort {$a <=> $b} keys %$batchlist];
    my $batchno_labs = {};
	$batchno_labs->{$_} = "$batchlist->{$_}->{TITLE}:($_)" foreach @$batchno_vals;
    unshift @$batchno_vals,'';
    $batchno_labs->{''}='Any Batch';

    # Give some info on how to display some of the fields.
    $fields->{BATCHNO}->{cgi}->{func}='popup_menu';
    $fields->{BATCHNO}->{cgi}->{args}={-default=>'',-values=>$batchno_vals,-labels=>$batchno_labs};
    $fields->{STAT}->{cgi}->{func}='popup_menu';
    my $search_stat_labels = {};
	my $stat_labels = $self->status_labels();
    $search_stat_labels->{$_} = $stat_labels->{$_} foreach keys %$stat_labels;
    $search_stat_labels->{''} = 'Any Status';
    $fields->{STAT}->{cgi}->{args}={-value=>[sort {$a<=>$b } keys %$search_stat_labels ],-labels=>$search_stat_labels,-default=>''};
    $fields->{EMAIL}->{cgi}->{args}->{-size}=20;
    $fields->{FULLNAME}->{cgi}->{args}->{-size}=20;
    $fields->{UID}->{cgi}->{args}->{-size}=20;

    ### We don't want these fields in the search screen.
    delete $fields->{$_} foreach qw(TS REMINDERS EXPIRES);
    return $ez->form(row=>{},fields=>$fields,state_vars=>{SID=>$SID},
        action=>$action,target=>$target,twidth=>$lf->twidth,
        heading=>"Search for Respondants",compact=>1,button_val=>'Search');
    # print $q->dumper ($fields);

}
sub right3 {
	##This does the edit and resend stuff 
	my $self = shift;
	my %args = @_;
    my $dbh = $self->dbh;
    my $ez = new TPerl::DBEasy (dbh=>$dbh);
    my $q = $self->cgi;
    my $SID = $self->{SID};
    my $lf = $self->look;

	my $pwd = $args{PWD};

	### Here we handle the submit
	#
	$args{EMAIL} =~ s/^\s*(.*)\s*$/$1/;
	$args{FULLNAME} =~ s/^\s*(.*)\s*$/$1/;
	my $successful_update_message = '';
	if ($args{submit}){
		my $sql = "select * from $SID where PWD=?";
		my $row = $dbh->selectrow_hashref($sql,{},$pwd);
		if (($args{old_EMAIL} eq $args{EMAIL}) and ($args{old_FULLNAME} eq $args{FULLNAME})){
			#no changes ito make
			$self->right3_sendemail($row) || return $q->err($self->err());
			$successful_update_message = join "\n",
				$lf->sbox ('Sucessful Update'),
				'No changes where made',
				'<br>',
				'<br>',
				"Email was resent to $args{EMAIL}",
				$lf->ebox;

		}else{
			#update ufile, dfile and broadcastfile and the table.
			#first we need the record from the SID table 
			return $q->err({sql=>$sql,dbh=>$dbh,params=>[$pwd]}) unless $row;

			my $tlist = new TPerl::TransactionList;
			my $troot = getConfig('TritonRoot');
			{
				my $br_file = join '/',$troot,$SID,'broadcast',"broadcast$row->{BATCHNO}";
				$br_file = join '/',$troot,$SID,'config',"broadcast$row->{BATCHNO}" unless -e $br_file;

				my $tsv = new TPerl::TSV (file=>$br_file,nocase=>1);
				my $a = sub {
					my $row = shift;
					if ($row->{PASSWORD} eq $pwd){
						$row->{EMAIL} = $args{EMAIL};
						$row->{FULLNAME} = $args{FULLNAME};
					}
					return $row;
				};
				my $item = $tlist->item(pretty=>"Update broadcast file broadcast$row->{BATCHNO}");
				if (my $new_br = $tsv->edit_to_temp(callbacks=>{action=>$a})){
					$item->edit($new_br);
					$item->orig($br_file);
				}else{
					$item->err($tsv->err);
				}
				$tlist->push($item);
			}
			my $en = new TPerl::Engine();
			{	
				## ufile.
				my $old = join '/',$troot,$SID,'web',"u$pwd.pl";
				my $new = $en->u_edit_to_temp(file=>$old,change=>{email=>$args{EMAIL},fullname=>$args{FULLNAME}});
				my $item = $tlist->item(pretty=>"Update ufile u$pwd.pl",orig=>$old,edit=>$new);
				$item->err($en->err) unless $new;
				$tlist->push($item);
			}
			{
				##dfile
				if (my $seq = $row->{SEQNO}){
					my $old = join '/',$troot,$SID,'web',"D$seq.pl";
					my $new	= $en->qt_edit_to_temp(file=>$old,change=>{email=>$args{EMAIL},fullname=>$args{FULLNAME}});
					my $item = $tlist->item(pretty=>"Update Dfile D$pwd.pl",orig=>$old,edit=>$new);
					$item->err($en->err) unless $new;
					$tlist->push($item);
				}
			}
			{
				###db update
				my $sql = "update $SID set EMAIL=?,FULLNAME=? where PWD = ?";
				my $params = [$args{EMAIL},$args{FULLNAME},$pwd];
				my $item = $tlist->item(pretty=>"Update $SID table for pwd $pwd",dbh=>$dbh,sql=>$sql,params=>$params);
				$tlist->push($item);
			}
			###
			my $work_errs = $tlist->errs || [];
			if (@$work_errs){
				return join "\n",
					# $q->dumper($work_errs),
					$lf->sbox("File Edit Errors:"),
					join ("\n<BR>",map $_->pretty.': '.$_->err,@$work_errs),
					'<BR>',
					'<BR>',
					'No Changes made',
					$lf->ebox;
			}else{
				#start database work, and do sqls
				$dbh->begin_work;
				$tlist->dbh_do;
				my $dbh_errs = $tlist->errs || [];
				if (@$dbh_errs){
					$tlist->dbh_rollback_message($dbh->rollback);
					return join "\n",
						$lf->sbox("Database errors occured"),
						join ("\n<BR>",map $_->pretty.': '.$_->err,@$dbh_errs),
						'<br>',
						'<br>',
						'Rollback status follows',
						join ("\n<br>", map $_->rollback_err || $_->rollback_msg,@$dbh_errs),
						'<br>',
						'<br>',
						'No File changes where commited',
						$lf->ebox;
				}else{
					$tlist->commit_files;
					# $tlist->list->[-2]->err("You are a goose");
					my $fc_errs = $tlist->errs || [];
					if (@$fc_errs){
						$tlist->dbh_rollback_messages($dbh->rollback);
						$tlist->rollback_files;
						return join "\n",
							# $q->dumper($tlist),
							$lf->sbox ("A File commit error occured."),
							'The following errors occured commiting file edits',
							'<BR>',
							'<BR>',
							join ("\n<br>", map $_->pretty.' :'.$_->err,@{$tlist->errs}),
							'<BR>',
							'<BR>',
							'Rollback status follows',
							'<BR>',
							'<BR>',
							join ("\n<br>", map $_->rollback_err || $_->rollback_msg,@{$tlist->list}),
							$lf->ebox;
					}else{
						$dbh->commit;
						### Now we send an email.
						$self->right3_sendemail($row) || return $q->err($self->err());
						$successful_update_message = join "\n",
							$lf->sbox ('Sucessful Update'),
							'Changes to the following were made',
							'<br>',
							'<br>',
							join ("\n<br>",map $_->pretty,@{$tlist->list}),
							'<br>',
							'<br>',
							"Email was resent to $args{EMAIL}",
							$lf->ebox;
					}
				}
			}
		}
	}

	### Here we do the display
	my $sql = "select * from $SID where PWD=?";
	my $row = $dbh->selectrow_hashref($sql,{},$pwd);
	return $q->err({sql=>$sql,dbh=>$dbh,params=>[$pwd]}) unless $row;
	
	my $fields = $ez->fields(table=>$SID);
	$fields->{PWD}->{cgi}->{func} = 'hidden';
	delete $fields->{$_} foreach qw (UID STAT TS EXPIRES SEQ REMINDERS BATCHNO);
	my $state = {SID=>$SID};
	$state->{"old_$_"} = $row->{$_} foreach qw(EMAIL FULLNAME);
	return join "\n",
		$successful_update_message ,
		$ez->form(fields=>$fields,row=>$row,look=>$lf,state_vars=>$state,button_val=>'Resend Email'),
		# $q->dumper($state),
		# $q->dumper(\%args);

}
sub right3_sendemail {
	my $self = shift;
	my $row = shift;

    my $q = $self->cgi;
    my $SID = $self->SID;
	my $troot = getConfig('TritonRoot');

	my $pkt_file = join '/',$troot,$SID,'binfo',"$row->{BATCHNO}.ini";
	my ($h,$p);
	if (-e $pkt_file){
		my $pkt_ini = new Config::IniFiles(-file=>$pkt_file);
		($self->err("'pkt_file' is not an ini file") && return undef) unless $pkt_ini;
		$h = $pkt_ini->val('args','html_template');
		$p = $pkt_ini->val('args','plain_template');
	}else{
		# return $q->err("Changes made.  Could not send email: File $pkt_file does not exist") unless -e $pkt_file;
		# lets assume in the case where we can't find the
		# ini file......  This is for MAP026 on the triton
		# vhosts, where the new style packet file is not
		# being written.  ideally we'll get rid of it one
		# day.
		$h = 'invitation-html1';
		$p = 'invitation-plain1';
	}
	my $pwd = $row->{PWD};
	my $aspinvite = "perl aspinvite.pl $SID --just=$pwd --html=$h --plain=$p --list=$row->{BATCHNO}";
	my $exec = execute TPerl::CmdLine(dir=>getConfig('scriptsDir'),cmd=>$aspinvite);
	my $msg = '';
	unless ($exec->success){
		if ($h eq '' or $p eq ''){
			$self->err( "This batch is probably too old.  Can't get html_template and plain_template from $pkt_file");
			return undef;
		}
		$self->err("Email Send failed. ".'<pre>'.$exec->output.'</pre>');
		return undef;
	}
	return $exec->output;
}
sub right1 {
    ### This takes the search fields from left and build
    # and displays the SQL.  We also allow changing of the
    # status from this screen.
    # Fields with NEW_ distinguish edited status values from
    # the search fields.  The status update form uses the SQL fields
    # as state info, so that the same page will be displayed, after an edit.

	#We also update dfiles, including creating a dfile if there is not one.

	my $self=shift;
	my %args = @_;

	my $dbh = $self->dbh;
	my $ez = new TPerl::DBEasy (dbh=>$dbh);
	my $q = $self->cgi;
	my $SID = $self->{SID};
	my $lf = $self->look;

	my $pwd_sprintf = $args{pwd_sprintf} || 
		{fmt=>qq{<a target="right2" href="$ENV{SCRIPT_NAME}/right2?SID=$SID&PWD=%s">%s</a>},
		names=>[qw(PWD PWD)]};
	my $limit =$args{limit} || '5';

	my $print = undef;

    my $fields = $ez->fields(table=>$SID);

    if ($args{NEW_PWD}){
        ### do an sql update. 
        my $row = {};  # the new values for the database
        my $update_fields = {};  # only pass the fields that we will need.
        foreach my $a (keys %args){
            if (my ($f) = $a =~/^NEW_(.*)$/){
                $row->{$f} = $args{$a};
                $update_fields->{$f} = $fields->{$f};
            }
        }

		## We also need to create a new dfile if we move from from status 0 to some thing else and the seq is blank.
		## if the seekno is set in the db but dfile does not exist, nuthing will happen, as
		## the dfile is probably in the deleted folder.
		if ( ($args{EXIST_STAT} eq '0') and ($args{NEW_STAT} ne '0') and ($row->{SEQ} eq '')){
			my $en = new TPerl::Engine;
			my $resp = $en->qt_new($SID) or $q->mydie("Could not make a new dfile:".$en->err);
			my $ufile = join '/',getConfig('TritonRoot'),$SID,'web',"u$row->{PWD}.pl";
			$en->u2resp($ufile,$resp);
			my $dfile = join '/',getConfig('TritonRoot'),$SID,'web',"D$resp->{seqno}.pl";
			$en->qt_save($dfile,$resp) or die($en->err());
			$row->{SEQ} = $resp->{seqno};
			$update_fields->{SEQ} = $fields->{SEQ};
			$print .="<BR>Dfile $row->{SEQ} created\n"
		}else{
			## Mike wants to update the dfile to reflect these changes.
			my $dfile = join '/',getConfig('TritonRoot'),$SID,'web',"D$row->{SEQ}.pl";
			if ($row->{SEQ} && -e $dfile){
				#lets update the dfile (if it exists)
				my $en = new TPerl::Engine;
				my $resp = $en->qt_read($dfile) || die $en->err();
				$resp->{status} = $row->{STAT};
				$en->qt_save($dfile,$resp) || die $en->err();
				$print .="<BR>Dfile $row->{SEQ} updated\n"
			}

			# If we set status to zero, then we clear the record in the table,
			# and move dfile to deleted.
			if ($row->{STAT} eq '0'){
				my $del_dir = join '/',getConfig('TritonRoot'),$SID,'deleted';
				die "Delete dir '$del_dir' does not exist" unless -d $del_dir;
				if (-e $dfile){
					move ($dfile,$del_dir) or die "Could not move $dfile to $del_dir";
					$print .= "<BR>Dfile to moved to trash\n";
				}
				## Mike want to only clear the SEQ.
				foreach my $f (qw(SEQ )){
					$row->{$f} = undef;
					$update_fields->{$f} ||= $fields->{$f};
				}
			}
		}
		# Additionally update the DoNotSend list if someone gets refused.
		my $dns = new TPerl::DoNotSend;
		if ($args{NEW_STAT} ==1 and $args{EXIST_EMAIL}){
			if (my $msg = $dns->add(EMail=>$args{EXIST_EMAIL},SID=>$SID,PWD=>$args{NEW_PWD})){
				$print .= "<BR>$msg";
			}else{
				$print .= "<BR>Could not add to DoNotSend list:".$dns->err;
			}
		}
		if ($args{EXIST_STAT} ==1 and $args{NEW_STAT} != 1 and $args{EXIST_EMAIL}){
			if (my $msg = $dns->remove(email=>$args{EXIST_EMAIL})){
				$print .= "<BR>$msg";
			}else{
				$print .= "<BR>Could not remove from DoNotSend list:".$dns->err;
			}
		}
		
        # $print .= $q->dumper($row);
		# now sql update or die in attempt.
        my $db_err = $ez->row_manip(fields=>$update_fields,table=>$SID,
            action=>'update',vals=>$row,keys=>['PWD']);
        if ($db_err){
            if ($db_err->{validate}){
                $print.= $q->dumper ($db_err);
            }else{
                $print.= $q->dberr(sql=>$db_err->{sql},dbh=>$dbh);
            }
        }else{
			my $ev = new TPerl::Event(dbh=>$dbh);
			# 19 is reset recipient
			$ev->I(SID=>$SID,msg=>"Status changed to $args{NEW_STAT}",who=>$ENV{REMOTE_USER},pwd=>$args{NEW_PWD},code=>19);
            $print.= "<BR>Changes made sucessfully for password '$args{NEW_PWD}'\n<BR><BR>";
        }
    }

	##### This is 'standard' lister configuration stuff.

	### modify the fields hash so that the 'pretty' batch names come up in the serch results.
	my $asp = new TPerl::ASP (dbh=>$dbh);
	my $batchlist = $asp->batch_list(SID=>$SID,table_only=>1);
	my $labs = {};
	$labs->{$_} = "$batchlist->{$_}->{TITLE} : ($_)" foreach keys %$batchlist;
	$fields->{BATCHNO}->{cgi}->{args}->{-labels} = $labs;
	$fields->{BATCHNO}->{pretty} = 'Batch';


    ### Now build the sql.  Some text fields are searched with sql wildcards (where FULLNAME like %Andrew%)
    my $sql = "select * from $SID";
	# Lets reverse the sense of this so that table extensions are likes by default.
    # my $likes = {PWD=>1,UID=>1,FULLNAME=>1,EMAIL=>1};
	my $likes = {};
	$likes->{$_} = 1 foreach keys %$fields;
	$likes->{BATCH}=0;
	$likes->{STAT}=0;

    my @wheres = ();  # parts of the where condition
    my @params = ();  # values for ? placeholders
    my $state = {SID=>$SID};
    foreach my $f (keys %$fields){
        next unless $args{$f} ne '';  # no search term, no where condition
        $state->{$f}=$args{$f};
        if ($likes->{$f} ne ''){
            push @wheres, qq{upper($f) like upper(?)};
            push @params, qq{%$args{$f}%};
        }else{
            push @wheres, qq{$f=?};
            push @params, $args{$f};
        }
    }
    # The lister function can execute a piece of code for a field.  This code draws
    # a little form for status changing in each record, if there is a seqno.
	my $stat_labels = $self->status_labels;
	my $msg = 'Any collected data will be deleted.\nThis cannot be undone\nDo you want to continue';
	my $js = qq{
		if (this.NEW_STAT.value == this.EXIST_STAT.value){
			return false;
		}
		if (this.NEW_STAT.value==0){	
			if (this.NEW_SEQ.value != ''){
				return confirm('$msg')
			}else{
				return true;
			}
		}else{
			return true;
		}
	};
    my $code_ref = sub {
        my $def = shift;
        my $pwd = shift;
		my $seq = shift;
		my $email = shift;
        my $q = new CGI ('');
		my $val = undef;
		$val = join "\n",
		$q->start_form(-action=>"$ENV{SCRIPT_NAME}/right1",-onSubmit=>$js),
		$q->popup_menu(-name=>'NEW_STAT',-values=>[0,1,2,3,4],-labels=>$stat_labels,-default=>$def),
		$q->hidden(-name=>'NEW_PWD',-default=>$pwd),
		$q->hidden(-name=>'NEW_SEQ',-default=>$seq),
		$q->hidden(-name=>'EXIST_STAT',-default=>$def),
		$q->hidden(-name=>'EXIST_EMAIL',-default=>$email),
		$q->submit(-name=>'submit',-value=>'Save');
		$val .= $q->hidden(-name=>$_,-default=>$state->{$_})."\n" foreach keys %$state;
		$val .= $q->end_form;
        return $val;
    };
    $fields->{STAT}->{code}={ref=>$code_ref,names=>[qw(STAT PWD SEQ EMAIL)]};
    $fields->{PWD}->{sprintf}=$pwd_sprintf;

	$fields->{RESEND} = {order=>10,sprintf=>{fmt=>qq{<a href="$ENV{SCRIPT_NAME}/right3?SID=$SID&PWD=%s">Resend</a>},names=>['PWD']}};

    if (@wheres){
        $sql = $sql . " where ". join (' AND ',@wheres);
    }
    my $page = $args{next} if $args{submit} =~ /next/i;
    $page = $args{previous} if $args{submit} =~ /prev/i;
    $page = $args{page} if $args{submit} =~ /go/i;


    # Dont want these fields in the form
    delete $fields->{$_} foreach qw(TS EXPIRES REMINDERS);
    # Now display the fields.
    my $lister =  $ez->lister (sql=>$sql,fields=>$fields,look=>$lf,params=>\@params,limit=>$limit,form=>1,form_hidden=>$state,page=>$page);
    if ($lister->{count}){
            $print.= "$lister->{count} Row(s)";
            $print.= join '',@{$lister->{html}};
            $print.= join '',@{$lister->{form}};
    }elsif ($lister->{err}){
            $print.= $q->dberr (sql=>$lister->{sql}, dbh=>$dbh);
    }else{
            $print.= "No Data";
    }
	# $print .= "<BR>\n$sql";
	# $print.= $q->dumper(\%args);
	# $print.= $q->dumper($batchlist);
	# $print.= $q->dumper($fields->{BATCHNO});
	# $print.= $q->dumper($fields);
	return $print;
}

sub right2 {
    #### right2 is the bottom half of the screen,
    # here we display events for a person, if they click on the password hyperlink in the
    # right1 frame above.

	my $self = shift;
	my %args = @_;
	my $dbh = $self->dbh;
	my $SID = $self->SID;
	my $lf = $self->look;
	my $q = $self->cgi;
	my $ez = new TPerl::DBEasy(dbh=>$dbh);
	my $print = undef;
	my $evlog_link = 1;
	$evlog_link = $args{evlog_link};
	my $do_head = $args{do_head};

	my $head_text = "Eventlog for password ";

    if ($args{PWD}){
        my $table = $SID.'_E';
		$head_text .="'$args{PWD}'";
        my $ev = new TPerl::Event (dbh=>$dbh);
        my $fields = $ev->fields($SID);
        delete $fields->{$_} foreach qw(BROWSER BROWSER_VER OS OS_VER YR MON MDAY HR MINS);
        my $sql = qq{select * from $table where PWD=?};
        my $state = {SID=>$SID,PWD=>$args{PWD}};
        my $page = $args{next} if $args{submit} =~ /next/i;
        $page = $args{previous} if $args{submit} =~ /prev/i;
        $page = $args{page} if $args{submit} =~ /go/i;
		$print .= qq{<p class="heading">$head_text</p>} if $do_head;
        my $lister =  $ez->lister (sql=>$sql,fields=>$fields,look=>$lf,params=>[$args{PWD}],limit=>$args{limit}||5,form=>1,form_hidden=>$state,page=>$page);
		# $print .= $q->dumper (\%args);
		# $print .= $q->dumper (\%ENV);
        if ($lister->{count}){
                $print.= join '',@{$lister->{html}};
                $print.= join '',@{$lister->{form}};
        }elsif ($lister->{err}){
                $print.= $q->dberr (sql=>$lister->{sql}, dbh=>$dbh);
        }else{
                $print.= "No Data";
				$print.= '<BR>' if $evlog_link;
        }
    }
    $print.= qq{<a target="_new" href="/cgi-adm/aspeventlog.pl?SID=$SID">Full Eventlog</a>} if $evlog_link;
	return $print;
}

sub top {
	my $self = shift;
	my $SID = $self->SID;
	my $q = $self->cgi;
    return $q->img({-align=>'bottom',-src=>"/$SID/banner.gif"}),"$SID Person Finder";
}


1;
