#$Id: Question.pm,v 2.67 2011-12-05 21:50:28 triton Exp $
package TPerl::Survey::Question;
use strict;
use Carp;
use Data::Dumper;
use TPerl::Error;
use Text::Balanced qw(extract_bracketed);
use TPerl::TritonConfig;
our $AUTOLOAD;
 
=head1 SYNOPSIS

Usually these objects are created by the parsing process, and TPerl::Dump is 
used to save a text dump of the Survey Object.

There are lots of accessor methods for

 label
 prompt
 options
 scale_words
 code
 skips
 pulldown
 qtype
 scores
 options
 vars
 setvalues
 sections
 attributes

and foreach of the options like

 limlo
 limhi
 i_pos
 grid_type
 etc....

and even non-supported options are remembered, but i'm not sure if this is a good thing

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	return $self;
}

sub supported_options {
	my $self = shift;
	my $normal = [qw(
		grid_include instr others external
		mask_reset mask_reverse
		mask_include mask_exclude mask_update mask_copy mask_local
		age_var randomise selectvar var execute
		scale skip middle dk na left_word right_word other_text
		var_prefix require_file cnt_var
		jump max_select
		javascript
		specify_n allow_leading_0
		table_cellspacing 
		force_expand
		instr
		i_pos
		true_flags
		autoselect
		specify_n
		table_width
		tight
		text_size
		script
		varlabel
		varname
		display_label
		rank_grid
		vertical
		eraser
		header_repeat
		set_columns
		q_style
		no_highlight
		no_rescore
		horizontal_dupes
		percent_complete
	)];
	my $set_if_exist =  [qw(show_date show_time no_validation 
		no_recency
		fixed
		random_options
		last_onset_only
		optional_written 
		written_required
	)];
	my $special = [qw(tally required middle dk limlo limhi 
		left_word right_word scale qtype scale
	)];
	return {normal=>$normal,set_if_exist=>$set_if_exist,special=>$special};
}
sub DESTROY {};
sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	my $type = ref $self;

	# print "AutoLoad $name\n";

	my $options = $self->supported_options;

	my @methods = qw (prompt label options scale_words code skips pulldown
		qnum
		qtype recodes scores options vars setvalues sections attributes
		g_varnames a_varnames
		g_varlabels a_varlabels
		external_info
		);

	if (grep $name eq $_, @methods){
		return $self->{"_$name"} = shift if @_; return $self->{"_$name"};
	}elsif (grep $name eq $_, @{$options->{normal}},@{$options->{special}}){
		return $self->{_opt}->{$name} =shift if @_; return $self->{_opt}->{$name};
	}elsif (grep $name eq $_, @{$options->{set_if_exist}}){
		if (@_){
			my $val = shift;
			$val = 1 if $val eq '';
			return $self->{_opt}->{$name} = $val;
		}else{
			return $self->{_opt}->{$name};
		}
	}else{
		croak "Can't access '$name' method in class $type";
		if (@_){
			return $self->{_no_opt}->{$name} = shift;
		}else{
			return $self->{_no_opt}->{$name}
		}
	}
}

sub pretty_label {
	my $self = shift;
	return $self->varname() || $self->label();
}

sub pretty_prompt {
	my $self = shift;
	return $self->varlabel() || $self->prompt();
}

sub setDataInfo {
	my $gnams;
	my $self = shift;
	my %args = @_;
	my $ext_info = $args{ext_info} || {};
	my $qtype = $self->qtype;
	my $dlab = uc $self->label;
	my $rkey = $dlab;
	$dlab = "Q$dlab" if  $dlab =~ /^\d/;
	
	my @vars = ();  		# The name of the variable A1 or A1x1 or A1x2x3
	my @keys = ();			# the keys into the resp hash
	my @pos = ();			# the index into the array after split /===/,$resp{$key};
	my @specify = ();		# Where to find specify_data
	my @spec_after = ();	# When to look for specify data.
	my @varlab = ();		# the variable label,
	my @vallab = ();		# the value labels
	my @valiftrue = ();		# what to do with the data in the resp hash.  +1 or 1 or nuthin
	my @maskpos = ();		# {grid=>3,mask=>2} means look in the grid_include[3] and mask_include[2] mask before specifing rf or dk
	my @sections = ();		# for tally and tally_multi questions, sections are needed in iprocess for endorsements
	my @types = ();			# type of input, used for externals only.
	my @lengths = ();		# length of input, externals only...

	if (grep $qtype==$_,3,4){
		push @vars,$self->varname || $dlab;
		push @pos,0;
		push @keys , ("_Q$rkey");
		push @varlab,$self->varlabel || $self->prompt;
		push @valiftrue,'+1';
		push @maskpos,undef;
		my $alabs = $self->a_varlabels();
		my $as = $self->attributes || [];
		if ($_ = $self->specify_n){
			push @spec_after,(@$as - $_);
			push @specify,["_Q$rkey-0"] 
		}elsif($self->others){
			push @spec_after,scalar(@$as);
			push @specify,["_Q$rkey-0"] 
		}else{
			push @spec_after,undef;
			push @specify,undef;
		}
		my $vall = {};
		foreach my $a (1..@$as){
			my $adx=$a-1;
			$vall->{$a} = $alabs->[$adx] || $as->[$adx];
		}
		$vall->{0} ||= 'Please Select' if $self->force_expand eq '0';
		push @vallab,$vall;
	}elsif (grep $qtype==$_,1,5,6,9,15,16,18,30,31){
		my $as = $self->attributes || [];
		$as->[0] ||='' if $qtype==5;
		my $alabs = $self->a_varlabels();
		my $anams = $self->a_varnames();
		my $stem_lab = $self->varlabel || $self->prompt;
		my $stem_nm = $self->varname || $dlab;
		foreach my $ct (1..@$as){
			my $ext = '';
			$ext = "$ct" if @$as >1;
			my $idx=$ct-1;
			my $an = $alabs->[$idx] || $as->[$idx];
			$ext = $anams->[$idx] if (@$as >1) && $anams->[$idx];
			my $x = 'x' if ($stem_nm =~ /\d$/) and ($ext =~ /^\d/);
			$x = 'x' if ($stem_nm =~ /[A-Za-wy-z]$/) and ($ext =~ /^[A-Za-wy-z]/);
			push @vars, "$stem_nm$x$ext";
			if ($qtype==15){
				push @pos,0;
				push @keys,"_Q$rkey-$idx";
			}else{
				push @pos,$idx;
				push @keys,"_Q$rkey";
			}
			push @varlab,"$an-$stem_lab";
			if ($qtype==16){
				push @valiftrue,'date';
			}else{
				push @valiftrue,undef;
			}
			push @vallab,undef;
			push @specify,undef;
			push @spec_after,undef;
			push @maskpos,{mask=>$idx};
		}
	}elsif (grep $qtype==$_,2,23){
		my $as = $self->attributes || [];
		my $ot = $self->other_text || 'Other';
		push @$as,"$ot $_" foreach (1..$self->others);
		my $oths = $self->others + $self->specify_n;
		@keys = map "_Q$rkey",@$as;
		my $sections = $self->sections;
		my $alabs = $self->a_varlabels();
		my $anams = $self->a_varnames();
		my $stemlab = $self->varlabel || $self->prompt;
		my $stemnam = $self->varname || $dlab;
		foreach my $ct (1..@$as){
			my $idx = $ct-1;
			my $llab = $alabs->[$idx] || $as->[$idx];
			push @varlab,"$llab-$stemlab";
			# +other specifier goes in _QA-0
			# +specify_n goes in _QA-6
			if ($qtype==23){
				push @sections,$sections->[$idx] if $sections;
			}
			if ($ct > @$as - $oths){
				if ($self->specify_n){
					push @specify,["_Q$rkey-$idx"];
				}else{
					# This is a mistake 
					# my $pos = $idx-$oths-1;
					my $pos = $oths-1;
					push @specify,["_Q$rkey-$pos"];
				}
				push @valiftrue,$ct;
				push @vallab,undef;
				push @spec_after,$idx;
			}else{
				push @valiftrue,$ct;
				push @specify,undef;
				my $vall = $alabs->[$idx] || $as->[$idx];
				push @vallab,{$ct=>$vall};
				push @spec_after,undef;
			}
			push @maskpos,{mask=>$idx};
			my $ext = $anams->[$idx] || $sections->[$idx] || "$ct";
			my $x = 'x' if ($stemnam =~ /\d$/) and ($ext =~ /^\d/);
			$x = 'x' if ($stemnam =~ /[A-Za-wy-z]$/) and ($ext =~ /^[A-Za-wy-z]/);
			# print "st=$stemnam x=$x ext=$ext\n";
			push @vars,"$stemnam$x$ext";
			push @pos,$idx;
		}
		my $var = $self->varname || $dlab;
		@vars=($var) if @$as == 1;

	}elsif (grep $qtype==$_,24,29,26,25){
		## grid pulldown (26) data takes no notice of others or specify_n 
		## grid multi (25) data takes no notice of specify_n
		## grid number (29) data takes no notice of others or specify_n
		## grid text (24)takes no notice of others or specify_n 
		my $as = $self->attributes || [];
		my $gs = $self->scale_words || [];
		my $gsnum = @$gs;  # number of grids, b4 others are added in.
		my $vallab = undef;
		if ($qtype ==26){
			my $ps = $self->pulldown || [];
			$ps = [@$ps];
			shift @$ps;
			my $ct=1;
			$vallab->{$ct++} = $_ foreach @$ps;
		}
		my $oths = $self->others;
		my $oth_txt = $self->other_text || 'Other';
		# print "Found an others=$oths".Dumper $self if $oths;
		if ($qtype ==25){
			#others affects the data for grid_multi.
			push @$gs,"$oth_txt $_" foreach 1..$oths;
		}
		my $count = 1;
		my $stemnam = $self->varname || $dlab;
		my $stemlab = $self->varlabel || $self->prompt;
		my $anams = $self->a_varnames;
		my $alabs = $self->a_varlabels;
		$gnams = $self->g_varnames;
		my $glabs = $self->g_varlabels;
		foreach my $a (1..@$as){
			my $adx = $a-1;
			my $axt = undef;
			my $x1= undef;
			my $an = undef;
			if (@$as>1){
				$an = $alabs->[$adx] || $as->[$adx];
				$axt = $anams->[$adx] || "$a" if @$as >1;
				$x1 = 'x' if ($stemnam =~ /\d$/) and ($axt =~ /^\d/);
				$x1 = 'x' if ($stemnam =~ /[A-Za-wy-z]$/) and ($axt =~ /^[A-Za-wy-z]/);
			}
			foreach my $g (1..@$gs){
				my $gdx = $g-1;
				my $x2='';
				my $gxt='';
				my $gn = undef;
				if (@$gs>1){
					$gn = $glabs->[$gdx] || $gs->[$gdx];
					$gxt = $gnams->[$gdx] || $g;
					$x2 = 'x' if ($axt =~ /\d$/) and ($gxt =~ /^\d/);
					$x2 = 'x' if ($axt =~ /[A-Za-wy-z]$/) and ($gxt =~ /^[A-Za-wy-z]/);
				}
				push @vars,"$stemnam$x1$axt$x2$gxt";
				push @keys,"_Q$rkey";
				push @specify,undef;
				push @spec_after,undef;
				push @maskpos, {mask=>$adx,grid=>$gdx};
				if ($qtype==25){
					push @valiftrue,$g;
					$vallab={$g=>"$an-$gn"};
					push @varlab,"$an-$gn-$stemlab";
				}elsif ($qtype==26){
					push @varlab,"$an-$gn-$stemlab";
					my $valif ='!0' if $vallab;
					push @valiftrue,$valif;
				}else{
					push @valiftrue,undef;
					push @varlab,"$an-$gn-$stemlab";
				}
				if ($vallab){
					push @vallab,{%$vallab};
				}else{
					push @vallab,$vallab;
				}
				push @pos,$count++-1;
			}
			if ($qtype == 25){
				#grid_multi now does others, 
				foreach my $oth (1..$oths){
					push @vars,"$stemnam$axt"."_o$oth";
					push @specify,undef;
					push @spec_after,0;
					push @maskpos,{};
					push @pos,0;
					push @valiftrue,undef;
					push @varlab,"Specifier-$an-other $oth-$stemlab";
					push @vallab,undef;
					my $gnum = $gsnum+$oth;
					if ($oth==1){
						push @keys,"_Q$rkey-$adx";
					}else{
						push @keys,undef;
					}
				}
			}
		}
	}elsif ($qtype==14){
		my $as = $self->attributes || [];
		my $gs = $self->scale_words || [];
		unless (@$gs){
			my $scale=$self->scale;
			if ($scale >1){
				$gs=[1..$scale];
			}elsif ($scale <1){
				$gs=[reverse(1..abs($scale))];
			}
		}
		if (my $dk = $self->dk){
			push @$gs,$dk;
		}
		my $varl = {};
		my $ct = 1;
		$gnams = $self->a_varnames;
		# Fixing this bug causes incompatibility with WUS102.
		# We need to fix it.
		$gnams = $self->g_varnames;
		my $glabs = $self->g_varlabels;
		foreach (@$gs){
			$_ ||= $gnams->[$ct-1];
			$varl->{$ct} = $glabs->[$ct-1] || $_ ;
			$ct++;
		}
		# Others in a grid puts an other option in, even if others=2.
		# Other Data is saved, but not reloaded into the form
		if ($self->others){
			$varl->{$ct++} = $self->other_text || 'Other (specify)';
		}
		if (my $lw = $self->left_word){
			my $mw = $self->middle;
			$varl->{1} = "$gs->[0] $lw $mw";
		}
		if (my $rw = $self->right_word){
			my $l = $ct-1;
			$l -=1 if $self->dk;
			$l -=1 if $self->others;
			my $mw = $self->middle;
			my $gs_x = -1;
			$gs_x = -2 if $self->dk;
			$varl->{$l} = "$gs->[$gs_x] $rw $mw";
		}
		my $stemlab = $self->varlabel || $self->prompt;
		my $stemnan = $self->varname || $dlab;
		my $anams = $self->a_varnames;
		my $alabs = $self->a_varlabels;
		foreach my $a (1..@$as){
			my $adx = $a-1;
			my $an = $alabs->[$adx] || $as->[$adx];
			my $ext = '';
			if (@$as >1){
				$ext ="$a" if @$as >1;
				$ext = $anams->[$adx] if $anams->[$adx];
			}
			my $x = 'x' if ($stemnan =~ /\d$/) and ($ext =~/^\d/);
			$x = 'x' if ($stemnan =~ /[A-Za-wy-z]$/) and ($ext =~/^[A-Za-wy-z]/);
			## This would also be nice, but it will orphan WUS102
			# we are ignoring WUS102.  see other WUS102 comment.
			$x = '' if scalar(@$as) == 1;
			push @vars,"$stemnan$x$ext";
			push @keys,"_Q$rkey";
			if ($self->others){ # The engine only does 1 other in  a grid.
				push @spec_after,$ct-2;
				push @specify,["ext_gridQ${rkey}_${adx}other"];
			}else{
				push @spec_after,undef;
				push @specify,undef;
			}
			push @vallab,{%$varl};
			push @varlab,"$an-$stemlab";
			push @pos,$adx;
			push @valiftrue,'+1';
			push @maskpos,{mask=>$adx};
		}
		foreach my $sp (reverse 1..$self->specify_n){
			my $an = @$as-$sp;
			my $an_human = $anams->[$an] || $an+1;
			push @vars,$stemnan."x${an_human}_s";
			push @keys,"_Q$rkey-$an";
			push @specify,undef;
			push @pos,0;
			push @valiftrue,undef;
			my $vlab = $alabs->[$an] || $as->[$an];
			push @varlab, "Specify-$vlab-$stemlab";
			push @vallab,undef;
			push @spec_after,undef;
			push @maskpos,undef;
		}
	}elsif (grep $qtype==$_,21,19){ # tally , ageonset.
		my $as = $self->attributes || [];
		my $ps = $self->pulldown || [];
		$ps = [@$ps];
		shift @$ps if $qtype==19;
		my $varlab = {};
		my $ct=1;
		$ct=0 if $qtype==21;
		$varlab->{$ct++} = $_ foreach @$ps;
		my $pts = 2;
		$pts=4 if $qtype ==21;
		my $pexts = {1=>'a',2=>'c'};
		$pexts = {1=>'oa',2=>'oc',3=>'ra',4=>'rc'} if $qtype ==21;
		my $sections = $self->sections;
		my $no_rec = $self->no_recency;
		my $stemnam = $self->varname || $dlab;
		my $stemlab = $self->varlabel || $self->prompt;
		my $anams = $self->a_varnames;
		my $alabs = $self->a_varlabels;
		my $last_onset_only = $self->last_onset_only();
		if (@$as==2 and !$anams->[0] and !$anams->[1]){
			$anams->[0]='o' if $as->[0]=~ /FIRST|ONS/i;
			$anams->[1]='r' if $as->[1]=~ /LAST|REC/i;
		}
		if ($qtype == 21){
			my $var_pref = $self->var_prefix;
			my ($r_ext) = $dlab =~ /(_R\d+)$/;
			if (!$self->{_tmp}->{$var_pref}->{$r_ext}){
				foreach my $a (1..@$as){
					my $adx = $a-1;
					my $aext = $a;
					$aext = $sections->[$adx] if $sections->[$adx];
					# my $x1 = 'x' if ($var_pref =~ /\d$/) and ($aext =~ /^\d/);
					my $x1 = '_' unless $var_pref =~/_$/;
					push @vars,"$var_pref$x1$aext$r_ext";
					push @keys,lc("v$var_pref$aext$r_ext");
					push @specify,undef;
					push @pos,0;
					push @valiftrue,undef;
					push @varlab,"Circled-$aext-$stemlab";
					push @vallab,{1=>'Circled',0=>'Not Circled'};
					push @spec_after,undef;
					push @maskpos,undef;
					push @sections,$aext;
				}
				$self->{_tmp}->{$var_pref}->{$r_ext}++;
			}
		}
		my $pos =0;
		foreach my $a (1..@$as){
			my $adx = $a-1;
			my $an = $alabs->[$adx] || $as->[$adx] if (@$as>1) or !$no_rec;
			my $aext = $a if @$as >1;
			$aext = $sections->[$adx] if $sections->[$adx];
			$aext = $anams->[$adx] if $anams->[$adx];
			my $x1 ='';
			$x1 = 'x' if ($stemnam =~ /\d$/) and ($aext =~/^\d/);
			$x1 = 'x' if ($stemnam =~ /[A-Za-wy-z]$/) and ($aext =~/^[A-Za-wy-z]/);
			foreach my $p (1..$pts){
				if ($no_rec and ($p==2 or $p==4)){
					# no data for no_recency
				}elsif ($last_onset_only and !($p % 2) and ($a != @$as)){
					# no data for even $p when in not last Attribute when last_onset_only is on.
				}else{
					my $pext = $pexts->{$p} if (@$as>1) or !$no_rec;
					# my $pext = "x$p" if (@$as>1) or !$no_rec;
					my $x2;
					if ($aext eq ''){
						$x2 = 'x' if ($stemnam =~ /\d$/) and ($pext =~/^\d/);
						$x2 = 'x' if ($stemnam =~ /[A-Za-wy-z]$/) and ($pext =~/^[A-Za-wy-z]/);
					}else{
						$x2 = 'x' if ($aext =~ /\d$/) and ($pext =~/^\d/);
						$x2 = 'x' if ($aext =~ /[A-Zbd-wy-z]$/) and ($pext =~/^[A-Zbd-wy-z]/);
					}
					push @vars,"$stemnam$x1$aext$x2$pext";
					push @pos,$pos;
					push @specify,undef;
					push @keys,"_Q$rkey";
					push @spec_after,undef;
					push @maskpos, {mask=>$adx};
					my $time;
					if ($qtype==21){
						# die Dumper $self;
						$time='First ';
						$time='Last ' if grep $p==$_,3,4;
						push @sections,$_ if $_ = $sections->[$adx];
					}
					if ($p==2 or $p==4){
						push @vallab,{%$varlab};
						push @varlab,$time."Code-$an-$stemlab";
						my $valif = '!0' if $qtype==19;
						push @valiftrue,$valif;
					}else{
						push @valiftrue,undef;
						push @vallab,undef;
						my $age = 'Age-' if (@$as>1) or !$no_rec;
						my $minus = '-' if $an;
						push @varlab,$time."$age$an$minus$stemlab";
					}
				}
				$pos++;
			}
		}
	}elsif ($qtype==7){
		if (my $fbase = $self->external()){
			if (my $page_inf = $ext_info->{pages}->{$fbase}){
				# handle externals;
				# print Dumper $page_inf;
				my $names = $page_inf->{names};
				my $values = $page_inf->{values};
				my $labels = $page_inf->{labels}; ## These labels are value labels, not variable labels.
				foreach my $name (@$names){
					# These will already be in the data file.
					next if grep lc ($name) eq $_,qw(email id sid token status survey_id ipaddr year month weekday hour min lastq version modified modified_s);
					push @vars,$name;
					push @pos,0;
					push @specify,undef;
					push @keys,"ext_$name";
					push @spec_after,undef;
					push @valiftrue,undef;
					push @maskpos,undef;
					my $desc = $page_inf->{options}->{$name}->{title};
					$desc = "$desc-" if $desc;
					push @varlab,$desc.$self->pretty_prompt;
					push @types,$page_inf->{options}->{$name}->{type};
					push @lengths,$page_inf->{options}->{$name}->{maxlength} || 
						$page_inf->{options}->{$name}->{size};
					if (my $labs = $labels->{$name}){
						push @vallab,$labs;
					}elsif( my $vals =  $values->{$name}){
						my $labs = {};
						foreach my $v (@$vals){
							next if $v =~ /ext_/;
							$labs->{$v}=$v ;
						}
						push @vallab,$labs;
					}else{
						push @vallab,undef;
					}
				}
			}
		}
	}elsif (grep $qtype == $_,7,8,20,22,27,28){
		# Do nothing.
	}else{
		print "no setDataInfo action for $dlab $qtype\n";
	}

	# Programmer sanity check.
	my $vars = @vars;
	die "Insanity with $dlab type $qtype with keys ".Dumper (\@keys). ' vars='.Dumper (\@vars) unless @keys == $vars;
	die "Insanity with $dlab type $qtype with specify ".Dumper (\@specify). ' vars='.Dumper (\@vars) unless @specify == $vars;
	die "Insanity with $dlab type $qtype with pos ".Dumper (\@pos). ' vars='.Dumper (\@vars) unless @pos == $vars;
	die "Insanity with $dlab type $qtype with valiftrue ".Dumper (\@valiftrue). ' vars='.Dumper (\@vars) unless @valiftrue == $vars;
	die "Insanity with $dlab type $qtype with varlab ".Dumper (\@varlab). ' vars='.Dumper (\@vars) unless @varlab == $vars;
	die "Insanity with $dlab type $qtype with vallab ".Dumper (\@vallab). ' vars='.Dumper (\@vars) unless @vallab == $vars;
	die "Insanity with $dlab type $qtype with spec_after ".Dumper (\@spec_after). ' vars='.Dumper (\@vars) unless @spec_after == $vars;
	die "Insanity with $dlab type $qtype with maskpos ".Dumper (\@maskpos). ' vars='.Dumper (\@vars) unless @maskpos == $vars;
	die "Insanity with $dlab type $qtype with sections ".Dumper (\@sections). ' vars='.Dumper (\@vars) if @sections && (@sections != $vars);
	die "Insanity with $dlab type $qtype with types ".Dumper (\@types). ' vars='.Dumper (\@vars) if @types && (@types != $vars);
	die "Insanity with $dlab type $qtype with lengths ".Dumper (\@lengths). ' vars='.Dumper (\@vars) if @lengths && (@lengths != $vars);
	my $l = [];
	foreach my $v (0..$#vars){
		next unless $vars[$v] ne '';
		my $h = {
			var=>$vars[$v],
			rkey=>$keys[$v],
			pos=>$pos[$v],
		};
		$h->{specify} = $_ if $_= $specify[$v];
		$h->{val_if_true} = $_ if $_= $valiftrue[$v];
		$h->{var_label} = $_ if $_= $varlab[$v];
		$h->{val_label} = $_ if $_= $vallab[$v];
		# Sometimes autocode_after will be a 0.
		$_= $spec_after[$v];
		$h->{autocode_after} = $_ if $_ ne '';
		$h->{section} = $_ if $_ = $sections[$v];
		$h->{type} = $_ if $_ = $types[$v];
		$h->{length} = $_ if $_ = $lengths[$v];
		if (my $mhsh = $maskpos[$v]){
			foreach my $inc (qw(mask grid)){
				my $method = $inc.'_include';
				delete $mhsh->{$inc} unless $self->$method;
			}
			$h->{maskpos} = $mhsh if %$mhsh;
		}
		push @$l,$h;
	}
	$self->{_dataInfo}  = $l;
}
sub getDataInfo{
	my $self = shift;
	my %args = @_;
	my $codes = $args{codes};
	my $rf_code = $args{rf_code};
	my $dk_code = $args{dk_code};
	# print "Here ".Dumper $codes;
	my $ext_info = $args{ext_info};
	$self->setDataInfo(ext_info=>$ext_info) unless exists $self->{_dataInfo};
	if ($codes){
		foreach my $ci (@{$self->{_dataInfo}}){
			my $vallabs;
			my $col = $ci->{var};
			if ($vallabs = $ci->{val_label}){
				if (my $aca = $ci->{autocode_after}){
					foreach my $k (keys %$vallabs){
						delete $vallabs->{$k} if $k > $aca;
					}
				}
			}
			if ($ci->{specify}){
				$vallabs ||={};
				if (my $cds = $codes->{$col}){
					$vallabs->{$cds->{$_}} = $_ foreach keys %$cds;
				}
			}
			if ($vallabs){
				$vallabs->{$rf_code} = "Refused" if $rf_code;
				$vallabs->{$dk_code} = "Don't Know" if $dk_code;
			}
			$ci->{val_label} = $vallabs if $vallabs;
		}
	}
	return $self->{_dataInfo};
}

sub chk_direct_data_use {
	my $self = shift;
	my %args = @_;
	my $e = $args{err} || new TPerl::Error;
	my $qbylab = $args{qbylab};
	# print Dumper $self->code if $self->code;
	return 1 unless my $codes = $self->code;
	# print Dumper $self if $self->label eq'A11A_pre';
	foreach my $l (@$codes){
		if ( my ($lab) = $l =~ /[gs]et_data\(.*'Q(\S+?)'/ ){
			$lab =~ s/-\d+$// ; #text questions are dumb...
			$lab = uc $lab;
			# print "lab=$lab\n" if $self->label eq'A11A_pre';
			$e->E(sprintf "Cannot access data from Q$lab in %s'$l':No such question",$self->label)
				unless $qbylab->{$lab};
		}
	}
}

# sub data_headings {
# 	my $self = shift;
# 
# 	my @data = ();
# 	my $qtype = $self->qtype;
# 	my $dlab = $self->label;
# 	$dlab = "q$dlab" if $dlab =~ /^\d/ ;
# 
# 	if ($qtype == 3){
# 		push @data,$dlab;
# 	}elsif (grep $qtype == $_,24,25,26,29){
# 		my ($ol,$il);
# 		if (grep $qtype == $_,24,25,29 ){
# 			$ol = scalar(@{$self->attributes});
# 			$il = scalar(@{$self->scale_words});
# 		}else{
# 			$il = scalar(@{$self->attributes});
# 			$ol = scalar(@{$self->scale_words});
# 		}
# 		foreach my $o (1..$ol){
# 			foreach my $i (1..$il){
# 				push @data, $dlab .'x'. $o . 'x' .$i;
# 			}
# 		}
# 	}elsif (grep $qtype == $_,21,19){
# 		my $pnts = 4; # 4 bits per A
# 		$pnts = 2 if $qtype == 19;
# 		foreach my $a (1..scalar(@{$self->attributes})){
# 			foreach my $pnt (1..$pnts){
# 				push @data, join 'x',$dlab,$a,$pnt;
# 			}
# 		}
# 	}else{
# 		my $atts = scalar(@{$self->attributes});
# 		if ($atts == 1 ){
# 			push @data ,$dlab;
# 		}else{
# 			push @data, $dlab."x$_" foreach 1..$atts;
# 		}
# 	}
# 	return {data=>\@data};
# }

1;
