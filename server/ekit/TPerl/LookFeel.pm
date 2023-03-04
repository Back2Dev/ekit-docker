package TPerl::LookFeel;
## copyright Triton Technology 2002
## $Id: LookFeel.pm,v 1.29 2011-05-06 17:27:42 triton Exp $
use strict;
use Data::Dumper;
use Carp;

use vars qw ($AUTOLOAD);
# our ($AUTOLOAD);


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
	my $class = ref $self;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	my $defs = {twidth=>'',border=>0,style=>''};

	if (exists $defs->{$name}){
		return $self->{opt}->{$name} = $_[0] if @_;
		return $self->{opt}->{$name} if exists $self->{opt}->{$name};
		return $defs->{$name};
	}else{
		confess "Cant call method '$name' of class $class";
		return undef;
	}
}

sub st {
	my $self = shift;
	my $width = $self->twidth ;# || "100%";
	my $style = $self->style;
	my $wid;
	if ($width) {
		$wid = qq{WIDTH="$width"}
	} else {
		$wid = "";
	}
	return qq{\n<table $wid CELLPADDING="5" CELLSPACING="0" CLASS="mytable" STYLE="$style">},
}

sub srbox {
	my $self = shift;
	my $heading = shift;
	return join "\n",
		qq{<table class="rtable" border="0" cellpadding="5" cellspacing="0"> },
		qq{ <tr>},
		qq{  <td class="boxtopleft"><img src="/pix/clearpixel.gif"></td>},
		qq{  <td align="left" class="boxtopmiddle">$heading</td>},
		qq{  <td class="boxtopright"><img src="/pix/clearpixel.gif"></td>},
		qq{ </tr>},
		qq{ <tr class="options"><td></td><td>};
}
sub erbox {
	return join "\n",
		qq{ </td><td></td></tr>},
		qq{ <tr height=5>},
		qq{  <td class="boxbottomleft"><img src="/pix/clearpixel.gif"></td>},
		qq{  <td class="boxbottommiddle"><img src="/pix/clearpixel.gif"></td>},
		qq{  <td class="boxbottomright"><img src="/pix/clearpixel.gif"></td>},
		qq{ </tr>},
		qq{</table>};
}

sub sbox {
	my $self = shift;
	my $heading = shift;

	my $width= $self->twidth;
	my $border = $self->border;
	my $head = qq{ <tr><th class="heading">$heading</th></tr>} if $heading;
	my $sbox = join "\n",
		$self->st(),
		$head,
		qq{ <tr><td class="options">};
	return $sbox;
}

sub stbox {
	my $self = shift;
	my $head = shift;
	my %args = @_;

	my $colspan = $args{colspan};
	$colspan ||= @$head if @$head;
	my $colsp = qq{colspan="$colspan"} if $colspan;
	my $headstr = $args{head};

	my $hrow = undef;
	if ($headstr){
		$hrow = qq{ <tr><TH align="center" class="heading" $colsp>$headstr</TH></tr>}
	}
	my $col_heading =undef;
	if (@$head){
		$col_heading = join "\n",
			' <tr>',
			map (qq{  <th ALIGN="center" class="heading" VAL IGN="TOP">$_</th>},@$head),
			' </tr>','';
	}

	return join "\n",
		$self->st,
		$hrow,
		$col_heading;

}
sub box_head_align {
    my $self = shift;
    if (@_){
        $self->{box_head_align} = $_[0];
    }else{
        return $self->{box_head_align} if exists $self->{box_head_align};
        return 'CENTER';
    }   
}
sub next_row_option {
	my $self = shift;
	if ($self->{_last_row} == 1){
		$self->{_last_row} =2;
		return "options2";
	}else{
		$self->{_last_row} =1;
		return "options";
	}
}
sub trowl {
	my $self = shift;
	my $row = shift;
	my $opt = $self->next_row_option();
	my $ro = qq{\n <tr class="$opt">};
	$ro .= qq{\n  <td align="left">$_</td>} foreach @$row;
	$ro .= qq{\n </tr>};
	return $ro;
}
sub trow_properties{
	my $self = shift;
	my %args = @_;
	$self->{_trow_properties} = \%args if @_;
	return $self->{_trow_properties};
	
}
sub trow {
	my $self = shift;
	my $row = shift;

	my $props = $self->trow_properties || {};
	my $aligns = $props->{align} || [];
	my $opt = $self->next_row_option();
	my $ro = qq{\n <tr class="$opt">};
	for (my $idx=0;$idx<=$#$row;$idx++){
		my $cont = $row->[$idx];
		my $align = $aligns->[$idx] || 'center';
		$ro .= qq{\n  <td align="$align">$cont</td>}
	}
	$ro .= qq{\n </tr>};
	return $ro;
}


sub ebox {
	my $self = shift;
	return qq{ </td></tr>\n</table>\n};
}
sub etbox {
	my $self = shift;
	return qq{\n</table>\n};
}
sub et {
	return '</table>';
}
sub msg {
	my $self = shift;
	my $title = shift;
	return join "\n",$self->sbox($title),join ('<br>',@_),$self->ebox,'<br>';
}
sub DESTROY{};
1;
