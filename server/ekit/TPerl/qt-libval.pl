#!/usr/bin/perl
## $Id: qt-libval.pl,v 2.12 2011-07-26 20:54:21 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl validation library for QT project
#
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the incoming data
#
sub qt_validate
	{
	&subtrace('qt_validate');
#	&qt_dumpinput;
	my $startq = $start_q_no;
	my $endq = $q_no;
	my $br = &input('browser');
	if ($br eq 'ie4')
		{
	    my $filename = "$qt_root/$resp{'survey_id'}/config/qlabels.pl";
	  	&my_require ($filename,1);
# Set up the loop here... 
		$startq = $q_no;
		$endq = $numq;
		}
	&debug("Processing for q's $startq to $endq");
	my $j;
	for ($q_no = $startq; $q_no <= $endq; $q_no++)
		{
#
# Retrieve the specific stuff for this question
#
		$resp{'browser'} = &input('browser');
		$resp{'score'} = &input('score');
		&debug("Survey = $resp{'survey_id'}");
		$SelectVar = '';		# Get rid of this later ???
		$selectvar = '';
		$ResultVar = '';		# Get rid of this later ???
		$resultvar = '';
		$random_options = 0;
		$rank_grid = 0;
		undef $mask_include;
		undef $mask_update;
		undef $mask_exclude;
		undef $mask_reset;
#		undef $no_validation;
		undef $fixed;
		undef $grid_type;
		undef $grid_exclude;
		undef $grid_include;
		undef $execute;
		undef $external;			# Make sure this does not carry forward
		undef $autoselect;
	    my $filename = "$qt_root/$resp{'survey_id'}/config/q$q_no.pl";
	  	&my_require ($filename,1);
		
		if ($mask_reset ne '')
			{
			&qt_mask_reset($mask_reset,$others);
			}
		next if ($autoselect ne '');
#
# Do unmasking now to adjust the @vars array
#
		&do_masking('validation');
#
# Do ungriding
#
		&do_griding;
		&debug("qtype=$qtype");
		my $i = 0;
#		$ans = '';
		
		&val_number if ($qtype == QTYPE_NUMBER);
		&val_multi if ($qtype == QTYPE_MULTI);
	    &val_one if ($qtype == QTYPE_YESNO);
	    &val_one if ($qtype == QTYPE_ONE_ONLY);	
	    &val_written if ($qtype == QTYPE_WRITTEN);
	    &val_number if ($qtype == QTYPE_PERCENT);
#	    &val_instruct if ($qtype == QTYPE_INSTRUCT);		# No validation required for instruction qtype
#	    &val_eval if ($qtype == QTYPE_EVAL);				# No validation required for evaluator qtype
	    &val_number if ($qtype == QTYPE_DOLLAR);
	    &val_rating if ($qtype == QTYPE_RATING);
	    &val_unknown if ($qtype == QTYPE_UNKNOWN);
	    &val_firstm if ($qtype == QTYPE_FIRSTM);
	    &val_compare if ($qtype == QTYPE_COMPARE);
	    if ($qtype == QTYPE_GRID)
	    	{
	    	my $n = &grid_include;
	    	&val_grid if ($grid_type eq '');
	    	&val_grid_multi if ($grid_type eq 'multi');
	    	&val_grid_pulldown if ($grid_type eq 'pulldown');
	    	&val_grid_text if ($grid_type eq 'text');
	    	&val_grid_number if ($grid_type eq 'number');
	    	}
	    &val_opens if ($qtype == QTYPE_OPENS);
	    &val_date if ($qtype == QTYPE_DATE);
	    &val_yesnowhich if ($qtype == QTYPE_YESNOWHICH);
	    &val_weight if ($qtype == QTYPE_WEIGHT);
	    &val_ageonset if ($qtype == QTYPE_AGEONSET);
	    &val_tally if ($qtype == QTYPE_TALLY);
	    &val_cluster if ($qtype == QTYPE_CLUSTER);
	    &val_tally_multi if ($qtype == QTYPE_TALLY_MULTI);
    	&val_grid_text if ($qtype == QTYPE_GRID_TEXT);
    	&val_grid_multi if ($qtype == QTYPE_GRID_MULTI);
    	&val_grid_pulldown if ($qtype == QTYPE_GRID_PULLDOWN);
# none for perl_code
# none for repeater (only a virtual qtype)
    	&val_grid_number if ($qtype == QTYPE_GRID_NUMBER);
    	&val_slider if ($qtype == QTYPE_SLIDER);
    	&val_rank if ($qtype == QTYPE_RANK);
	    
		&debug("Response for Q$q_no = ".get_data($q,$qlab,$qlab));
	    my $filename = "$qt_root/$resp{'survey_id'}/config/$execute";
		&my_require($filename,1) if ($execute ne '');
		delete $resp{"rf_$qlab"} if ($input{"rf_$qlab"} eq '');		# Make sure these are cleared if not present
		delete $resp{"dk_$qlab"} if ($input{"dk_$qlab"} eq '');
		delete $resp{"mn_$qlab"} if ($input{"mn_$qlab"} eq '');
		}
	keep_external_data();
	$q_no = $endq;
	$resp{'lastq'} = max($endq,$resp{'lastq'});
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Tally data
#
sub val_tally
	{
	&subtrace();
	my $j = 0;
	my $gscore = 0;
	my $counter = 0;
	my $ans = '';
	my $cletter = '';
	my $letter = '';
	my $fini = 0;
	foreach (@vars)
		{
		my $thisrow = 0;
		my $k = 0;
		my $thing;
		foreach $thing ("ONS_$j","sons$j","REC_$j","srec$j")
			{
			my $objname = "tally${qlab}$thing";
			my $this = trim(&input($objname));
			my $letter = uc(substr($sections[$j],0,1));
			$fini = 0 if ($letter ne $cletter);
			if (($this ne '') && ($k == 0))
				{
				if ($letter ne $cletter)
					{
					$counter++;
					$fini = 1;
					}
				elsif (!$fini)
					{
					$counter++;
					$fini = 1;
					}
				}
			$cletter = $letter;
			$ans .= $array_sep if (($j > 0) || ($k > 0));
# Filter out junk
			$this =~ s/^0*([1-9]+)/$1/;			# Get rid of octal representation (leading 0's)
        	$this =~ s/[\\'`]//g;				# Just being defensive, it should only ever contain a number
       		$ans .= $this;
        	$gscore += $this;
        	$thisrow += $this;
        	$k++;
	        }
        &setvar($_,$thisrow);
	    $j++;
		}
	&setvar($selectvar,$counter);
	set_data($q,$q_no,$qlab, $ans);
   	&setvar("score_$qlab",$gscore);
	&endsub;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Tally data
#
sub val_tally_multi
	{
	&subtrace();
	my @results = ();
	my $j = 0;
	my $gscore = 0;
	my $counter = 0;
	my $ans = '';
	my $cletter = '';
	my $letter = '';
	my $fini = 0;
	foreach (@vars)
		{
		my $thisrow = 0;
		my $k = 0;
		my $thing;
		my $objname = "check${qlab}_$j";
		my $this = &input($objname);
		my $letter = uc(substr($sections[$j],0,1));
#			&debug("Tally multi ans='$this' letter=$letter, last letter=$cletter");
		$fini = 0 if ($letter ne $cletter);
		if ($this ne '')
			{
			if ($letter ne $cletter)
				{
				$counter++;
				$fini = 1;
				}
			elsif (!$fini)
				{
				$counter++;
				$fini = 1;
				}
			push @results,$sections[$j];
			}
		setvar($_,($this ne '') ? 1 : 0);
		$cletter = $letter;
		$ans .= $array_sep if ($j > 0);
   		$ans .= ($this ne '') ? $this : '0';
    	$gscore += $this;
	    $j++;
		}
	&setvar($selectvar,$counter);
	&setvar_str($qlab,join($list_sep,@results));
	set_data($q,$q_no,$qlab, $ans);
   	&setvar("score_$qlab",$gscore);
	&endsub;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Cluster data
#
sub val_cluster
	{
	&subtrace();
	
	&endsub;
	}
	
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Multi-select data
#
sub val_multi
	{
	&subtrace();
	my @ans = @skips;
	my $k = 0;
	my $cnt = 0;
	my $result = '';
#	&debug("options=".$#options);
	foreach (@options)
		{
#				&debug($k);
		my $chick = "check${qlab}_$k";
		$ans[$k] = (&input($chick) > 0) ? '1' : '0';
		if ($force_select ne '')
			{
			$ans[$k] = '1' if ($k == $force_select);
			}
       	&unsetvalue($setvalues[$k]);	# Set the values as required
		if ($ans[$k])
			{
			$cnt++;
			$result = $result.$list_sep if ($cnt != 1);
			my $o = &subst($options[$k]);
			$result .= $o;
			$resp{'score'} += $scores[$k];
           	&setvalue($setvalues[$k]);	# Set the values as required
			}
		&debug("Multi($chick)=$ans[$k]");
		&setvar($vars[$k],$ans[$k]);			# This needs to be done after unmasking
		$k++;
		}
	undef $force_select;
#
# Allow for 'others'
#
	if ($others > 0)
		{
		for (my $j = 0; $j < $others; $j++)
			{
			$ans[$k] = (&input("check${qlab}_$k") > 0) ? '1' : '0';
			my $this = &input("check${qlab}_other$j");
			my $opt = "$qlab-$j";
			set_data($q,$opt,$opt,'');
			if ($this ne '')
				{
# Filter out junk
				$this =~ s/[\\'`]//g;
				set_data($q,$opt,$opt,$this);
				$ans[$k] = 1;					# Force answer on
				$result = $result.$list_sep if ($cnt != 0);
				$result .= $this;
				my $m = $k+1;
				my $key = lc($qlab)."x$m";
#				set_data($q,$key,$key,$this);
				&setvar_str($key,$this);
				}
			$cnt++ if ($ans[$k]);
			$k++;
			}
		}
#
# Allow for 'others'
#
	elsif ($specify_n > 0)
		{
		for (my $j = $#options; $j > $#options-$specify_n; $j--)
			{
			my $this = &input("other${qlab}_$j");
			my $opt = "$qlab-$j";
			set_data($q,$opt,$opt,'');
			if ($this ne '')
				{
# Filter out junk
				$this =~ s/[\\'`]//g;
				set_data($q,$opt,$opt,$this);
				$result = $result.$list_sep if ($cnt != 0);
				$result .= $this;
				my $m = $j+1;
				my $key = lc($qlab)."x$m";
#				set_data($q,$key,$key,$this);
				setvar_str($key,$this);
				}
			}
		}
#
# We have the data, do we need to unmask it ?
#
	if (0)#($mask_include ne '') || ($mask_exclude ne ''))
		{
		my ($mask_name,$maskt_name);
		my @old = @ans;
		my @newans = ();
		my $maskin = ($mask_include ne '');
		my $mask_name = '';
		if ($maskin)	# Masking in
			{
			$mask_name = &qt_get_mask($mask_include);
			$maskt_name = &qt_get_maskt($mask_include);
			}
		else			# Masking out
			{
			$mask_name = &qt_get_mask($mask_exclude);
			$maskt_name = &qt_get_maskt($mask_exclude);
			}
		&debug ("Unmasking mask $mask_name (inc=$mask_include, exc=$mask_exclude)");
		my (@mask) = split(/$array_sep/,$resp{$mask_name});
		my (@maskt) = split(/$array_sep/,$resp{$maskt_name});
		my $ix = 0;
		for (my $i=0;$i<=$#ans;$i++)
			{
			$newans[$i] = 0;
			if ($mask[$i] == $maskin)
				{
				$newans[$i] = $ans[$ix++];
				}
			}
		debug("New answer is ".join($list_sep,@newans));
		@ans = @newans;
		}
#
# OK now update the response
#
	&setvar($SelectVar,$cnt);		# Save the counter		# Get rid of this later ???
	&setvar($selectvar,$cnt);		# Save the counter
	set_data($q,$q_no,$qlab,join($array_sep,@ans));
#
# This one breaks the way that variables are treated !!!
#
	$resp{$ResultVar} = $result if ($ResultVar ne '');		# Get rid of this later ???
	$resp{$resultvar} = $result if ($resultvar ne '');
	&setvar_str($qlab,&subst($result));
# !!!
	&qt_update_mask($mask_update,@ans);
	&endsub;
	}


#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Single-select data
#
sub val_one
	{
	&subtrace();
	my $pull_down = 0;
	$pull_down = 1 if (($one_at_a_time == 0) && ($others != 1) && ($specify_n eq '') && ($#options >= 3) && ($force_expand == 0));
	my $ans = '';
	if ($pull_down)
		{
		$ans = &input('select'.$qlab);
		set_data($q,$q_no,$qlab,$ans);
		}
	else
		{
		$ans = &input('radio'.$qlab);
		set_data($q,$q_no,$qlab,$ans);
		}
	if ($ans ne '')
		{
		&setvar_str($qlab,&subst($options[$ans]));
		my $ix = $ans - 1;
		$resp{'score'} += $scores[$ix];
		&debug ("radio=$ans pulldown=$pull_down");
#
# Reset all variables to 0 first
#
		foreach (@vars)
			{
			&setvar($_,0);
			}
		&setvar($vars[$ans],1);			# Set the one selected
	   	&setvalue($setvalues[$ans]);	# Set the values as required
	   	&setvar("score_$qlab",1);
		}
#
# Allow for 'others'
#
	if ($others == 1)
		{
		my $this = &input("radio${qlab}_other");
        if ($this ne "")
        	{
        	my $opt = "$qlab-0";
        # Filter out junk
        	$this =~ s/[\\'`]//g;
			set_data($q,$opt,$opt,$this);
			&setvar_str($qlab,$this) if ($others && ($ans > $#vars));
			&setvar_str($qlab,$this) if ($specify_n && ($ans == $#vars));
        	}
		}
	elsif ($specify_n ne '')
		{
		for (my $no=$#vars-$specify_n;$no<=$#vars;$no++)
			{my $x = &input("radio${qlab}_${no}_other");}		# Read them all to stop them ending up as externals
		my $no = $ans;
		my $this = &input("radio${qlab}_${no}_other");
        if ($this ne "")
        	{
        	my $opt = "$qlab-0";
        # Filter out junk
        	$this =~ s/[\\'`]//g;
			set_data($q,$opt,$opt,$this);
			&setvar_str($qlab,$this) if ($others && ($ans > $#vars));
			&setvar_str($qlab,$this) if ($specify_n && ($ans == $#vars));
        	}
		}
	if ($ans ne '')
		{
		&qt_update_mask_single($mask_update,$ans);			# This should be here ??
		}
	&endsub;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Number data
#
sub val_number
	{
	&subtrace();
	my $i = 0;
	my $ans = '';
#???	&setvar($vars[$resp{$q_no}],1);		# Set the one selected
	foreach (@vars)
		{
		$ans = $ans.$array_sep if ($i > 0);
		my $this = &input("number${qlab}_$i");
		$this =~ s/^0*([1-9]+)/$1/ unless $allow_leading_0;
#		$this = '0' if ($this eq ''); 
		&debug("this[$i]=$this");
		$ans = $ans.$this;
		&setvar($_,$this);
		$i++;
		}
	$resp{lc($qlab)} = $ans if ($i == 1);
	set_data($q,$q_no,$qlab,$ans);
	&qt_update_mask_number($mask_update,split(/===/,$ans));
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Open ended data
#
sub val_opens
	{
	&subtrace();
	my @ans = ();
	my $j = 0;
	my $selcnt = 0;
	my @stack = ();
	foreach (@options)
		{
		my $this = &input("opens${qlab}_$j");
		$this =~ s/\t/ /g;		# Remove tabs, because they mess up the data file
       	my $opt = "$qlab-$j";
# Filter out junk
       	$this =~ s/[\\'`]//g;
       	set_data($q,$opt,$opt,&subst($this));
       	&setvar_str($vars[$j],&subst($this));
        if ($this ne '')
        	{
        	$selcnt++;
        	push @stack,$this;
        	}
        $ans[$j++] = $this;
    	if ($#options > 0)
    		{
    		my $qresp = lc($qlab);
    		$qresp .= "x$j";
			&setvar_str($qresp,&subst($this));
			}
		}
	&setvar("sel$qlab",$selcnt);
	&qt_update_mask_opens($mask_update,@ans);
	if ($#stack == 1)
		{
		&setvar_str($qlab,join(" and ",@stack));
		}
	elsif ($#stack > 1)
		{
		my $last1 = pop @stack;
		&setvar_str($qlab,join($list_sep,@stack)." and $last1");
		}
	else
		{
		&setvar_str($qlab,join($list_sep,@stack));
		}
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Regular grid data
#
sub val_rating
	{
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Regular grid data
#
sub val_grid
	{
	&subtrace();
	my $j = 0;
	my $gscore = 0;
	my @ans = ();
	my @counter = ();
	foreach (@vars)
		{
		my $this = &input("grid${qlab}_$j");
		$counter[$this]++ if ($this ne '');
	    # Filter out junk
    	$this =~ s/[\\'`]//g;
    	$gscore += $this+1;
    	&setvar($_,$this+1);
    	$ans[$j] = $this;
		my $x = $#options + 1 - $j;		
    	if (($specify_n ne '') && ($specify_n >= ($x)))
    		{
			my $thing = &input("grid${qlab}_other$j");
			set_data($q,$q_no,"$qlab-$j",$thing);
			my $m = $j+1;
			my $key = lc($qlab)."x$m";
			setvar_str($key,$thing);
    		}
       	&unsetvalue($setvalues[$j]);	# Set the values as required
		my @flags = split(/,/,$true_flags);
		if ($#flags != -1)
			{
			&setvalue($setvalues[$j]) if ($flags[$this]);
			}
		else
			{
			&setvalue($setvalues[$j]) if ($this == 1);
	        }
    	$j++;
		}
	set_data($q,$q_no,$qlab,join($array_sep,@ans));
	if ($selectvar ne '')
		{
		for (my $j=0;$j<abs($scale)+$others;$j++)
			{
			my $k = $j + 1;
			&setvar($selectvar."_$k",($counter[$j] eq '') ? 0 : $counter[$j]);
			}
		}
	&qt_update_mask_grid($mask_update,@ans);
   	&setvar("score_$qlab",$gscore);
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the grid text data
#
sub val_grid_text
	{
	&subtrace();
	my $j = 0;
	my $k = 0;
	my $gscore = 0;
	my @counter = ();
	my $ans = '';
	my $result = '';
	my $sofar;
	foreach (@vars)
		{
   		$sofar = '';
   		for ($k=0;$k<abs($scale);$k++)
   			{
			$ans = $ans.$array_sep if (($j > 0) || ($k > 0));
			my $this = &input("grid${qlab}_${j}_${k}");
			$ans .= $this;
			$sofar .= $list_sep if (($sofar ne '') && ($this ne ''));
			$sofar .= $this;
			}
       	&setvar($_,$sofar);
		$result .= $list_sep if (($result =~ /[^,]$/) && ($sofar ne ''));
		$result .= $sofar;
        $j++;
		}
	set_data($q,$q_no,$qlab,$ans);
# ??? This really does not look right, as $sofar is out of scope here...
   	&setvar_str($qlab,$sofar);
	if ($selectvar ne '')
		{
		for ($j=0;$j<abs($scale);$j++)
			{
			$k = $j + 1;
			&setvar($selectvar."_$k",($counter[$j] eq '') ? 0 : $counter[$j]);
			}
		}
   	&setvar("score_$qlab",$gscore);
	&setvar_str($qlab,&subst($result));
# Not so straightforward, as we have matrix data here...
#	&qt_update_mask_text($mask_update,split(/$list_sep/,$ans));
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the grid number data
#
sub val_grid_number
	{
	&subtrace();
	my $j = 0;
	my $k = 0;
	my $gscore = 0;
	my @counter = ();
	my $ans = '';
	my $result = '';
	my $sofar;
	foreach (@vars)
		{
   		$sofar = '';
   		for ($k=0;$k<abs($scale);$k++)
   			{
			$ans = $ans.$array_sep if (($j > 0) || ($k > 0));
			&debug(qq{gn=grid${qlab}_${j}_${k}});
			my $this = &input("grid${qlab}_${j}_${k}");
			$ans .= $this;
			$sofar .= $list_sep if (($sofar ne '') && ($this ne ''));
			$sofar .= $this;
			}
       	&setvar($_,$sofar);
		$result .= $list_sep if (($result =~ /[^,]$/) && ($sofar ne ''));
		$result .= $sofar;
        $j++;
		}
	set_data($q,$q_no,$qlab,$ans);
   	&setvar_str($qlab,$sofar);
	if ($selectvar ne '')
		{
		for ($j=0;$j<abs($scale);$j++)
			{
			$k = $j + 1;
			&setvar($selectvar."_$k",($counter[$j] eq '') ? 0 : $counter[$j]);
			}
		}
   	&setvar("score_$qlab",$gscore);
	&setvar_str($qlab,&subst($result));
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Multi-select grid data
#
sub val_grid_multi
	{
	&subtrace();
	my $j = 0;
	my $k = 0;
	my $m = 0;
	my $gscore = 0;
	my @counter = ();
	my $ans = '';
	my %attr_sels = ();
	my $this;
	foreach (@vars)
		{
		my $n = $j + 1;
		my @grid_sels = ();
   		my $sofar = 0;
   		my $loop = abs($scale) + $others;
   		debug("grid_multi_loop=$loop");
   		for ($k=0;$k<$loop;$k++)
   			{
			$ans = $ans.$array_sep if (($j > 0) || ($k > 0));
   			$m = $k+1;
			$this = (&input("grid${qlab}_${j}_${m}") > 0) ? '1' : '0';
			$ans .= $this;
			push @grid_sels,$scale_words[$k] if ($this && ($scale_words[$k] ne ''));
			$attr_sels{$k} = [] if (!$attr_sels{$k});
			push @{$attr_sels{$k}},$options[$j] if ($this && ($options[$j] ne ''));
			$sofar += $this;
			}
    	if ($others)
    		{
			my $thing = &input("grid${qlab}_${j}_${m}other");
			set_data($q,$q_no,"$qlab-$j",$thing);
			$m = $j+1;
			push @grid_sels,$thing if ($this);
			my $key = lc($qlab)."x$m";
			setvar_str($key,$thing);
    		}
       	&setvar($_,$sofar);
        $j++;
		&setvar(qq{${qlab}_row$n},join($list_sep,@grid_sels));
		}
	set_data($q,$q_no,$qlab,$ans);
	if ($selectvar ne '')
		{
		for ($j=0;$j<abs($scale);$j++)
			{
			$k = $j + 1;
			&setvar($selectvar."_$k",($counter[$j] eq '') ? 0 : $counter[$j]);
			}
		}
	my $loop = abs($scale) + $others;
	for ($k=0;$k<$loop;$k++)
		{
		my $n = $k + 1;
		if ($attr_sels{$k})
			{
			&setvar(qq{${qlab}_col$n},join($list_sep,@{$attr_sels{$k}}));
			}
		}
   	&setvar("score_$qlab",$gscore);
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the grid pulldown data
#
sub val_grid_pulldown
	{
	&subtrace();
	my $j = 0;
	my $gscore = 0;
	my @counter = ();
	my $ans = '';
	foreach (@vars)
		{
		my $thisrow = 0;
		for (my $k=0;$k<abs($scale);$k++)
			{
			my $objname = "grid${qlab}_${j}_${k}";
			my $this = &input($objname);
			$counter[$this]++ if ($this ne '');
#			$this = "X_${j}_${k}" if ($this eq ''); 		# Shouldn't need to force a value, but we'll do it anyway
			$ans .= $array_sep if (($j > 0) || ($k > 0));
# Filter out junk
        	$this =~ s/[\\'`]//g;				# Just being defensive, it should only ever contain a number
       		$ans .= $this;
        	$gscore += $this;
        	$thisrow += $this;
	        }
        &setvar($_,$thisrow);
	    $j++;
		}
	if ($selectvar ne '')
		{
		for (my $j=1;$j<=$#pulldown;$j++)		# Go from first valid response
			{
			&setvar($selectvar."_$j",($counter[$j] eq '') ? 0 : $counter[$j]);
			}
		}
	set_data($q,$q_no,$qlab,$ans);
   	&setvar("score_$qlab",$gscore);
	&endsub;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Written data
#
sub val_written
	{
	&subtrace();
	my $this = &input("written${qlab}");
	$resp{"w_na${qlab}"} = &input("written_na${qlab}");		# Just grab the 'nothing to say' checkbox
	$resp{"w_opt_in${qlab}"} = &input("opt_in${qlab}");		# Just grab the 'nothing to say' checkbox
# Escape out unwanted characters in input string
	$this =~ s/\t/ /g;		# Remove tabs, because they mess up the data file
	if (!$old_written)
		{
		set_data($q,$q_no,$qlab,$this);					# We do not need to save open-ends in the data file !
		}
	else
		{
		&debug("Saving written response to file...");
		my $filename = "$data_dir/W${q_no}_$resp{seqno}.txt";
		&debug("...$filename");
		if (!open (DATA_FILE, "> $filename"))
    		{
    		&add2body("Can't create data file: $filename\n");
    		}
    	else
    		{
    		$this =~ s/\\n/\n/g;			# Fix line feeds
    		print DATA_FILE "$this\n";
    		close DATA_FILE;
    		}
    	}
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Date/time data
#
sub val_date
	{
	&subtrace();
	my $j = 0;
	my $ans = '';
	my $timestr = '';
	my $datestr = '';
	foreach (@vars)
		{
		$ans = $ans.$array_sep if ($j > 0);
		if ($show_date)
			{
			my $year = &input("year${qlab}_$j");
			my $month = &input("month${qlab}_$j");
			my $day = &input("day${qlab}_$j");
			$datestr = "$day/$month/$year";
			}
		if ($show_time)
			{
			my $hr = &input("hour${qlab}_$j");
			my $min = &input("min${qlab}_$j");
			my $sec = &input("sec${qlab}_$j");
			$timestr = "$hr:$min:$sec";
			}
		$ans = $ans."$datestr $timestr";
		$j++;
		}
	set_data($q,$q_no,$qlab,$ans);
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Incoming weight data
#
sub val_weight
	{
	&subtrace();
# Not supported yet !!
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the Age Onset data
#
sub val_ageonset
	{
	&subtrace();
	my $i = 0;
	my $ages = '';
	foreach (@vars)
		{
		$ages = $ages.$array_sep if ($i > 0);
		my $this = &input("age${qlab}_$i");
		$this =~ s/^0*([1-9]+)/$1/;
#		$this = '0' if ($this eq ''); 
		&debug("this age[$i]=$this");
		$ages .= $this;
		&setvar($_,$this);

		$ages = $ages.$array_sep;
		my $this = &input("onset${qlab}_$i");
		$this = '0' if ($this eq ''); 
		&debug("this onset[$i]=$this");
		&setvar("${_}o",$this);		# Update the onset as well
		$ages .= $this;
		$i++;
		}
	set_data($q,$q_no,$qlab,$ages);
	&endsub;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the slider data
#
sub val_slider
	{
	&subtrace();
	my $j = 0;
	my $gscore = 0;
	my @ans = ();
	my @dkans = ();
	foreach (@vars)
		{
		my $this = &input("slider${qlab}_$j");
	    # Filter out junk
    	$this =~ s/[\\'`]//g;
    	$gscore += $this+1;
    	&setvar($_,$this+1);
    	$ans[$j] = $this;
		$dkans[$j] = &input("dk${qlab}_$j");
		$ans[$j] = -1 if ($dkans[$j]);			# Save the DK response as a -1
    	$j++;
		}
	set_data($q,$q_no,$qlab,join($array_sep,@ans));
#	set_data($q,$q_no,"${qlab}dk",join($array_sep,@dkans));
   	&setvar("score_$qlab",$gscore);
	&endsub;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Validate the slider data
#
sub val_rank
	{
	&subtrace();
	my $j = 0;
	my $gscore = 0;
	my @ans = ();
	my @dkans = ();
	foreach (@vars)
		{
		my $this = &input("rank${qlab}_$j");
	    # Filter out junk
    	$this =~ s/[\\'`]//g;
    	$gscore += $this+1;
    	&setvar($_,$this+1);
    	$ans[$j] = $this;
		$dkans[$j] = &input("dk${qlab}_$j");
		$ans[$j] = -1 if ($dkans[$j]);			# Save the DK response as a -1
    	$j++;
		}
	set_data($q,$q_no,$qlab,join($array_sep,@ans));
	my @m;
	map({$m[$_] = ($_ ne '')} @ans); 
	&qt_update_mask_rank($mask_update,@m);
   	&setvar("score_$qlab",$gscore);
	&endsub;
	}

# Please leave this soldier intact, it's important to tell the caller we are OK
1;
