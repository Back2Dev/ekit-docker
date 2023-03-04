#$Id: StatsPage.pm,v 2.9 2006-11-09 04:01:51 triton Exp $
package TPerl::StatsPage;
use strict;
use Data::Dumper;
use TPerl::StatSplit;
use Carp qw (confess);

#### This contains some code from the statsspage.pl that we need to use elsewhere.

sub new {
	my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;

    my %args = @_;
    $self->{SID} = $args{SID};
	return $self;
}


sub err { my $self = shift; return $self->{err} = $_[0] if @_; return $self->{err}; }
sub SID {my $self = shift; return $self->{SID};}

# this looks at the TPerl::Survey object and assigns the data elements to pages etc
# it also does some labeling stuff.

# returns number of questions, the ci sorted into pages, and the column_names for 
# trawling the data file with.

sub survey2pages {
	my $self = shift;
	my %args = @_;

	my $s = $args{survey};
	my $do_whatpage = $args{do_whatpage};
	my $graphs_per_page = $args{graphs_per_page} || 30;
	my $limit_to = $args{limit_to};
	confess "passing do_custom  here is deprecated" if $args{do_custom};

	my $pidx=0;
	my $pages =  [{}];
	my $n_questions = 0;
	my $column_names = [];

	foreach my $q (@{$s->questions}){
		my $gl =  $self->question2graphlist (question=>$q,data=>{},
			do_whatpage=>$do_whatpage,limit_to=>$limit_to);
		my $ngl = @$gl;
		if ($ngl > 0){
			$n_questions++;
			$pidx++ if ($ngl + $pages->[$pidx]->{n_graphs}) > $graphs_per_page;
			$pages->[$pidx]->{n_graphs} += $ngl;
			# $pages->[$pidx]->{first_label} ||= $q->pretty_label;
			$pages->[$pidx]->{first_label} ||= $gl->[0]->{var};
			push @{$pages->[$pidx]->{questions}},$q;
			foreach my $ci (@{$q->getDataInfo()}){
				next if !$do_whatpage and !$ci->{val_label};
				push @$column_names,$ci->{var} 
			}
		}
	}
	return ($n_questions,$pages,$column_names);
}

sub question2graphlist {
	my $self = shift;

	my %args = @_;
	my $q = $args{question};
	my $data = $args{data};
	my $codes=$args{codes};
	my $rf_code=$args{rf_code};
	my $dk_code=$args{dk_code};
	my $do_whatpage = $args{do_whatpage};

	confess "passing do_custom  here is deprecated" if $args{do_custom};

	my $limit_to = $args{limit_to};
	my $limit = 1 if $limit_to;
	$limit_to ||= [];
	
	my $attrs = $q->attributes;
	my $qlab = $q->label;
	my $qtype= $q->qtype;

	my $graphlist = [];
	
	my $cis = $q->getDataInfo (codes=>$codes,rf_code=>$rf_code,dk_code=>$dk_code);

	#for whatpage, just return the cis that are text areas in externals, or written question
	if ($do_whatpage){
		if ( $qtype==7 ){
        	$cis = [grep $_->{type} eq 'textarea',@$cis];
		}elsif ($qtype==5){
		}else{
			return [];
		}
		return $cis;
	}
	$cis = [grep $_->{val_label},@$cis];

	if ($qtype==3){
		push @$graphlist ,{
				hist=>$data->{$cis->[0]->{var}},
				labels=>$cis->[0]->{val_label},
				var=>$q->pretty_label,
				label=>$q->pretty_prompt
			};
	}elsif ( $qtype==7){
		foreach my $ci (@$cis){
			push @$graphlist ,{
					hist=>$data->{$ci->{var}},
					labels=>$ci->{val_label},
					var=>$ci->{var},
					label=>$ci->{var_label}
				}if $ci->{val_label} && %{$ci->{val_label}};
		}
	}elsif ($qtype ==2){
		my $hist = {};
		my $labels = {};
		# print Dumper $cis;
		my $attrs = $q->attributes;
		my $alabs = $q->a_varlabels;
		my $count = 0;
		foreach my $ci (@$cis){
			my $var = $ci->{var};
			my $chist = $data->{$var};
			$hist->{$count} += $chist->{$_} foreach keys %$chist;
			$labels->{$count} = $alabs->[$count] || $attrs->[$count];
			# $labels->{$_} = $ci->{val_label}->{$_} foreach keys %{$ci->{val_label}};
			$count++;
		}
		# print "Multi ".$q->pretty_label. Dumper $hist;
		push @$graphlist, {
				hist=>$hist,
				labels=>$labels,
				var=>$q->pretty_label,
				label=>$q->pretty_prompt,
			};
	}elsif ($qtype == 14){
		foreach my $ci (@$cis){
			push @$graphlist ,{
				hist=>$data->{$ci->{var}},
				labels=>$ci->{val_label},
				label=>$ci->{var_label},
				var=>$ci->{var}
			};
		}
	}elsif ($qtype == 26){
		foreach my $ci (@$cis){
			my $vm = $ci->{var};
			my $pr = $ci->{var_label};
			$pr=~ s/\Q$qlab\E//;
			push @$graphlist,{
					hist=>$data->{$ci->{var}},
					labels=>$ci->{val_label},
					var=>$vm,
					label=>$pr
				};
		}
	}else{
		next;
	}
	if ($limit){
		my $vhsh ={};
		$vhsh->{$_}++ foreach @$limit_to;
		$graphlist = [ grep $vhsh->{$_->{var}},@$graphlist ];
	}
	foreach my $g (@$graphlist){
		$g->{label} =~ s/-&nbsp;//g;
		$g->{label} =~ s/&nbsp;-//g;
		$g->{label} =~ s/--/-/g;
		$g->{label} = $self->clean($g->{label});
	}
	return $graphlist;
}

sub clean {
    my $self = shift;
    my $thing = shift;
    my $newthing = $thing;
    $newthing =~ s/<.*?>//g;
    # print "was=$thing new=$newthing\n" unless $thing eq $newthing;
    return $newthing;
}

sub graph_hist {
	my $self = shift;
    my %args = @_;
    # print "args ".Dumper \%args;

	my $e = $args{err};
	my $gr = $args{graph};

    my $hist = $args{hist};
    my $docases = 1 unless $args{nocases};
    my $labels = $args{labels};

	$_ = $self->clean($_) foreach values %$labels;

    my $graph;
    my $cases;

	# var and label are used for warnings.
	my $var = $args{var};
	my $label = $args{label};

    $hist->{$_} ||= 0 foreach keys %$labels;
    foreach (keys %$hist){
        unless (exists $labels->{$_}){
            $labels->{$_} = "$_ (unlabeled)";
			my $msg = "Unlabeled histogram element '$_'";
			$msg .= " in graph '$var'" if $var ne '';
            $e->W($msg);
        }
    }
    $cases += $hist->{$_} foreach keys %$hist;
    my $cases_div = $cases;
    $cases_div ||=1;
    my $columndata = {};
    $columndata->{item}=$labels;
    $columndata->{count} = $hist;
    $columndata->{percent}->{$_} = sprintf ("%0.1f%",$hist->{$_}/$cases_div*100) foreach keys %$hist;
    # print Dumper $columndata;
    my $order= [sort {$a <=> $b} keys %$hist];

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
    $graph .= $gr->table (
        data=>$hist, images=>$images, order=>[sort {$a <=> $b} keys %$hist],
        columns=>[qw(item count percent)], columndata=>$columndata,
    );

    $graph .= "<blockquote><i> $cases cases</i></blockquote>" if $docases ;
    return $graph;

}


1;
