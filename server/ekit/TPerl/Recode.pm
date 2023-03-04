#$Id: Recode.pm,v 2.5 2005-09-13 11:01:35 triton Exp $
package TPerl::Recode;
use strict;
use TPerl::ConfigIniFiles;
use TPerl::TritonConfig;
use Carp qw (confess);
use TPerl::Error;
use Data::Dumper;
use TPerl::IniMapper;
use TPerl::Hash;
use TPerl::TSV;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;

    my %args = @_;
    $self->{SID} = $args{SID};
	confess ("SID is required param") unless $args{SID};
	$self->{ext} = $args{ini} || $args{ext} || 'extract';
	$self->{source} = $args{source} if exists $args{source};

	my $err = $args{err} || new TPerl::Error(SID=>$self->{SID});
	$self->{err_obj} = $err;
	
    return $self;
}

sub SID { my $self = shift; return $self->{SID};}
sub err { my $self = shift; return $self->{err} = $_[0] if @_; return $self->{err}; }
sub err_obj { my $self = shift; return $self->{err_obj} = $_[0] if @_; return $self->{err_obj}; }
sub source { my $self = shift; return $self->{source} = $_[0] if @_; return $self->{source}; }

=head1 SYNOPSYS

 my $rec = new TPerl::Recode (SID=>$SID);
 
 #get the inifile object from extract
 my $ini=$rec->ini();
 
 # get the columns that we are are going to extract from the datafile.
 my $columns = $rec->columns();

 # get the recode vars for each var.
 my $recodes = $rec->recodes();

 # get the new value labels (if any) You get warnings in the TPerl::Error object 
 # if two things are recoded to the same value.
 my $value_labels = $rec->new_vallabs(var=>'A21',err=>$e,vallabs=>$vallabs);

 # to find the new name of a var
 my $ini =$rec->ini;
 my $newname = $ini->val('extract',$var);

 # if you want to just recode, and have all columns preservered, 
 # have and ini file with no [extract] section
 # but supply the source file to this.
 my $rec = new TPerl::Recode(source=>'path_to_source_file');

=head1 DESCRIPTION

Recoding is the process of relabeling, reordering or removing survey data from 
a dataset.  It is also the place where the +code=A info from the text file is stored.

=cut

sub ext { 
	my $self = shift; return $self->{ext} = $_[0] if @_ ;
	$self->err ("ext() specifies an ini file to use") unless $self->{ext};
	return $self->{ext};
}

sub ini {
	my $self = shift;
	if ($self->{ini}){
		return $self->{ini};
	}else{
		my $ext = $self->ext() or return undef;
		my $eext = $ext;
		$eext =~ s/^_//;
		my $SID = $self->SID() or return undef;
		my $troot = getConfig('TritonRoot');
		my $fn = join '/',$troot,$SID,'config',"$eext.ini";
		unless (-e $fn){
			$self->err("Inifile '$fn' does not exist");
			return undef;
		}
		if (my $ini= new TPerl::ConfigIniFiles (-file=>$fn)){
			$self->{ini} = $ini;
			return $ini;
		}else{
			$self->err("Could not parse ini file $fn\n".join "\n",@Config::IniFiles::Error);
			#using it twice turns of the warning if -w is on...
			$self->err("Could not parse ini file $fn\n".join "\n",@Config::IniFiles::Error);
			return undef;
		}
	}
}

sub columns {
	my $self = shift;
	my $ini = $self->ini or return undef;

	return $self->{columns} if $self->{columns};
	my @columns=();

	if ($ini->SectionExists('extract')){
		my $err=$self->err_obj;
		my $repeats = {};
		tie %$repeats,'TPerl::Hash';
		foreach my $e ($ini->Parameters('extract')){
			next if $e =~ /^\s*!/;
			if ($repeats->{$e}){
				if ($repeats->{$e}==1){
					# This picks up different case duplication
					$err->W("Key $e has duplicated case in [extract] using first occurance");
				}
			}else{
				push @columns ,$e ;
			}
			$repeats->{$e}++;
		}
	}else{
		# if there is no [extract] section lets do all the headers from the src file.
		if (my $sfn = $self->source){
			unless (-e $sfn){
				$self->err("Could not get columns: $sfn does not exist");
				return undef;
			}
			my $tsv = new TPerl::TSV(file=>$sfn);
			my $head = $tsv->header;
			unless ($head){
				$self->err($tsv->err);
				return undef;
			}
			push @columns,$_ foreach @$head;
		}else{
			$self->err("Could not get columns:[extract] section does not exist,no source filename supplied ");
			return undef;
		}
		# Then lets add in any of [calcs] too.
		if ($ini->SectionExists('calcs')){
			foreach my $e ($ini->Parameters('calcs')){
				push @columns,$e;
			}
		}
	}
	unless (@columns){
		$self->err("Found no columns to extract.  Nothing to do");
		return undef;
	}
	$self->{columns}=\@columns;
	return \@columns;
}

sub renames {
	my $self=shift;
	my $ini=$self->ini or return undef;
	my $cols=$self->columns;
	my %renames = ();
	tie %renames, 'TPerl::Hash';
	my $e = $self->err_obj;
	foreach my $c (@$cols){
		my @vals = $ini->val('extract',$c);
		if (@vals>1){
			# This pick up same case duplication.
			$e->W("Duplicate key $c [extract]. Using first val:$vals[0]");
		}
		$vals[0] =~ s/^\s*(.*?)\s*$/$1/;
		$renames{$c}=$vals[0] || $c;
	}
	return \%renames;
}

sub recodes {
	my $self = shift;
	my $ini = $self->ini or return undef;

	return $self->{recodes} if  $self->{recodes};
	my $recodes = {};
	tie (%$recodes, 'TPerl::Hash');
    foreach my $col ($ini->Parameters('recode')){
        if (my @recs = $ini->val('recode',$col)){
            next unless defined $recs[0];
            my $lu = $recodes->{$col} || {};
            foreach my $r (@recs){
                my ($key,$val) = split /,/,$r;
                $key=~ s/^\s*(.*?)\s*$/$1/;
                $val=~ s/^\s*(.*?)\s*$/$1/;
                $lu->{$key}=$val;
            }
            $recodes->{$col}=$lu;
        }
    }
	$self->{recodes} = $recodes;
	return $recodes;
}

sub calcs {
	my $self=shift;

	return $self->{calcs} if $self->{calcs};

	my %args = @_;
	my $vars = $args{vars} || [];

	my $ini = $self->ini or return undef;
	my $calcs = {};
	tie %$calcs, 'TPerl::Hash';
	my $cols = $self->columns;
	my $e = $self->err_obj();
	my $im = new TPerl::IniMapper;
	my @allowed=();
	push @allowed,$_ foreach @$cols;
	push @allowed,uc($_) foreach @$vars;
	my $map_errors = {};
	my $order = 0;
	if ($ini->SectionExists('calcs')){
    	foreach my $n ($ini->Parameters('calcs')){
			my @vals = $ini->val('calcs',$n);
			if (@vals>1){
				$e->W("Duplicated column $n in [calcs]. Using first entry.");
			}
			my $v = $vals[0];
			if (my $f = $im->mapping2field(mapping=>$v,name=>$n,headings=>\@allowed)){
				$f->{order} = ++$order;
				$calcs->{$n} = $f;
				push @allowed,$n;
			}else{
				$map_errors->{$n} = $im->err;
			}
		}
		if (%$map_errors){
			$self->err("[calcs] has some problems:".join ("\n",map "$_=:$map_errors->{$_}",keys %$map_errors));
			return undef;
		}
	}
	$self->{calcs} = $calcs;
	return $calcs;
}

sub ini_vallabs {
	# Gets the value labels from the [values] section of the ini file.
	my $self = shift;
	my $ini = $self->ini or return undef;
	my $columns = $self->columns or return undef;
	my $ini_vallabs = {};
	foreach my $col (@$columns){
        if (my @recs = $ini->val('values',$col)){
            my $lu = {};
            foreach my $r (@recs){
                my ($key,$val) = split /,/,$r;
                $key=~ s/^\s*(.*?)\s*$/$1/;
                $val=~ s/^\s*(.*?)\s*$/$1/;
                $lu->{$key}=$val if $key ne '';
            }
            $ini_vallabs->{$col} = $lu if %$lu;
        }
    }
	return $ini_vallabs;
}

sub new_vallabs {
	my $self = shift;
	my %args = @_;
	my $e = $args{err} || new TPerl::Error;
	my $col = $args{col};
	my $vallabs = $args{vallabs} || {};
	my $warned_clash = $args{warn};
	my $recodes = $self->recodes or return undef;
	if (my $rec = $recodes->{$col}){
		my $h = {};
		$vallabs = {} unless ($vallabs);
		foreach my $ov (keys %$vallabs){
			my $nv = $ov;
			$nv = $rec->{$ov} if exists $rec->{$ov};
			if ($h->{$nv}){
				my $ini = $self->ini or return undef;
				my $new_var = $ini->val('extract',$col) || $col;
				$e->E("In col $col ($new_var) cannot assign code $nv to $vallabs->{$ov} it already means '$h->{$nv}'")
					unless $warned_clash->{"$col-$nv"};
				$warned_clash->{"$col-$nv"}++;
			}else{
				$h->{$nv} = $vallabs->{$ov};
			}
		}
		$vallabs=$h;
	}
	return $vallabs;
}

1;
