#Copyright 2002 Triton Technology
#$Id: Dump.pm,v 1.12 2004-05-10 02:54:00 triton Exp $
package TPerl::Dump;
use strict;
use Data::Dump qw(dump);
use File::Slurp;
use LockFile::Simple;
use Carp;
use FileHandle;

use vars qw ($AUTOLOAD);

=head1 SYNOPSIS

If you want to read and eval a perl structure in some file, your are in the right
namespace.  If you want to lock the file, so you can modify the structure
before you write it back, then you are still in the right place.

 use strict;
 use TPerl::Dump;
 use Data::Dumper;

 # read only file content.
 if (my $content = getro TPerl::Dump ('some file')){
 	#sucess
 }else{
 	print "eval error $@, fs error $!";
 }
 
 my $dump = new TPerl::Dump (file=>'perldata.txt',touch=>1);
 die "new err:$_" if $_ = $dump->err;
 
 ###Change the config of the lock_mgr 
 # see LockFile::Simple man page.

 # lock files older than 20 seconds are stale??
 $dump->lock_mgr->configure(-hold=>20);

 # if you are not going to write it back use getro
 my $thing = $dump->getro;
 
 # read the file content into a variable.
 # lock it so no one else can write in the mean time.
 my $thing = $dump->getnlock();
 
 if ($dump->err){
     print "err ".$dump->err ."\n";
 }else{
     $thing->{goose} = "me";
     print 'thing '. Dumper $thing;
     $dump->putnunlock($thing);
     die "unlock error $_" if $_ = $dump->err;
 }

=head1 DESCRIPTION

Uses LockFile::Simple which uses lockfiles, and is available on avtive state to lock files

If you want to lock more than one file, use more than of these objects.

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	my $file = $args{file};
	confess "file is a required arg" unless $file;
	$self->file($file);
	if ($args{touch}){
		unless (-e $file){
			my $thing=undef;
			$thing = dump $args{touch} if ref $args{touch};
			unless (write_file $file, $thing){
				$self->err ("Could not touch file '$file':$!");
				return $self;
			}
		}
	}
	my $lock_args = $args{lock_init} || {-max=>10,-delay=>1} ;
	my $lmgr =make LockFile::Simple (%$lock_args);
	$self->lock_mgr ($lmgr);
	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	my $class = ref($self);
	$name =~ s/.*://;
	if (grep ($name eq $_,qw(lock_mgr lock file err))){
		return return $self->{$name} = $_[0] if @_;return $self->{$name};
	}else{
		croak "Can't access method '$name' of class '$class'";
	}
}

sub getro {
	my $self = shift;
	my $file = shift;
	if (-e $file){
		my $res = eval read_file $file;
		if ($@){
			# warn "eval failure of '$file':\n$@";
			return undef;
		}else{
			return $res;
		}
	}else{
		$@="File '$file' does not exist";
		return undef;
	}
}

sub justput {
	# just as you can readro without caring about locking, so
	# you can just write. who cares about locking.
	my $self = shift;
	my $file = shift;
	my $thing = shift;
	return write_file $file, dump $thing;
}

sub getnlock {
	my $self = shift;
	my $file = $self->file;

	my %args = @_;
	my $do_get=1;
	$do_get = $args{get} if defined $args{get};
	
	if (-e $file){
		if ($self->lock($self->lock_mgr->lock($file))){
			if ($do_get){
				my $thing = eval read_file $file;
				if ($@){
					$self->err("Eval error in '$file':$@$!'");
					$self->lock->release;
					return undef;

				}else{
					return $thing;
				}
			}else{
				return undef;
			}
		}else{
			my $end = " (respect lockfiles younger than ".
				$self->lock_mgr->hold()." secs)" if -e "$file.lock";
			$self->err("Could not lock '$file'$end");
			return undef;
		}
	}else{
		$self->err("File '$file' does not exist");
		return undef;
	}
}
sub putnunlock {
	my $self = shift;
	my $thing = shift;

	my $file = $self->file;
	if (my $lock = $self->lock){
		if ( -w $file){
			write_file $file, dump $thing;
			$lock->release;
		}else{
			$self->err("Cannot write to file '$file'");
		}
	}else{
		my $lf = $self->lock_mgr->lockfile($file);
		my $cont = read_file ($lf) if -e $lf;
		$self->err ("lockfile '$lf' for file '$file' exists with content '$cont'");
		return undef;
	}
}
sub locked {
	my $self = shift;

	my $file = $self->file;
	return -e "$file.lock"
}
sub save_dfile {
	my $self = shift;
	my $fn = shift;
	my $resp = shift;
	return "No File sent" unless $fn;
	my $type = ref $resp;
	return "Second param must be a hash ref not $type" unless $type eq 'HASH';
	my $fh = new FileHandle ("> $fn") or return "Could not open ufile $fn:$!";
	printf $fh "# file made %s\n",scalar(localtime);
	my $dumped = dump ($resp);
	$dumped =~ s/^\s*{/(/;
	$dumped =~ s/}\s*$/)/;
	print $fh "%resp=\n$dumped;\n\n1;\n";
	close $fh;
	return undef;
}

sub DESTROY {};
1;
