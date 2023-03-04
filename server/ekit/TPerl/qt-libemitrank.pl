# $Id: qt-libemitrank.pl,v 1.7 2012-01-18 03:20:51 triton Exp $

sub emit_rank
	{
	&subtrace('emit_rank');
#	$len = @options;
	my @htbits = ();			# Make sure this is cleaned out.
	my $len = 0;
	my ($j,$hidden);
# Javascript validation code
	$code = "";
	my $num = grep(/1/,@a_show);		# How mny do we need dragged across?
	my $shownum = $num;
	$num = $required if (($required =~ /^[0-9]+$/) && ($required < $num));
	my $err29a = &subst_errmsg($sysmsg{ERRSTR_E29a});
	my $err29b = &subst_errmsg($sysmsg{ERRSTR_E29b});
	my $err30a = &subst_errmsg($sysmsg{ERRSTR_E30a});
	my $err30b = &subst_errmsg($sysmsg{ERRSTR_E30b});
	$code = qq{
	var a = \$('#drag .sortable-target').sortable('toArray');
//	alert(a.join(','));
	for (i=0;i<$shownum;i++)
		document.getElementById("rank${qlab}_"+i).value = '';				
	for (i=0;i<a.length;i++)
		{
		document.getElementById("rank${qlab}_"+i).value = a[i];				
		}
	if (a.length < $num)
		{
		alert("$err29a $num $err29b");
		return false;
		}
	if (a.length > $num)
		{
		alert("$err30a $num $err30b");
		return false;
		}
	return true;
};

	my $htbit = &indentme;
	$left_word = &subst($left_word);
	$left_word = $sysmsg{TXT_YOURS} if ($left_word eq '');
	$right_word = &subst($right_word);
	$right_word = $sysmsg{TXT_AVAIL} if ($right_word eq '');
# Includes for draggable widgets
	$htbit .= <<INCLUDE;
<!-- Includes -->
<link rel="stylesheet" type="text/css" href="/includes/drag.css" media="screen" />
<script type="text/javascript" src="/includes/jquery.min.js"></script>
<script type="text/javascript" src="/includes/jquery-ui.min.js"></script>
<!-- The next file may or may not contain hotfixes -->
<script type="text/javascript" src="/includes/hotfix.js"></script>

<!-- Drag'n'sort jQuery code (JavaScript)  -->
<script type="text/javascript">
\$(document).ready(function(){
	\$('#drag .sortable-list').sortable({
		connectWith: '#drag .sortable-target'
	});

	\$('#drag .sortable-target').sortable({
		connectWith: '#drag .sortable-list'
	});
});
</script>

INCLUDE

# Preliminary divs etc
	$htbit .= <<PRELIM;
<div id="center-wrapper">
	<div id="drag">
PRELIM
	my ($selected,$unselected,$hidden,@done);
	my @values = split($array_sep,get_data($q,$q_no,$qlab));
# First pass shows the ones that were selected last time around (if any)
	foreach (@values)
		{
		if ($a_show[$_])
			{
			$selected .= qq{<li class="sortable-item" id="$_">}.&subst($options[$_]).qq{</li>\n};
			$done[$_]++;
			}
		}
# Second pass shows the unselected ones...
	$i = $ix = 0;
	my $iy = 0;
	foreach (@options)
		{
		$i = $nlist[$ix] if ($random_options);
		if ($a_show[$i])
			{
			$unselected .= qq{<li class="sortable-item" id="$i">}.&subst($options[$i]).qq{</li>\n} if (!$done[$i]);
			my $idname = qq{rank${qlab}_$iy};
			$hidden .= qq{<input type="HIDDEN" name="$idname" id="$idname" value="">\n};
			$iy++;
			}
		$i++;
		$ix++;
		}

# Dump it all down...
	$htbit .= <<POST;
		<div class="column left first $qlab" >
			$left_word
			<div class="scale">
				<img src="/$survey_id/scale.$qlab.png"> 
			</div>
			<div class="target">
				<ol class="sortable-target">
				$selected
				</ol>
			</div>
		</div>

		<div class="column left $qlab">
			$right_word
			<ul class="sortable-list">
			$unselected
			</ul>
		</div>
		<div class="clearer">&nbsp;</div>
	</div>
</div>
$hidden
POST
	$htbit .= &undentme;
	&endsub;
	$htbit;
	}
1;
