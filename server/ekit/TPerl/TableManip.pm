package TPerl::TableManip;

use strict;
use Carp qw (confess);
use Data::Dumper;
use FileHandle;

use TPerl::DBEasy;
use TPerl::MyDB;

# use vars qw (@ISA @EXPORT);
# use Exporter;
# @TPerl::TableManip::ISA = qw(Exporter);
# @EXPORT=qw(shell);
# sub shell {
# 	my $self = shift;
# 	print "Here ".Dumper $self;
# }

=head1 SYNOPSIS

This is the base for creating modules for database tables.  See TPerl::MAP
TPerl::UploadData.  This supplies some usefule functions for you, like new()
dbh() table_manip() dump_filename() etc which also work as class functions, as
well as member functions.

You can copy scripts/map_tables.pl and make a file that does that.

Alternatley you can dump drop create read tables from the command line with

 perl -MTPerl::DoNotSend -e 'TPerl::DoNotSend->tables2file()'
 perl -MTPerl::DoNotSend -e 'print join "\n",TPerl::DoNotSend->table_manip(drop_all=>1)'
 perl -MTPerl::DoNotSend -e 'print join "\n",TPerl::DoNotSend->table_manip()'
 perl -MTPerl::DoNotSend -e 'TPerl::DoNotSend->file2tables(print_sql=>1)'


=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
	my %args = @_;
    bless $self,$class;
	if ($args{dbh}){
		$self->{dbh} = $args{dbh};
	}else{
		# confess "dbh is required param" unless $args{dbh};
		$self->{dbh} = $self->dbh(%args);
	}
    return $self;
}

sub dbh {
	my $self = shift;
	return $self->{dbh} if ref($self) && $self->{dbh};
	return dbh TPerl::MyDB(@_) or confess ("Could not create a dbh".TPerl::MyDB->err);
}


sub table_create_list {
	my $self = shift;
	my $class  =ref $self || $self;
	confess "Your class ($class) needs to define a table_create_list method that returns a reference to list of tables in creation order";
}

sub table_sql {
	my $self = shift;
	my $class  =ref $self || $self;
	my $table = shift;
	confess "method table_sql('$table') of Class $class needs to return some SQL for creating the table";
}

sub table_manip {
	# This is a 'modernisation' of do_tables.  it returns something on sucess
	# and uses the err function on failure (instead of return undef on sucess, and the error on failure)
	# Also, does not confess, or print the sql.  returns a ref to list of sqls as the sucess value.
	my $self = shift;
	my %args = @_;
    my $dbh = $self->dbh;
    my $make = $args{create} || [];
    my $drop = $args{drop} || [];
	my $drop_all = $args{drop_all};
	unless (%args){
		$make = $self->table_create_list;
	}
	if ($drop_all){
		$drop = $self->table_create_list;
	}
	my $fh = $args{fh};
	unless ( ref $dbh eq 'DBI::db'){
    	$self->err ("database handle '$dbh' is not a DBI::db");
		return undef;
	}
    my @tables =  $dbh->tables;
	#s/^[`'"](.*?)[`'"]$/$1/ foreach @tables;   #Not sure if it should be 1 or $1 here so going with latest from server but keeping this if head is wrong.
	s/^[`'"].*?[`'"]\.// foreach @tables;		# Get rid of database name
	s/^[`'"](.*?)[`'"]$/\1/ foreach @tables;
	# die Dumper \@tables;
	if (my $er = $dbh->errstr){
		$self->err("Could not get table list:$er");
		return undef;
	}
    my @sql = ();
    foreach my $dr (@$drop){
        unshift @sql,"DROP TABLE $dr" if grep /^$dr$/i,@tables;
    }
    foreach my $mk (@$make){
        my $sql = $self->table_sql($mk);
		unless ($sql){
			$self->err("no sql for table '$mk'");
			return undef;
		}
        if (grep /^$mk$/i,@tables){
            push @sql ,$sql if grep /^$mk$/i,@$drop;
        }else{
            push @sql ,$sql;
        }
    }
	my $ret = [];
    foreach my $sql (@sql){
        push @$ret, "doing $sql\n";
        unless ($dbh->do($sql)){
			$self->err({err=>$dbh->errstr,sql=>$sql});
			return undef;
		}
    }
	return wantarray ? @$ret : $ret;
}


sub do_tables {
### Try to use the table_manip version that does more, does not print stuff out, and uses the err etc.
	my $self = shift;
    my %args = @_;
    my $dbh = $self->dbh;
    my $make = $args{create} || [];
    my $drop = $args{drop} || [];
	unless (%args){
		$make = $self->table_create_list;
	}
#print "Dropping these tables...\n";
#print Dumper \$drop;
	my $fh = $args{fh};
    confess "database handle '$dbh' is not a DBI::db" unless ref $dbh eq 'DBI::db';
    my @tables =  $dbh->tables ;
	#s/^[`'"](.*?)[`'"]$/$1/ foreach @tables;  #conflict from server head, marking server head resolved but keeping this in for posterity
	# die Dumper \@tables;
	s/^[`'"].*?[`'"]\.// foreach @tables;		# Get rid of database name
	s/^[`'"](.*?)[`'"]$/\1/ foreach @tables;	# Strip off quotes on table names
#	 print Dumper \@tables;
    return "Could not get table list:".$dbh->errstr if $dbh->errstr;
    my @sql = ();
    foreach my $dr (@$drop){
#print "? $dr\n";
        unshift @sql,"DROP TABLE $dr" if grep /^$dr$/i,@tables;
    }
#print "sql=\n";
#print Dumper \@sql;
    foreach my $mk (@$make){
        my $sql = $self->table_sql($mk) or return "no sql for table '$mk'";
        if (grep /^$mk$/,@tables){
            push @sql ,$sql if grep /^$mk$/i,@$drop;
        }else{
            push @sql ,$sql;
        }
    }
    foreach my $sql (@sql){
        print "doing $sql\n";
        $dbh->do($sql) or return Dumper {err=>$dbh->errstr,sql=>$sql};
        return {err=>$dbh->errstr,sql=>$sql} if $dbh->errstr;
    }
}

# This puts a whole lot of SQL statements into a fh.
sub tables2file {
    my $self = shift;
    my %args = @_;
    my $fh = $args{fh} || $self->dump_fh(write=>1);
	return $self->err("No fh supplied") unless $fh;
    my $dbh = $args{dbh} || $self->dbh;
	my $tables = $args{tables} || [];
    my $ez = $self->ez;
	$tables = $self->table_create_list() unless @$tables;
    foreach  (@$tables){
        my $err = $ez->table2file(dbh=>$dbh,fh=>$fh,table=>$_);
        return $err if $err;
    }
    return undef;
}

# This does a whole lot of sql statements from a filehandle.
sub file2tables {
	my $self = shift;
	my %args = @_;
	my $fh = $args{fh} || $self->dump_fh;
	my $dbh = $args{dbh} || $self->dbh;
	my $print_sql = $args{print_sql};
	my $tables = $args{tables} || [];
	$tables =  $self->table_create_list() unless @$tables;

	return $self->err("No fh supplied") unless $fh;

	my @errors = ();
	while (<$fh>){
		chomp;
		print "$_\n" if $print_sql;
		unless ($dbh->do ($_)){
			$self->err(sql=>$_,err=>$dbh->errstr);
			push @errors,{sql=>$_,err=>$dbh->errstr};
		}
	}
	return (wantarray ? @errors : \@errors) if @errors;
	return undef;
}

sub dump_filename {
	my $self = shift;
	my $class = ref($self) || $self;
	$class =~ s/://g;
	return "dump_$class.sql"
}

sub dump_fh {
	my $self = shift;
	my $fn = $self->dump_filename;
	my %args = @_;
	my $write = $args{write};
	
	my $mod = '> ' if $write;
	my $fh = new FileHandle ("$mod$fn");
	unless ($fh){
		$self->err("Could not create '$fh':$!");
		return undef;
	}
	return $fh;
}


# Lets make this 'confess' if its called without blessing.
# which is better than 
#    Can't use string ("TPerl::DoNotSend") as a HASH ref while "strict refs" in use at TPerl/TableManip.pm line 199.
# Also means you can 

sub err {
    my $self = shift;
	my $err = $_[0];
	if (ref ($self)){
		return $self->{err} = $err if @_;
		return $self->{err};
	}elsif ($err){
		my $msg = $err;
		if (ref($err) eq 'HASH'){
			$err->{dbh} = $err->{dbh->errstr} if ref ($err->{dbh});
			$msg = join "\n",map "$_:$err->{$_}",keys %$err;
		}elsif (ref($err) eq 'ARRAY'){
			$msg = join "\n",@$err;
		}
		confess $msg;
	}else{
		# Do nuthing.  sometimes we call err with '' just to reset it.
		# in TPerl::DoNotSend->exists() for instance.
	}
}

# Sets up a TPerl::DBEeasy for use.
sub ez {
	my $self=shift;
	return $self->{_ez} if ref ($self) && defined ($self->{_ez});
	my $dbh = $self->dbh;
	return undef unless $dbh;
	my $ez = new TPerl::DBEasy(dbh=>$dbh);
	if (ref($self)){
		$self->{_ez} = $ez;
		return $self->{_ez};
	}else{
		return $ez;
	}
}


1;

