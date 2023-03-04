package TPerl::TransactionList::Item;
#$Id: TransactionList.pm,v 1.9 2007-06-13 05:57:32 triton Exp $
use strict;
use Data::Dumper;
use File::Copy;
use File::Temp;
use TPerl::Error;
use Carp qw/confess/;

=head1 SYNOPSIS

Suppose you've got a dfile and a ufile and a tsv file to edit and an sql update to make.
you want to use a transaction approach, and be able to roll back things, if anything goes wrong.

 my $trl = new TPerl::TransactionList();

 # do the dfile.
 my $new_ufile = $qt->u_edit_to_temp(file=>$ufile,chages=>{email=>'new@email.address'});
 $trl->push_item(
   pretty=>'Updating a ufile',
   orig=>$ufile,
   new=>$new_ufile,
   err=>($new_ufile ? '' : $qt->err()),
 );
 
 # dfile
 my $new_dfile = $qt->qt_edit_to_temp(file=>$dfile,chnages=>{status=>1});
 $trl->push_item (
  pretty=>"Set status in $dfile",
  orig=>$dfile,
  new=>$new_dfile,
  err=>($new_dfile ? '' : $qt->err),
 );

 #tsv editing
 my $new_tsv = $tsv->edit_to_temp(....see the docs.);
 $trl->push_item (
  pretty=>'Did something funky to incoming file...',
  orig=>$tsv_fn,
  new=>$new_tsv,
  err=>($new_tsv ? '' : $tsv->err),
 );

 #sql update
 $trl->push_item(
  pretty=>'Seeting the status of goose to 1',
  sql=>'update XXX set where ?',
  params=>[1233],
  dbh=>$dbh,
 );

 # now attempt to do every thing.  You might say everything has been done
 # already, but its all about being defensive, and not making any assumptions
 $dbh->begin_work;
 $trl->dbh_do;
 $trl->commit_files;
 if (my $errs = $trl->errs()){
 	# this puts the dbh rollback status into each item.
 	$trl->dbh_rollback_messages($dbh->rollback);
	$trl->rollback_files;
	my $probs = $trl->msg_summary(list=>$errs);
	my $rb_summary = $trl->msg_summary(rollback=>1);
	#There is also stuff in $_->rollback_msg foreach @{$trl->list};
	if (my $rb_errs = $trl->rollback_errs()){
		die "Problems occured\n$probs\nAlso probs while rolling back\n$$rb_summary";
	}else{
		die "Problems occured\n"$probs\n Everything was roleld back OK though\n$rb_summary";
	}
 }else{
 	$dbh->commit;
	print "Everything went swimmingly\n";
	print join "\n",map $_->pretty,@{$trl->list};

 }

=cut


sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;
    my %args = @_;
    my $init_funcs = [qw(edit dbh orig sql params pretty err create)];
	foreach my $f  (@$init_funcs){
		$self->$f($args{$f}) if exists $args{$f};
	}
	# print Dumper $self;
    return $self;
}

sub err { my $self = shift;$self->{err}=$_[0] if @_;return $self->{err}; }
sub rollback_err { my $self = shift;$self->{rollback_err}=$_[0] if @_;return $self->{rollback_err}; }
sub rollback_msg { my $self = shift;$self->{rollback_msg}=$_[0] if @_;return $self->{rollback_msg}; }
sub pretty { my $self = shift;$self->{pretty}=$_[0] if @_;return $self->{pretty}; }

## dbhy  things,
sub dbh { my $self = shift;$self->{dbh}=$_[0] if @_;return $self->{dbh}; }
sub sql { my $self = shift;$self->{sql}=$_[0] if @_;return $self->{sql}; }
sub params { my $self = shift;$self->{params}=$_[0] if @_;return $self->{params}; }

##Filey things
sub orig { my $self = shift;$self->{orig}=$_[0] if @_;return $self->{orig}; }
sub edit { my $self = shift;$self->{edit}=$_[0] if @_;return $self->{edit}; }
sub back { my $self = shift;$self->{back}=$_[0] if @_;return $self->{back}; }
sub moved { my $self = shift;$self->{moved}=$_[0] if @_;return $self->{moved}; }
sub create { my $self = shift;$self->{create}=$_[0] if @_;return $self->{create}; }

sub dbh_do {
	my $self = shift;
	my $sql=$self->sql;
	return 1 unless $sql;
	my $dbh=$self->dbh || confess ("No dbh supplied");
	my $p = $self->params;
	if (my $rc = $dbh->do($sql,{},@$p)){
		# print "$sql @$p\n";
		return $rc;
	}else{
		$self->err({sql=>$sql,params=>$p,errstr=>$dbh->errstr});
		return undef;
	}
}

sub commit_file {
	my $self = shift;
	return 1 if $self->sql;
	my $o = $self->orig;
	my $n = $self->edit;
	my $create = $self->create;
	return undef if $self->err;
	unless ($o){
		$self->err("Cannot commit file without 'orig' being set");
		return undef;
	}
	unless ($n){
		$self->err("Cannot commit file without 'edit' being set");
		return undef;
	}
	if ((!-e $o) and !$create){
		$self->err("orig file '$o' does not exist");
		return undef;
	}
	unless (-e $n){
		$self->err("edited file '$n' does not exist");
		return undef;
	}
	my $tmp = new File::Temp(UNLINK=>0);
	my $b = $tmp->filename;
	if (-e $o){
		if (copy ($o,$b)){   # COpy to a File::Temp seems to break on pho.
			$self->back($b);
		}else{
			$self->err("Could not copy orig '$o' to temp '$b':$!");
			return undef;
		}
	}
	if (move ($n,$o)){
		print "Moved $n to $o\n";
		$self->moved(1);
		return 1;
	}else{
		$self->err("Could not move edited '$n' to orig '$o':$!");
		return undef;
	}
}
sub rollback_file {
    my $self = shift;
    my $b    = $self->back;
    my $o    = $self->orig;
    if ( $self->moved ) {
        if ($b) {
            if ( move( $b, $o ) ) {
                $self->rollback_msg(
                    "Successfully rolled backup '$b' to orignal '$o'");

            } else {
                $self->rollback_err(
                    "Could not rollback backup '$b' to original '$o'");
            }
        } else {
            if ( unlink($o) ) {
                $self->rollback_msg("Original file '$o' deleted");
            } else {
                $self->rollback_err(
                    "Original file '$o' could not be deleted:$!");
            }
        }
    } else {
        $self->rollback_msg(" Original file was never moved ");
    }
}

package TPerl::TransactionList;
use strict;
use File::Copy;
use File::Temp;



sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;
    my %args = @_;
    $self->{dbh} = $args{dbh};
    $self->{look} = $args{look};
    $self->{cgi} = $args{cgi};
	$self->{list} = [];
    return $self;
}

#sub err { my $self = shift;$self->{err}=$_[0] if @_;return $self->{err}; }
sub dbh { my $self = shift;return $self->{dbh}; }

sub errs{
	my $self = shift;
	my $list = $self->list;
	my @errs = grep $_->err() ,@$list;
	return \@errs if @errs;
	return undef;
}

sub rollback_errs {
	my $self = shift;
	my $list = $self->list;
	my @errs = grep $_->rollback_err(),@$list;
	return \@errs if @errs;
	return undef;
}

sub list {
	my $self =  shift;
	return $self->{list};
}

sub dbh_do {
	my $self = shift;
	my $list = $self->list;
	foreach my $i (@$list){
		return undef unless $i->dbh_do;
	}
	return 1
}

sub rollback_files{
	my $self = shift;
	my $list = $self->list;
	$_->rollback_file foreach @$list;
}	

sub commit_files {
	my $self = shift;
	my $list = $self->list;
	foreach my $i (@$list){
		last unless $i->commit_file;
	}
}

sub push {
	my $self = shift;
	my @new =  @_;
	my $list = $self->list;
	push @$list,@new;
}

sub item {
	my $self = shift;
	my %args = @_;
	$args{dbh} ||= $self->dbh if ($args{sql});
	return new TPerl::TransactionList::Item(%args);
}

sub push_item {
	my $self = shift;
	my $item = $self->item(@_);
	$self->push($item);
}

sub dbh_rollback_messages {
	# Puts the status of the dbh->rollback into each item.
	# called like $self->dbh_rollback_message($dbh->rollback());
	my $self = shift;
	my $dbh_rollback_rc = shift;
	my $list = $self->list;
	foreach my $i (@$list){
		next unless $i->sql;
		if ($dbh_rollback_rc){
			$i->rollback_msg("Succesfully rolled back ".$i->pretty);
		}else{
			$i->rollback_err("Could not rollback ".$i->pretty);
		}
	}
}

sub msg_summary {
	my $self = shift;
	my %args = @_;
	my $join = $args{join} || "\n";
	my $list = $args{list} || $self->list;
	my $rollback=$args{rollback};

	return join $join,map ($_->pretty().' : '.(fmterr TPerl::Error($_->rollback_err()) || $_->rollback_msg()),@$list) if $rollback;
	return join $join,map (($_->pretty().' : '.fmterr TPerl::Error ($_->err())),@$list);
}


1;
