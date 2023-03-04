package TPerl::IniMapper;
#
# $Id: IniMapper.pm,v 2.6 2007-02-21 00:39:57 triton Exp $
#
use strict;
use Text::Balanced qw (extract_bracketed);
use Data::Dumper;
use TPerl::DBEasy;
use Carp qw(confess);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    my %args = @_;
    bless $self,$class;
    return $self; 
}

sub err { my $self = shift; return $self->{err} = $_[0] if @_; return $self->{err}; }

=head2 function_definitions

This is package global.  you can quickly add (or redefine) a function by saying
All function names should be lowercase.

 $TPerl::IniMapping::function_definitions{new_function} = sub {return "Hello"};

=cut

### All function names should be in lowercase.
my %function_definitions = (
	fullname_first_non_blank => sub {
		my $def = shift;
		my $fullname = shift;
		my $first = shift;
		my $middle = shift;
		my $last = shift;
		my @others = @_;

		my $combined = "$first $middle $last";
		my @list = ($fullname,$combined,@others);
		foreach my $try (@list){
			$try =~ s/^\s*(.*?)\s*$/$1/;
			return $try if $try ne '';
		}
		return $def;
	},
	fullname => sub {
		my $def = shift;
		my $fullname = shift;
		my @others = @_;

		$fullname =~ s/^\s*(.*?)\s*$/$1/;
		return $fullname if $fullname ne '';
		my $join = join ' ',@others;
		$join =~ s/^\s*(.*?)\s*$/$1/;
		return $join if $join ne '';
		return $def;
	},
	emails => sub {
		my @non_blanks = ();
		foreach my $em (@_){
			$em =~ s/^\s*(.*?)\s*$/$1/;
			push @non_blanks,$em if $em ne '';
		}
		return join ',',@non_blanks;
	},
	join => sub { 
		my $exp = shift;
		return join ($exp,@_);
	},
	sprintf => sub { my $fmt = shift; return sprintf ($fmt,@_)},
	ifblank => sub { 
		my $val = shift; 
		my $replace = shift; 
		return $replace if $val eq '';
		return $val;
	},
	split => sub {
		my $pos = shift;
		my $rex = shift;
		my $string = shift;
		my @res = split /$rex/,$string;
 		# print "Here:pos=$pos,rex=$rex,str='$string'".Dumper \@res;
		return $res[$pos];
	},
);


sub func_ref {
	my $self = shift;
	my $func_name = shift;

	# print Dumper \%function_definitions;
	if (my $ref = $function_definitions{lc($func_name)}){
		return $ref;
	}else{
		$self->err("'$func_name' is not a valid function name");
		return undef;
	}
}

sub mapping2field {
	my $self = shift;
	my %args = @_;
	my $map = $args{mapping};
	my $headings = $args{headings};
	my $name = $args{name};

	my $uc_heads = {};
	$uc_heads->{uc($_)}++ foreach @$headings;
	my $ez = new TPerl::DBEasy;

	foreach (qw(mapping headings name)){
		confess ("$_ is a required fields") unless $args{$_};
	}
	if (my $p = $self->_parse($map)){
		foreach my $arg (@{$p->{args_list}}){
			if ($arg->{type} eq 'variable'){
				unless ($uc_heads->{uc($arg->{name})}){
					$self->err("Bad arguments: Could not find '$arg->{name}'");
					return undef;
				}
			}
		}
		return {
			code=>{ref=>$p->{function_ref},args_list=>$p->{args_list},
					function_name=>$p->{function_name}},
			name=>$name,
			pretty=>$ez->name2pretty($name),
		};

	}else{
		return undef;
	}
	
}

sub _parse {
	my $self = shift;
	my $mapping = shift;

	my $debug = 1;

	# Keep the original for error messages etc.
	my $map = $mapping;
	$map =~ s/^\s*(.*?)\s*$/$1/;

	my $valid = {};
	if (my ($func_call) = $map =~ /^func:(.*)$/i){
		return $self->_parse_func_call($func_call);
	}else{
		return $self->_parse_func_call(qq{join(' ',$map)});
	}
}

sub _parse_func_call {
	my $self = shift;
	my $func_call = shift;

	if (my ($func_name,$rest) = $func_call =~ /^\s*(\w+)\s*(.*?)$/){
		if (my $fref = $self->func_ref($func_name)){
			my ($args,$remaider) = extract_bracketed ($rest,'()');
			if ($args){
				if ($remaider){
					$self->err ("Expected end of line but found '$remaider'");
				}else{
					if (my $arg_list = $self->_parse_arg_list($args)){
						return {
							function_name=>$func_name,
							function_ref=>$fref,
							args_list=>$arg_list
							};
					}
				}
			}else{
				$self->err ($@->{error});
			}
		}
	}else{
		$self->err("Syntax error in function call '$func_call'");
	}
	return undef;
}

sub _parse_arg_list {
	my $self = shift;
	my $args_str = shift;
	my $str = $args_str;

	$str =~ s/^\s*\((.*?)\)\s*$/$1/;
	my @args = split /,/,$str;
	s/^\s*(.*?)\s*$/$1/ foreach @args;
	
	my @list = ();
	foreach my $arg (@args){
		my $type = 'variable';
		if ($arg =~ /^'.*'$/){
			$type = 'literal';
			$arg =~ s/^'(.*?)'$/$1/;
		}else{
			$arg = uc($arg);
		}
		push @list,{type=>$type,name=>$arg};
	}
	return \@list;
}

