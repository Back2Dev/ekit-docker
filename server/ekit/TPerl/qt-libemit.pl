#!/usr/bin/perl
## $Id: qt-libemit.pl,v 2.66 2012-11-21 10:12:37 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl emission library for QT project
#
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Emit the question HTML
#
#
#-----------------------------------------------------------------------------------------
#
#use strict;

require 'TPerl/qt-libjs.pl';
#
	$tdo =  qq{TD class="options" };
	$tdo1 = qq{TD class="options" };
	$tdo2 = qq{TD class="options2"};
	$tro =  qq{TR class="options" };
	$tro2 = qq{TR class="options2"};
	$tdo_grid =  qq{TD class="grid_options"};
	$tdo1_grid = qq{TD class="grid_options"};
	$tdo2_grid = qq{TD class="grid_options2"};
	$tro_grid =  qq{TR class="grid_options_row"};
	$tro2_grid = qq{TR class="grid_options_row2"};	
	$thh =  qq{TH class="heading"};
	$trh =  qq{TR class="heading"};

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub get_instr
	{
	my $entity = shift;
	$entity = qq{P} if ($entity eq '');
	my $myinstr = $instr;
	my $retinstr;
	if ($instr eq '')
		{
		$myinstr = $def_instr[$qtype];
		}
	if ($myinstr ne '')
		{
		$myinstr = &subst($myinstr);
		if ($one_at_a_time == 1)
			{
			$retinstr = qq{<$entity class="instruction">$myinstr</$entity>\n};
			}
		else
			{
# This looks like a bug, but is deliberate... only show explicit instructions in multi-q per page mode
			$retinstr = qq{<$entity class="instruction">$myinstr</$entity>\n} if ($instr ne '');
			}
		}
	$retinstr;
	}
	
sub mytable 
	{
	my $class = shift;
	$class = "mytable" if (!$class);
#	my $twid = ($table_width) ? qq{width="$table_width"} : '';
	qq{<TABLE border="0" cellspacing="0" class="$class" >\n};
	}

sub mytable_grid 
	{
	mytable("grid_table");
	}	
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Emit the question HTML code
#
sub emit_q
	{
	my $do_code = shift;
	&subtrace($q_no,$qlab,$do_code);
	my $i = 0;
	$numopt = 0;
	for (my $k=0;$k<=$#options;$k++)
		{
		$options[$k] = &subst($options[$k]);	
		$numopt++ if ($a_show[$k]);
		}
	if ($random_options)		# Randomise options
		{
		my $got = 0;
		my $gix = 0;
		my @ilist;
		undef @nlist;
		my @fixed_items = ();
		if ($fixed ne '')
			{
			@fixed_items = split(",",$fixed);
			foreach my $fixed_item(@fixed_items) 
				{
				#my $iy = $fixed;
				my $iy = $fixed_item;
				$ilist[$iy] = 1;
				$nlist[$iy] = $iy;
				$got++;
				}
			}
		while ($got <= $#options)
			{
    		my $n = int(rand($#options)+0.5);
    		if ($ilist[$n] == 0)
    			{
    			$ilist[$n] = 1;
				if ($fixed ne '')
					{
					#$gix++ if ($gix == $fixed);
					$gix++ if (grep $_ eq $gix, @fixed_items);
					}
    			$nlist[$gix++] = $n;
    			$got++;
    			}
    		}
		}
	my $html = '';
	for (my $i=0;$i<$indent;$i++)
		{
		$html .= &indentme;
		}
	$i_pos = 3 if ($i_pos eq '');
	$html .= &get_instr.qq{<br>} if ($i_pos == 1);
	$prompt =~ s/^(\w+\.)/$display_label./ if $display_label ne '';
	$prompt =~ s/^[\w_\.]+\s*</</;			# Strip qno if HTML tag present
	$prompt =~ s/^(\w+\.)/<SPAN class="qlabel">$1<\/SPAN>$2/;
	my $i4 = ($i_pos == 4) ? &get_instr("SPAN") : '';
	my $i5 = ($i_pos == 5) ? &get_instr("SPAN") : '';
	$html .= qq{$i4<SPAN class="prompt">$prompt</SPAN> $i5<BR>\n};
	$html .= &get_instr if ($i_pos == 2);

#	$focus_control = '';		# Top level should reset this
	$pad = (($#options+$others) > 10) ? 2 : 5;
	$pad = 1 if (($#options+$others) > 9);
	$code = '';								# Validation code done by individual methods...
	$can_proceed_code = '';
	&add_script("clr_$qlab","JavaScript",$code) if ($eraser);		# Supply a default 'clear' method
	my $q_html;
	$q_html = &emit_number if ($qtype == QTYPE_NUMBER);
	$q_html = &emit_multi if ($qtype == QTYPE_MULTI);
    $q_html = &emit_one if ($qtype == QTYPE_YESNO);
    $q_html = &emit_one if ($qtype == QTYPE_ONE_ONLY);	
    $q_html = &emit_written if ($qtype == QTYPE_WRITTEN);
    $q_html = &emit_percent if ($qtype == QTYPE_PERCENT);
    $q_html = &emit_instruct if ($qtype == QTYPE_INSTRUCT);
    $q_html = &emit_eval if ($qtype == QTYPE_EVAL);
    $q_html = &emit_number if ($qtype == QTYPE_DOLLAR);
    $q_html = &emit_rating if ($qtype == QTYPE_RATING);
    $q_html = &emit_unknown if ($qtype == QTYPE_UNKNOWN);
    $q_html = &emit_firstm if ($qtype == QTYPE_FIRSTM);
    $q_html = &emit_compare if ($qtype == QTYPE_COMPARE);
    if ($qtype == QTYPE_GRID)
    	{
    	$q_html = &emit_grid if ($grid_type eq '');
    	$q_html = &emit_grid_multi if ($grid_type eq 'multi');
    	$q_html = &emit_grid_pulldown if ($grid_type eq 'pulldown');
    	$q_html = &emit_grid_text if ($grid_type eq 'text');
    	$q_html = &emit_grid_number if ($grid_type eq 'number');
    	}
	$q_html = &emit_grid_multi if ($qtype == QTYPE_GRID_MULTI);
	$q_html = &emit_grid_pulldown if ($qtype == QTYPE_GRID_PULLDOWN);
	$q_html = &emit_grid_text if ($qtype == QTYPE_GRID_TEXT);
	$q_html = &emit_grid_number if ($qtype == QTYPE_GRID_NUMBER);
    $q_html = &emit_slider if ($qtype == QTYPE_SLIDER);
    $q_html = &emit_rank if ($qtype == QTYPE_RANK);
    $q_html = &emit_opens if ($qtype == QTYPE_OPENS);
    $q_html = &emit_date if ($qtype == QTYPE_DATE);
    $q_html = &emit_yesnowhich if ($qtype == QTYPE_YESNOWHICH);
    $q_html = &emit_weight if ($qtype == QTYPE_WEIGHT);
    $q_html = &emit_ageonset if ($qtype == QTYPE_AGEONSET);
    $q_html = &emit_tally_multi if ($qtype == QTYPE_TALLY_MULTI);
    $q_html = &emit_tally if ($qtype == QTYPE_TALLY);
    $q_html = &emit_cluster if ($qtype == QTYPE_CLUSTER);
#
# Decide about margin notes
#
	if ($margin_notes && (($qtype != QTYPE_INSTRUCT) && ($qtype != QTYPE_EVAL)
		 && ($qtype != QTYPE_CLUSTER) && ($qtype != QTYPE_CODE) && ($qtype != QTYPE_PERL_CODE)))
		{
		if (($qtype == QTYPE_TALLY) || ($qtype == QTYPE_TALLY_MULTI))
			{
			$html .= $q_html;
			my $val = $resp{"mn_$qlab"};
			$val =~ s/\\n/\n/g;
			$val =~ s/\r//g;
			$val =~ s/&/&amp;/g;
			$val =~ s/</&lt;/g;
			$val =~ s/>/&gt;/g;
			$html .= qq{$sysmsg{TXT_NOTES}<BR> <TEXTAREA ROWS="4" COLS="50" TABINDEX="-1" class="notes" name="mn_$qlab" WRAP="PHYSICAL">};
			$html .= qq{$val</TEXTAREA>\n};
			my $checked = $resp{"rf_$qlab"} eq '' ? '' : 'CHECKED';

#??? This line appeared to be missing, not sure if it's right or not
			my $jsdk = qq{onclick="jsdk_$qlab()"};
#??? Similar thing for jsrf ?
			my $jsrf = qq{onclick="jsrf_$qlab()"};
			$html .= qq{<INPUT TYPE="CHECKBOX" NAME="rf_$qlab" VALUE="1" ID="rf_$qlab" $checked $jsrf TABINDEX="-1">};
			$html .= qq{<LABEL FOR="rf_$qlab" class="notes">$sysmsg{BTN_REFUSED}</LABEL>&nbsp;\n};
			my $checked = $resp{"dk_$qlab"} eq '' ? '' : 'CHECKED';
			$html .= qq{<INPUT TYPE="CHECKBOX" NAME="dk_$qlab" VALUE="1" ID="dk_$qlab" $checked $jsdk TABINDEX="-1">};
			$html .= qq{<LABEL FOR="dk_$qlab" class="notes">$sysmsg{BTN_DK}</LABEL><BR>\n};
			}
		else
			{
			$html .= qq{<TABLE BORDER="0" class="tablenotes">\n};		# Was: cellspacing="0" cellpadding="2">
			$html .= qq{\t<TR >\n\t<TD class="body">$q_html\n};
			$html .= qq{\t</TD><TD width="10%" class="notes">};
			my $val = $resp{"mn_$qlab"};
			$val =~ s/\\n/\n/g;
			$val =~ s/\r//g;
			$val =~ s/&/&amp;/g;
			$val =~ s/</&lt;/g;
			$val =~ s/>/&gt;/g;
			$html .= qq{<TEXTAREA ROWS="5" TABINDEX="-1" cols="30" class="notes" name="mn_$qlab" WRAP="PHYSICAL">};
			$html .= qq{$val</TEXTAREA>\n};
			my $checked = $resp{"rf_$qlab"} eq '' ? '' : 'CHECKED';
			my $jsrf = qq{onclick="jsrf_$qlab()"};
			my $jscode = qq{\tdocument.q.dk_$qlab.checked = false;\n};
			$jscode .= qq{\tclr_$qlab();\n} if ($eraser);
			&add_script("jsrf_$qlab","JavaScript",$jscode);
			$html .= qq{<INPUT TYPE="CHECKBOX" NAME="rf_$qlab" VALUE="1" ID="rf_$qlab" $checked $jsrf TABINDEX="-1">};
			$html .= qq{<LABEL FOR="rf_$qlab" class="notes">$sysmsg{BTN_REFUSED}</LABEL>&nbsp;\n};
			
			my $checked = $resp{"dk_$qlab"} eq '' ? '' : 'CHECKED';
			my $jsdk = qq{onclick="jsdk_$qlab()"};
			my $jscode = qq{\tdocument.q.rf_$qlab.checked = false;\n};
			$jscode .= qq{\tclr_$qlab();\n} if ($eraser);
			&add_script("jsdk_$qlab","JavaScript",$jscode);
			$html .= qq{<INPUT TYPE="CHECKBOX" NAME="dk_$qlab" VALUE="1" ID="dk_$qlab" $checked $jsdk TABINDEX="-1">};
			$html .= qq{<LABEL FOR="dk_$qlab" class="notes">$sysmsg{BTN_DK}</LABEL>\n};
			$html .= qq{\t</TD></tr></TABLE>};
			}
		}
	else
		{
		$html .= $q_html;
		}
	if ($one_at_a_time)
		{
		my $uni_submit = subst_errmsg($sysmsg{BTN_SUBMITTING});
		$code .= <<QVALID;
//
// OK, we have passed all the checks and are about to allow the form to be submitted. 
// So we gray it out to make sure it cannot be clicked again
//
//???	document.q.btn_submit.value = "$uni_submit";
QVALID
#		$code .= qq{	document.q.btn_submit.disabled = true;\n} if !($ENV{HTTP_USER_AGENT} =~ /opera/i);
		}
	$code .= qq{\treturn true;\n};
	if ($do_code && ($code ne ''))
		{
		my $script_name = ($one_at_a_time) ? "QValid" : qq{QValid_$qcnt};
		&add_script($script_name,"JavaScript",$code);
		$html .= &get_instr if ($i_pos == 3);
		}
	if ($do_code)
		{
		if (!$one_at_a_time)
			{
			$can_proceed_code .= qq{\treturn false\n};
			&add_script("Can_Proceed_$qcnt","JavaScript",$can_proceed_code);
			}
		}
	if ($javascript ne '')
		{
		$javascript = &subst($javascript);
		my ($jsfile,$method) = ($1,$2) if ($javascript =~ /^(.*?),(.*)/);#split(/,/,$javascript);
		$extra_js_methods{$method} = $method;
		my $jsfname = qq{$qt_root/$survey_id/html/$jsfile};
		if (-f $jsfname)
			{
			my $name = qq{src_$jsfile};
			$name =~ s/\..*//;		# Get rid of the file extension for the key
			&add_script($name,"JavaScript","$jsfile");
			}
		else
			{
			$jsfname =~ s/\\/\//g;
			my $jc = qq{alert('Error: Javascript file not found: $jsfname');};
			&add_script("","JavaScript",$jc);
			}
		}
	for (my $i=0;$i<$indent;$i++)
		{
		$html .= &undentme;
		}
	$html .= '<BR>' if (!$one_at_a_time);
	&endsub;
	$html;			# Give the caller back the fruits of our labour
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_written
	{
#	$written_required = qq{yes} if ($written_required eq '');
	&subtrace('emit_written');
	my $disp_qlab = $display_label || $qlab;
	$disp_qlab .= '.' unless $disp_qlab =~ /\./;
	if ($optional_written eq '')
		{
		if ($written_required eq '')
			{
			if ($na ne '')
				{
			my $msg = subst_errmsg($sysmsg{ERRSTR_E1a});
			$code .= <<CODE;
	if ((document.q.written${qlab}.value == "") && (document.q.written_na${qlab}\[0].checked != '1') && (document.q.written_na${qlab}\[1].checked != '1'))
	   {
	   alert("$disp_qlab $msg");
	   document.q.written${qlab}.focus();
	   return false;
	   }
CODE
				}
			else
				{
			my $msg = subst_errmsg($sysmsg{ERRSTR_E1a});
			$code .= <<CODE;
	if ((document.q.written${qlab}.value == "") && (!document.q.written_na${qlab}.checked))
	   {
	   alert("$disp_qlab. $msg");
	   document.q.written${qlab}.focus();
	   return false;
	   }
CODE
				}
			}
		elsif ($written_required eq 'yes')
			{
			my $msg = subst_errmsg($sysmsg{ERRSTR_E1a});
			$code .= <<CODE2;
	if (document.q.written${qlab}.value == "")
	   {
	   alert("$disp_qlab $msg");
	   document.q.written${qlab}.focus();
	   return false
	   }
CODE2
			}
		elsif ($written_required ne 'no')
			{
			my $msg = subst_errmsg($sysmsg{ERRSTR_E1a});
			$code .= <<CODE;
	if ((document.q.written${qlab}.value == "") && (!document.q.written_na${qlab}.checked))
	   {
	   alert("$disp_qlab $msg");
	   document.q.written${qlab}.focus();
	   return false;
	   }
CODE
			}
		}
#
	&endsub;
	my $htbit = &indentme;
	$extras{dojo}{modules}{SimpleTextarea}++;			# Need this dijit component for this qtype
	$extras{jquery}{modules}{spellchecker}++;	# Need this for IE - jquery spellchecker

	my $value = '';
	if ($old_written)
		{
		$value = &get_written($q_no,$resp{seqno});
		}
	else
		{
		$value = get_data($q,$q_no,$qlab);
		$value =~ s/\\n/\n/g;
		}
	$value =~ s/\r//g;
	$value =~ s/&/&amp;/g;
	$value =~ s/</&lt;/g;
	$value =~ s/>/&gt;/g;
	$focus_control = qq{written${qlab}} if ($focus_control eq '');
	my $cols = 50;
	$cols = $written_cols if ($written_cols ne '');
	my $rows = 8;
	$rows = $written_rows if ($written_rows ne '');
	my $dojotype = ($extras{dojo}{enabled}) ? qq{data-dojo-type="dijit.form.SimpleTextarea" style="width:600px;height:100px;"} : "";
	$htbit .= <<WRITTEN1;
<DIV class="writtenbox" width="610px">
<TEXTAREA class="written" NAME="written${qlab}" ID="written${qlab}" TABINDEX="$tabix" onchange="yuk();" WRAP="PHYSICAL" COLS="$cols" ROWS="$rows" $dojotype >$value</TEXTAREA><BR>
WRITTEN1
		if ($extras{jquery}{enabled}) {		# Using the jquery spellchecker?
			$htbit .= <<WRITTEN2;
<!--[if IE]>
			<button id="btnwritten${qlab}">
				Check Spelling
			</button>&nbsp;
			<span id="okwritten${qlab}" class="status"></span>
<![endif]-->
WRITTEN2
			my $initcode = $script_body{"jquerySetup()"};
			$initcode .= <<CODE;
		// check the spelling on a textarea
	if (navigator.appName == "Microsoft Internet Explorer")
		\$("#btnwritten${qlab}").click(checkit);
CODE
		&add_script("jquerySetup()","JavaScript",$initcode);			
		}
	$tabix++;
	if ($optional_written eq '')
		{
		my $ftype = 'checkbox';
		if ($na ne '')
			{
			$ftype = 'radio';
			}
		if ($written_required eq '')
			{
			$dk = $sysmsg{TXT_NOTHING} if ($dk eq '');
			my $checked = ($resp{"w_na${qlab}"}) ? "CHECKED" : '';
			$htbit .= <<WRITTEN2;
	<INPUT TYPE="$ftype" TABINDEX="$tabix" id="written_na${qlab}" name="written_na${qlab}" VALUE="1" $checked onchange="yuk();">
	<LABEL FOR="written_na${qlab}" class="nothing">$dk</LABEL>
WRITTEN2
			$tabix++;
			my $opt_in_checked = ($resp{"w_opt_in${qlab}"}) ? "CHECKED" : '';
			# See rt3 149.  these spaces look dumb if the opt_in is crudely
			# moved to the next line with a <BR> on the +dk
			my $sp = '&nbsp;&nbsp;';
			$sp = '' if $dk =~ /<BR>$/i;
			$htbit .= <<OPT_IN if ($opt_in ne '');
	$sp<INPUT onchange="yuk(this)" TYPE="$ftype" TABINDEX="$tabix" id="opt_in${qlab}" name="opt_in${qlab}" VALUE="1" $opt_in_checked>
	<LABEL FOR="opt_in${qlab}" class="attribute">$opt_in</LABEL>
OPT_IN
			$tabix++;
			if ($na ne '')
				{
				$htbit .= <<WRITTEN2;
	<BR><INPUT onchange="yuk(this)" TYPE="$ftype" TABINDEX="$tabix" id="written_na2${qlab}" name="written_na${qlab}" VALUE="2">
	<LABEL FOR="written_na2${qlab}" class="attribute">$na</LABEL>
WRITTEN2
				$tabix;
				}
			}
		elsif (($written_required ne 'no') && ($written_required ne 'yes'))
			{
			$htbit .= <<WRITTEN2;
	<INPUT onchange="yuk(this)" TYPE="checkbox" TABINDEX="$tabix" id="written_na${qlab}" name="written_na${qlab}" VALUE="1">
	<LABEL FOR="written_na${qlab}" class="attribute">$written_required</LABEL>
WRITTEN2
			$tabix;
			}
		}
	$htbit .= "</div>\n";
	$htbit .= &undentme;
	$htbit;
	}

#
#-----------------------------------------------------------------------------------------
#
sub emit_number
	{
	&subtrace('emit_number');
# Number validation
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my $minreq = &subst_errmsg($sysmsg{ERRSTR_E2b},'required');
	my $badtot = &subst_errmsg($sysmsg{ERRSTR_E9a},'validate_number.arguments[3]','tot');
	my $len = @options;
	&addjs_rank_number($rank_order,"number${qlab}_",$len) if ($rank_order ne ''); # Standard js function
	if($limhi ne '')
		{
		if ($limhi =~ /[a-z]/i)		# Non-numeric ?
			{
			my $savhi = $limhi;
			$limhi = &getvar($limhi);	# Look up the value
			alert("Error: limhi variable '$savhi' not found") if ($limhi eq '');
			}
		}
	else
		{
		$limhi = 999999999;
		}
	if($limlo ne '')
		{
		if ($limlo =~ /[a-z]/i)		# Non-numeric ?
			{
			$limlo = &getvar($limlo);	# Look up the value
			}
		}
	else
		{
		$limlo = 0;
		}
	&addjs_check_number(); # Standard js function
	my $subcode = <<N_VAL2;
	var errs = 0;
	var lastn = 0;
	var tot = 0;
	if (validate_number.arguments[2] == 'desc')
		lastn = 99999999;
	var n;
	qlabel = validate_number.arguments[validate_number.arguments.length-1]+".";
N_VAL2
	$subcode .= <<N_VAL2 if ($required =~ /^[0-9]/);
	var cnt = 0;
	var required = $required;
	for (i=4;i<validate_number.arguments.length-1;i++)
		{
		if (validate_number.arguments[i] != "")
		    {
		    cnt++;
		    }
		}
	if (cnt < $required)
		{
	    alert(qlabel+" $minreq");
		return false;
		}
N_VAL2

	$code_number_refused = uc($code_number_refused); 
	$code_number_never   = uc($code_number_never);   
	if (($code_number_never ne '') && ($code_number_refused ne ''))
		{
		$if_not_never_or_refused = qq{\tif ((n.toUpperCase() != '$code_number_refused')};
		$if_not_never_or_refused .= qq{ && (n.toUpperCase() != '$code_number_never'))};
		}
	elsif ($code_number_refused ne '')
		{
		$if_not_never_or_refused = qq{\tif (n.toUpperCase() != '$code_number_refused')};
		}
	elsif ($code_number_never ne '')
		{
		$if_not_never_or_refused = qq{\tif (n.toUpperCase() != '$code_number_never')};
		}

	my $reqd = ($required ne '') ? $required : "''";	# Empty string is the default, because something needs to get passed thru
	$reqd = qq{'all'} if ($required eq 'all');
$subcode .= <<N_VAL2;
	for (i=4;i<validate_number.arguments.length-1;i++)
		{
		n = validate_number.arguments[i];
		$if_not_never_or_refused
			{
			if (!check_number(n,validate_number.arguments[0],validate_number.arguments[1],qlabel,$reqd))
				{
				return false;
				}
//			var reg = new RegExp("[^0-9\\.\\-]","g");
//			m = n.replace(reg,'');
//			validate_number.arguments[i] = m;
			n = new Number(n);
			if (validate_number.arguments[2] == 'desc')
				{
				if (n > lastn)
					{
				    alert(qlabel+" $sbdesc");
					return false;
					}
				}
			if (validate_number.arguments[2] == 'asc')
				{
				if (n < lastn)
					{
				    alert(qlabel+" $sbasc");
					return false;
					}
				}
			tot = tot + n;
			lastn = n;
			}
		}
	if (validate_number.arguments[3] != '')
		{
		if (tot != validate_number.arguments[3])
			{
		    alert(qlabel+" $badtot");
			return false;
			}
		}
	return true;	
N_VAL2
		&add_script("validate_number()","JavaScript",$subcode);

		my $val = qq{''};
		$val = qq{'asc'} if ($validation eq 'validate_number_asc');
		$val = qq{'desc'} if ($validation eq 'validate_number_desc');
		$validation = '';
		$total = qq{''} if ($total eq '');
		$total = &subst($total);
		$code .= qq{\tif (!validate_number($limlo,$limhi,$val,$total};
		$total = '';
    	for (my $i=0;$i< $len;$i++)
    		{
			if ($a_show[$i])
				{
				$code .= qq{,document.q.number${qlab}_$i.value};
				}
    		}
    	$code .= qq{,"$qlab"))\n\t\treturn false;\n};
    	if ($validation ne '')
    		{
#    		$code .= qq{\talert('arg[0]='+QValid.arguments.length);\n};
    		}
#
	my $htbit = &indentme;
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	my $siz = 'size="6"';
	if ($limlo eq "" || !$limlo || $limlo eq "''") {
		$limlo = 0;
	}
	if ($limhi eq "" || !$limhi || $limhi eq "''") {
		$limhi = 9999;
	}	
	if ($limhi ne '')
		{
		my $len = length($limhi);
		my $wid = $len+1;
		$siz = qq{size="$wid"  maxlength="$len"};
		}
	my $onclick = '';
	$onclick = qq{onclick="select_this1(this)"} if ($inline_keypad);
	my $first_control;
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $objectname = qq{number${qlab}_$i};
			$focus_control = $objectname if ($focus_control eq '');
			$first_control = $objectname if ($first_control eq '');
		 	my $o = &subst($options[$i]);
		 	$htbit .= qq{<$tro><$tdo>$o</TD>\n};
		 	my $js = qq{onkeyup='var reg = new RegExp("[^0-9\\.\\-]","g");if (reg.test(this.value)) this.value = this.value.replace(reg,"");'};
		 	if ($html5) {
		 		$htbit .= qq{\t\t <TD><INPUT onchange="yuk(this)" NAME="$objectname" class="text_box" TYPE="number" TABINDEX="$tabix" VALUE="$values[$i]" MIN="$limlo" MAX="$limhi" $siz $js $onclick></TD></TR>\n};
		 	} else {
		 		$htbit .= qq{\t\t <TD><INPUT onchange="yuk(this)" NAME="$objectname" class="text_box" TYPE="text" TABINDEX="$tabix" VALUE="$values[$i]" $siz $js $onclick></TD></TR>\n};
		 	}
		 	$tabix++;
		 	}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	if ($inline_keypad)
		{
		&addjs_keypad($first_control);
		$htbit .= <<KEYPAD;
<TABLE border=0 class="tablekeypadbox"><tr><TD>Number entry keypad:
<TD><Table border="0" class="tablekeypad">
<TR class="options">
	<TH onclick="enter_num(this)">9</th>
	<TH onclick="enter_num(this)">8</th>
	<TH onclick="enter_num(this)">7</th>
	<TH onclick="enter_num(this)">6</th>
<TR class="options">
	<TH onclick="enter_num(this)">5</th>
	<TH onclick="enter_num(this)">4</th>
	<TH onclick="enter_num(this)">3</th>
	<TH onclick="enter_num(this)">2</th>
<TR class="options">
	<TH onclick="enter_num(this)">1</th>
	<TH onclick="enter_num(this)" colspan="2">0</th>
	<TH onclick="enter_num(this)">.</th>
<TR class="options">
	<TH onclick="clr_num()"colspan="4"><IMG src="/pix/clear.gif" alt="Clear">
</table></table>
KEYPAD
		}
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}

#
#-----------------------------------------------------------------------------------------
#
sub emit_multi
	{
	&subtrace('emit_multi');
	&addjs_highlightmulti;
	$extras{dojo}{modules}{CheckBox}++;			# Need this dijit component for this qtype
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my $len = 0;
	my @indices = ();
	for (my $i=0;$i<=$#options;$i++)
		{
		if ($a_show[$i])
			{
			$len++;
			push(@indices,$i);
			}
		}
	my $totopt = $len + $others;
	my $halfway = $indices[int(($totopt+1)/2)];
	if ($none ne '')
		{
		$none_text = $options[$none-1];
		$none_text =~ s/['"]//g;
		$none_text = qq{'$none_text'};
		}
	my $ncols = ($len >= $max_multi_per_col) ? 2 : 1;
	if ($ncols == 2)
		{		
		$pad = ((($#options+$others)/2) > 5) ? 2 : 5;
		$pad = 1 if ((($#options+$others)/2) > 9);
		}
	my $pad = 0 if ($tight);
# Javascript validation code
	my $loop = $#options+$others;
	if (($required ne 'all') || ($max_select > 0))
		{
		$code .= qq{   	var nsel = 0;\n};
		$code .= qq{   	var nreq = $required;\n};
		for (my $i=0;$i<=($loop);$i++)
			{
			if ($a_show[$i] || ($i > $#options))
				{
				$code .= qq{   		if (document.q.check${qlab}_$i.checked)\n};
				$code .= qq{   			nsel++;\n};
				}
			}
		if ($required ne 'all')
			{
			my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E7a},$required);
			$errmsg = &subst_errmsg($sysmsg{ERRSTR_E7b},$none_text,$required) if ($none ne '');
			$code .= qq{   	if (nsel < nreq)\n};
			$code .= qq{   		\{\n};
			$code .= qq{   		alert("$qlab. $errmsg");\n};
			$code .= qq{   		return false;\n};
			$code .= qq{   		\}\n};
			if ($none ne '')
				{
				my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E10a},$none_text);
				$code .= qq{   	if (document.q.check${qlab}_$#options.checked && (nsel > 1))\n};
				$code .= qq{   		\{\n};
				$code .= qq{   		alert("$qlab. $errmsg");\n};
				$code .= qq{   		return false;\n};
				$code .= qq{   		\}\n};
				}
			}
		if ($max_select > 0)
			{
			my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E11a},$max_select);
			$code .= qq{   	if (nsel > $max_select)\n};
			$code .= qq{   		\{\n};
			$code .= qq{   		alert("$qlab. $errmsg");\n};
			$code .= qq{   		return false;\n};
			$code .= qq{   		\}\n};
			}
		}
#
# MERGE
# OTHER CONFIRMATION FIX IS HERE
#		
	for (my $i=0;$i<$others;$i++) {
		my $j = $#options+1+$i;
		my $msg = subst_errmsg($sysmsg{ERRSTR_E22a});
		$code .= qq{ // Checking for '+others=$others'
	if (document.q.check${qlab}_$j.checked && document.q.check${qlab}_other$i.value == '') \{
		var x = prompt("$msg","");
		if (x != null && x != "") \{
			document.q.check${qlab}_other$i.value = x;
		\} else \{
			document.q.check${qlab}_other$i.focus();
			return false;
		\}
	\}
	}; #END JAVASCRIPT CODE BLOCK
	}  #END FOR LOOP
	if ($specify_n > 0) {
		for (my $i=$#options-$specify_n+1;$i<=$#options;$i++) {
			my $msg = subst_errmsg($sysmsg{ERRSTR_E22a});
			$code .= qq{ // Checking for '+specify_n=$specify_n'
	if (document.q.check${qlab}_$i.checked && document.q.other${qlab}_$i.value == '') \{
		var x = prompt("$msg","");
		if (x != null && x != "") \{
			document.q.other${qlab}_$i.value = x;
		\} else \{
			document.q.check${qlab}_$i.focus();
			return false;
		\}
	\}
	}; #END JAVASCRIPT CODE BLOCK
	}  #END FOR LOOP
	}  #END IF LOOP
#
# CLEAR_NONE ADDITION IS HERE
# ALSO ADD "uncheck_all($i);" to checkbox output instances (there are 2)
#
	my $clear_none_code = "		//CLEAR ALL CHECKBOXES ON NONE SELECTION \n";
	if ($none_clear) {
		my $none_index = $none_clear-1;
		#$clear_none_code .= "		alert('NONE_CLEAR: >>>>>>>> $none_clear|NONE_INDEX>$none_index|BOX_INDEX>' + myindex);\n";
		$clear_none_code .= "		if (myindex != $none_index) {\n";
		$clear_none_code .= "			document.q.check${qlab}_$none_index.checked = false;\n";
		$clear_none_code .= "		} else {\n";
		for (my $i=0;$i<=($loop);$i++) {
			if ($i ne $none_index) {
				$clear_none_code .= "			document.q.check${qlab}_$i.checked = false;\n";
				}
			}
		$clear_none_code .= "		}\n";
	}
	&add_script("uncheck_all(myindex)","JavaScript",$clear_none_code);
#
# END CLEAR_NONE
# END MERGE
#
	my $htbit = &indentme;
	$htbit .= mytable();
	my @parts = ();
#
# Assemble the html bits, ready for assembly later...
#
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	if (@qlab = 'Q2A' && $maptype='010A')
	{
		@values = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
		&db_conn;
		my $pwd = $resp{token};
		my_require("$qt_root/$config{participant}/web/u$pwd.pl");
		foreach (my $n=1;$n<=$config{npeer};$n++)
		{
			if ($resp{"peersent$n"}  == '')
			{
				@values[$n-1] = 1;
			}
		}
	}
	my $i = 0;
	foreach (@options)
		{
		my $checked = ($values[$i]) ? "CHECKED" : '';
		$checked = qq{DISABLED} if ($values[$i] == -1);
		my $tdclass = ($values[$i]) ? "highlight" : 'options';
		my $idname = qq{check${qlab}_$i};
		$parts[$i]  = qq{<td class="$tdclass" id="TD$idname">};
		# MERGE		
		$parts[$i] .= qq{<INPUT onchange="yuk(this)" NAME="check${qlab}_$i" ID="$idname" TYPE="checkbox" onclick="highlightmulti(this); uncheck_all($i);" $checked \n};
		#$parts[$i] .= qq{<INPUT onchange="yuk(this)" NAME="check${qlab}_$i" ID="$idname" TYPE="checkbox" onclick="highlightmulti(this)" $checked \n};
		$parts[$i] .= qq{TABINDEX="$tabix" VALUE="1">\n};
		$parts[$i] .= qq{&nbsp;<LABEL FOR="$idname" class="attribute">}.&subst($options[$i])."</LABEL>&nbsp;";
		$tabix++;
		my $x = $#options + 1 - $i;		# Problem with length of options array here if last one is masked out !
		if (($specify_n ne '') && ($specify_n >= ($x)))
			{
			my $size = 20;
			$size = 14 if ($tight);
			my $value = get_data($q,"$q_no-$i","$qlab-$i");
    		$parts[$i] .= qq{\n\t<INPUT class="text_box" TYPE="TEXT" SIZE="$size" NAME="other${qlab}_$i" VALUE="$value"\n};
    		$parts[$i] .= qq{\tTABINDEX="$tabix" \n};
   			$parts[$i] .= qq{\tonchange="yuk(this);document.q.check${qlab}_$i.checked = (this.value != '');">\n};
    		$parts[$i] .= qq{  </TD></TR>\n};
    		$tabix++;
    		}
		$i++;
		}

	my $i = 0;
#	$n = $len+1;
	my $t1 = qq{<TABLE border=0 class="tableinternal">\n};
	my $t2 = $t1;
	my $ix = 0;
	foreach (@options)
		{
		$i = $ix;
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			$focus_control = qq{check${qlab}_$i} if (($focus_control eq '') && ($values[$i] != -1));
#			my $j = $loop + $i;
			my $o = qq{&nbsp;}.&subst($options[$i]).qq{&nbsp;};
			my $col = ($ncols == 1) || (($ncols != 1) && ($i < $halfway)) ? 1 : 2;
			if ($col == 1)
				{
				$t1 .= qq{<$tro>$parts[$i]</TR>\n};
				}
			else
				{
				$t2 .= qq{<$tro>$parts[$i]</TR>\n};
				}
			}
		$ix++;
		}
	if ($others >= 1)
		{
		my $j = $#options+1;
		for (my $i=0;$i<$others;$i++)
			{
    		my $n = $i + 1;
			my $checked = ($values[$j]) ? "CHECKED" : '';
			my $tdclass = ($values[$j]) ? "highlight" : 'options';
			my $idname = qq{check${qlab}_$j};
			my $bit;
			$bit .= qq{<td class="$tdclass" id="TD$idname">};
			# MERGE
			$bit .= qq{	<INPUT onchange="yuk(this)" TYPE="checkbox" TABINDEX="$tabix" NAME="check${qlab}_$j" ID="$idname" VALUE="1" onclick="highlightmulti(this); uncheck_all($i);" $checked>};
			#$bit .= qq{	<INPUT onchange="yuk(this)" TYPE="checkbox" TABINDEX="$tabix" NAME="check${qlab}_$j" ID="$idname" VALUE="1" onclick="highlightmulti(this)" $checked>};
			$tabix++;
			my $number = ($others > 1) ? "$n." : "";
			$bit .= qq{<LABEL FOR="$idname" class="attribute">};
			$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
			$bit .= qq{&nbsp; $other_text $number &nbsp;\n};
			my $size = 20;
			$size = 14 if ($tight);
			my $value = get_data($q,"$q_no-$i","$qlab-$i");
    		$bit .= qq{</LABEL><INPUT class="text_box" TYPE="TEXT" TABINDEX="$tabix" SIZE="$size" NAME="check${qlab}_other$i" VALUE="$value"\n};
    		$tabix++;
   			$bit .= qq{onchange="yuk(this);document.q.check${qlab}_$j.checked = (this.value != '');">\n};
			my $col = ($ncols == 1) || (($ncols != 1) && ($j < $len/2)) ? 1 : 2;
			if ($col == 1)
				{
				$t1 .= qq{<$tro>$bit</TR>\n};
				}
			else
				{
				$t2 .= qq{<$tro>$bit</TR>\n};
				}
    		$j++;
    		}
#		$htbit .= qq{</TD></TR>\n};
		}
		if ($ncols > 1)
			{
			$t1 .= qq{</table>};
			$t2 .= qq{</table>};
			$htbit .= qq{<$tro><$tdo valign="top">$t1</td>\n<$tdo valign="top">$t2</td>\n</tr>};
			}
		else
			{
			$t1 .= qq{</table>};
			$htbit .= qq{<$tro><$tdo>\n\t$t1</td>\n\t</tr>};
			}
	$htbit .= qq{</TABLE>\n};
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
# alias = emit_single
#
sub emit_one
	{
	&subtrace('emit_one');
#	$len = @options;
	&addjs_highlightradio;
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my @htbits = ();			# Make sure this is cleaned out.
	my $len = 0;
	my $j;
	my @indices = ();
	my $cp = 0;
	if ($#can_proceed > 0)
		{
		if (join('',@can_proceed) > 0)
			{
			$cp++;
			}
		}	
	for (my $i=0;$i<=$#options;$i++)
		{
		if ($a_show[$i])
			{
			$len++;
			push(@indices,$i);
			}
		}
	my $totopt = $len + $others;
	my $halfway = $indices[int(($totopt+1)/2)];
	my $pull_down = 0;
	$pull_down = 1 if (($one_at_a_time == 0) && ($others != 1) && ($specify_n eq '') && ($#options >= 3) && ($force_expand == 0));
# Javascript validation code
	my $disp_qlab = $display_label || $qlab;
	$disp_qlab .= '.' unless $disp_qlab =~ /\./;
	if (!$pull_down)
		{
		&addjs_clrradio if ($eraser);
		&addjs_getradio;
		
		my $msg = subst_errmsg($sysmsg{ERRSTR_E12a});

		$code .= qq{
if (!getradio(document.q.radio$qlab))
   {
   alert("$disp_qlab $msg");
   return false;
   }
};
		$j = $#options+1;
		if ($others == 1)
			{
			my $other_prompt = ($missing_prompt eq '') ? subst_errmsg($sysmsg{ERRSTR_E22a}) : subst_errmsg($missing_prompt);
#
# MERGE
# OTHER CONFIRMATION FIX IS HERE
#
#-------------
			$code .= <<JS;
		if ((document.q.radio${qlab}\[$len].checked == "1") && (document.q.radio${qlab}_other.value == '')) {
			var x = prompt("$other_prompt","");
			if (x != null && x != "") {
				document.q.radio${qlab}_other.value = x;
			} else {
				document.q.radio${qlab}_other.focus();
				return false;
			}
		}
JS
#-------------
			}
		}
	else
		{
		my $msg = subst_errmsg($sysmsg{ERRSTR_E13a});
		$code .= <<JCODE;
if (document.q.select$qlab.value == -1)
	{
	alert("$disp_qlab. $msg")
	document.q.select$qlab.focus();
	return false;
	}
JCODE
		}
	if ($specify_n > 0) { 
		my $start_pos = $#options - ($specify_n - 1);
		#$code .= "// OPTIONS: $#options\n";
		#$code .= "// START POS: $start_pos\n";
		for (my $i=$start_pos;$i<=$#options;$i++) {
			my $msg = subst_errmsg($sysmsg{ERRSTR_E22a});
			$code .= qq{ // Checking for '+specify_n=$specify_n'
	if (document.q.radio${qlab}_${i}_id.checked && document.q.radio${qlab}_${i}_other.value == '') \{
		var x = prompt("$msg","");
		if (x != null && x != "") \{
			document.q.radio${qlab}_${i}_other.value = x;
		\} else \{
			document.q.radio${qlab}_${i}_other.focus();
			return false;
		\}   
	\}   
        }; #END JAVASCRIPT CODE BLOCK
        }  #END FOR LOOP 
        }  #END IF LOOP 
# END MERGE			
	$pad = 0 if ($tight);
	my $htbit = &indentme;
#	$table_cellspacing = 1 if (($ncols > 1) && ($table_cellspacing eq ''));			# Possible enhancement !!
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	if ($pull_down)
		{
		my $objectname = qq{select${qlab}};
		$focus_control = $objectname if ($focus_control eq '');
		$htbit .= qq{<TR><TD><select onchange="yuk(this)" class="input" name="$objectname" TABINDEX="$tabix">\n};
		$tabix++;
# NEED TO TRANSLATE FOR OTHER LANGUAGES
		$htbit .= qq{<OPTION VALUE="-1">-- Please select -- \n};
		foreach (@options)
			{
			$i = $nlist[$ix] if ($random_options);
			if ($a_show[$i])
				{
				my $o = &subst($options[$i]);
				my $selected = (get_data($q,$q_no,$qlab) eq $i) ? 'SELECTED' : '';
				$htbit .= qq{<OPTION VALUE="$i" $selected>$o \n};
				}
			$i++;
			$ix++;
			}
		$htbit .= qq{</select></TD></TR>\n};
		}
	else
		{
		if (($#options < 3) && ($others != 1) && ($specify_n  eq '') && $vertical eq "off")		# Catching short lists here, do them horizontally
			{
			$htbit .= "<$tro>\n";
			foreach (@options)
				{
				$i = $nlist[$ix] if ($random_options);
				if ($a_show[$i])
					{
					my $o = qq{&nbsp;}.&subst($options[$i]).qq{&nbsp;};
					my $checked = (get_data($q,$q_no,$qlab) eq $i) ? 'CHECKED' : '';
					my $tdclass = (get_data($q,$q_no,$qlab) eq $i) ? 'highlight' : 'options';
					my $idname = qq{radio${qlab}_${i}_id};
					$focus_control = $idname if ($focus_control eq '');
					my $js = '';
					$js .= qq{onclick="rf_$qlab.checked = false;dk_$qlab.checked = false;"} if ($margin_notes);
					$htbit .= qq{<TD class="$tdclass" ID="TD$idname"><INPUT onchange="yuk(this)" NAME="radio$qlab" ID="$idname" TYPE="radio" VALUE="$i" onclick="highlightradio(this);" $checked};
		    		$htbit .= qq{\t$js TABINDEX="$tabix" \n};
					$htbit .= qq{>};
					$htbit .= qq{<LABEL FOR="$idname" class="attribute">$o</LABEL>};
					if ($cp && ($can_proceed[$i]))
						{
	   					$can_proceed_code .= qq{\t\tif (document.q.radio$qlab\[$i].checked == '1') return true;\n};
	   					}
					}
				$i++;
				$ix++;
				}
			if ($eraser) {
				my $img = (-f "$qt_root/$survey_id/html/clear.gif") ? qq{/$survey_id/clear.gif} : qq{/pix/clear.gif};
				my $clr = qq{&nbsp;<IMG SRC="$img" onclick="clrradio(document.q.radio$qlab);" alt="Clear this answer">};	
				$htbit .= qq{  <$tdo align="right">&nbsp;$clr</TR>\n};
			}
    		$tabix++;
			}
		else
			{			# Regular layout
			my @bits = ();
			$i = 0;
			my @hitbits;
			foreach (@options)
				{
				$i = $nlist[$ix] if ($random_options);
				if ($a_show[$i])
					{
					my $do_highlight = qq{onclick="highlightradio(this);"};
					if ($no_highlight) { $do_highlight = ""; }
					my $o = "&nbsp;".&subst($options[$i])."&nbsp;";
					my $checked = (get_data($q,$q_no,$qlab) eq $i) ? 'CHECKED' : '';
					my $tdclass = (get_data($q,$q_no,$qlab) eq $i) ? 'highlight' : 'options';
					my $tdclass_box = (get_data($q,$q_no,$qlab) eq $i) ? 'highlight' : 'options_box';
					if ($no_highlight) {
						$tdclass_box = 'options_box';
					}
					if ($no_rescore) {
						$checked = "";
					}
					my $idname = "radio${qlab}_${i}_id";
					$focus_control = $idname if ($focus_control eq '');
					my $js = '';
					$js .= qq{onclick="rf_$qlab.checked = false;dk_$qlab.checked = false;"} if ($margin_notes);
					my $x = $#options + 1 - $i;		
					if (($specify_n ne '') && ($specify_n >= $x))
						{
#						my $k = 0;		# This is because there is only ever 1 other for single select questions
						my $size = 20;
						$size = 15 if ($tight);
						my $value = get_data($q,"$q_no-0","$qlab-0");
						$value = '' if(!$checked);
						$j = $#options;
						$htbits[$i]  = qq{<td class="$tdclass_box" ID="TD$idname">};
						$htbits[$i] .= qq{<INPUT onchange="yuk(this)" NAME="radio$qlab" ID="$idname" TYPE="RADIO"};
			    		$htbits[$i] .= qq{ VALUE="$i" TABINDEX="$tabix" $do_highlight $checked>\n};
						$htbits[$i] .= qq{&nbsp;<LABEL FOR="$idname" class="attribute">$o&nbsp;</LABEL>\n};
						my $other_name = "radio${qlab}_${i}_other";
						$htbits[$i] .= qq{<INPUT class="text_box" TYPE="TEXT" SIZE="$size" NAME="$other_name" VALUE="$value"\n};
			    		$htbits[$i] .= qq{\tTABINDEX="$tabix" \n};
						$htbits[$i] .= qq{onchange="yuk(this);document.q.radio$qlab\[$i].checked = (this.value != '');"></td>};
						}
					else
						{
						$htbits[$i]  = qq{<td class="$tdclass_box" ID="TD$idname">};
						$htbits[$i] .= qq{<INPUT onchange="yuk(this)" NAME="radio$qlab" ID="$idname" TYPE="radio" VALUE="$i" $do_highlight $checked};
			    		$htbits[$i] .= qq{ $js TABINDEX="$tabix" };
						$htbits[$i] .= qq{>};
						$htbits[$i] .= qq{<LABEL FOR="$idname" class="attribute">$o</LABEL>};
						if ($cp && ($can_proceed[$i]))
							{
		   					$can_proceed_code .= qq{\t\tif (document.q.radio$qlab}.qq{[$i].checked == '1') return true;\n};
		   					}
		   				}
					}
				$i++;
				$ix++;
				}
			my $n = $#options+1;
			my $ncols = ($len >= $max_single_per_col) ? 2 : 1;
			if ($set_columns) {
				$ncols = ($len >= $set_columns) ? 2 : 1;
			}
#			my $loop = ($ncols > 1) ? int(($n+1)/$ncols) : $n;
			my $t1 = qq{<TABLE CLASS="tableinternal">\n};
			my $t2 = $t1;
			my $ix = 0;
			foreach (@options)
				{
				$i = $ix;
				$i = $nlist[$ix] if ($random_options);
				if ($a_show[$i])
					{
					$focus_control = qq{check${qlab}_$i} if ($focus_control eq '');
		#			my $j = $loop + $i;
					my $o = qq{&nbsp;}.&subst($options[$i]).qq{&nbsp;};
					my $col = ($ncols == 1) || (($ncols != 1) && ($i < $halfway)) ? 1 : 2;
					if ($col == 1)
						{
						$t1 .= qq{<$tro>$htbits[$i]</TR>\n};
						}
					else
						{
						$t2 .= qq{<$tro>$htbits[$i]</TR>\n};
						}
					}
				$ix++;
				}
			
			my $o_stuff = '';
			if ($others == 1)
				{
				my $i = 0;		# This is because there is only ever 1 other for single select questions
				my $size = 20;
				$size = 15 if ($tight);
				my $checked = (get_data($q,$q_no,$qlab) eq $j) ? 'CHECKED' : '';
				my $value = get_data($q,"$q_no-$i","$qlab-$i");
# NEED TO TRANSLATE FOR OTHER LANGUAGES
				my $idname = qq{radio${qlab}_${j}_id};
				$focus_control = $idname if ($focus_control eq '');
				$other_text = qq{$sysmsg{TXT_OTHER_SPEC}} if ($other_text eq '');
				$o_stuff .= qq{<$tro><$tdo><INPUT onchange="yuk(this)" TYPE="RADIO" NAME="radio$qlab" ID="$idname" ";
 VALUE="$j" TABINDEX="$tabix" $checked>\n
&nbsp;<LABEL FOR="$idname" class="attribute">$other_text&nbsp;</LABEL>\n
<INPUT class="input" TYPE="TEXT" SIZE="$size" NAME="radio${qlab}_other" VALUE="$value"\n";
\tTABINDEX="$tabix" \n";
onchange="yuk(this);document.q.radio$qlab\[$j].checked = (this.value != '');"";# if ($one_at_a_time);
></TD></TR>
};
				}
				my $img = (-f "$qt_root/$survey_id/html/clear.gif") ? qq{/$survey_id/clear.gif} : qq{/pix/clear.gif};
			my $clr = "";
			$clr = qq{&nbsp;<IMG SRC="$img" onclick="clrradio(document.q.radio$qlab);" alt="Clear this answer">} if ($eraser);
			if ($ncols > 1)
				{
				$t1 .= qq{</table>};
				$t2 .= $o_stuff;
				$t2 .= qq{</table>};
				$htbit .= qq{<$tro><$tdo valign="top">$t1</td>\n<$tdo valign="top">$t2<$tro><$tdo>&nbsp;<$tdo align="right">$clr</td>\n</tr>};
				}
			else
				{
				$t1 .= $o_stuff;
				$t1 .= qq{</table>};
				$htbit .= qq{<$tro><$tdo>$t1<$tro><$tdo align="right">$clr</td>\n};
				}			
			$tabix++;
			}
		}
	$htbit .= qq{</TABLE>};
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_percent
	{
	&subtrace('emit_percent');
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	$limlo = qq{0};
	$limhi = qq{100};
	my $isnan1 = &subst_errmsg($sysmsg{ERRSTR_E3a},'n');
	my $isnan2 = &subst_errmsg($sysmsg{ERRSTR_E3a},'n');
	my $islo = &subst_errmsg($sysmsg{ERRSTR_E4a},'n','limlo');
	my $ishi = &subst_errmsg($sysmsg{ERRSTR_E5a},'n','limhi');
	my $sbdesc = &subst_errmsg($sysmsg{ERRSTR_E6a},'n','lastn');
	my $sbasc = &subst_errmsg($sysmsg{ERRSTR_E8a},'n','lastn');
	my $badtot = &subst_errmsg($sysmsg{ERRSTR_E9a},'validate_number.arguments[3]','tot');
# Percentages validation
	my $len = @options;
	my $subcode  = <<N_VAL;
	if (isNaN(n))
	    {
	    alert(qlabel+" $isnan1");
	    return false;
	    }
	if (limlo != '')
		{
		if (n < limlo)
		    {
		    alert(qlabel+" $islo");
		    return false;
		    }
		}
	if (limhi != '')
		{
		if (n > limhi)
		    {
		    alert(qlabel+" $ishi");
		    return false;
		    }
		}
	return true;
N_VAL
		&add_script("check_percent(n,limlo,limhi,qlabel)","JavaScript",$subcode);
		my $add = qq{\tvar tot = 0};
    	for (my $i=0;$i< $len;$i++)
    		{
			if ($a_show[$i])
				{
		    	$code .= qq{     if (!check_percent(document.q.number${qlab}_$i.value,$limlo,$limhi,"$qlab"))\n\treturn false;\n};
		    	$add = $add.qq{ + new Number(document.q.number${qlab}_$i.value)};
		    	}
    		}
    	$code .= qq{$add;\n};
# This Opera feature was many moons ago !!!
#    	$code .= qq{\tvar br = navigator.userAgent;\n};
#    	$code .= qq{\tif (-1 == br.indexOf('Opera'))\n};
    	$code .= qq{\tif (tot != 100)\n};
    	my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E14a},'tot');
    	$code .= qq{\t\t\{\n\t\talert("$qlab. $errmsg");\n};
    	$code .= qq{\t\treturn false;\n\t\t\}\n};
#
	my $htbit = &indentme;
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $objectname = qq{number${qlab}_$i};
			$focus_control = $objectname if ($focus_control eq '');
			my $o = &subst($options[$i]);
		 	$htbit .= qq{<$tro><$tdo>$o</TD><$tdo><INPUT onchange="yuk(this)" NAME="$objectname" class="input" TYPE="text" TABINDEX="$tabix" VALUE="$values[$i]" size="4" maxlength="3"></TD></TR>\n};
		 	$tabix++;
		 	}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_instruct
	{
	&subtrace('emit_instruct');
	my $htbit = '';
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_eval
	{
	&subtrace('emit_eval');
	my $htbit = &indentme;
	$htbit .= qq{<TABLE class="tableeval">};
	$htbit .= <<QQ;
<TR><TD>EVALUATOR</TD></TR>
QQ
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_rating
	{
	&subtrace('emit_rating');
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my $htbit = &indentme;
	$htbit .= qq{<TABLE class="tablerating">};
	my $ix = 0;
	my $i = 0;
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_unknown
	{
	&subtrace('emit_unknown');
	my $htbit = &indentme;
	$htbit .= qq{<TABLE class="tableunknown">};
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_firstm
	{
	&subtrace('emit_firstm');
	my $htbit = &indentme;
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	$htbit .= qq{<TABLE class="tableunknown">};
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_compare
	{
	&subtrace('emit_compare');
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my $htbit = &indentme;
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_grid_text
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
# Text Grid validation code - assuming text only here
	my $i = 0;
	my $ix = 0;
	$code = qq{\tvar cnt = 0;\n};
	my @entries = ();
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			for (my $k=0;$k<$scale;$k++)
				{
				if ($g_show[$k])
					{
					@entries = ();
					my $objname = qq{grid${qlab}_${i}_${k}};
					$focus_control = $objname if ($focus_control eq '');
					if ($required eq 'all')
						{
						$code .= qq{\tif (document.q.$objname.value == '')\n};
						my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E15a},"'$options[$i]'");
						$code .= qq{\t\t\{\n\t\talert("$qlab. $errmsg")\n};
						$code .= qq{\t\tdocument.q.$objname.focus();\n};
						$code .= qq{\t\treturn false;\n\t\t\}\n};
						}
					elsif ($required ne '')
						{
						push @entries,qq{(document.q.$objname.value != '')}
						}
					}
				}
			if (($required ne 'all') && ($required ne ''))
				{
				my $expr = join (" || ",@entries);
				$code .= qq{\tif ($expr) {cnt++};\n};		# Count the line if all entries are non blank
				}
			}
		$i++;
		$ix++;
		}
	if (($required ne 'all') && ($required ne ''))
		{
		my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E15c},"'$required'");
		$code .= qq{\tif (cnt < $required)\n\t\t\{\n\t\talert("$qlab. $errmsg");\n\t\treturn false;\n\t\t\}\n};
		}
#
# Now get on with the HTML output
#
	my $htbit = &indentme;
	
	$htbit .= mytable();
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
	$left_word = &subst($left_word);
	$left_word = qq{Unappealing} if ($left_word eq '');
	$right_word = &subst($right_word);
	$right_word = qq{Appealing} if ($right_word eq '');
	$scale = 10 if ($scale eq '');
#	my $half = int(($scale+1)/2);
	my $half = int(($scale)/2);
	my $extra = int(($scale-($half*2)));
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	$dk = &subst($dk);
	my $rowcnt = 0;
	foreach (@options)
		{
#		if ((($rowcnt % 6) == 0) && (($#options > 6) || ($rowcnt == 0)))
		my $orphan = 0;
		$orphan = (($#options + 1 - $rowcnt) == 1) if (($rowcnt % 6) == 0);
		if (($ix == 0) || ((($rowcnt % 6) == 0)&& ($rowcnt > 0) && (!$orphan)))
			{
			if ($show_anchors)
				{
				my $dkfiller = '';
				$dkfiller = qq{<$thh colspan="2">&nbsp;</TH>} if ($dk ne '');
				$htbit .= <<GRID_TOP1;
	<$trh>
		<$thh VALIGN="TOP">&nbsp;$caption</TH>
		<$thh COLSPAN=$half ALIGN="LEFT" VALIGN="TOP">
			&nbsp;$left_word&nbsp;&nbsp;<BR>&nbsp;&lt;==</TH>
GRID_TOP1
				$htbit .= qq{		<$thh VALIGN="TOP">&nbsp;$middle&nbsp;</TH>} if ($extra);
				$htbit .= <<GRID_TOP2;
		<$thh COLSPAN=$half ALIGN="RIGHT" VALIGN="TOP">
			&nbsp;&nbsp;$right_word&nbsp;<BR>==&gt;&nbsp;</TH>
$dkfiller
	</TR>
GRID_TOP2
				}
			if ($show_scale_nos)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=1;$k<=$scale;$k++)
					{
					$htbit .= qq{\t\t<$thh VALIGN="TOP"><CENTER>&nbsp;$k&nbsp;</CENTER></TH>\n};
					}
#				$htbit .= qq{\t\t<$thh>&nbsp;</TH>} if ($extra);
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh VALIGN="TOP"><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh VALIGN="TOP">&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{   </TR>\n};
				}
			if ($show_scale)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=0;$k<=$#scale_words;$k++)
					{
					if ($g_show[$k])
						{
	#					$scale_words[$k] =~ s/-/&minus;/;
	#					$scale_words[$k] =~ s/\+/&plus;/;		There is no PLUS sign yet ????
						$scale_words[$k] = &subst($scale_words[$k]);
						my $stuff = ($scale_words[$k] =~ /^</) ? "$scale_words[$k]" : "&nbsp;$scale_words[$k]&nbsp;";
						$htbit .= qq{\t\t<$thh VALIGN="TOP">$stuff</TH>\n};
						}
					}
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh VALIGN="TOP"><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh>&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{</TR>\n};
				}
			}
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $o = &subst($options[$i]); 
			$htbit .= qq{\t\t<$tro>\n\t\t\t<$tdo>$o&nbsp;&nbsp;&nbsp;</TD>\n};
			for (my $k=0;$k<$scale;$k++)
				{
				if ($g_show[$k])
					{
					my $value = $values[($i*$scale)+$k];
	#			&debug(" GRID i=$i, k=$k value = $value ");
					my $objname = qq{grid${qlab}_${i}_${k}};
					$focus_control = $objname if ($focus_control eq '');
					my $irows = ($text_rows) ? qq{rows="$text_rows"} : "";
					my $control_html = qq{<INPUT onchange="yuk(this)" class="text_box" $irows TYPE="TEXT" size="$text_size" };
					$control_html .= qq{TABINDEX="$tabix" name="$objname" id="$objname" VALUE="$value">\n};
					$htbit .= qq{\t\t\t<$tdo><CENTER>$control_html</CENTER></TD>\n};
					}
				}
			$tabix++;
			$htbit .= qq{\t\t</TR>\n};
			$rowcnt++;
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_grid_number
	{
	&subtrace();
# Number Grid validation code - assuming numbers only here
	&addjs_check_number(); # Standard js function
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
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
	my $i = 0;
	my $ix = 0;
	$code = qq{};
	my $objname;
	my ($limhigh,$limlow);
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			if ($limhi ne '')
				{
				$limhigh = $limhi;
				if ($limhi =~ /,/)
					{
					my @lim = split(/,/,$limhi);
					$limhigh = $lim[$i];
					}
				}
			if ($limlo ne '')
				{
				$limlow = $limlo;
				if ($limlo =~ /,/)
					{
					my @lim = split(/,/,$limlo);
					$limlow = $lim[$i];
					}
				}
			$code .= qq{\tnsel = 0;\n};
			my $req = 0;
			for (my $k=0;$k<$scale;$k++)
				{
				if ($g_show[$k])
					{
					$objname = qq{grid${qlab}_${i}_${k}};
					if ($limhigh.$limlow ne '')
						{
						my $reqd = ($required ne '') ? "'$required'" : "''";	# Empty string is the default, because something needs to get passed thru
						$code .= qq{\tif (!check_number(document.q.$objname.value,$limlow,$limhigh,'$qlab',$reqd))\n};
						$code .= qq{\t\t\{\n\t\tdocument.q.$objname.focus();\n\t\treturn false;\n\t\t\}\n};
						}
					$focus_control = $objname if ($focus_control eq '');
					$code .= qq{\tif (document.q.$objname.value != '')\n\t\tnsel++;\n};
					$req++;
					}
				}
			if ($required eq 'all')
				{
				$code .= qq{\tif (nsel != $req)\n};
				my $o = &subst($options[$i]);
				$o =~ s/'/\\'/g;
				$o =~ s/<.*?>//g;
				my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E15a},qq{'$o'});
				$code .= qq{\t\{\n\talert("$qlab. $errmsg")\n};
				$code .= qq{\tdocument.q.$objname.focus();\n};
				$code .= qq{\treturn false;\n\t\}\n};
				}
			elsif ($required ne '')
				{
				my $reqd = $required;
				if ($required =~ /,/)
					{
					my @rq = split(/,/,$required);
					$reqd = $rq[$i] if ($rq[$i] ne '');
					}
				$code .= qq{\tif (nsel < $reqd)\n};
				my $o = &subst($options[$i]);
				$o =~ s/'/\\'/g;
				$o =~ s/<.*?>//g;
				my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E15d},qq{'$o'},$reqd);
				$code .= qq{\t\{\n\talert("$qlab. $errmsg")\n};
#				$code .= qq{\tdocument.q.$objname.focus();\n};
				$code .= qq{\treturn false;\n\t\}\n};
				}
			}
		$i++;
		$ix++;
		}
#
# Now get on with the HTML output
#
	my $htbit = &indentme;
	
	$htbit .= mytable();
	$left_word = &subst($left_word);
#	$left_word = qq{Unappealing} if ($left_word eq '');
	$right_word = &subst($right_word);
#	$right_word = qq{Appealing} if ($right_word eq '');
	$scale = 10 if ($scale eq '');
#	my $half = int(($scale+1)/2);
	my $half = int(($scale)/2);
	my $extra = int(($scale-($half*2)));
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	$dk = &subst($dk);
	my $rowcnt = 0;
	foreach (@options)
		{
#		if ((($rowcnt % 6) == 0) && (($#options > 6) || ($rowcnt == 0)))
		my $orphan = 0;
		$orphan = (($#options + 1 - $rowcnt) == 1) if (($rowcnt % 6) == 0);
		if (($ix == 0) || ((($rowcnt % 6) == 0)&& ($rowcnt > 0) && (!$orphan)))
			{
			if ($show_anchors)
				{
				my $dkfiller = '';
				$dkfiller = qq{<$thh colspan="2" valign="top">&nbsp;</TH>} if ($dk ne '');
				$htbit .= <<GRID_TOP1;
	<$trh>
		<$thh valign="top">&nbsp;$caption</TH>
		<$thh COLSPAN=$half ALIGN="LEFT" valign="top">
			&nbsp;$left_word&nbsp;&nbsp;<BR>&nbsp;&lt;==</TH>
GRID_TOP1
				$htbit .= qq{		<$thh valign="top">&nbsp;$middle&nbsp;</TH>} if ($extra);
				$htbit .= <<GRID_TOP2;
		<$thh COLSPAN=$half ALIGN="RIGHT" valign="top">
			&nbsp;&nbsp;$right_word&nbsp;<BR>==&gt;&nbsp;</TH>
$dkfiller
	</TR>
GRID_TOP2
				}
			if ($show_scale_nos)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=1;$k<=$scale;$k++)
					{
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>&nbsp;$k&nbsp;</CENTER></TH>\n};
					}
#				$htbit .= qq{\t\t<$thh valign="top">&nbsp;</TH>} if ($extra);
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh valign="top">&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{   </TR>\n};
				}
			if ($show_scale)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=0;$k<=$#scale_words;$k++)
					{
					if ($g_show[$k])
						{
	#					$scale_words[$k] =~ s/-/&minus;/;
	#					$scale_words[$k] =~ s/\+/&plus;/;		There is no PLUS sign yet ????
						$scale_words[$k] = &subst($scale_words[$k]);
						my $stuff = ($scale_words[$k] =~ /^</) ? "$scale_words[$k]" : "&nbsp;$scale_words[$k]&nbsp;";
						$htbit .= qq{\t\t<$thh valign="top">$stuff</TH>\n};
						}
					}
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh valign="top">&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{</TR>\n};
				}
			}
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $siz = 'size="6"';
			if ($limhi ne '')
				{
				$limhigh = $limhi;
				if ($limhi =~ /,/)
					{
					my @lim = split(/,/,$limhi);
					$limhigh = $lim[$i];
					}
				my $len = length($limhigh);
				my $wid = $len+1;
				$siz = qq{size="$wid"  maxlength="$len"};
				}
			my $o = &subst($options[$i]); 
			$htbit .= qq{\t\t<$tro>\n\t\t\t<$tdo>$o&nbsp;&nbsp;&nbsp;</TD>\n};
			for (my $k=0;$k<$scale;$k++)
				{
				if ($g_show[$k])
					{
					my $value = $values[($i*$scale)+$k];
	#			&debug(" GRID i=$i, k=$k value = $value ");
					my $objname = qq{grid${qlab}_${i}_${k}};
					$focus_control = $objname if ($focus_control eq '');
				 	my $js = qq{onkeyup='var reg = new RegExp("[^0-9\\.\\-]","g"); if (reg.test(this.value)) this.value = this.value.replace(reg,"");'};
					my $control_html = qq{<INPUT onchange="yuk(this)" class="text_box" TYPE="TEXT" TABINDEX="$tabix" name="$objname" VALUE="$value" $siz $js>\n};
					$htbit .= qq{\t\t\t<$tdo><CENTER>$control_html</CENTER></TD>\n};
					}
				}
			$tabix++;
			$htbit .= qq{\t\t</TR>\n};
			$rowcnt++;
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_grid_pulldown
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
# Grid validation code - assuming pulldowns only here
	my $i = 0;
	my $ix = 0;
	$code = qq{};
	if ($required =~ /^\d+/)
		{
		my $objname;
		$code .= qq{\tvar cnt = 0;\n};
		foreach (my $i=0;$i<=$#vars;$i++)
			{
			if ($a_show[$i])
				{
				for (my $k=0;$k<$scale;$k++)
					{
					if ($g_show[$k])
						{
						$objname = qq{grid${qlab}_${i}_${k}};
						$code .= qq{\tif (document.q.$objname.selectedIndex != 0)\n};
						$code .= qq{\t\tcnt++;\n};
						}
					}
				}
			}
		my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E15c},$required);
		$code .= qq{\tif (cnt < $required)\n};
#		$code .= qq{\t\t\{\n\t\talert("$qlab. $errmsg");\n\t\treturn false\n\t\t}\n};
		$code .= qq{\t\{\n\talert("$qlab. $errmsg")\n};
		$code .= qq{\tdocument.q.$objname.focus();\n};
		$code .= qq{\treturn false;\n\t\}\n};
		}
	else
		{
		foreach (my $i=0;$i<=$#vars;$i++)
			{
			if ($a_show[$i])
				{
				for (my $k=0;$k<$scale;$k++)
					{
					if ($g_show[$k])
						{
						my $objname = qq{grid${qlab}_${i}_${k}};
						$code .= qq{\tif (document.q.$objname.selectedIndex == 0)\n};
						my $o = &subst($options[$i]);
						$o =~ s/'/\\'/g;
						$o =~ s/<\S+>//g;
						my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E15a},"'$o'");
	#					$code .= qq{\t\t\{\n\t\talert("$qlab. $errmsg");\n\t\treturn false\n\t\t}\n};
						$code .= qq{\t\{\n\talert("$qlab. $errmsg")\n};
						$code .= qq{\tdocument.q.$objname.focus();\n};
						$code .= qq{\treturn false;\n\t\}\n};
						}
					}
				}
			}
		}
#
# Now get on with the HTML output
#
	my $htbit = &indentme;
	
	$htbit .= mytable();
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
	$left_word = &subst($left_word);
	$left_word = qq{Unappealing} if ($left_word eq '');
	$right_word = &subst($right_word);
	$right_word = qq{Appealing} if ($right_word eq '');
	$scale = 10 if ($scale eq '');
#	my $half = int(($scale+1)/2);
	my $half = int(($scale)/2);
	my $extra = int(($scale-($half*2)));
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	$dk = &subst($dk);
	my $value_ix = 0;
	my $rowcnt = 0;
	foreach (@options)
		{
#		if ((($rowcnt % 6) == 0) && (($#options > 6) || ($rowcnt == 0)))
		my $orphan = 0;
		$orphan = (($#options + 1 - $rowcnt) == 1) if (($rowcnt % 6) == 0);
		if (($ix == 0) || ((($rowcnt % 6) == 0)&& ($rowcnt > 0) && (!$orphan)))
			{
			if ($show_anchors)
				{
				my $dkfiller = '';
				$dkfiller = qq{<$thh colspan="2">&nbsp;</TH>} if ($dk ne '');
				$htbit .= <<GRID_TOP1;
	<$trh>
		<$thh valign="top">&nbsp;$caption</TH>
		<$thh COLSPAN=$half ALIGN="LEFT" valign="top">
			&nbsp;$left_word&nbsp;&nbsp;<BR>&nbsp;&lt;==</TH>
GRID_TOP1
				$htbit .= qq{		<$thh valign="top">&nbsp;$middle&nbsp;</TH>} if ($extra);
				$htbit .= <<GRID_TOP2;
		<$thh COLSPAN=$half ALIGN="RIGHT" valign="top">
			&nbsp;&nbsp;$right_word&nbsp;<BR>==&gt;&nbsp;</TH>
$dkfiller
	</TR>
GRID_TOP2
				}
			if ($show_scale_nos)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=1;$k<=$scale;$k++)
					{
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>&nbsp;$k&nbsp;</CENTER></TH>\n};
					}
#				$htbit .= qq{\t\t<$thh>&nbsp;</TH>} if ($extra);
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh valign="top">&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{   </TR>\n};
				}
			if ($show_scale)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=0;$k<=$#scale_words;$k++)
					{
					if ($g_show[$k])
						{
	#					$scale_words[$k] =~ s/-/&minus;/;
	#					$scale_words[$k] =~ s/\+/&plus;/;		There is no PLUS sign yet ????
						$scale_words[$k] = &subst($scale_words[$k]);
						my $stuff = ($scale_words[$k] =~ /^</) ? "$scale_words[$k]" : qq{&nbsp;$scale_words[$k]&nbsp;};
						$htbit .= qq{\t\t<$thh valign="top">$stuff</TH>\n};
						}
					}
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh valign="top">&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{</TR>\n};
				}
			}
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $o = &subst($options[$i]); 
			$htbit .= qq{\t\t<$tro>\n\t\t\t<$tdo>$o&nbsp;&nbsp;&nbsp;</TD>\n};
			for (my $k=1;$k<=$scale;$k++)
				{
				my $x = $k-1;
				if ($g_show[$x])
					{
					my $objname = qq{grid${qlab}_${i}_${x}};
					$focus_control = $objname if ($focus_control eq '');
					my $control_html = qq{<select onchange="yuk(this)" name="$objname" TABINDEX="$tabix" class="input">\n};
					$tabix++;
					&debug("value_ix=$value_ix, value=$values[$value_ix+$x]");
					foreach (my $m = 0;$m<=$#pulldown;$m++)
						{
						my $selected = ($m == $values[$value_ix+$x]) ? "SELECTED" : "";
						$control_html .= qq{<option value="$m" $selected>$pulldown[$m]</option>\n};
						}
					$control_html .= qq{</select>\n};
					$htbit .= qq{\t\t\t<$tdo><CENTER>$control_html</CENTER></TD>\n};
					}
				}
			$htbit .= qq{\t\t</TR>\n};
			$rowcnt++;
			}
		$value_ix += $scale;
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
require 'TPerl/qt-libemitrank.pl';
#
#-----------------------------------------------------------------------------------------
#
#require 'TPerl/emit_grid.pl';
sub emit_grid
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	&addjs_highlightgrid;
	&addjs_clrradio;
	&addjs_getradio;
# Grid validation code
	my $msg16a = subst_errmsg($sysmsg{ERRSTR_E16a});
	my $msg17a = subst_errmsg($sysmsg{ERRSTR_E17a});
	my $msg18a = subst_errmsg($sysmsg{ERRSTR_E18a});
	my $msg19a = subst_errmsg($sysmsg{ERRSTR_E19a});
	my $msg20a = subst_errmsg($sysmsg{ERRSTR_E20a});
	my $vcode = <<JAG1;
var errs = 0;
for (i=1;i<validate_grid_$qcnt.arguments.length;i++)
	{
	if (!getradio(validate_grid_$qcnt.arguments[i]))
		errs++;
	}
if (errs != 0)
	{
	alert(validate_grid_$qcnt.arguments[0]+" $msg16a");
	document.q.grid${qlab}_0[0].focus();
	return false;
	}
return true;	
JAG1
	if ($rank_grid == 1)
		{
		$vcode = <<JGRID;			# Validation differs for ranking grid, because the grid is vertical
var ans = new Array(validate_grid_$qcnt.arguments.length-1);
var errs = 0;
for (i=1;i<validate_grid_$qcnt.arguments.length;i++)
	{
	var control_$qcnt = validate_grid_$qcnt.arguments[i];
//		alert("Control for validation is "+control_$qcnt+", length="+control_$qcnt.length);
	ans[i] = -99;
	for (var j=0;j< control_$qcnt.length;j++)
		{
		if (control_${qcnt}\[j].checked == "1")
			{
			ans[i] = control_${qcnt}\[j].value;
			break;
			}
		}
	if (ans[i] < 0)
		errs++;
	}
if (errs != 0)
	{
	alert(validate_grid_$qcnt.arguments[0]+" $msg18a");
	return false;
	}
JGRID
		if ($rank_order && ($scale = ($#options+1)) && !$horizontal_dupes)
			{
			$vcode .= <<JGRID2;			# Check for dupes
//
// 2nd pass - check for horizontal dupes with rank_order
//
	var taken = new Object;
	for (i=0;i<$scale;i++)				// The number of responses we have
		{
		j = new Number(ans[i+1]);		// Get the answers from above
		if (taken[j])					// Is this answer taken already?
			{
			alert(validate_grid_$qcnt.arguments[0]+" $msg19a");
			var ctrl = validate_grid_$qcnt.arguments[1];
			ctrl[0].focus();
			return false;
			}
		taken[j] = true;
		}
	return true;	
JGRID2
			}
		elsif (!$horizontal_dupes)
			{
			$vcode .= <<JGRID2;			# Check for dupes
//
// 2nd pass - check for horizontal dupes with rank_grid
//
	var taken = new Object;
	for (i=0;i<$scale;i++)				// The number of responses we have
		{
		j = new Number(ans[i+1]);		// Get the answers from above
		if (taken[j])					// Is this answer taken already?
			{
			alert(validate_grid_$qcnt.arguments[0]+" $msg20a");
			var ctrl = validate_grid_$qcnt.arguments[1];
			ctrl[0].focus();
			return false;
			}
		taken[j] = true;
		}
	return true;	
JGRID2
			}
		}
	if ($horizontal_dupes) {
		$vcode .= qq{\n	return true; \n};
	}
	&add_script("validate_grid_$qcnt","JavaScript",$vcode);
#
# We may need to revisit this one. It works for now to require at least one answer
#
	my $disp_qlab = $display_label || $qlab;
	$disp_qlab .= '.' unless $disp_qlab =~ /\./;
	$code .= qq{    var res = validate_grid_$qcnt("$disp_qlab ",};
	my $ocode = '';
	my $i = 0;
	my $ix = 0;
	my $n = 0;
	if ($rank_grid)
		{
		for (my $i=0;$i<$scale;$i++)
			{
			$code .= qq{,} if ($n != 0);
			$code .= qq{document.q.grid${qlab}_$i};
			if ($n >= 25)			# Netscape 2 on the Mac does not like any more than 10 parameters to a subroutine.
				{
				$code .= qq{);\n};
				$code .= qq{if (res == true)\n};
				$code .= qq{res = validate_grid_$qcnt("$qlab. ",};
				$n = -1;
				}
			$n++;
			}
		}
	else
		{
		foreach my $opt (@options)
			{
			$i = $nlist[$ix] if ($random_options);
			if ($a_show[$i])
				{
				my $x = $#options + 1 - $i;		
				if (($specify_n ne '') && ($specify_n >= $x))
					{
					$ocode .= qq{\tif ((res) && (document.q.grid${qlab}_other$i.value != ''))\n};
					$ocode .= qq{\t\tres = validate_grid_$qcnt("$qlab. ",document.q.grid${qlab}_$i);\n};
					$ocode .= qq{\tvar n = getradio(document.q.grid${qlab}_$i);\n};
					if (defined($true_flags))
						{
						my @flags = split(/,/,$true_flags);
						for (my $k=0;$k<=$#flags;$k++)
							{
							if ($flags[$k])
								{
								my $msg = subst_errmsg($sysmsg{ERRSTR_E22a});	
								$ocode .= qq{\tif ((res) && (document.q.grid${qlab}_other$i.value == '') && (n == $k))\n\t\t{\n\t\talert('$msg');\n\t\treturn false;\n\t\t}\n};
								}
							}
						}
					else
						{
						my $msg = subst_errmsg($sysmsg{ERRSTR_E22b});	
						$ocode .= qq{\tif ((res) && (document.q.grid${qlab}_other$i.value == '') && (n != ''))\n\t\t{\n\t\talert('$msg');\n\t\treturn false;\n\t\t}\n};
						}
					}
				else
					{
					$code .= qq{,} if ($n != 0);
					$code .= qq{document.q.grid${qlab}_$i};
					if ($n >= 25)			# Netscape 2 on the Mac does not like any more than 10 parameters to a subroutine.
						{
						$code .= qq{);\n};
						$code .= qq{if (res == true)\n};
						$code .= qq{res = validate_grid_$qcnt("$qlab. ",};
						$n = -1;
						}
					$n++;
					}
				}
			$i++;
			$ix++;
			}
		}
	$code .= qq{);\n};
	$code .= $ocode;
	$code .= qq{return res;\n};
#
# END OF JAVASCRIPT VALIDATION/UTILITY CODE
#
	my $htbit = &indentme;
	$htbit .= mytable_grid();
	my $spacer = qq{&nbsp;};#&nbsp;&nbsp;};
	$spacer = theme_part("spacer5") if ($theme);
	$show_anchors = 0;
	$show_anchors = 1 if (!defined(@scale_words) ); # || $rank_grid);
	$show_scale = defined(@scale_words);
	$show_scale_nos = !defined(@scale_words);
	if ($scale < 0)		# Negative scale means 'show anchors anyway'
		{
		$show_anchors = 1;		
		$show_scale = 1;
		$show_scale_nos = 0;
		$scale = abs($scale);
		}
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
	$dk = &subst($dk);
	my $js = '';
# Don't clear out RF/DK, because other parts of this question might still want it !!
#	$js .= qq{onclick="rf_$qlab.checked = false;dk_$qlab.checked = false;"} if ($margin_notes);
	my $rowcnt = 0;
	foreach (@options)
		{
#		if ((($ix % 6) == 0) && (($#options > 6) || ($rowcnt == 0)))
		my $orphan = 0;
		$orphan = (($#options + 1 - $rowcnt) == 1) if (($rowcnt % 6) == 0);
		#print "row count: $rowcnt --- header_repeat: $header_repeat<br>";
		#if (($ix == 0) || ((($rowcnt % 6) == 0)&& ($rowcnt > 0) && (!$orphan))) 
		if (($ix == 0) || ($header_repeat && (($rowcnt % $header_repeat) == 0) && ($rowcnt > 0)))
		#if ($ix ==0)
			{
			if ($show_anchors)
				{
				my $dkfiller = '';
				$dkfiller = qq{<$thh colspan="3">&nbsp;</TH>} if (($dk ne '') && !$rank_grid);
				$htbit .= <<GRID_TOP1;
	<$trh>
		<$thh>&nbsp;$caption</TH>
		<$thh COLSPAN=$half ALIGN="LEFT" valign="top">
			&nbsp;$left_word&nbsp;&nbsp;<BR>&nbsp;&lt;==</TH>
GRID_TOP1
				$htbit .= qq{		<$thh $middle_span valign="top">&nbsp;$middle&nbsp;</TH>} if ($extra);
				$htbit .= <<GRID_TOP2;
		<$thh COLSPAN=$half ALIGN="RIGHT" valign="top">
			&nbsp;&nbsp;$right_word&nbsp;<BR>==&gt;&nbsp;</TH>
$dkfiller
	</TR>
GRID_TOP2
				}
			if ($show_scale_nos)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=1;$k<=$scale;$k++)
					{
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>$spacer $k $spacer</CENTER></TH>\n};
					}
#				$htbit .= qq{\t\t<$thh>&nbsp;</TH>} if ($extra);
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh valign="top"><CENTER>$spacer $dk $spacer</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh valign="top">&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{   </TR>\n};
				}
			if ($show_scale)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=0;$k<=$#scale_words;$k++)
					{
					if ($g_show[$k])
						{
	#					$scale_words[$k] =~ s/-/&minus;/;
	#					$scale_words[$k] =~ s/\+/&plus;/;		There is no PLUS sign yet ????
						$scale_words[$k] = &subst($scale_words[$k]);
						my $stuff = ($scale_words[$k] =~ /^</) ? "$scale_words[$k]" : "&nbsp;$scale_words[$k]&nbsp;";
						$htbit .= qq{\t\t<$thh valign="top">$stuff</TH>\n};
						}
					}
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh>&nbsp;&nbsp;&nbsp;</TH>\n};
					$htbit .= qq{\t\t<$thh>&nbsp;&nbsp;&nbsp;</TH>\n};
					$htbit .= qq{\t\t<$thh valign="top">$spacer $dk $spacer</TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh valign="top">&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{</TR>\n};
				}
			}
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $td = $tdo_grid;
			my $tr = $tro_grid;
			if ($ix % 2)
				{
				$td = $tdo2_grid;
				$tr = $tro2_grid;
				}
			my $o = &subst($options[$i]);
			my $x = $#options + 1 - $i;		# Problem with length of options array here if last one is masked out !
			my $clr = '';
			my $img = (-f "$qt_root/$survey_id/html/clear.gif") ? qq{/$survey_id/clear.gif} : qq{/pix/clear.gif};
			$clr = qq{&nbsp;<IMG SRC="$img" onclick="clrradio(document.q.grid${qlab}_$i);" alt="Clear this row">} if ($eraser);
			my $val = qq{VALUE="}.get_data($q,$q_no,"$qlab-$i").qq{"};
			my $ojs = qq{onchange="yuk(this);if (this.value == '') for(i=0;i<$scale;i++) document.q.grid${qlab}_$i\[i].checked = false;"};
			my $ccode = '';
			if (($specify_n ne '') && ($specify_n >= ($x)))
				{
				$ccode = qq{\tdocument.q.grid${qlab}_other$i.value = '';\n};
				}
			$ccode .= qq{   var len = new Number(document.q.grid${qlab}_$i.length);\n};
			$ccode .= qq{       for (var i=0;i< len;i++)\n};
			$ccode .= qq{          \{\n};
			$ccode .= qq{          document.q.grid${qlab}_$i\[i].checked = false;\n};
			$ccode .= qq{          \}\n};
			if ($eraser)
				{
			&add_script("clr_${qlab}_$i","JavaScript",$ccode);
			my $img = (-f "$qt_root/$survey_id/html/clear.gif") ? qq{/$survey_id/clear.gif} : qq{/pix/clear.gif};
				$clr = qq{&nbsp;<IMG SRC="$img" onclick="clr_${qlab}_$i();" alt="Clear this row">};
				}
			if (($specify_n ne '') && ($specify_n >= ($x)))
				{
				$o .= qq{<BR><INPUT onchange="yuk(this)" name="grid${qlab}_other$i" TYPE="TEXT" class="text_box" TABINDEX="$tabix" $val $ojs>};
				$tabix++;
				}
			if (($specify_n ne '') && ($specify_n >= ($x)))
				{
				my $colspan = $scale + 1;
				$htbit .= qq{<TR class="heading" height="4"><TD colspan="$colspan" height="4" class="heading"></TD></TR>\n};
				}
			$htbit .= qq{\t\t<$tr>\n\t\t\t<$td>$o&nbsp;&nbsp;&nbsp;</TD>\n};
			for (my $k=1;$k<=$scale;$k++)
				{
				my $objname = qq{grid${qlab}_$i};
				my $x = $k-1;
				my $value = $x;
				if ($g_show[$x])
					{
					if ($rank_grid)
						{
						$objname = qq{grid${qlab}_$x};
						$value = $i;
						}
					my $test = '';
					if ($rank_grid)
						{
						$test = $values[$k-1];
						}
					else
						{
						$test = $values[$i];
						}
					&debug(" GRID i=$i, $test eq $value ");
					my $checked = ($test eq $value) ? "CHECKED" : '';
					#my $tdclass = ($test eq $value) ? "highlight" : "options";
					my $tdclass = "grid_options";
					$tdclass = qq{${tdclass}2} if ($ix % 2);
					my $idname = qq{grid${qlab}_${i}_${k}_id};
					$focus_control = $idname if ($focus_control eq '');
					$htbit .= <<STUFF;
			<td class="$tdclass" id="TD$idname" nowrap align="center"><label for="$idname" class="attribute">
			$spacer
			<INPUT onchange="yuk(this)" TYPE="RADIO" NAME="$objname"
			 class="grid" onclick="highlightgrid(this)"
			 ID="$idname" VALUE="$value" $checked $js
			 TABINDEX="$tabix">
			$spacer
			 </label>
			 </TD>
STUFF
					if ($eraser) {
						$htbit .= qq{<$td>$clr} if ($k == $scale);
					}
					}
				}
	#		$htbit .= qq{		<TD>&nbsp;</TD>} if ($extra);
			if (($dk ne '') && !$rank_grid)
				{
				my $value = $scale;
				my $checked = ($values[$i] eq $value) ? "CHECKED" : '';
				$htbit .= qq{\t\t\t<$td><CENTER>&nbsp;</CENTER></TD>};
				my $idname = qq{grid${qlab}_${i}_dk_id};
				$htbit .= qq{\t\t\t<$td id="TD$idname"><CENTER>&nbsp;<INPUT onchange="yuk(this)" TYPE="RADIO" ID="$idname" NAME="grid${qlab}_$i" $js onclick="highlightgrid(this)" VALUE="$value" $checked>&nbsp;</CENTER></TD>\n};
				}
			if (($others) && !$rank_grid)
				{
				my $value = $scale;
				my $checked = ($values[$i] eq $value) ? "CHECKED" : '';
				my $idname = "grid${qlab}_${i}_ot_id";
				$htbit .= qq{\t\t\t<$td><CENTER><label for="$idname" class="attribute">&nbsp;&nbsp;<INPUT onchange="yuk(this)" TYPE="RADIO" ID="$idname" };
				$htbit .= qq{NAME="grid${qlab}_$i" TABINDEX="$tabix" $js VALUE="$value" $checked>&nbsp;&nbsp;</label>\n};
				$htbit .= qq{\t\t\t<INPUT onchange="yuk(this)" class="text_box" TYPE="TEXT" TABINDEX="-1" NAME="grid${qlab}_${i}other"></CENTER></TD>\n};
				}
			$tabix++;
			$htbit .= qq{\t\t</TR>\n};
			$rowcnt++;
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_grid_multi
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
# Grid validation code
	&addjs_cnt_row_multi;		 # Bring in a library Javascript method
	$code = <<JAG1;
	var n = 0;
JAG1
	my $i = 0;
	foreach (@options)
		{
		my @chicks = ();
		if ($a_show[$i])
			{
			my $o = &subst($options[$i]); 
			$o =~ s/'/\\'/g;
			my $msg = &subst_errmsg($sysmsg{ERRSTR_E26},"'$o'");
			for (my $k=1;$k<=abs($scale)+1;$k++)
				{
				if ($g_show[$k-1])
					{
					my $objname = qq{grid${qlab}_${i}_${k}};
					push @chicks,qq{document.q.$objname};
					}
				}
			if ($others)
				{
				my $k = abs($scale)+1;
				my $objname = qq{grid${qlab}_${i}_${k}};
				push @chicks,qq{document.q.$objname};
				}
			my $fatchicks = join(",",@chicks);
			$code .= <<JGRID2 if (($required > 0) && ($required ne 'all'));			# Validation differs for ranking grid
	n = cnt_row_multi($fatchicks);
	if (n < 1)
		{
		alert("$qlab. $msg");
		document.q.grid${qlab}_${i}_1.focus();
		return false;
		}
JGRID2
			if ($others)
				{
				my $k = abs($scale)+1;
				my $objname = qq{grid${qlab}_${i}_${k}};
				my $msg = &subst_errmsg($sysmsg{ERRSTR_E22c},"'$o'");
				$code .= <<JGRID3;
	if ((document.q.${objname}other.value == '') && (document.q.$objname.checked))
		{
		alert("$qlab. $msg");
		document.q.$objname.focus();
		return false;
		}
JGRID3
				}
			}
		$i++;
		}
# Don't need this, as we get it for free elsewhere
#	$code .= qq{\treturn true;\n};		# Default is to return success
#
	my $htbit = &indentme;
	
	$htbit .= mytable_grid();
	$show_anchors = 0;
	$show_anchors = 1 if (!defined(@scale_words) ); # || $rank_grid);
	$show_scale = defined(@scale_words);
	$show_scale_nos = !defined(@scale_words);
	if ($scale < 0)		# Negative scale means 'show anchors anyway'
		{
		$show_anchors = 1;		
		$show_scale = 1;
		$show_scale_nos = 0;
		$scale = abs($scale);
		}
	$left_word = &subst($left_word);
	$left_word = qq{Unappealing} if ($left_word eq '');
	$right_word = &subst($right_word);
	$right_word = qq{Appealing} if ($right_word eq '');
	$middle = &subst($middle);
	$scale = 10 if ($scale eq '');
#	my $half = int(($scale+1)/2);
	my $half = int(($scale)/2);
	my $extra = int(($scale-($half*2)));
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	$dk = &subst($dk);
	my $rowcnt = 0;
	foreach (@options)
		{
#		if ((($rowcnt % 6) == 0) && (($#options > 6) || ($rowcnt == 0)))
		my $orphan = 0;
		$orphan = (($#options + 1 - $rowcnt) == 1) if (($rowcnt % 6) == 0);
		#if (($ix == 0) || ((($rowcnt % 6) == 0)&& ($rowcnt > 0) && (!$orphan)))
		if (($ix == 0) || ($header_repeat && (($rowcnt % $header_repeat) == 0) && ($rowcnt > 0)))
			{
			if ($show_anchors)
				{
				my $dkfiller = '';
				$dkfiller = qq{<$thh colspan="2">&nbsp;</TH>} if (($dk ne '') && !$rank_grid);
				$htbit .= <<GRID_TOP1;
	<$trh>
		<$thh>&nbsp;$caption</TH>
		<$thh COLSPAN=$half ALIGN="LEFT">
			&nbsp;$left_word&nbsp;&nbsp;<BR>&nbsp;&lt;==</TH>
GRID_TOP1
				$htbit .= qq{		<$thh>&nbsp;$middle&nbsp;</TH>} if ($extra);
				$htbit .= <<GRID_TOP2;
		<$thh COLSPAN=$half ALIGN="RIGHT">
			&nbsp;&nbsp;$right_word&nbsp;<BR>==&gt;&nbsp;</TH>
$dkfiller
	</TR>
GRID_TOP2
				}
			if ($show_scale_nos)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=1;$k<=$scale+1;$k++)
					{
					if ($g_show[$k-1])
						{
						$htbit .= qq{\t\t<$thh><CENTER>&nbsp;$k&nbsp;</CENTER></TH>\n};
						}
					}
#				$htbit .= qq{\t\t<$thh>&nbsp;</TH>} if ($extra);
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh>&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{   </TR>\n};
				}
			if ($show_scale)
				{
				$htbit .= qq{\t<$trh>\n\t\t<$thh>&nbsp;</TH>\n};
				for (my $k=0;$k<=$#scale_words;$k++)
					{
#					$scale_words[$k] =~ s/-/&minus;/;
#					$scale_words[$k] =~ s/\+/&plus;/;		There is no PLUS sign yet ????
					if ($g_show[$k])
						{
						$scale_words[$k] = &subst($scale_words[$k]);
						my $stuff = ($scale_words[$k] =~ /^</) ? "$scale_words[$k]" : "&nbsp;$scale_words[$k]&nbsp;";
						$htbit .= qq{\t\t<$thh>$stuff</TH>\n};
						}
					}
				if (($dk ne '') && !$rank_grid)
					{
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;&nbsp;&nbsp;</CENTER></TH>\n};
					$htbit .= qq{\t\t<$thh><CENTER>&nbsp;$dk&nbsp;</CENTER></TH>\n};
					}
				if (($others) && !$rank_grid)
					{
					$other_text = $sysmsg{TXT_OTHER_SPEC} if ($other_text eq '');
					$htbit .= qq{		<$thh>&nbsp;$other_text&nbsp;</TH>};
					}
				$htbit .= qq{</TR>\n};
				}
			}
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $o = &subst($options[$i]); 
			my $td = $tdo_grid;
			my $tr = $tro_grid;
			if ($ix % 2)
				{
				$td = $tdo2_grid;
				$tr = $tro2_grid;
				}
			$htbit .= "\t\t<$tr>\n\t\t\t<$td>$o&nbsp;&nbsp;&nbsp;</TD>\n";
## ??? I WANT TO CHANGE THIS TO NUMBER OBJECTS FROM ZERO. THIS HAS IMPLICATIONS IN the VALIDATION CODE
			for (my $k=1;$k<=abs($scale);$k++)
				{
				if ($g_show[$k-1])
					{
					my $objname = qq{grid${qlab}_${i}_${k}};
					my $x = $k-1;
		#			&debug(" GRID i=$i, $values[$i] eq $value ");
					my $iy = ($i*(abs($scale)+$others))+$k-1;
					my $checked = ($values[$iy]) ? "CHECKED" : '';
					$focus_control = $objname if ($focus_control eq '');
					$htbit .= qq{\t\t\t<$td><CENTER><label for="$objname" class="attribute">&nbsp;&nbsp;};
					$htbit .= qq{<INPUT onchange="yuk(this)" TYPE="CHECKBOX" TABINDEX="$tabix" id="$objname" NAME="$objname" VALUE="1" $checked>};
					$htbit .= qq{&nbsp;&nbsp;</label>};
					$htbit .= qq{</CENTER></TD>\n};
					$tabix++;
					}
				}
	#		$htbit .= qq{		<TD>&nbsp;</TD>} if ($extra);
			if ($dk ne '')
				{
				my $value = 1;
				my $checked = ($values[$i] eq $value) ? "CHECKED" : '';
				$htbit .= qq{\t\t\t<$td><CENTER>&nbsp;</CENTER></TD>};
				my $objname = qq{grid${qlab}_$i};
				$htbit .= qq{\t\t\t<$td><CENTER>};
				$htbit .= qq{<label for="$objname" class="attribute">&nbsp;&nbsp;};
				$htbit .= qq{<INPUT onchange="yuk(this)" TYPE="CHECKBOX" TABINDEX="$tabix" NAME="$objname" VALUE="$value" $checked>};
				$htbit .= qq{&nbsp;&nbsp;</label>};
				$htbit .= qq{</CENTER></TD>\n};
				$tabix++;
				}
			if ($others)
				{
				my $value = 1;
				my $iy = ($i*(abs($scale)+$others))+abs($scale);
				my $checked = ($values[$iy] eq $value) ? "CHECKED" : '';
				my $k = $scale + 1;
				my $objname = "grid${qlab}_${i}_${k}";
				$htbit .= qq{\t\t\t<$td><CENTER><label for="$objname" class="attribute">&nbsp;&nbsp;};
				$htbit .= qq{<INPUT onchange="yuk(this)" TYPE="CHECKBOX" TABINDEX="$tabix" NAME="$objname" VALUE="$value" $checked>\n};
				$htbit .= qq{&nbsp;&nbsp;</label>};
				$tabix++;
				$value = $resp{"_$qlab-$i"};
				$htbit .= qq{\t\t\t<INPUT onchange="yuk(this)" class="text_box" TYPE="TEXT" TABINDEX="$tabix" NAME="${objname}other" VALUE="$value" size="$text_size"></CENTER></TD>\n};
				$tabix++;
				}
			$htbit .= qq{\t\t</TR>\n};
			$rowcnt++;
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#-----------------------------------------------------------------------------------------
#
sub emit_opens
	{
	&subtrace('emit_opens');
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
# Text validation code
	$code .= qq{var cnt = 0;\n};
	my ($msg,$n);
	my $masked_in=0;
	for (my $i = 0;$i < $#options+1;$i++)
		{
		if ($a_show[$i])
			{
			$masked_in++;
	    	$code = $code.<<CODE;
	if (document.q.opens${qlab}_$i.value != "")
		cnt = cnt + 1;
CODE
			}
	    }
	if ($required eq 'all')
		{
		$msg = subst_errmsg($sysmsg{ERRSTR_E2a});
		$n = $masked_in;
		}
	else
		{
		$msg = ($required > 1) ? &subst_errmsg($sysmsg{ERRSTR_E23a},$required) : &subst_errmsg($sysmsg{ERRSTR_E23b},$required);
		$n = $required;
		}
	my $disp_lab = $qlab;
	$disp_lab = $display_label if $display_label ne '';
	$code = $code.<<CODE;
	if (cnt < $n)
		{	
		alert("$disp_lab. $msg");
		return false;
		}
CODE
#
	my $htbit = &indentme;
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	my @maxlengths = split (',',$maxlengths);
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			$focus_control = qq{opens${qlab}_$i} if ($focus_control eq '');
			my $o = &subst($options[$i]);
	#		&debug("option[$ix] = $o");
			my $value = get_data($q,"$q_no-$i","$qlab-$i");
			if ($text_rows)
				{
				$value =~ s/\\n/\n/g;
				$value =~ s/\r//g;
				$value =~ s/&/&amp;/g;
				$value =~ s/</&lt;/g;
				$value =~ s/>/&gt;/g;
				}
			my $maxlength = "MAXLENGTH=$maxlengths[$i]" if $maxlengths[$i]>0;
			$htbit .= qq{\t<$tro><$tdo valign="middle">&nbsp;$o &nbsp;</TD>\n};
			$htbit .= ($text_rows) ? qq{\t<TD><TEXTAREA NAME="opens${qlab}_$i" rows="$text_rows" class="written" TABINDEX="$tabix" cols="$text_size">$value</TEXTAREA></TD></TR>}
									: qq{\t<TD><INPUT onchange="yuk(this)" NAME="opens${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" $maxlength size="$text_size" VALUE="$value"></TD></TR>};
			$tabix++;
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
	

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_date
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
#
	$required = qq{all}; 				# All responses required for date/time Q
	addjs_check_number();		# Now we pick up a standard function
	my $i = 0;
	foreach (@options)
		{
		my $j = $i + 1;
		if ($a_show[$i])
			{
			if ($show_date)
				{
				$code .= <<CODE;
	if (!check_number(document.q.day${qlab}_$i.value,1,31,'$qlab.$j (Day)','all'))
		{
		document.q.day${qlab}_$i.focus();
		return false;
		}
	if (!check_number(document.q.month${qlab}_$i.value,1,12,'$qlab.$j (Month)','all' ))
		{
		document.q.month${qlab}_$i.focus();
		return false;
		}
	if (!check_number(document.q.year${qlab}_$i.value,1800,new Date().getFullYear(),'$qlab.$j (Year)','all'))
		{
		document.q.year${qlab}_$i.focus();
		return false;
		}
CODE
				if ($age_var ne '')
					{
					my $age = &getvar($age_var);
					if ($resp{ext_date_new})
						{
						my @parts = ();
# Allow for the 3 possible date separators:
						@parts = split(/\//,$resp{ext_date_new}) if ($resp{ext_date_new} =~ /\//);
						@parts = split(/\-/,$resp{ext_date_new}) if ($resp{ext_date_new} =~ /\-/);
						@parts = split(/\./,$resp{ext_date_new}) if ($resp{ext_date_new} =~ /\./);
						my ($day,$mon,$year) = ($parts[0],$parts[1],$parts[2]);
						($day,$mon,$year) = ($parts[1],$parts[0],$parts[2]) if ($us_date);
						$year =~ s/\s.*//;
						$code .= <<CODE;
	var refYear = $year;
	var sbYear = refYear - $age;
CODE
						}
					else
						{
				$code .= <<CODE;
	var myDate = new Date();
	var refYear = myDate.getFullYear();
	var sbYear = refYear - $age;
CODE
						}
		my $msga = subst_errmsg($sysmsg{ERRSTR_E27a});	
		my $msgb = subst_errmsg($sysmsg{ERRSTR_E27b});	
		my $msgc = subst_errmsg($sysmsg{ERRSTR_E27c});	
		my $msgd = subst_errmsg($sysmsg{ERRSTR_E27d});	
					$code .= <<CODE;
	var ageYear = new Number(document.q.year${qlab}_$i.value) + $age;
//	alert('ageyear='+ageYear+', refYear='+refYear);
	if (Math.abs(ageYear - refYear) > 1)
		{
		alert('${qlab}.$j $msga'+document.q.year${qlab}_$i.value+'$msgb $age $msgc'+sbYear+'$msgd');
		return false;
		}
CODE
					}
				}
			if ($show_time)
				{
				$code .= <<CODE;
	if (!check_number(document.q.hour${qlab}_$i.value,0,23,'$qlab.$j (Hour)','all'))
		{
		document.q.hour${qlab}_$i.focus();
		return false;
		}
	if (!check_number(document.q.min${qlab}_$i.value,0,59,'$qlab.$j (Minute)','all' ))
		{
		document.q.min${qlab}_$i.focus();
		return false;
		}
	if (!check_number(document.q.sec${qlab}_$i.value,0,59,'$qlab.$j (Second)','all'))
		{
		document.q.sec${qlab}_$i.focus();
		return false;
		}
CODE
				}
			}
		$i++;
		}
	
#	$code .= qq{return true\n};		
#
	my $htbit = &indentme;
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	if ($show_date)
		{
		if ($us_date)
			{
			$htbit .= qq{\t<$tro><$thh>&nbsp;</TD><$thh>$sysmsg{TXT_MONTH}</TD><$thh>&nbsp;</TD><$thh>$sysmsg{TXT_DAY}</TD><$thh>&nbsp;</TD><$thh>$sysmsg{TXT_YEAR}</TD>\n};
			}
		else
			{
			$htbit .= qq{\t<$tro><$thh>&nbsp;</TD><$thh>$sysmsg{TXT_DAY}</TD><$thh>&nbsp;</TD><$thh>$sysmsg{TXT_MONTH}</TD><$thh>&nbsp;</TD><$thh>$sysmsg{TXT_YEAR}</TD>\n};
			}
		}
	if ($show_time)
		{
		$htbit .= qq{<$thh>&nbsp;</TD><$thh>HH</TD><$thh>&nbsp;</TD><$thh>MM</TD><$thh>&nbsp;</TD><$thh>SS</TD>\n};
		}
	$htbit .= qq{</TR>\n};
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			$focus_control = ($us_date) ? "month${qlab}_$i" : "day${qlab}_$i" if ($focus_control eq '');
			my $o = &subst($options[$i]);
			my $val = $values[$i];
			my ($vday,$vmon,$vyr,$vhr,$vmin,$vsec)=(undef,undef,undef,undef,undef,undef);
			if ($show_date && ($val =~ /(\d*)\/(\d*)\/(\d*)/))
				{
				$vday = $1;
				$vmon = $2;
				$vyr = $3;
				}
			if ($show_time && ($val =~ /(\d*):(\d*):(\d*)/))
				{
				$vhr = $1;
				$vmin = $2;
				$vsec = $3;
				}
#		&debug("option[$ix] = $o");
			my $value = get_data($q,"$q_no-$i","$qlab-$i");
			$htbit .= qq{\t<$tro><$tdo>&nbsp;$o &nbsp;</TD>\n};
			if ($show_date)
				{
				if ($us_date)
					{
					$htbit .= qq{\t<TD><INPUT onchange="yuk(this)" NAME="month${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" MAXLENGTH="2" VALUE="$vmon"></TD><TD>/</TD><TD>\n};
					$tabix++;
					$htbit .= qq{\t<INPUT onchange="yuk(this)" NAME="day${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" MAXLENGTH="2" VALUE="$vday"></TD><TD>/</TD><TD>\n};
					$tabix++;
					}
				else
					{
					$htbit .= qq{\t<TD><INPUT onchange="yuk(this)" NAME="day${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" MAXLENGTH="2" VALUE="$vday"></TD><TD>/</TD><TD>\n};
					$tabix++;
					$htbit .= qq{\t<INPUT onchange="yuk(this)" NAME="month${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" MAXLENGTH="2" VALUE="$vmon"></TD><TD>/</TD><TD>\n};
					$tabix++;
					}
				$htbit .= qq{\t<INPUT onchange="yuk(this)" NAME="year${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="4" MAXLENGTH="4" VALUE="$vyr"></TD>\n};
				$tabix++;
				}
			if ($show_time)
				{
				$htbit .= qq{\t<$tdo>&nbsp;&nbsp;&nbsp;&nbsp;Time: </TD>\n};
				$htbit .= qq{<TD><INPUT onchange="yuk(this)" NAME="hour${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" MAXLENGTH="2" VALUE="$vhr"></TD><TD>:</TD><TD>\n};
				$tabix++;
				$htbit .= qq{\t<INPUT onchange="yuk(this)" NAME="min${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" MAXLENGTH="2" VALUE="$vmin"></TD><TD>:</TD><TD>\n};
				$tabix++;
				$htbit .= qq{\t<INPUT onchange="yuk(this)" NAME="sec${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" MAXLENGTH="2" VALUE="$vsec"></TD>\n};			
				$tabix++;
				}
			$htbit .= qq{</TR>};
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
	
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_yesnowhich
	{
	&subtrace('emit_yesnowhich');
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
#
	my $htbit = &indentme;
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $o = &subst($options[$i]);
	#		&debug("option[$ix] = $o");
			my $value = get_data($q,"$q_no-$i","$qlab-$i");
			$htbit .= qq{\t<$tro><$tdo>&nbsp;$o &nbsp;</TD>\n};
			$htbit .= qq{\t<TD><INPUT onchange="yuk(this)" NAME="opens${qlab}_$i" class="input" TYPE="TEXT" TABINDEX="$tabix" size="$text_size" VALUE="$value"></TD></TR>};
			$tabix++;
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_weight
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
#
	my $htbit = &indentme;
	$htbit .= mytable();
	my $ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			$focus_control = qq{opens${qlab}_$i} if ($focus_control eq '');
			my $o = &subst($options[$i]);
	#		&debug("option[$ix] = $o");
			my $value = get_data($q,"$q_no-$i","$qlab-$i");
			$htbit .= qq{\t<$tro><$tdo>&nbsp;$o &nbsp;</TD>\n};
			$htbit .= qq{\t<TD><INPUT onchange="yuk(this)" NAME="opens${qlab}_$i" class="input"};
			$htbit .= qq{ TYPE="TEXT" TABINDEX="$tabix" size="$text_size" VALUE="$value"></TD></TR>};
			$tabix++;
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_ageonset
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
#
# # # ???? Need validation code here
	if ($limhi ne '')
		{
		$limhi = &getvar($limhi) if ($limhi =~ /[a-z]/i);		# Non-numeric start ?
		}
	else
		{
		$limhi = 105;
		}
	if ($limlo ne '')
		{
		$limlo = &getvar($limlo) if ($limlo =~ /[a-z]/i);		# Non-numeric start ?
		}
	else
		{
		$limlo = 0;
		}

	&addjs_auto_code(); # Standard js function
	&addjs_check_number(); # Standard js function
	
# This looks like an unfortunate default, bcos we don't want it to be too smart for us ???
# I think we need to check on the impact on NAgs B4 WE CHANGE IT
	my $age = ($age_var eq '') ? &getvar('age') : &getvar($age_var);
	$age = 105 if ($age eq '');
	my $i = 0;
	my $ix = 0;
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $objname = qq{onset${qlab}_${i}};
			my $no_sel = (($i != $#options) && ($last_onset_only));
			$no_sel = 1 if ($no_recency);
			my $o = &subst($options[$i]);
			$o =~ s/'/\\'/g;
			$o =~ s/<\S+>//g;
			my $errmsg = &subst_errmsg($sysmsg{ERRSTR_E15b},"'$o'");
			my $never = 1;
#----- JavaScript CODE INCLUSION
			if (($code_age_never ne '') && ($code_age_refused ne ''))
				{
				$never = qq{(document.q.age${qlab}_$i.value != '$code_age_never')};
				$code = $code.<<CODE;
	if ((document.q.age${qlab}_$i.value != '$code_age_refused') && (document.q.age${qlab}_$i.value != '$code_age_never'))
CODE
				}
			elsif ($code_age_refused ne '')
				{
				$code = $code.<<CODE;
	if (document.q.age${qlab}_$i.value != '$code_age_refused')
CODE
				}
			elsif ($code_age_never ne '')
				{
				$never = qq{(document.q.age${qlab}_$i.value != '$code_age_never')};
				$code = $code.<<CODE;
	if (document.q.age${qlab}_$i.value != '$code_age_never')
CODE
				}
			my $reqd = ($required ne '') ? $required : "''";	# Empty string is the default, because something needs to get passed thru
		    $code = $code.<<CODE;
		{
		if (!check_number(document.q.age${qlab}_$i.value,$limlo,$age,'$qlab',$reqd))
			return false;
CODE
		    $code = $code.<<CODE if (!$no_sel);
		if ((document.q.$objname.selectedIndex == 0) && $never)
			{
			alert("$qlab. $errmsg");
			document.q.$objname.focus();
			return false
			}
CODE
		    $code = $code.<<CODE;
		}
CODE
#----- JavaScript END-OF-CODE-INCLUSION
			}
		$i++;
		$ix++;
		}
	my $htbit = &indentme;
	$htbit .= mytable();
	my $long_ago = $sysmsg{TXT_HOWLONG} if (!$no_recency);
	$htbit .= qq{\t<$trh><$thh>&nbsp;</TD><$thh>&nbsp;$sysmsg{TXT_AGE}&nbsp;</TD><$thh>&nbsp;$long_ago&nbsp;</TD></TR>\n};
	$ix = 0;
	my $i = 0;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	$age = ($age_var eq '') ? &getvar('age') : &getvar($age_var);
	$age = 105 if ($age eq '');
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			my $no_sel = (($i != $#options) && ($last_onset_only));
			$no_sel = 1 if ($no_recency);
			$focus_control = qq{age${qlab}_$i} if ($focus_control eq '');
			my $o = &subst($options[$i]);
	#		&debug("option[$ix] = $o");
			my $iy = $i*2;		# Every 2nd one is the actual age in years
			$htbit .= "\t<$tro><$tdo>&nbsp;$o &nbsp;</TD>\n";
#			$htbit .= qq{\t\t<$tdo><INPUT NAME="age${qlab}_$i" class="text_box" TYPE="TEXT" $siz VALUE="$values[$iy]"};
			$htbit .= qq{\t\t<$tdo><INPUT NAME="age${qlab}_$i" class="text_box" TYPE="TEXT" TABINDEX="$tabix" size="2" maxlength="2" VALUE="$values[$iy]"};
			$tabix++;
			$htbit .= qq{ onchange="yuk(this);auto_code(document.q.onset${qlab}_$i,this.value,$age)">\n} if (!$no_sel);
			$htbit .= qq{</TD>\n};
			if ($no_sel)
				{
				$htbit .= qq{\t\t<$tdo>&nbsp;</TD>\n};
				}
			else
				{
				$onset_pulldown = qq{<SELECT onchange="yuk(this)" NAME="onset${qlab}_$i" TABINDEX="$tabix" class="input">\n};
				$tabix++;
				for (my $kk = 0;$kk<=$#pulldown;$kk++)
					{
					my $iy = ($i*2)+1;
					my $selected = ($values[$iy] == ($kk)) ? " SELECTED" : "";
					my $val = ($kk == 0) ? -1 : $kk;
					$onset_pulldown .= qq{<OPTION VALUE="$val" $selected>$pulldown[$kk]\n};
					}
				$onset_pulldown .= qq{</SELECT>\n};
				$htbit .= qq{\t\t<$tdo>$onset_pulldown</TD>\n};
				}
			$htbit .= qq{\t</TR>};
			}
		$i++;
		$ix++;
		}
	$htbit .= <<QQ2;
</TABLE>
QQ2
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_tally
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my $lastitem;
	my $rpt_postfix = '';
	$rpt_postfix = $1 if ($q_label =~ /(_R\d+)$/i);
#
	&add2hdr(<<HDR);
<script language="JavaScript" src="/$survey_id/popmenu.js">
</script>
<link rel="stylesheet" href="/$survey_id/msmenu.css">
HDR
	my $htbit = '';#&indentme;		# Not indented to save space on the page
	my $subcode = <<SUBCODE;
	var obj = window.event.srcElement;
//  	alert("Selected "+val+", was="+theBtn.innerHTML);
	theSecret.value = val;
  	theBtn.src = qq{/$survey_id/pop}+val+qq{.gif};
  	theBtn.alt = obj.innerText;
  	theBtn.there = 0;
  	popup.hide();
SUBCODE
	&add_script("set(val)","JavaScript",$subcode);
#
	if (!$no_recency)
		{
		$subcode = <<SUBCODE;
	MenuInit();
	
	var SearchMenu = new Menu(0,0);
SUBCODE
		my $item;
		my $k = 0;
		foreach $item (@pulldown)	
			{
			$item =~ s/'/\\'/g;
			$subcode .= qq{\tSearchMenu.addItem(new MenuItem('$item',new Function("set($k); MenuBarClose();")));\n};
			$k++;
			}
		$subcode .= <<SUBCODE;
	SearchMenu.show(true);
	
	popup = SearchMenu;
SUBCODE
		&add_script("loadme()","JavaScript",$subcode);
		$load_script = qq{loadme() onclick="DocOnClick"};
#
		$lastitem = $pulldown[$#pulldown];
		}
	my $msg = subst_errmsg($sysmsg{ERRSTR_E25});
	$subcode = <<SUBCODE;
//	alert(src.value);
	if (src.value > age)
		{
		alert("$msg"+age);
		src.focus();
		window.event.cancelBubble = true;
		}
SUBCODE
	if (!$no_recency)
		{
		$subcode .= <<SUBCODE ;
	else
		{
		if (src.value >= (age - 1))
			{
//			alert("Possibly within 12 months - please ask...qq{);
			popclick(btn,secret);
			}
		else
			{
			if (src.value == '')
				{
				secret.value = '';
			  	btn.src = qq{/$survey_id/pop.gif};
			  	btn.alt = qq{Click to select};
				}
			else
				{
				secret.value = $#pulldown;
			  	btn.src = qq{/$survey_id/pop"+$#pulldown+}.gif};
			  	btn.alt = qq{$lastitem};
			  	}
			}
		}
SUBCODE
		}
	&add_script("auto_code_tally(btn,secret,src,age)","JavaScript",$subcode);
	$subcode = qq{};
	my ($section,$cletter);
	$cletter = '';
	my @stack = ();
	my $sum = '';
	foreach $section (@sections)
		{
		my $letter = uc(substr($section,0,1));
		$sum .= qq{+}.lc($letter) if ($sum eq '');
		if (($letter ne $cletter) && ($cletter ne ''))
			{
#			push(@stack,$section);		# Hang on to it
			$subcode .= qq{\tvar }.lc($cletter).qq{ = document.q.tally${qlab}_${stack[0]}.checked};
			for (my $k=1;$k<=$#stack;$k++)
				{
				$subcode .= qq{ || document.q.tally${qlab}_${stack[$k]}.checked};
				}
			$subcode .= qq{;\n};
			@stack = ();
			push(@stack,$section);		# Hang on to it
			$sum .= qq{+}.lc($letter);
			}
		else
			{
			push(@stack,$section);		# Hang on to it
			}
		$cletter = $letter;
		}
	$subcode .= qq{\tvar }.lc($cletter).qq{ = document.q.tally${qlab}_${stack[0]}.checked};
	for (my $k=1;$k<=$#stack;$k++)
		{
		$subcode .= qq{ || document.q.tally${qlab}_${stack[$k]}.checked};
		}
	$subcode .= qq{;\n};
	$subcode .= qq{\tftotal.innerHTML = 0$sum;\n};
	&add_script("tally()","JavaScript",$subcode);
#
# Main validation code for tally sheet
#
	my $age = ($age_var eq '') ? &getvar('age') : &getvar($age_var);
	$age = 105 if ($age eq '');
    $code = $code.<<CODE;
//	return false;
CODE
#
	my $blackline = '<TR bgcolor="000000" height="5"><TD colspan="4" height="5"></TD></TR>';
	my $hdr = qq{<TH>$sysmsg{TXT_QS}</TH><TH>$sysmsg{TXT_ITEM}</TH><TH>$sysmsg{TXT_AGE_ONS}</TH><TH>$sysmsg{TXT_AGE_REC}</TD>};
	$htbit .= <<THEAD;
<TABLE border=1 bordercolor="#EEEEEE" bordercolorlight="#EEEEEE" 
	bordercolordark="#EEEEEE" width="100%" cellspacing="0" cellpadding="2">
$blackline
<tr class="heading">
	$hdr
	</TR>
THEAD
	my $ix = 0;
	my $iy = 0;
	$text_size = 4;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	my $tallyqlab = goto_q_no($tally) if ($tally ne '');
	my @tally_ageons = ();
	my @tally_agerec = ();
	if ($tallyqlab ne '')
		{
		my @things = split /$array_sep/,get_data(0,$tally,$tallyqlab);;
		foreach my $s (@sections)
			{
			push (@tally_ageons,shift @things);shift @things;
			push (@tally_agerec,shift @things);shift @things;
			}
		}
	my $cletter = '';
	foreach (@options)
		{
		my $i = $nlist[$ix] if ($random_options);
		$iy = $i*4;			# 4 data items for each attribute
		if ($a_show[$i])
			{
			my $o = &subst($options[$i]);
			my $letter = uc(substr($sections[$i],0,1));
			$htbit .= $blackline if ($letter ne $cletter);
			$cletter = $letter;
			my $cl = qq{toptions};
			$cl = qq{selected} if (&getvar("$var_prefix$sections[$i]$rpt_postfix"));
	#		&debug("option[$ix] = $o");
			my $objectname = qq{tally${qlab}ONS_$ix};
			$focus_control = $objectname if ($focus_control eq '');
			my $ageons = $values[$iy];
			my $codeons = $values[$iy+1];
			if (&getvar("$var_prefix$sections[$i]$rpt_postfix"))	# Only bring fwd ages if symptom is endorsed
				{
				if (($ageons eq '') && ($onset_data[$i] ne ''))
					{
					my @onsitems = split(/,/,$onset_data[$i]);
					my $odata = get_data($q,$qlab,'Q'.$onsitems[0]);
					$odata = get_thing($onsitems[0]) if ($odata eq '');
					my @data = split(/$array_sep/,$odata);
					$ageons = $data[0];
					$codeons = ($data[1] > 0) ? $data[1]-1 : '';
					}
				}
			my $agerec = $values[$iy+2];
			my $coderec = $values[$iy+3];
			if (&getvar("$var_prefix$sections[$i]$rpt_postfix"))	# Only bring fwd ages if symptom is endorsed
				{
				if (($agerec eq '') && ($onset_data[$i] ne ''))
					{
					my @onsitems = split(/,/,$onset_data[$i]);
					my $onset_item = ($onsitems[1] eq '') ? $onsitems[0] : $onsitems[1];
					my $odata = get_data($q,$qlab,'Q'.$onset_item);
					$odata = get_thing($onset_item) if ($odata eq '');
					my @data = split(/$array_sep/,$odata);
					debug("ODATA(REC)=$odata, data=}.join(',',@data).qq{, n=$#data");
					if ($#data == 3)		# Full ageons/agerec data
						{
						$agerec = $data[2];
						$coderec = ($data[3] > 0) ? $data[3]-1 : '';
						}
					elsif ($#data == 1)		# Just a 2-d array
						{
						$agerec = $data[0];
						$coderec = ($data[1] > 0) ? $data[1]-1 : '';
						}
					else					# Singleton data, (most likely a variable)
						{
						$agerec = $data[0];
						$coderec = '';
						}
					}
				}
			debug("ageons=$ageons, agerec=$agerec");
			my $altons = qq{Click to select};
			my $altrec = $altons;
			$altons = $pulldown[$codeons] if ($codeons ne '');
			my $altrec = $pulldown[$coderec] if ($coderec ne '');
			$tabiy = $tabix + 1;
			my $sect = $sections[$i];
			my $qs = qq{};
			if ($section_start{$sections[$i]} ne '')
				{
				my @labs = split(/,/,$section_start{$sections[$i]});
				foreach my $lab (@labs)
					{
#						$qs .= qq{<A HREF="/cgi-mr/godb.pl};
#						$qs .= qq{<A HREF="${vhost}${virtual_cgi_bin}$go.$extension};
#						$qs .= qq{?survey_id=$survey_id&seqno=$resp{seqno}&q_label=$lab">$lab</A><BR>};
					$qs .= qq{<A HREF="x" onclick="document.q.jump_to.value='$lab';document.q.submit();return false;">$lab</A><BR>};
					}
				$qs =~ s/<BR>$//;
				}
			my $ons_html = '';
			my $rec_html = '';
			my $change1 = qq{onchange="yuk(this);auto_code_tally(document.q.tally${qlab}ons$ix, document.q.tally${qlab}sons$ix,this,$age)"};
			my $change2 = qq{onchange="yuk(this); auto_code_tally(document.q.tally${qlab}rec$ix, document.q.tally${qlab}srec$ix,this,$age)"};
			if (!$no_recency)
				{
				$ons_html = qq{<INPUT type="hidden" name="tally${qlab}sons$ix" value="$codeons">\n};
				$ons_html .= qq{<IMG SRC="/$survey_id/pop$codeons.gif" onclick="popclick(this,document.q.tally${qlab}sons$ix)" \n};
				$ons_html .= qq{alt="$altons" name="tally${qlab}ons$ix" align="top">};

				$rec_html = qq{<INPUT type="hidden" name="tally${qlab}srec$ix" value="$coderec">\n};
				$rec_html .= qq{<IMG SRC="/$survey_id/pop$coderec.gif" onclick="popclick(this,document.q.tally${qlab}srec$ix)" \n};
				$rec_html .= qq{alt="$altrec" name="tally${qlab}rec$ix" align="top">};
				}
			$htbit .= <<ROW;
	<TR class="$cl" valign="top">
		<TD class="$cl">$qs</TD>
		<TD class="$cl">$o</TD>
		<TD class="$cl" align="center" NOWRAP>
			$sect
			<INPUT name="$objectname" value="$ageons"
				class="text_box" TYPE="TEXT" SIZE="1" maxlength="2" TABINDEX="$tabix"
				$change1>
				$ons_html
				</TD>
		<TD class="$cl" align="center" NOWRAP>
			<INPUT name="tally${qlab}REC_$ix"  value="$agerec"
				class="text_box" TYPE="TEXT" SIZE="1" maxlength="2" TABINDEX="$tabiy"
				$change2>
			$rec_html
			</TD>
	</tr>
ROW
			$tabix = $tabiy + 1;
			}
		$ix++;
		$i++;
		}
	my $tally_cnt = &getvar("$cnt_var");
	$htbit .= <<QQ2;
$blackline
</TABLE>
QQ2
my $rs = <<QQ2;
	<TR class="heading" valign="top"><TH colspan="3" align="right">&nbsp;Total # of separate letters circled</TH>
		<TH>previously: $tally_cnt</TD>
		<TH>now: <DIV id="ftotal">0</DIV></TH></TR>
$blackline
</TABLE>
QQ2
#	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_tally_multi
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my $rpt_postfix = '';
	$rpt_postfix = $1 if ($q_label =~ /(_R\d+)$/i);
#
	my $htbit = '';#&indentme;		# Not indented to save space on the page
	$htbit .= qq{<link rel="stylesheet" href="/$survey_id/msmenu.css">\n};
#
	my $subcode = qq{};
	my ($section,$cletter);
	$cletter = '';
	my @stack = ();
	my $sum = '';
	foreach $section (@sections)
		{
		my $letter = uc(substr($section,0,1));
		$sum .= qq{+}.lc($letter) if ($sum eq '');
		if (($letter ne $cletter) && ($cletter ne ''))
			{
#			push(@stack,$section);		# Hang on to it
			$subcode .= qq{\tvar }.lc($cletter).qq{ = document.q.tally${qlab}_${stack[0]}.checked};
			for (my $k=1;$k<=$#stack;$k++)
				{
				$subcode .= qq{ || document.q.tally${qlab}_${stack[$k]}.checked};
				}
			$subcode .= qq{;\n};
			@stack = ();
			push(@stack,$section);		# Hang on to it
			$sum .= qq{+}.lc($letter);
			}
		else
			{
			push(@stack,$section);		# Hang on to it
			}
		$cletter = $letter;
		}
	$subcode .= qq{\tvar }.lc($cletter).qq{ = document.q.tally${qlab}_${stack[0]}.checked};
	for (my $k=1;$k<=$#stack;$k++)
		{
		$subcode .= qq{ || document.q.tally${qlab}_${stack[$k]}.checked};
		}
	$subcode .= qq{;\n};
	$subcode .= qq{\tftotal.innerHTML = 0$sum;\n};
	&add_script("tally()","JavaScript",$subcode);
#
# Main validation code for tally sheet
#
	my $age = ($age_var eq '') ? &getvar('age') : &getvar($age_var);
	$age = 105 if ($age eq '');
    $code = $code.<<CODE;
//	return false;
CODE
#
	my $blackline = qq{<TR bgcolor="000000" height="5"><TD colspan="4" height="5"></TD></TR>};
	my $hdr = qq{<TH>$sysmsg{TXT_QS}</TH><TH>$sysmsg{TXT_ITEM}</TH><TH colspan="2">$sysmsg{TXT_TICK}</TD>};
	$htbit .= <<THEAD;
<TABLE border=1 bordercolor="#EEEEEE" bordercolorlight="#EEEEEE" 
	bordercolordark="#EEEEEE" width="100%" cellspacing="0" cellpadding="2">
$blackline
<tr class="heading">
	$hdr
	</TR>
THEAD
	my $ix = 0;
	my $iy = 0;
	$text_size = 4;
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
	my $tallyqlab = goto_q_no($tally) if ($tally ne '');
	my @tally_ageons = ();
	my @tally_agerec = ();
	if ($tallyqlab ne '')
		{
		my @things = split /$array_sep/,get_data(0,$tally,$tallyqlab);;
		foreach my $s (@sections)
			{
			push (@tally_ageons,shift @things);shift @things;
			push (@tally_agerec,shift @things);shift @things;
			}
		}
	my $cletter = '';
	foreach (@options)
		{
		my $i = $nlist[$ix] if ($random_options);
		$iy = $i;
		if ($a_show[$i])
			{
			my $o = &subst($options[$i]);
			my $letter = uc(substr($sections[$i],0,1));
			$htbit .= $blackline if ($letter ne $cletter);
			$cletter = $letter;
			my $cl = qq{toptions};
			$cl = qq{selected} if (&getvar("$var_prefix$sections[$i]$rpt_postfix"));
	#		&debug("option[$ix] = $o");
			my $chk = ($values[$iy]) ? "CHECKED" : "";
			$focus_control = qq{check${qlab}_$i} if ($focus_control eq '');
			my $extra = qq{$tally_ageons[$iy]/$tally_agerec[$iy]};
			$extra = '' if ($extra eq '/');
			my $sect = $sections[$i];
			my $qs = qq{};
			if ($section_start{$sections[$i]} ne '')
				{
				my @labs = split(/,/,$section_start{$sections[$i]});
				foreach my $lab (@labs)
					{
#						$qs .= qq{<A HREF="${vhost}${virtual_cgi_bin}$go.$extension};
#						$qs .= qq{?survey_id=$survey_id&seqno=$resp{seqno}&q_label=$lab">$lab</A><BR>};
					$qs .= qq{<A HREF="x" onclick="document.q.jump_to.value='$lab';document.q.submit();return false;">$lab</A><BR>};
					}
				$qs =~ s/<BR>$//;
				}
			$htbit .= <<ROW;
	<TR class="$cl" valign="top">
		<TD class="$cl">$qs</TD>
		<TD class="$cl">$o</TD>
		<TD class="$cl" align="left" NOWRAP colspan="2">
			$sect
			<INPUT onchange="yuk(this)" name="check${qlab}_$i" class="input" VALUE="1" TYPE="CHECKBOX" TABINDEX="$tabix" $chk> $extra
			</TD>
	</tr>
ROW
			$tabix++;
			}
		$ix++;
		$i++;
		}
	my $tally_cnt = &getvar("$cnt_var");
	$htbit .= <<QQ2;
$blackline
</TABLE>
QQ2
my $rs = <<QQ2;
	<TR class="heading" valign="top"><TH colspan="3" align="right">&nbsp;Total # of separate letters circled</TH>
		<TH>previously: $tally_cnt</TD>
		<TH>now: <DIV id="ftotal">0</DIV></TH></TR>
$blackline
</TABLE>
QQ2
#	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
	
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub emit_cluster
	{
	&subtrace();
	$extras{dojo}{modules}{TextBox}++;			# Need this dijit component for this qtype
	my $htbit = qq{<link rel="stylesheet" href="/$survey_id/msmenu.css">\n};
	$htbit .= &indentme;	# Indent this part
#
# $code should contain any JavaScript validation code
#
	$code = '';								
#	
# Emit HTML code from here on...
#
	my $tallyqlab = goto_q_no($tally);
	my @things = split /$array_sep/,get_data(0,$tally,$tallyqlab);
	my @cluster = ();
	foreach my $s (@sections)
		{
		my $hsh = {};
		$hsh->{l} = $s;
		$hsh->{s} = shift @things; shift @things;
		$hsh->{e} = shift @things; shift @things;
		push @cluster,$hsh;
		}

	my $hist = {};
	if (my $group_symptoms = 0)			# This is one hell of a way to do if (0) !!!
		{
		&debug('Should never get here');
		my $s_group = {};
		foreach my $s (@cluster)
			{
			my ($lab) = $s->{l} =~ /(^\w)/;
			$s_group->{$lab}->{l} = $lab;
			$s_group->{$lab}->{s} ||= $s->{s};
			$s_group->{$lab}->{s} = $s->{s} if $s->{s} && $s->{s} < $s_group->{$lab}->{s};
			$s_group->{$lab}->{e} ||= $s->{e};
			$s_group->{$lab}->{e} = $s->{e} if $s->{e} > $s_group->{$lab}->{e};
	  	 # $htbit .= Dump ($s_group->{$lab}) if $lab eq 'F' ;
			}
		my @new_clust = ();
		push @new_clust,$s_group->{$_} foreach (sort keys %$s_group);
		$hist = AgeHistogram (symptoms=>\@new_clust);
		}
	else
		{
#		&debug('Should always be here');
		$hist = AgeHistogram (symptoms=>\@cluster);
		}

#  	$htbit .= Dump ($hist->{years});
#  	$htbit .= Dump ($hist->{symptoms});
# 	$htbit .= Dump (\@cluster);
	$htbit .= join "\n",@{$hist->{html}};
	$htbit .= &undentme;
	&endsub;
	return $htbit;					# Return the html code to the caller
	}

sub AgeHistogram 
	{
	my %args = @_;
	my $symps = $args{symptoms};

	###%years is a sparse hash where each key is a year
	## and the values are a list of the symptoms that occur
	## %histo is like %years, but the symptoms are groups according to their first letter

	my %histo = ();
	my %years = ();
	my $rpt_postfix = '';
	$rpt_postfix = $1 if ($q_label =~ /(_R\d+)$/i);
	foreach my $symp (@$symps)
		{
		$symp->{e} ||= $symp->{s};
		$symp->{s} ||= $symp->{e};
# We only want non-zero ages:
        next if (($symp->{s} < 1) || ($symp->{e} < 1) || !(&getvar("$var_prefix$symp->{l}$rpt_postfix")));
		if ( $symp->{s} && $symp->{e} )
			{
			foreach my $year ($symp->{s}..$symp->{e})
				{
				$year =$year*1;
				my ($lab) = $symp->{l} =~ /(^.)/;
				push @{$years{$year}},$symp->{l};
				if (($year == $symp->{s}) || ($year == $symp->{e}))
					{
					push @{$histo{$year}},$lab unless grep $lab eq $_,@{$histo{$year}};
					}
				}
			}
		}
	# %symptoms is the opposite.  the keys are the symptom
	# and the values are the years.
	my %symptoms = ();
	foreach my $year (sort {$a <=> $b} keys %years)
		{
		foreach my $symp (@{$years{$year}})
			{
			push @{$symptoms{$symp}},$year;
			}
		}
	
	my @years = sort {$a<=>$b} keys %years;
	
	@years = $years[0]..$years[-1]; #leave it out if you on;y want years with symptoms

	## max is max number of symptoms in any one year.  for the histogram
	my $max = undef;
	foreach (keys %histo)
		{
		my $num = scalar @{$histo{$_}};
		$max = $num if $num>$max;
		}

	my @html = ();
	# push @html,"<BR>Max=$max\n";
	# push @html,"<BR>SID=$survey_id\n";
	# build the heading line
	push @html,sprintf qq{<TABLE CELLPADDING="0" CELLSPACING="1" BORDER="0" bgcolor="#000000">};
	push @html, qq{<$trh>};
	push @html,	sprintf qq{<th COLSPAN="%d">$sysmsg{TXT_COUNT}</th>},$max+1;
	push @html,qq{<$thh>&nbsp;$sysmsg{TXT_AGE}&nbsp;</th>};
	push @html, qq{<$thh>&nbsp;$_->{l}&nbsp;</th>} foreach (@$symps);
	push @html,qq{<$thh>&nbsp;$sysmsg{TXT_AGE}&nbsp;</th>};
	push @html,qq{</TR>};

	# build the table
	foreach my $year (@years)
		{
		push @html, qq(<$tro>);
		####Histogram
		my $num = scalar(@{$histo{$year}}) if $histo{$year};
		# $num ||= '0';  ## if you wanna 0 for no symptoms
		
		push @html, qq{<$tdo>}x($max-$num);

		if ($num >= 3)
			{
			push @html, qq{<$tdo align="center">&nbsp;$num&nbsp;</td>};
			if ($num==1)
				{
				push @html,qq{<td><img src="/$survey_id/horizh.gif"></td>};
				}
			elsif ($num>1)
				{
#				push @html,qq{<td><img src="/$survey_id/leftbar.gif"></td>};
				push @html,qq{<td><img src="/$survey_id/horizbar.gif"></td>}x($num);
#				push @html,qq{<td><img src="/$survey_id/rightbar.gif"></td>};
				}
			}
		else
			{
			push @html,qq{<td>&nbsp;</td>}x($num+1);
			}
		#####age col
		push @html,"<$thh>$year</th>";
		####symptom bars
		my $last_lab = undef;
		my $count = 0;
		foreach my $s (@$symps)
			{
			my $two = '';
			my $cell = undef;
			my $image = '';
			if (grep /^$s->{l}/,@{$years{$year}})
				{
				$image = 'vertbar';
				if ( scalar (@{ $symptoms{$s->{l}} }) == 1 )
					{
					$image = '';#verth';
					}
				elsif ($year == $symptoms{$s->{l}}->[0])
					{
					$image = '';#topbar';
					}
				elsif ($year == $symptoms{$s->{l}}->[-1])
					{
					$image = '';#bottombar';
					}
				$cell = qq{<img src="/$survey_id/$image.gif">};
				$cell = qq{<B>$year</B>} if ($image eq '');
				}
			my $td = $tdo;
			my ($lab) = $s->{l} =~ /(^.)/;
			$count++ if $lab ne $last_lab;
			if ($count % 2)
				{
				$two = '2';
				$td = $tdo2;
				if (grep /^$s->{l}/,@{$years{$year}})
					{
					$cell = qq{<img src="/$survey_id/$image$two.gif">};
					$cell = qq{<B><FONT color="red">$year</B>} if ($image eq '');
					}
				}
			push @html,qq{<$td align="CENTER">$cell</td>};
			$last_lab=$lab;
			}
		push @html,"<$thh>$year</th>";
		push @html,'</tr>';
		}
	push @html, qq{<$trh>};
	push @html,	sprintf qq{<th COLSPAN="%d">$sysmsg{TXT_COUNT}</th>},$max+1;
	push @html,qq{<$thh>&nbsp;$sysmsg{TXT_AGE}&nbsp;</th>};
	push @html, qq{<$thh>&nbsp;$_->{l}&nbsp;</th>} foreach (@$symps);
	push @html,qq{<$thh>&nbsp;$sysmsg{TXT_AGE}&nbsp;</th>};
	push @html,qq{</TR>};
	push @html,'</TABLE>';
	return { years=>\%years,symptoms=>\%symptoms,html=>\@html};
	}

sub Dump 
	{
# 	use Data::Dumper;
# 	my $result = '<PRE>';
# 	$result .= Dumper ($_) foreach (@_);
# 	return $result.'</PRE>';
	}

#
#-----------------------------------------------------------------------------------------
#
require 'TPerl/qt-libemitslider.pl';

#}
# Keep the general happy
1;
