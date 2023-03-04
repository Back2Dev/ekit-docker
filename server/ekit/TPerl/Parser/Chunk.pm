#$Id: Chunk.pm,v 1.17 2004-09-15 04:21:36 triton Exp $
package TPerl::Parser::Chunk;
use strict;
use Data::Dumper;

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	foreach (qw(lines number type file)){
		$self->{"_$_"} = $args{$_} if exists $args{$_};
	}
	return $self;
}

sub lines {
	my $self = shift;
	return $self->{_lines};
}
sub number {
	my $self = shift;
	return $self->{_number} = $_[0] if @_;
	return $self->{_number};
}
sub type {
	my $self = shift;
	return $self->{_type};
}
sub file {
	my $self = shift;
	return $self->{_file};
}

sub options {
	#??? don;t need to parse everytime.
	my $self = shift;
	my %args = @_;

	my $opt_name = $args{opt};
	my $whole_line = $args{whole_line};

	my $options={};
	foreach my $line ( @{$self->{_lines}}  ) {
        next unless $line->{type} eq 'option';
		my $ob = {line=>$line} ;
        my $opt = $line->{line};
        $opt =~ s/\+//;
        my ($key,$val) = split '=',$opt,2;
        $key =~ s/\s//g;
        $key = lc $key;
        $val =~ s/^\s*(.*?)\s*$/$1/;
		$ob->{val}= $val;
		if ($whole_line){
			$options->{$key}=$ob;
		}else{
        	$options->{$key}=$val;
		}
	}
	return $options->{$opt_name} if $opt_name;
	return $options;
}
sub replace_options {
	my $self = shift;
	my %args = @_;
	my $new = $args{new};
	foreach my $opt (keys %$new){
		my $whole = $self->options(whole_line=>1,opt=>$opt);
		# print "$opt ".Dumper $whole;
		my $rex = quotemeta $whole->{val};
		# print "opt=$opt val=$whole->{val} rex=$rex\n";
		$whole->{line}->{line} =~ s/$rex/$new->{$opt}/;
	}
}
sub used_mask {
	my $self = shift;
	my $opt = $self->options;
	foreach (qw(mask_include mask_exclude mask_reverse)){
		return $opt->{$_} if $opt->{$_};
	}
	return undef;
}

sub qlabel {
	my $self = shift;
	my %args = @_;
	# print Dumper \%args;
	my $want_label = $args{label};
	my $want_prompt = $args{prompt};
	my $replace = $args{new_prompt} || $args{new_label};
	my $new_p = $args{new_prompt} || $self->qlabel(prompt=>1) if $replace;
	my $new_l = $args{new_label} || $self->qlabel(label=>1) if $replace;
	if ($self->type ne 'question'){
		# print "(I) trying to get a qlabel from a non question\n";
		return undef;
	}
	#get all the unrecognised lines till something else
	my @lines = ($self->lines->[0]->{line});
	# print "lines=".Dumper $self->lines;
	foreach ( @{$self->lines }){
		# print "lines=".Dumper $_;
		if ($_->{type} eq 'question'){
			$_->{line} = qq{$new_l. $new_p} if $replace;
		}elsif ($_->{type} eq 'leftovers'){
			$_->{line} = undef if $replace;
			push @lines,$_->{line}
		}else{
			last;
		}
	}
	# print Dumper \@lines;
	my $str = join ("\n",@lines);

	# Look across muliple lines.
	my ($lab,$prompt) = $str =~ /^\s*(\w+?)[[:space:].]+(.*)\s*$/s;
	$prompt =~ s/^\s*(.*?)\s*$/$1/;
	# print "SHIT p=$prompt|l=$lab|$str\n" if $lab eq '';

	$lab ||= $str;
	$lab =~ s/\.$//g;
	return $lab if $want_label;
	return $prompt if $want_prompt;
	return "$lab. $prompt";
}
sub line_filter {
	my $self=shift;
	my %args = @_;

	my $type = $args{type};
	my $line_only = $args{line_only};
	my $lines = $args{lines} || [];

	foreach my $line (@{$self->lines}){
		next unless $line->{type} eq $type;
		if ($line_only){
			push @$lines,$line->{line};
		}else{
			push @$lines,$line
		}
	}
	return $lines;
}
sub as_src {
	my $self = shift;
	my %args = @_;

	my $fh = $args{fh} || \*STDOUT;

	foreach (@{$self->lines}){
		print $fh "$_->{clean}$_->{line}\n";
	}
}
sub tokenise {
	my $self= shift;
    my %args = @_;
	#print Dumper \%args;
    my $tokens = $args{tokens} || {};
	my $tokbase = $args{tokbase} || 'BadNewsTokenMate';
	my $tok_use = $args{token_use} ||{};

    my $next_tok = 0;
    foreach (values %$tokens){
        m/(\d+)$/;
        $next_tok = $1 if $1>$next_tok
    }
	#some options need tranlation
		my $opts = $self->options(whole_line=>1);
		# print Dumper $opts;
		foreach my $opt (qw(instr survey_name window_title) ){
			my $tr = $opts->{$opt}->{val};
			next unless $tr;
			$tr =~ s/^\s*(.*?)\s*$/$1/;
			# print "Opt ".Dumper $opts->{$opt};
			
			my $tok = $tokens->{$tr} ||  $tokbase.++$next_tok;
			push @{$tok_use->{$tok}},$opts->{$opt}->{line};
			$tokens->{$tr} = $tok;
			my $rex = quotemeta $tr;
			$opts->{$opt}->{line}->{line} =~ s/$rex/$tok/;
			# $opts->{$opt}->{line}->{line} = "+$opt=$tok";
		}
	#some question labels need translation
		if ($self->type eq 'question'){
			my $trans = 1;
			# print Dumper $opts;
			$trans = 0 if $opts->{external};
			$trans=0 if grep $opts->{qtype}->{val} eq $_,qw(code eval );
			$trans = 0 if $self->qlabel(label=>1) =~ /^temp/i;
			if ($trans && (my $tr = $self->qlabel(prompt=>1)) ){
				$tr =~ s/^\s*(.*?)\s*$/$1/;
				my $tok = $tokens->{$tr} ||  $tokbase.++$next_tok;
				push @{$tok_use->{$tok}},$self->lines->[0];
				$tokens->{$tr} = $tok;
				$self->qlabel (new_prompt=>$tok);
			}
		}
	#Attributes Grid and GridPullown need translation
		if ( grep $_ eq $self->type, qw(attribute grid_heading grid_pulldown)){
			# print Dumper $self;
			my $tr = $self->lines->[0]->{line};
			# print "TR=$tr\n";
			$tr =~ s/^\s*(.*?)\s*$/$1/;
			my $tok = $tokens->{$tr} ||  $tokbase.++$next_tok;
			push @{$tok_use->{$tok}},$self->lines->[0];
			$tokens->{$tr} = $tok;
			$self->lines->[0]->{line} = $tok;
		}
}

sub orphan_warnings {
	my $self = shift;
	my %args = @_;
	my $err = $args{err} || new TPerl::Error();

	my $lst_type = undef;
	foreach my $line (@{$self->lines}){
		# print Dumper $line;
		# print "$line->{type}:$line->{line}\n";
		$lst_type = $line->{type} unless $line->{type} eq 'leftovers';
		$err->W("ignoring orphan line $line->{number}: $line->{line}") if 
			$line->{type} eq 'leftovers' and $lst_type ne 'question';
	}
	return 1;
}

1;
