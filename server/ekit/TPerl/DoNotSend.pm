package TPerl::DoNotSend;
#$Id: DoNotSend.pm,v 1.8 2007-02-23 00:10:11 triton Exp $
use strict;
use TPerl::TableManip;
use Email::Valid;
use TPerl::Engine;
use TPerl::Hash;
use TPerl::TransactionList;
use Carp qw(confess);
use Data::Dumper;

=head1 SYNOPSIS

You can set this up from the command line with
 
 perl -MTPerl::DoNotSend -e 'print join "\n",TPerl::DoNotSend->table_manip()'

Then you can use it like this

 use TPerl::DoNotSend;
 my $dns = new TPerl::DoNotSend;
 # Add an email address
 $dns->add(email=>'Blatent@wrong') || die $dns->err;

 #check if someone is in the thing
 if (my $rec = $dns->exists(email=>'ac@market-research.com')){
  print "adderess added on $rec->{INSERT_EPOCH} by job $rec->{SID} with $rec->{PWD}"
 }else{
  die "Error occoured".$dns->err;
  print "address not in DoNotSend system"
 }

 #remove from system
 my $remove_message = $dns->remove(email=>'goose@goose.com');
 die "Could not remove:".$dns->err unless $remove_message

 my $add_message = $dns->add('goose@goose.com');
 die "Could not add".$dns->err unless $add_message;
 
=cut

our @ISA;
@ISA = qw /TPerl::TableManip/;

sub table_create_list {
    return [qw(DONOTSEND)]
}

sub table_sql {
    my $self = shift;
    my $table = shift;
    my $sqls = {
        DONOTSEND=>q{
            CREATE TABLE DONOTSEND(
                DNS_ID          INTEGER         NOT NULL,
                EMAIL           VARCHAR(100)    NOT NULL UNIQUE,
                SID             VARCHAR(12),
                PWD             VARCHAR(12),
                INSERT_EPOCH    INTEGER         NOT NULL,
                PRIMARY KEY     (DNS_ID))
        },
    };
    my $sql = $sqls->{$table};
    $sql =~ s/#.*//;
    return $sql;
}

sub DONOTSEND_fields {
	my $self = shift;
	my $dbh = $self->dbh;
	my $ez = $self->ez;
	my $en = new TPerl::Engine;
	my $fields = $ez->fields(table=>'DONOTSEND');
	$fields->{DNS_ID}->{cgi}->{func} = 'hidden';
	$fields->{SID}->{cgi} ={
		func=>'popup_menu',
		args=>{-values=>$en->SID_list(add_blank=>1)}
	};
	return $fields;
}

sub add {
	# This is the Basic DONOTSEND table manipulation. use unsubscribe for a
	# more 'complete' version
    my $self = shift;
	my %args = ();
	tie %args, 'TPerl::Hash';
	if (@_ ==1){
		$args{email} = $_[0];
	}else{
    	%args = @_;
	}
	# use Data::Dumper; die Dumper \%args;
    my $dbh = $self->dbh;


    my $email = $args{email};
    my $cleaned_email = $self->clean(%args) || return undef;
    
    if ($self->exists(%args)){
        return "'$email' already in Do Not Send list" if $email eq $cleaned_email;
        return "'$cleaned_email'($email) already in Do Not Send list";
    }else{
        # Do an insert
        my $err = $self->ez->row_manip(action=>'insert',table=>'DONOTSEND',keys=>['DNS_ID'],
            vals=>{SID=>$args{SID},PWD=>$args{PWD},INSERT_EPOCH=>'now',EMAIL=>$cleaned_email});
        $self->err('');
        ($self->err($err) && return undef) if $err;
        return "'$cleaned_email'($email) added to Not Send list" if $email ne $cleaned_email;
        return "'$email' added to Do Not Send list";
    }
}

sub unsubscribe {
	# Sort of an wrapper to add.  A SID, pwd, troot  are complusory, email is
	# optional looks up the survey job, gets the email, creates a dfile if
	# necessary, does the add, sets the status, does an event....
	# copied from escheme_responder and the pfinder...
	
	my $self = shift;
	my %args = @_;
	my $SID = delete $args{SID};
	my $pwd = delete $args{pwd};
	my $email = delete $args{email};
	my $troot = delete $args{troot};

	confess "no 'SID' supplied" unless $SID;
	confess "no 'pwd' supplied" unless $pwd;
	confess "no 'troot' supplied" unless $troot;
	confess "Unrecognised args:".Dumper(\%args) if keys %args;

	my $sql = "select * from $SID where PWD = ?";

	my @messages = ();
	my $ret = {};

	my $dbh = $self->dbh;
	unless ($dbh){
		$self->err("No dbh available");
		return undef;
	}
	if (my $r = $dbh->selectrow_hashref($sql,{},$pwd)){
		my $en = new TPerl::Engine;
		my $fn = '';
		my $seq = '';
		$ret->{job_record}=$r;
		$email ||= $r->{EMAIL};
		if ($seq = $r->{SEQ}){
			$fn = join '/',$troot,$SID,'web',"D$seq.pl";
			unless (-e $fn){
				push @messages,"Database seq dfile '$fn' does not exist";
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
					push @messages,"Created '$fn' for pwd $pwd id $r->{UID}";
				}else{
					push @messages,"Could not save '$fn':".$en->err;
					$fn = '';
				}
			}else{
				push @messages,"Could not make new resp hash".$en->err();
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
					push @messages,"These problems occured:\n$probs\n Additional probs while rolling back:\n$rb_stat";
				}else{
					push @messages,"These problems occured:\n$probs\n but everything was rolled back OK:\n$rb_stat";
				}
			}else{
				push @messages,map $_->pretty. ' : '. $_->err,@{$trl->list};
				$dbh->commit;
			}
		}else{
			push @messages,"No dfile editing was done";
		}
	}else{
		push @messages,"DataBaseError:$_" if $_ = $dbh->errstr;
		push @messages,"No $SID database record for pwd $pwd";
	}
	if ($email){
		if (my $add_message = $self->add(email=>$email,pwd=>$pwd,SID=>$SID)){
			push @messages,$add_message;
		}else{
			return undef;
		}
	}else{
		push @messages,"No email address for '$pwd' in $SID";
	}
	$ret->{messages} = \@messages;
	return $ret;
}

sub clean {
    my $self = shift;
	my %args = ();
	# print Dumper \%args;
	tie %args, 'TPerl::Hash';
	if (@_ ==1){
		$args{email} = $_[0];
	}else{
    	%args = @_;
	}
    my $email = $args{email};
    ($self->err("No email supplied") && return undef) unless $email;
    my $cleaned_email = Email::Valid->address($email);
    ($self->err("'$email' is not valid") && return undef) unless $cleaned_email;
    return lc($cleaned_email);
    # return $cleaned_email;
}

sub exists {
    my $self = shift;
    my $email = $self->clean(@_) || return undef;
    my $sql = 'select * from DONOTSEND where UPPER(EMAIL) = UPPER(?)';
    my $dbh = $self->dbh;
    if (my $res = $dbh->selectrow_hashref($sql,{},$email)){
        $self->err(''); # res is undef if there are mo rows.
        return $res;
    }else{
        $self->err({sql=>$sql,dbh=>$dbh,errstr=>$dbh->errstr}) if $dbh->errstr;
        return undef;
    }
}

sub remove {
    my $self = shift;
	my %args = ();
	tie %args,'TPerl::Hash';
	if (@_ ==1){
		$args{email} = $_[0];
	}else{
    	%args = @_;
	}
    my $email = $args{email};
    $self->err('');
    if (my $row = $self->exists(@_)){
        my $sql = 'delete from DONOTSEND where UPPER(EMAIL) = UPPER(?)';
        my $dbh = $self->dbh;
        if ($dbh->do($sql,{},$row->{EMAIL})){
            return "'$row->{EMAIL}($email) removed from Do Not Send list" if $email ne $row->{EMAIL};
            return "'$email' removed from Do Not Send list";
        }else{
            $self->err({sql=>$sql,dbh=>$dbh,params=>[$row->{EMAIL}]});
            return undef;
        }
    }else{
        return undef if $self->err();
        return "$email was not in Do Not Send list";
    }
}

1;
