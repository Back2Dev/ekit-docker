# Copyright Triton Technology 2001
# $Id: Error.pm,v 1.31 2007-09-10 09:40:22 triton Exp $#
use strict;
package TPerl::Error;
use vars qw ($AUTOLOAD);
use Carp;
use Data::Dumper;
use Data::Dump qw(dump);
use TPerl::TritonConfig;
use FileHandle;
use File::Basename;

=head1 SYNOPSIS 

Prints consistantly formated error messages

 my $err = new TPerl::Error ();
 $err->I ("This is for information");
 $err->W ("This is a warning");
 $err->E ("This is an error");
 $err->F ("This is a fatal error");
 $err->D ("This is a Debug message");

You can print these to any GLOB, FileHandle, or IO::Scalar object you want.

 my $out = undef;
 my $o_fh = new IO::Scalar (\$out);
 $err->fh($o_fh);

 #or at new time.  Also turn on Timestamping each message
 my $fh = new FileHandle ("> /path/to/log/file");
 my $err = new TPerl::Error (fh=>$fh,ts=>1);
 # the fh can now be a listref of filehandles.  
 # fh=>[\*STDOUT,$fh]

 # turn off timestamping.
 $err->ts(0);

 #all messages preceeded by  \n<BR>tags for the web
 $err->web(1) 

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto ||$proto;
	my $self = {};
	bless $self,$class;
	my %args = @_;
	$self->{_types}->{$_} = [] foreach $self->types;
	unless ($args{noSTDOUT}){
		$self->{_fh} = $args{fh} || \*STDOUT;
	}
	$self->ts($args{ts});
	$self->web($args{web});
	$self->nodie($args{nodie});
	$self->SID($args{SID});
	return $self;
}

sub nodie { my $self = shift; return $self->{_nodie} = $_[0] if @_; return $self->{_nodie}; }
sub SID { my $self = shift; return $self->{_SID} = $_[0] if @_; return $self->{_SID}; }
sub web { my $self = shift; return $self->{_web} = $_[0] if @_; return $self->{_web}; }

sub AUTOLOAD {
	my $self=shift;
	my $type = ref ($self) or croak "$self is not an object";
	my $name = $AUTOLOAD;
# 	my $name = "GOOSE";
	$name =~ s/.*://;
	my %args = ();
	croak "Can't access method $name of class $type" 
		unless grep $name ,$self->types;
	if (scalar (@_) ==1){
		$args{msg} = shift;
	}else{
		%args = @_;
	}
	return $self->_error(%args,type=>$name);
	
}
sub DESTROY {}
sub types {
	my $self = shift;
	return qw (E W I D F);
}
sub no_print {
	my $self = shift; return $self->{_no_print}=$_[0] if @_;return $self->{_no_print};
}
sub ts {
	my $self = shift;
	if (@_){
		return $self->{_ts} = shift;
	}else{
		return $self->{_ts};
	}
}
sub fh {
	my $self = shift;
	if (@_){
		return $self->{_fh} = shift;
	}else{
		return $self->{_fh};
	}
}
sub fhl {
	my $self = shift;
	my $fhl = shift || $self->fh;

	# Mike wants logging for everyone automatically.
	# i'll only do a log if there is not a fh aleady in the list.
	$fhl = [$fhl] unless ref $fhl eq 'ARRAY';

	my ($name,$path,$suffix) = fileparse($0,qr{\.*$});
	$name =~ s/\.pl//ig;
	my $SID = $self->SID || '';
	$SID = "-$SID" if $SID;
	my $logname = "$name$SID.log";
	my $lfn = join '/',getConfig('TritonRoot'),'log',$logname;
	my $found_a_fh = 0;
	foreach my $fh (@$fhl){
		$found_a_fh++ if ref ($fh) eq 'FileHandle';
	}
	unless ($found_a_fh){
		my $fh = new FileHandle (">> $lfn") or die "Could not open logfile '$lfn':$!";
		unshift @$fhl,$fh;
		my $ts = scalar(localtime);
		print $fh "[I] $ts STARTING AUTOMATIC LOGGING TO FILE: $logname @ARGV\n";
		$self->fh($fhl);
	}
	return $fhl;
}

sub pretty_count {
	my $self = shift;
	my %args = @_;

	my $head = $args{head}||'Error Summary ';
	my $fhl = $self->fhl;
	foreach my $fh (@$fhl){
		print $fh $head;
		foreach ($self->types){
			next if $_ eq 'D';
			next if $_ eq 'F';
			printf $fh "[$_]=%s ",$self->count(type=>$_);
		}
		print $fh "\n";
	}
}
sub count {
	my $self = shift;
	my %args = @_;
	my $type = $args{type};
	my $total = $args{total};
	if ($type){
		return scalar @{$self->{_types}->{$type}};
	}elsif ($total){
		my $sum = 0;
		$sum += $self->count(type=>$_) foreach qw (E W I);
		return $sum;
	}else{
		my %h = ();
		foreach ($self->types){
			$h{$_} = scalar @{$self->{_types}->{$_}};
		}
		return \%h;
	}
}

sub _error {
	my $self = shift;
	my %args = @_;

	my $print = 1 unless ($args{no_print} || $self->no_print);
	my $type = $args{type};
	my $msg = $args{msg};
	$msg = $self->fmterr($msg);
	my $fhl = $args{fh} || $self->fh;
	my $nodie = $self->nodie;

	$msg = scalar (localtime) .' '. $msg if $self->ts;
	$fhl = $self->fhl($fhl);
	my $idx = -1;
	foreach my $fh (@$fhl){
		$idx++;
		die "[$type] $msg\n" if ($type eq 'F') && ($idx == $#$fhl) && !$nodie;
		my ($sweb,$eweb) = ('','');
		($sweb,$eweb) = ("\n<BR>",'') if $self->web;
		print $fh "$sweb\[$type\] $msg$eweb\n" if $print && grep ref ($fh) eq $_, qw(GLOB FileHandle IO::Scalar);
		push @{$self->{_types}->{$type}},{msg=>$msg};
		exit 1 if ($type eq 'F') && ($idx == $#$fhl) && $nodie;
	}
}

sub fmterr {
	my $self = shift;
	my $msg = shift;
	if (my $type = ref ($msg)){
		if (($type eq 'HASH') and (my $sql=$msg->{sql})){
			my $errstr = $msg->{dbh}->errstr if $msg->{dbh};
			$errstr ||= $msg->{errstr};
			$errstr||="DB error";
			my $prams = join '|',@{$msg->{params}} if $msg->{params};
			$prams ="\nwith '$prams'" if $prams;
			return "${errstr}:sql=$sql $prams";
		}elsif ($type eq 'ARRAY' and @$msg ==1){
			return $msg->[0];
		}else{
			return dump $msg;
		}
	}else{
		return $msg;
	}
}

1;
