package TPerl::Graph;
use strict;
use vars qw($AUTOLOAD);
use Carp;
use List::Util qw (max);
use TPerl::Error;
use Data::Dumper;

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	$self->$_($args{$_}) foreach keys %args;
	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	my $type = ref $self;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	my $defs = {
		datamax=>undef,
		width=>'400',
		ofh=>\*STDOUT,
	};
	
	if (exists $defs->{lc($name)}){
		if (my $arg = $_[0]){
			return $self->{$name} = $arg;
		}else{
			return $self->{$name} if exists $self->{$name};
			return $defs->{$name};
		}
	}else{
		croak "Can't access method '$name' of class '$type'";
	}
}

sub images {
	my $self = shift;
	my %args = @_;
	my $order = $args{data};
    my $colors = [
        '/pix/teal.gif',
        '/pix/navy.gif',
        '/pix/red.gif',
        '/pix/blue.gif',
        '/pix/yellow.gif',
    ];
	my $num = scalar @$colors;
    my $images={};
    foreach (1..@$order){
        $images->{$order->[$_-1]} = $colors->[$_ % $num]
    }
	return $images;
}

sub table {
	my $self = shift;
	my %args = @_;
	my $data = $args{data} || {red=>12,blue=>6,green=>9};
	my $order = $args{order} || [reverse sort {$data->{$a} <=> $data->{$b} } keys %$data];
	my $labels = $args{labels} || {};
	my $images = $args{images} || $self->images(data=>$order);
	my $columns = $args{columns} || [];
	my $columndata = $args{columndata} || {};
	my $columnlabels = $args{columnlabels} || {};
	my $zeros = $args{zeros};
	$zeros = 1 unless exists $args{zeros};
	
	# print STDERR "lab=".Dumper $labels;
	# print STDERR "data=".Dumper $data;
	# print STDERR "order=".Dumper $order;
	my $dmx = $self->datamax || max (values %$data) || 1;
	my $scale = $self->width/$dmx;

	# my $tabargs = 'border="0" cellpadding="0"';
	my $tabargs = '';

	my $out;
	$out.= qq{<table $tabargs>\n};
	my $ncols = @$columns;
	my $rows_since_last_data = 0;
	if ($ncols){
		$out.= "<tr>\n";
		foreach my $col (@$columns){
			my $clab = $columnlabels->{$col} || ucfirst($col);
			# $self->clean($clab);
			$out.= qq{\t<th>$clab</th>\n};
		}
		$out.= "</tr>\n";
	}
	foreach my $lab (@$order){
		my $plab = $labels->{$lab} || $lab;
		# $lab = $self->clean ($lab);
		my $num = $data->{$lab} || '0';
		my $imlength = max ($num*$scale , 2);
		if ($zeros || $num){	
			if ($rows_since_last_data){
				my $span = 2;
				$span = $ncols+1 if $ncols;
				$out.= qq{<tr><td COLSPAN="$span" ALIGN="left">....Skipping $rows_since_last_data row(s)....</td></tr>};
			}
			$out.= qq{<tr align="left">\n};
			foreach my $col (@$columns){
				my $align = 'align = "center"' unless $col eq $columns->[0];
				my $dat = '&nbsp;';
				$dat = $columndata->{$col}->{$lab} if defined $columndata->{$col}->{$lab};
				$out.= qq{\t<td $align >$dat</td>\n};
			}
			unless ($ncols){
				my $disp = $plab || $lab;
				$out.= qq{<td>$disp</td>};
				$out.= qq{\t<td>($num)</td>};
			}
			$out.= qq{\n\t<td align="left"><img src="$images->{$lab}" height="10" width="$imlength"></td></tr>\n};
			$rows_since_last_data=0;
		}else{
			$rows_since_last_data++;
		}
	}
	$out.= qq{</table>\n};
	return $out;
}

1;
