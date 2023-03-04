#$Id: Object.pm,v 1.10 2003-02-03 23:33:34 triton Exp $
package TPerl::Object;
use strict;
use File::Slurp;
use Tie::IxHash;
use Data::Dumper;
use TPerl::Error;
use FileHandle;

=head1 SYNOPSIS 

base class for objects that get loaded in from files

=head1 DESCRIPTION

use AUTOLOAD to return bits that are stored in the file.

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	return $self;
}

sub get {
	my $self = shift;
	my $file = undef;

	if (scalar (@_)==1){
		$file = shift;
	}
	die "must provide a file" unless $file;
	die "file '$file' does not readable" unless -r $file;
	my $str = join '',read_file($file);
	my $thing = eval $str;
	die "cannot eval content of $file\n$@" if $@;
	return $thing;
}
sub put {
	my $self = shift;
	my $file = shift;
	my $thing = shift || $self;

	die "usage: put (file,thing)" if @_;
	return "Cannot write file '$file'" unless 
		my $fh = new FileHandle ("> $file");
	print $fh 'my '.Dumper $thing;
	return undef;
}

sub _eval {
	my $self = shift;
	my %args = @_;
	my $file = $args{file};
	my $err = $args{err} || new TPerl::Error;

	if ($file){
		if (-r $file){
			my $str = join ('',read_file($file));
			no strict qw (vars);
			eval $str;
			if ($@){
				$err->F("Could not eval $str");
				return undef;
			}
			return 1;
		}else{
			$err->F("File $file not readable");
			return undef;
		}
	}else{
		$err->F("No file supplied");
		return undef;
	}
}
sub qfile {
	no strict qw(vars);
	undef $mask_update;
	undef $mask_include;
	undef $mask_reverse;
	undef $mask_exclude;
	undef $mask_reset;
	undef $others;
	undef $qlab;
	@pulldowns=();
	@options = ();
	@scale_words = ();
	undef $survey_id;
	undef $gridtype;
	undef $scale;
	if (my $sucess = _eval (@_)){
		return {
			scale=>$scale,
			grid_type=>$grid_type,
			options=>\@options,
			prompt=>$prompt,
			left_word=>$left_word,
			right_word=>$right_word,
			mask_update=>$mask_update,
			mask_reset=>$mask_reset,
			mask_exclude=>$mask_exclude,
			mask_include=>$mask_include,
			mask_reverse=>$mask_reverse,
			qlab=>$qlab,
			scale_words=>\@scale_words,
			pulldowns=>\@pulldown,
			others=>$others,
		};
	}else{
		return undef;
	}
}	
sub qlabels {
	no strict qw(vars);
	tie %qlabels,'Tie::IxHash';
	if (my $sucess = _eval (@_)){
		return {qlabels=>\%qlabels,survey_id=>$survey_id};
	}else{
		return undef;
	}
}	
sub config {
	no strict qw(vars);
	undef $code_age_refused;
	undef $code_age_refused;
	undef $code_number_dk;
	undef $code_number_dk;
	if (_eval (@_)){
		return {
			code_age_refused=>$code_age_refused,
			code_age_dk=>$code_age_dk,
			code_number_refused=>$code_number_refused,
			code_number_dk=>$code_number_dk,
		}
	}else{
		return undef
	}
	strict vars;
}
sub dfile {
	no strict 'vars';
	%resp = ();
	if (_eval (@_)){
		my %r = %resp;
		return {resp=>\%r};
	}else{
		return undef;
	}
	strict vars;
}
sub ufields {
	no strict 'vars';
	%ufields = ();
	if (_eval (@_)){
		my %u= %ufields;
		return \%u;
	}else{
		return undef;
	}
	strict vars;
}
1;
