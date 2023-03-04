#$Id: Template.pm,v 1.8 2005-12-15 00:03:13 triton Exp $
package TPerl::Template;
use strict;
use TPerl::Hash;
use Carp qw(confess);
use File::Slurp;

=head1 SYNOPSIS

 my $tt = new TPerl::Template (file=>'path/to/file');
 or
 my $tt = new TPerl::Template (template=>'[%some template%] or <%other%>');
 
 my $data = {'SOme TEMplate'=>1,oThEr=>'fill me up'}
 my $processed = $tt->process($data) || die $tt->err;

 # See what went on.
 my $results = $tt->process_results();#
 print Dumper $results;

 # you may want to analyse the template.
 # get a case insensitive hash of the vars found in the template
 my $vars = $tt->vars;
 
 # want to pass the $data in and see what vars from the template 
 # are missing?
 my $err =  $tt->err() unless $tt->check_subs({});
 # $err =  Substitution problem with 'SOME TEMPLATE','OTHER'"


=head1 Recursion

Your data can contain references.  

 my $data = {
  r1=>'<%r2%>',
  r2=>'<%r3%>',
  r3=>'The final value',
  }';
 my $tt = new TPerl::Template (template=>'The final values is:<%R1%>');
 my $processed = $tt->process($data);
 
If they are circluar, then it will recurse 100 times and then stop.  The sum of
the the subs in the $tt->process_results will be 100.  This behaviour can be changed.

=cut

# just a contructor.
sub new {
    my $proto = shift;
    my $class = ref $proto ||$proto;
    my $self = {};
    bless $self,$class;
	my %args = @_;
	$self->{template} = $args{template} if defined $args{template};
	$self->{filename} = $args{file} if defined $args{file};

	# programmer help.
	confess "Send either 'template' or 'file' " 
		if (defined ($args{file}) && defined ($args{template})) or 
			(!defined ($args{file}) && !defined ($args{template}));
	return $self;
}

sub err {
	# returns the last error message for this object
    my $self = shift;
    return $self->{err} = $_[0] if @_;
    return $self->{err};
}
sub filename { my $self = shift; return $self->{filename}; }

sub template {
	# if its already here, then return it.
	my $self = shift;
	return $self->{template} if $self->{template};
	
	#otherwise load it from file.
	my $file = $self->filename;
	unless ($file){
		$self->err("No Filename sent");
		return undef;
	}
	unless (-f $file){
		$self->err("File '$file' does not exist");
		return undef;
	}
	if (my $template = read_file ($file)){
		$self->{template} = $template;
		return $template;
	}else{
		$self->err("Could not read file '$file':$!");
		return undef;
	}
}

###THese two regexps are a pair.  Make sure you change them both.
# once we find all the vars, we need to replace them.
# make sure they are pretty close to being identical, 
# except that the (\w+) should be $thing;
# Also the the sub_ one needs the i on the end.

sub regexp {
	return qr{[\[<]%\s*(\w+)\s*%[>\]]|\$\$(\w+)};
}
sub sub_regexp {
	my $self = shift;
	my $thing = shift;
	return qr{[\[<]%\s*$thing\s*%[>\]]|\$\$$thing}i;
}

sub vars {
	my $self = shift;
	my $template;
	if (@_){
		$template = shift;
	}else{
		$template = $self->template() || return undef;
	}
	my $vars = {};
	tie %$vars, 'TPerl::Hash';
	my $rex = $self->regexp;
	
	while ($template =~ /$rex/g){
		my $var = $1 || $2;
		$vars->{$var}->{count}++;
		push @{$vars->{$var}->{uses}},$var;
	}
	return $vars;
}

sub check_subs{
	
	my $self = shift;
	my $supplied_data = shift || {};

	my $data = {};
	tie %$data, 'TPerl::Hash';
	$data->{$_} = $supplied_data->{$_} foreach keys %$supplied_data;

	my $template = $self->template() or return undef;


	my @bad = ();
	my $recurse = 0;
	my $limit = 100;
	while ($recurse++ < $limit){
		my $vars = $self->vars($template) or return undef;
		last unless scalar keys %$vars;
		foreach my $var (keys %$vars){
			push @bad,$var unless exists ($data->{$var});
			my $rex = $self->sub_regexp($var);
			my $subs = $template =~ s/$rex/$data->{$var}/g;
		}
	}
	if (@bad){
		$self->err("Substitution problem with ".join ' ',map "'$_'",@bad);
		$self->{bad_vars} = \@bad;
		return undef;
	}
	return 1;
}

sub process {
	my $self = shift;
	my $supplied_data = shift;

	my %args = @_;

	## Copy the supplied data into a case insensitive hash, so 
	# things continue to work.
	
	confess ("Must pass a hash ref as first param") unless ref $supplied_data eq 'HASH';
	
	my $data = {};
	tie %$data, 'TPerl::Hash';
	$data->{$_} = $supplied_data->{$_} foreach keys %$supplied_data;

	# Sometimes we only want to do part of the processing.  Lets have a flag that 
	# only does substitutions on the templates in the data hash.
	my $data_only = $args{data_only};

	# Now allow recursion... basically keep going till all the vars are gone,
	# unless its looking like its circular

	my $template = $self->template() or return undef;

	my $results = {};
	tie %$results, 'TPerl::Hash';
	my $recurse = 0;
	my $limit = 100;
	while ($recurse++ < $limit){
		my $vars = $self->vars($template) or return undef;
		if ($data_only) {
			# remove the vars that are in the data.
			foreach my $v (keys %$vars){
				delete $vars->{$v} unless exists $data->{$v};
			}
		}
		last unless scalar keys %$vars;
		foreach my $var (keys %$vars){
			my $rex = $self->sub_regexp($var);
			my $subs = $template =~ s/$rex/$data->{$var}/g;
			$results->{$var}->{substitutions} +=$subs;
			$results->{$var}->{regexp} = $rex;
			$results->{$var}->{data} = $data->{$var};
			$results->{$var}->{recurse}++;
		}
	}
	$self->{process_results} = $results;
	return $template;
}

sub process_results { $_[0]->{process_results}; }

1;
