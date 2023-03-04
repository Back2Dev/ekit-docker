#!/usr/bin/perl
## $Id: qt-libjs.pl,v 2.20 2012-04-24 17:20:51 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl JavaScript library for QT project
#
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Javascript functions live here
#
#
#-----------------------------------------------------------------------------------------
#
sub addjs_keypad()
	{
	my $control = shift;
	&append2script("","JavaScript",qq{var current;\n});
	&add_script("enter_num(control)","JavaScript",qq{	current.value = current.value+""+control.innerHTML;\n});
	&add_script("clr_num()","JavaScript",qq{	current.value = '';\n});
	&add_script("select_this1(control)","JavaScript",qq{	current = control;\n});
	&add_script("sel1()","JavaScript",qq{	current = document.q.$control;\n});
	$load_script = "sel1";
	}
sub addjs_check_number()
	{
# Looks like an orphan, so I commented it out:
#	$minreq = &subst_errmsg($sysmsg{ERRSTR_E2b},'required');

	my $isnan1 = &subst_errmsg($sysmsg{ERRSTR_E3a},'n');
	my $isnan2 = &subst_errmsg($sysmsg{ERRSTR_E3a},'m');
	my $islo = &subst_errmsg($sysmsg{ERRSTR_E4a},'m','limlo');
	my $ishi = &subst_errmsg($sysmsg{ERRSTR_E5a},'m','limhi');
	my $sbdesc = &subst_errmsg($sysmsg{ERRSTR_E6a},'n','lastn');
	my $sbasc = &subst_errmsg($sysmsg{ERRSTR_E8a},'n','lastn');
	my $badtot = &subst_errmsg($sysmsg{ERRSTR_E9a},'validate_number.arguments[3]','tot');
# Work out what special codes allow us to avoid numeric validation:
	my $if_not_never_or_refused = '';
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

	my $errmsg = subst_errmsg($sysmsg{ERRSTR_E2a});
	my $subcode  = <<N_VAL;			# JavaScript code for validation: check_number script
	
	var reg = new RegExp("[^0-9\\.\\-]","g");
	if (n == "")
		{
		if (reqd == "all")
		    {
		    alert(qlabel+" $errmsg");
		    return false;
		    }
		else
			return true;
		}
	m = n.replace(reg,'');
	if (m == "")
	    {
	    alert(qlabel+" $isnan1");
	    return false;
	    }
	if (isNaN(m))
	    {
	    alert(qlabel+" $isnan2");
	    return false;
	    }
	if ( ('str'+limlo) != ('str'+'') )
		{
		$if_not_never_or_refused
			{
			if (n < limlo)
			    {
		    alert(qlabel+" $islo");
	//		    alert(qlabel+" $sysmsg{ERRSTR_E4a} '"+m+"' $sysmsg{ERRSTR_E4b} "+limlo);
			    return false;
				}
			}
		}
	if ( ('str'+limhi) != ('str'+'') )
		{
		$if_not_never_or_refused
			{
			if (n > limhi)
			    {
		    	alert(qlabel+" $ishi");
	//		    alert(qlabel+" $sysmsg{ERRSTR_E5a} '"+m+"' $sysmsg{ERRSTR_E5b} "+limhi);
			    return false;
				}
			}
		}
	return true;
N_VAL
	&add_script("check_number(n,limlo,limhi,qlabel,reqd)","JavaScript",$subcode);
	}
#-----------------------------------------------------------------------------------
#
#
sub addjs_auto_code()
	{
	my $subcode = '';
	if (($code_age_never ne '') && ($code_age_refused ne ''))
		{
		$subcode .= <<SUBCODE;
	if ((val == '$code_age_never') || (val == '$code_age_refused'))
		{
		control.selectedIndex = 0;
		}
	else
SUBCODE
		}
	elsif ($code_age_refused ne '')
		{
		$subcode .= <<SUBCODE;
	if (val == '$code_age_refused')
		{
		control.selectedIndex = 0;
		}
	else
SUBCODE
		}
	elsif ($code_age_never ne '')
		{
		$subcode .= <<SUBCODE;
	if (val == '$code_age_never')
		{
		control.selectedIndex = 0;
		}
	else
SUBCODE
		}
	my $errmsg = subst_errmsg($sysmsg{ERRSTR_E25});
	$subcode .= <<SUBCODE;
		{
		if (val > age)
			{
			alert("$qlab. $errmsg "+age);
			}
		else
			{
			if (val > 0)
				{
				if (val >= (age - 1)) 
					{
//					alert("$qlab. $sysmsg{ERRSTR_E24}");
					if (control.length == 3)
						control.selectedIndex = control.length-2;					
					}
				else
					{
					control.selectedIndex = control.length-1;
					}
				}
			}
		}
SUBCODE
	&add_script("auto_code(control,val,age)","JavaScript",$subcode);
	}

sub addjs_grid()
	{
	my $msg16a = subst_errmsg($sysmsg{ERRSTR_E16a});
	my $msg22b = subst_errmsg($sysmsg{ERRSTR_E22b});	
	my $msg22d = subst_errmsg($sysmsg{ERRSTR_E22d});	
	my $msg22e = subst_errmsg($sysmsg{ERRSTR_E22e});	
	my $msg22f = subst_errmsg($sysmsg{ERRSTR_E22f});	
	my $subcode = <<JAG1;
	var errs = 0;
	var lab = validate_grid.arguments[0];
	for (i=1;i<validate_grid.arguments.length;i++)
		{
		if (!getradio(validate_grid.arguments[i]))
			errs++;
		}
	if (errs != 0)
		{
		alert(lab+" $msg16a");
		return false;
		}
// Make another pass looking for other/specifies
	for (i=1;i<validate_grid.arguments.length;i++)
		{
		if (!getradiolastother(validate_grid.arguments[i]))
			{
			alert(lab+" $msg22b");
			return false;
			}
		if (!getradioothertext(validate_grid.arguments[i]))
			{
			alert(lab+" $msg22d");
			return false;
			}
		if (!getradiolastspec(validate_grid.arguments[i]))
			{
			alert(lab+" $msg22e");
			return false;
			}
		if (!getradiospectext(validate_grid.arguments[i]))
			{
			alert(lab+" $msg22d");
			return false;
			}
		}
	return true;	
JAG1
# validate_grid has variable arguments
	&add_script("validate_grid","JavaScript",$subcode);
	}

sub addjs_rankgrid()
	{
	my $msg18a = subst_errmsg($sysmsg{ERRSTR_E18a});
	my $msg19a = subst_errmsg($sysmsg{ERRSTR_E19a});
	my $msg20a = subst_errmsg($sysmsg{ERRSTR_E20a});
	my $numreq = $scale;
	my $subcode = <<JSUB;
	var lab = validate_rankgrid.arguments[0];
	var ans = new Array(validate_rankgrid.arguments.length-1);
	var numsel = 0;
	
	for (i=1;i<validate_rankgrid.arguments.length;i++)
		{
		var control = validate_rankgrid.arguments[i];
	//		alert("Control for validation is "+control.id+", length="+control.length);
		ans[i] = -99;
		for (var j=0;j< control.length;j++)
			{
			if (control\[j].checked == "1")
				{
				ans[i] = control\[j].value;
				break;
				}
			}
		if (ans[i] >= 0)
			numsel++;
		}
	if (numsel < $numreq)
		{
		alert(lab+" $msg18a");
		return false;
		}
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
JSUB
# validate_rankgrid has variable arguments
	&add_script("validate_rankgrid","JavaScript",$subcode);
	}
	
sub addjs_getradio()
	{
	&addjs_toggle_highlight;
	my $subcode = <<JSUB;
	var selectedButton = "";
	var len = new Number(control.length);
	if (isNaN(len))
		selectedButton = control.checked == '1'
	else
		for (var j=0;j< len;j++)
			{
			if (control[j].checked)
				{
				selectedButton = control[j].value;
				break;
				}
			}
	return selectedButton;
JSUB
	&add_script("getradio(control)","JavaScript",$subcode);
#
# Sub to check if it's the last option selected 
#
	my $subcode = <<JSUB;
	var ok = true;
	var sel
	var len = new Number(control.length);
	var oname;
	if (isNaN(len))
		{
		sel = control.checked;
		oname = control.name+"other";
		}
	else
		{
		sel = control[len-1].checked;
		oname = control[len-1].name+"other";
		}
	if (sel && (document.getElementById(oname)))
		{
		ok = (document.getElementById(oname).value != '');
		}
	return ok;
JSUB
	&add_script("getradiolastother(control)","JavaScript",$subcode);
#
# Sub to check if it's the last option selected (specify)
#
	my $subcode = <<JSUB;
	var ok = true;
	var sel
	var len = new Number(control.length);
	var oname;
	if (isNaN(len))
		{
		sel = control.checked;
		oname = control.name.replace(/(\\d+)\$/,"other\$1");
		}
	else
		{
		sel = control[len-1].checked;
		oname = control[len-1].name.replace(/(\\d+)\$/,"other\$1");
		}
	if (sel && (document.getElementById(oname)))
		{
		ok = (document.getElementById(oname).value != '');
		}
	return ok;
JSUB
	&add_script("getradiolastspec(control)","JavaScript",$subcode);
#
# Sub to check if it's the last option was entered, but 'other' not selected 
#
	my $subcode = <<JSUB;
	var ok = true;
	var sel
	var len = new Number(control.length);
	var oname;
	if (isNaN(len))
		{
		sel = control.checked;
		oname = control.name+"other";
		}
	else
		{
		sel = control[len-1].checked;
		oname = control[len-1].name+"other";
		}
	if (document.getElementById(oname).value)
		{
		ok = sel;
		}
	return ok;
JSUB
	&add_script("getradioothertext(control)","JavaScript",$subcode);
	}

sub addjs_highlightradio()
	{
	my $subcode = <<JSUB;
//
// Generic script to highlight a selection 
//
//	alert("Looking for "+control.name);
	var radios = document.getElementsByName(control.name);
	if (radios)
		{
		var len = new Number(radios.length);
//		alert("Len="+len);
		if (isNaN(len))
			{
//			alert("id="+radios.id");
			if (radios.id)
				document.getElementById("TD"+radios.id).className = (radios.checked == '1') ? 'highlight' : 'options';
			}
		else
			for (var i=0;i<len;i++)
				{
//				alert("Looking for TD"+radios[i].id);
				if (radios[i].id)
					document.getElementById("TD"+radios[i].id).className = (radios[i].checked == '1') ? 'highlight' : 'options';
				}
		}
JSUB
	&add_script("highlightradio(control)","JavaScript",$subcode);
	}

sub addjs_highlightmulti()
	{
	my $subcode = <<JSUB;
//
// Generic script to highlight selections in a multi-select
//
//	alert("Looking for "+control.name);
	if (control.id)
		document.getElementById("TD"+control.id).className = (control.checked) ? 'highlight' : 'options';
JSUB
	&add_script("highlightmulti(control)","JavaScript",$subcode);
	}

sub addjs_toggle_highlight()
	{
	my $subcode = <<JSUB;
//
// Toggle function
//
	var reg = /\\D+/;
	var myclass = class_name;
	if (myclass == "grid_options" || myclass == "grid_options2" || myclass == "grid_highlight"  || myclass == "grid_highlight2") {
		var newclass = (on_off) ? 'grid_highlight' : 'grid_options';
	} else {
		var newclass = (on_off) ? 'highlight' : 'options';
	}
	var newname = myclass.replace(reg,newclass);
	//alert("Replacing "+myclass+" with "+newname+", "+on_off+", "+newclass);
	return newname;
JSUB
	&add_script("toggle_highlight(class_name,on_off)","JavaScript",$subcode);
	}

sub addjs_highlightgrid()
	{
	&addjs_toggle_highlight;
	my $subcode = <<JSUB;
//
// Generic script to highlight selections in a grid
//
//	alert("Looking for "+control.name);
	var radios = document.getElementsByName(control.name);
	if (radios)
		{
		var len = new Number(radios.length);
//		alert("Len="+len);
		if (isNaN(len))
			{
//			alert("id="+radios.id");
			if (radios.id)
				document.getElementById("TD"+radios.id).className = toggle_highlight(document.getElementById("TD"+radios.id).className,(radios.checked == '1'));
			}
		else
			for (var i=0;i<len;i++)
				{
//				alert("Looking for TD"+radios[i].id);
				if (radios[i].id)
					document.getElementById("TD"+radios[i].id).className = toggle_highlight(document.getElementById("TD"+radios[i].id).className,(radios[i].checked == '1'));
				}
		}
JSUB
	&add_script("highlightgrid(control)","JavaScript",$subcode);
	}


sub addjs_clrradio()
	{
	my $subcode = <<JSUB;
//
// Generic script to clear a single select question
//
	var len = new Number(control.length);
//	alert("len="+len);
	if (isNaN(len))
   		{
		control.checked = false;
		document.getElementById("TD"+control.id).className = toggle_highlight(document.getElementById("TD"+control.id).className,false);
		}
	else
		for (var i=0;i< len;i++)
			{
//			alert("Clearing "+control[i].id);
			control[i].checked = false;
			document.getElementById("TD"+control[i].id).className = toggle_highlight(document.getElementById("TD"+control[i].id).className,false);
			}
JSUB
	&add_script("clrradio(control)","JavaScript",$subcode);
	}

sub addjs_rank_number
	{
	my $subcode = <<JSUB;
//
// Generic script to provide a ranking feature for a number question
//
    var nn = new Array(max_rank+1);
    for (i=1;i<=max_rank;i++)
        {
        nn[''+i] = 0;
        }
    for (i=0;i<=num_elements;i++)
        {
# ??? Use of IE specific "all" is deprecated, should use .getElementById instead 
# Not sure if all controls have id attribute set - should check generation before
# we make this change
        control = document.all(prefix+i);
        if (control.value != '')
            {
            nn[control.value]++;
            }
        }
    for (i=1;i<=max_rank;i++)
        {
        if (nn[''+i] != 1)
            {
            alert('Please use each of the numbers 1 to '+max_rank+' once only');
            return false;
            }
        }
    return true;
JSUB
	&add_script("rank_number(max_rank,prefix,num_elements)","JavaScript",$subcode);
	}

sub addjs_cnt_row_multi
	{
	my $subcode = <<JSUB;
	var cnt = 0;
	for (i=0;i<cnt_row_multi.arguments.length;i++)
		{
		var control = cnt_row_multi.arguments[i];
//		alert("Control is "+control.name);
		if (control.checked)
			{cnt++;}
		}
	return cnt;
JSUB
	&add_script("cnt_row_multi()","JavaScript",$subcode);
	}

sub addjs_slider
	{
	my $qlab = shift;
	my $nattr = shift;
# This stuff is a hack to get some global variable declarations in:
# --- global subroutine:
	&add_script("global()","JavaScript",<<CODE);
var curElement;
var newleft=0;
var tag='';
CODE

#	$load_script = "loadme";		# Tell qt-libdb.pl to call this one
# --- loadme subroutine:
	&add_script("loadme()","JavaScript",<<CODE);
//	alert("Hello, I'm in the loadme() script now!");
//	document.ondragstart = doDragStart;
//	document.onmousedown = doMouseDown;
//	document.onmousemove = doMouseMove;
//	document.onmouseup = doMouseUp;
// Take this out for now, as it messes up if other stuff present on form
//	document.onkeypress = doKeyPress;
// NB onshow is only applicable to Internet Explorer !
//	document.onshow = doShow();
CODE

# --- doMouseMove subroutine:
	&add_script("doMouseMove()","JavaScript",<<CODE);
 	if ((event.button==1) && (curElement!=null)) 
 		{
        // position image
        newleft=event.clientX-document.getElementById("OuterDiv"+tag).offsetLeft-(curElement.width/2);
        if (newleft<document.getElementById("sliderbg"+tag).offsetLeft-(curElement.width)+2 ) 
        	newleft=document.getElementById("sliderbg"+tag).offsetLeft-(curElement.width)+2;
        if (newleft>462) newleft=462;
		calc_score();
        curElement.style.pixelLeft= newleft;
	    curElement.style.pixelTop = document.getElementById("sliderbg"+tag).style.pixelTop - 14;
        event.returnValue = false;
        event.cancelBubble = true;
    	}
CODE

# --- doDragStart subroutine:
	&add_script("doDragStart()","JavaScript",<<CODE);
    // Don't do default drag operation.
    if ("IMG"==event.srcElement.tagName)
    	event.returnValue=false;
CODE

# --- doMouseDown subroutine:
	my $mousedown = <<CODE;
    if ((event.button==1) && (event.srcElement.tagName=="IMG"))
    	{
      	curElement = event.srcElement;
      	tag = curElement.tag;
    	alert("MouseDown "+curElement.tagName);
CODE
	$mousedown .= <<CODE if ($dk ne '');
		if (document.getElementById("dk"+tag).checked) 
			{
			alert('Please uncheck "Don\\'t Know" before you provide a rating');
			}
CODE
	$mousedown .= qq{		\}\n};
	&add_script("doMouseDown()","JavaScript",$mousedown);

# --- doMouseUp subroutine:
	&add_script("doMouseUp()","JavaScript",<<CODE);
	if (curElement  != null)
		{
		if (newleft > 490)
			curElement.style.pixelLeft = 490;
		}
	curElement=null;
CODE
 
# --- doKeyPress subroutine:
	&add_script("doKeyPress()","JavaScript",<<CODE);
//	alert('keycode='+event.keyCode);
	if 	((event.keyCode >= 49) && (event.keyCode <= 57))
		{
		var n = event.keyCode;
		n -= 49;
		document.getElementById("sliderimg"+tag).style.pixelLeft = document.getElementById("sliderbg"+tag).offsetLeft-(document.getElementById("sliderimg"+tag).width)+2;
		document.getElementById("sliderimg"+tag).style.pixelLeft += 59*n;
		} 

	if ((event.keyCode == 43) || (event.keyCode == 61) || (event.keyCode == 46) || (event.keyCode == 62))	// +
		document.getElementById("sliderimg"+tag).style.pixelLeft += 30;
		
	if ((event.keyCode == 45) || (event.keyCode == 44) || (event.keyCode == 60))	// -
		document.getElementById("sliderimg"+tag).style.pixelLeft -= 30;
    if (document.getElementById("sliderimg"+tag).style.pixelLeft<document.getElementById("sliderbg"+tag).offsetLeft-(document.getElementById("sliderimg"+tag).width)+2 ) 
    	document.getElementById("sliderimg"+tag).style.pixelLeft=document.getElementById("sliderbg"+tag).offsetLeft-(document.getElementById("sliderimg"+tag).width)+2;
    if (document.getElementById("sliderimg"+tag).style.pixelLeft>462) document.getElementById("sliderimg"+tag).style.pixelLeft=462;
	calc_score();
CODE
	
# --- calc_score subroutine:
	&add_script("calc_score()","JavaScript",<<CODE);
	if (tag != '')
		{
		var score = 1 + Math.round((document.getElementById("sliderimg"+tag).style.pixelLeft+(10))/5.90)/10;
    	document.getElementById("slider"+tag).value = score;
    	}
CODE
	
# --- dkclick subroutine:
	&add_script("dkclick(control)","JavaScript",<<CODE);
//	alert('dk clicked');
	tag = control.tag;
	document.getElementById("sliderimg"+tag).src = "/pix/slider.gif";
	if (control.checked) 
		{
		document.getElementById("sliderimg"+tag).src = "/pix/sliderdk.gif";
		}
CODE
	}	
# Keep the general happy
1;
