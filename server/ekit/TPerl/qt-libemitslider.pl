sub emit_slider
	{
	&subtrace();
	$tdo =  qq{TD class="slider_options" };
	$tdo1 =  qq{TD class="slider_options1" };
	$tdo2 = qq{TD class="slider_options2"};
	my $vcode = '';
# Slider validation code
	my $i = 0;
	foreach my $o (@options)
		{
		my $item = $o;
		$item =~ s/"/\"/g;
		my $msg = qq{$qlab. Please select a rating for:\\n '$item'\\n (You have not moved it yet)};
		$msg = qq{$qlab. Please select a rating:\\n (You have not moved it yet)} if ($item eq '');
		$vcode .= <<CODE;
	if (document.getElementById("slider${qlab}_$i").value == '')
		{
		alert("$msg");
		return false;
		}
CODE
		$i++;
		}

	$vcode .= <<JAG1;
	return true;	
JAG1
	&add_script("validate_slider_$qcnt","JavaScript",$vcode);
#
# We may need to revisit this one. It works for now to require at least one answer
#
	$code = $code.qq{    var res = validate_slider_$qcnt("$qlab. ",0);\n};
	$code .= qq{return res;\n};
#
# Made a change to stop the slider being cleared, because some of the information may be provided.
#
	&add_script("clr_$qlab","JavaScript","return true") if ($eraser);
#	&addjs_slider($qlab,$#options);
#
# END OF JAVASCRIPT VALIDATION/UTILITY CODE
#
	my $htbit = &indentme;
	$htbit .= qq{
<link id="themeStyles" rel="stylesheet" href="/dojo/dijit/themes/soria/soria.css">
<!-- required: dojo.js -->
<script type="text/javascript" src="/dojo/dojo/dojo.js"
	djConfig="isDebug: true, parseOnLoad: true"></script>
<script type="text/javascript">
	dojo.require("dijit.dijit"); // optimize: load dijit layer
	dojo.require("dijit.form.Form");
	dojo.require("dijit.form.CheckBox");
	dojo.require("dijit.form.HorizontalSlider");
	dojo.require("dijit.form.HorizontalRule");
	dojo.require("dijit.form.HorizontalRuleLabels");
	dojo.require("dojo.parser");	// scan page for widgets and instantiate them
</script>
	};
	$htbit .= mytable("slider_table");
	$show_anchors = 0;
	$show_anchors = 1 if (!defined(@scale_words) );
	$show_scale = defined(@scale_words);
	$show_scale_nos = !defined(@scale_words);
	if ($scale < 0)		# Negative scale means 'show anchors anyway'
		{
		$show_anchors = 1;		
		$show_scale = 1;
		$show_scale_nos = 0;
		$scale = abs($scale);
		}
# MANUAL OVERRIDE FOR NOW: SHOW ANCHORS, BUT NOT SCALE
		$show_anchors = 1;		
		$show_scale = 0;
		$show_scale_nos = 0;
	$left_word = &subst($left_word);
	$left_word = qq{Unappealing} if ($left_word eq '');
	$right_word = &subst($right_word);
	$right_word = qq{Appealing} if ($right_word eq '');
	$middle = &subst($middle);
	$scale = 10 if ($scale eq '');
#	my $half = int(($scale+1)/2);
	my $half = int(($scale)/2);
	my $extra = int(($scale-($half*2)));
	if (($scale >= 7) && ($middle ne ''))
		{
		$middle_span = qq{COLSPAN="3"};
		$half -= 1;
		}
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
#	my @dkvals = split($array_sep,get_data($q,$q_no,"${qlab}dk"));
	$dk = &subst($dk);
	my $js = '';
# Don't clear out RF/DK, because other parts of this question might still want it !!
#	$js .= qq{onclick="rf_$qlab.checked = false;dk_$qlab.checked = false;"} if ($margin_notes);
	my $rowcnt = 0;
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $td = $tdo;
			my $tr = $tro;
			if ($ix % 2)
				{
				$td = $tdo2;
				$tr = $tro2;
				}
			$td = $tdo1 if ($rowcnt ==0);
			my $o = &subst($options[$i]);
			my $x = $#options + 1 - $i;		# Problem with length of options array here if last one is masked out !
				
			$htbit .= qq{\t\t<$tr>\n\t\t\t<$td style="padding:2px;">$o&nbsp;&nbsp;&nbsp;</TD>\n};
			my $xval = 170;
			my $myval = '';
			if (($values[$i] ne '') && ($values[$i] != -1))
				{
				$xval = -8 + (($values[$i]-1)*44.3);
				$myval = qq{VALUE="$values[$i]"};
				}
			my $topscale = ($show_anchors && ($rowcnt == 0)) ? qq{   <ol data-dojo-type="dijit.form.HorizontalRuleLabels" container="topDecoration" count="10"
      style="height:1.5em;font-size:100%;color:#45526e; font-weight:bold;">
	  <li></li>
    <li>$left_word</li>
	  <li></li>
	  <li></li>
	  <li></li>
    <LI>$middle</LI>
	  <li></li>
	  <li></li>
	  <li></li>
    <li>$right_word</li>
  </ol>

} : '';
			my $ruler = (1) ? qq{} : qq{<div data-dojo-type="dijit.form.HorizontalRule" container="bottomDecoration" count=10 style="height:5px;"></div>};
			my $bottomscale = ($show_anchors && ($rowcnt == 0) || 1) ? qq{   <ol data-dojo-type="dijit.form.HorizontalRuleLabels" container="bottomDecoration" count="10"
      style="height:1.5em;font-size:100%;color:gray;">
    <li> </li>
    <li><span  class="standout">1</span></li>
    <li>2</li>
    <li>3</li>
    <li>4</li>
    <li><span class="standout">5</span></li>
    <li>6</li>
    <li>7</li>
    <li>8</li>
    <li><span  class="standout">9</span></li>
  </ol>
} : '';
			if ($ix % 2){};

			$htbit .= <<SLIDER;
<$td >
<div id="${qlab}_$i" data-dojo-type="dijit.form.HorizontalSlider"
    value="0" minimum="0" maximum="9" discreteValues="10"
    intermediateChanges="false" TABINDEX="$tabix"
    showButtons="true" style="width:400px;" name="${qlab}_$i">
    $ruler
  $topscale
  $bottomscale
</div>

SLIDER


			my $checked = ($values[$i] == -1) ? "CHECKED" : '';
			$htbit .= <<DK if ($dk ne '');
	<TD >&nbsp;<INPUT TYPE="CHECKBOX" name="dk${qlab}_$i" id="dk${qlab}_$i" tag="${qlab}_$i" value="1" onclick="dkclick(this)" $checked>
	<LABEL for="dk${qlab}_$i" class="attribute">Don't Know</LABEL>
DK
			$tabix++;
			$htbit .= qq{\t\t</TR>\n};
			$rowcnt++;
			}
		$i++;
		$ix++;
		}
	$focus_control = '';
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
1;
