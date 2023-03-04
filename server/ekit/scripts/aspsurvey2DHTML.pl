#!/usr/local/bin/perl
# $Id: aspsurvey2DHTML.pl,v 1.6 2011-07-26 09:14:59 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
#
require 'TPerl/qt-libdb.pl'; 					#perl2exe
use Data::Dumper;

use constant QTYPE_NUMBER			=> 1;
use constant QTYPE_MULTI			=> 2;
use constant QTYPE_ONE_ONLY			=> 3;
use constant QTYPE_YESNO			=> 4;
use constant QTYPE_WRITTEN			=> 5;
use constant QTYPE_PERCENT			=> 6;
use constant QTYPE_INSTRUCT			=> 7;
use constant QTYPE_EVAL				=> 8;
use constant QTYPE_DOLLAR			=> 9;
use constant QTYPE_RATING			=> 10;
use constant QTYPE_UNKNOWN			=> 11;
use constant QTYPE_FIRSTM			=> 12;
use constant QTYPE_COMPARE			=> 13;
use constant QTYPE_GRID				=> 14;		# Regular grid
use constant QTYPE_OPENS			=> 15;
use constant QTYPE_DATE				=> 16;
use constant QTYPE_YESNOWHICH		=> 17;
use constant QTYPE_WEIGHT			=> 18;
use constant QTYPE_AGEONSET			=> 19;
use constant QTYPE_CODE				=> 20;
use constant QTYPE_TALLY			=> 21;
use constant QTYPE_CLUSTER			=> 22;
use constant QTYPE_TALLY_MULTI		=> 23;
use constant QTYPE_GRID_TEXT		=> 24;
use constant QTYPE_GRID_MULTI		=> 25;
use constant QTYPE_GRID_PULLDOWN	=> 26;
use constant QTYPE_PERL_CODE		=> 27;
use constant QTYPE_REPEATER			=> 28;
use constant QTYPE_GRID_NUMBER		=> 29;
use constant QTYPE_SLIDER			=> 30;
#

$dhtml = 1;
$cmdline = 1;
$t = 1;
#$d = 1;
$no_wait=1;

sub die_usage
	{
	my ($msg) = @_;
	print STDOUT qq{Error: $msg\n} if ($msg ne '');
    print STDOUT qq{Usage: $0 [-v] [-t] [-h] [-l] Survey_ID\n};
    print STDOUT qq{\t-h Display help\n};
    print STDOUT qq{\t-v Display version no\n};
	print STDOUT qq{\t-t Trace mode\n};
	print STDOUT qq{\t-btn Include non-frame buttons\n};
    print STDOUT qq{\tSurvey_ID eg WOW101\n};
	if (!$no_wait)
		{	
		print STDOUT qq{\nPress <RETURN> to continue...};
		getc();
		}
	exit 0;
	}
	
sub die
	{
	my ($msg) = @_;
	print STDOUT qq{Error: $msg\n} if ($msg ne '');
	if (!$no_wait)
		{	
		print STDOUT qq{\nPress <RETURN> to continue...};
		getc();
		}
	exit 0;
	}

if ($h)
    {
    &die_usage;
    }
if ($v)
    {
    print STDOUT qq{$0: }.'$Header: /au/apps/alltriton/cvs/scripts/aspsurvey2DHTML.pl,v 1.6 2011-07-26 09:14:59 triton Exp $';
    exit 0;
    }

#
#
# ---- End of Configurable items ----
#

#
# Copy file, and substitute any tokens found along the way
#
sub xlate_copy
	{
	my $srcfile = shift;
	my $destfile = shift;
	my $skipping = 0;
	
	open (SRC,"<$srcfile") || die qq{Cannot read file $srcfile\n};
	print STDOUT qq{$srcfile => $destfile\n} if ($t);
	open (DST, ">$destfile") || die qq{Cannot create file $destfile\n};
	while (<SRC>)
		{
		s /\r//g;
		$skipping = 1 if (/<NOSUBST>/i);
		$skipping = 0 if (/<\/NOSUBST>/i);
		s /<\/*NOSUBST>//i;
		if (!$skipping)
			{
			while (/<%(\w+)%>/)
				{
				my $thing = $1;
				my $newthing = eval("\$$thing");
	#			$newthing = };//Unknown token: $thing} if ($newthing eq '');	# I Suppose we should log this substitution error somewhere
				$newthing = qq{} if ($newthing eq '');
				print STDOUT qq{<%$thing%> ==> $newthing\n} if ($d);
				s /<%$thing%>/$newthing/g;
				}
			}
		print DST;
		}
	close SRC;
	close DST;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
#
#
#

sub q_number
	{
	my $html = '';
	my $list = '';
#
# Build a list of the elements :-
#
	foreach (@options)
		{
		$setvars = $setvars.qq{setvar('$vars[$i]',document.triton.number${qlab}_$i.value);} if ($vars[$i] ne '');
		
		$list = $list.qq{document.triton.number${qlab}_$i.value,};
		$bits[$i] = qq{<$tdo>&nbsp;$options[$i]</TD><$tdo> <INPUT NAME="number${qlab}_$i" TYPE="text" SIZE="8"></TD>};
		$i++;
		}
#
# Now render them :-
#
	$html = $html.qq{<BLOCKQUOTE><TABLE CELLPADDING="$pad" cellspacing="$cellspacing">\n};
	if ($len < 1)
		{
		$html = $html.qq{<$tro>\n};
		for ($i = 0;$i < @bits;$i++)
			{
			$html = $html.qq{$bits[$i]\n};
			}
		$html = $html.qq{<$tro>\n};
		}
	else
		{
		$ncols = ($len > 15) ? 2 : 1;		
		$n = int((@bits+1)/$ncols);
		for ($i = 0;$i < $n;$i++)
			{
			$j = $n + $i;
			$html = $html.qq{<$tro>$bits[$i]\n};
			$bit = $bits[$j];
			$bit = qq{} if ($j > @bits);
			$html = $html.qq{$bit</TR>\n};
			}
		}
	chop($list);
	$val = qq{''};
	$val = qq{'asc'} if ($validation eq 'validate_number_asc');
	$val = qq{'desc'} if ($validation eq 'validate_number_desc');
	$validation = '';
	$total = qq{''} if ($total eq '');
	$validate = qq{data-validate="validate_number($limlo,$limhi,$val,$total,$list)"}; 
	$total = '';
	$html = $html.qq{</TABLE></BLOCKQUOTE>\n};
	$html;
	}
	
sub q_multi
	{
	my $html = '';
	my $controls = '';
#
# Build a list of the elements :-
#
	my $ncols = ($len >= $max_multi_1_col) ? 2 : 1;		
	foreach (@options)
		{
		$bits[$i] = qq{<INPUT NAME="check${qlab}_$i" ID="check${qlab}_$i" TYPE="checkbox" };
		$bits[$i] = $bits[$i].qq{onclick="setvar('$vars[$i]',this.checked)" } if ($vars[$i] ne '');
		$bits[$i] = $bits[$i].qq{VALUE="1">&nbsp;<LABEL FOR="check${qlab}_$i">$options[$i]</LABEL>&nbsp;};
		$controls .= qq{,} if ($i > 0);
		$controls .= qq{'check${qlab}_$i'};
		$i++;
		}
	if ($others >= 1)
		{
		$bit = qq{};
		for ($j = 1; $j <= $others; $j++)
			{
			$bits[$i] = qq{<INPUT NAME="check${qlab}_$i" TYPE="checkbox" VALUE="1">};
			$bit = qq{$j.} if ($others > 1);
			$bits[$i] = $bits[$i].qq{&nbsp;Other $bit <I>(specify) : </I>\n};
			$bits[$i] = $bits[$i].qq{\t<INPUT TYPE="TEXT" SIZE="20" NAME="other${qlab}_$i" \n};
			$bits[$i] = $bits[$i].qq{\t onchange="triton.check${qlab}_$i.checked = (this.value != '');">};
			$controls .= qq{,} if ($i > 0);
			$controls .= qq{'check${qlab}_$i'};
			$i++;
			}
		}
	$validate = qq{data-validate="validate_multi('$required','$max_select','$others',$controls)" };

#
# Now render them :-
#
	&add2body(qq{<BLOCKQUOTE><TABLE CELLPADDING="$pad" cellspacing="$cellspacing">});
	if ($len < $KMAX_ONELINE)
		{
		$html = $html.qq{<$tro>\n};
		for ($i = 0;$i < @bits;$i++)
			{
			$html = $html.qq{\t<$tdo>$bits[$i]</TD>\n};
			}
		$html = $html.qq{<$tro>\n};
		}
	else
		{
		$n = $#bits+1;
		$loop = ($ncols > 1) ? int(($n+1)/$ncols) : $n;
		for ($i = 0;$i < $loop;$i++)
			{
			$j = $loop + $i;
			$html = $html.qq{<$tro><$tdo>$bits[$i]</TD>\n};
			$bit = $bits[$j];
			if ($ncols > 1)
				{
				$bit = qq{} if ($j > @bits);
				$html = $html.qq{\t<$tdo>$bit</TD>};
				}
			$html = $html.qq{</TR>\n};
			}
		}
	$html = $html.qq{</TABLE></BLOCKQUOTE>\n};
	}
	
sub q_opens
	{
	my $html = '';
#
# Build a list of the elements :-
#
	my @labs;
	my $controls = '';
	foreach (@options)
		{
		$labs[$i] = qq{&nbsp;$options[$i] &nbsp;};
		$bits[$i] = qq{<INPUT NAME="opens${qlab}_$i" TYPE="TEXT" size="$text_size">};
		$controls = $controls.qq{,} if ($i > 0);
		$controls = $controls.qq{'opens${qlab}_$i'};
		$i++;
		}
	
	$validate = qq{data-validate="validate_opens('$required',$controls)"};
#
# Now render them :-
#
	$html = $html.qq{<BLOCKQUOTE><TABLE CELLPADDING="$pad" cellspacing="$cellspacing">\n};
	if ($len < $KMAX_ONELINE)
		{
		$html = $html.qq{<$tro>\n};
		for ($i = 0;$i < @bits;$i++)
			{
			$html = $html.qq{\t<$tdo>$labs[$i]</TD><$tdo>$bits[$i]</TD>\n};
			}
		$html = $html.qq{</TR>\n};
		}
	else
		{
		$ncols = ($len > 10) ? 2 : 1;		
		$n = int((@bits)/$ncols);
		for ($i = 0;$i < $n;$i++)
			{
			$j = $n + $i;
			$html = $html.qq{\t<$tro><$tdo>$labs[$i]</TD><$tdo>$bits[$i]</TD>\n};
			$bit = $bits[$j];
			$lab = $labs[$j];
			if ($ncols > 1)
				{
				$bit = qq{} if ($j > @bits);
				$lab = qq{} if ($j > @bits);
				$html = $html.qq{\t\t<$tdo>$lab</TD><$tdo>$bit</TD>};
				}
			$html = $html.qq{</TR>\n};
			}
		}
	$html = $html.qq{</TABLE></BLOCKQUOTE>\n};
	}

sub grid_extra
	{
	my $html = shift;
	if ($show_anchors)
		{
		$html = $html.qq{<$trh>\n\t\t<$thh></TD>};
		$html = $html.qq{	<$thh COLSPAN="$half" ALIGN="LEFT">$left_word&nbsp;&nbsp;<BR>&nbsp;&lt;==</TH>\n};
		$html = $html.qq{		<$thh>&nbsp;$middle&nbsp;</TH>} if ($extra);
		$html = $html.qq{	<$thh COLSPAN="$half" ALIGN="RIGHT">&nbsp;&nbsp;$right_word <BR>==&gt;&nbsp;</TH>\n};
		$html .= qq{<$thh>&nbsp;</TH><$thh>&nbsp;</TH>} if ($dk ne '');
		$html = $html.qq{</TR>\n};
		}
	if ($show_scale_nos)
		{
		$html = $html.qq{\t<$trh>\n\t\t<$thh></TD>\n};
		for ($k=1;$k<=$scale;$k++)
			{
			$html = $html.qq{		<$thh><CENTER>&nbsp;$k&nbsp;</CENTER></TH>};
			}
		}
	if ($show_scale)
		{
		$html = $html.qq{\t<$trh>\n\t\t<$thh></TD>\n};
		for ($k=0;$k<=$#scale_words;$k++)
			{
			$html = $html.qq{\t\t<$thh>&nbsp;$scale_words[$k]&nbsp;</TH>\n};
			}
		}
	if (($dk ne '') && !$rank_grid)
		{
		$html = $html.qq{		<$thh>&nbsp;&nbsp;&nbsp;</TH>};
		$html = $html.qq{		<$thh>$dk</TH>};
		}
	if (($others) && !$rank_grid)
		{
		$html = $html.qq{		<$thh>&nbsp;Other (specify)&nbsp;</TH>};
		}
	$html = $html.qq{   </TR>};
	}
	
sub q_grid
	{
	my $html = '';
	$show_anchors = 0;
	$show_anchors = 1 if (!defined(@scale_words) || $rank_grid);
	$show_scale = defined(@scale_words);
	$show_scale_nos = !defined(@scale_words);
	if ($scale < 0)		# Negative scale means 'show anchors anyway'
		{
		$show_anchors = 1;		
		$show_scale = 1;
		$show_scale_nos = 0;
		$scale = abs($scale);
		}
	$cellspacing = 0;
	$html = $html.qq{<TABLE CELLPADDING="$pad" cellspacing="$cellspacing" border=0 class="mytable">\n};
	$left_word = qq{Unappealing} if ($left_word eq '');
	$right_word = qq{Appealing} if ($right_word eq '');
	$scale = 10 if ($scale eq '');
	$half = int(($scale)/2);
	$extra = int(($scale-($half*2)));
	$list = '';
	$i = 0;
	my $itype = ($multi) ? 'CHECKBOX' : 'RADIO';
	foreach (@options)
		{
		if (($i % 6) == 0)
			{
			$html = &grid_extra($html);
			}
		$html = $html.qq{\t\t<$tro>\n\t\t\t<$tdo>&nbsp;$options[$i] &nbsp;&nbsp;&nbsp;</TD>\n};
		for ($k=0;$k<$scale;$k++)
			{
			$html = $html.qq{\t\t\t<$tdo><CENTER><INPUT TYPE="$itype" NAME="grid${qlab}_$i" VALUE="$k"></CENTER></TD>\n};
			}
#		$html = $html.qq{		<$tdo>&nbsp;</TD>\n} if ($extra);
		$list = $list.qq{'grid${qlab}_$i',};
		if (($dk ne '') && !$rank_grid)
			{
			$html = $html.qq{\t\t\t<$tdo><CENTER>&nbsp;</CENTER></TD>\n};
			$html = $html.qq{\t\t\t<$tdo><CENTER>\n};
			$html = $html.qq{<INPUT TYPE="$itype" NAME="grid${qlab}_$i" VALUE="$k">\n};
			$html = $html.qq{</CENTER></TD>\n};
			}
		if (($others) && !$rank_grid)
			{
			$html = $html.qq{\t\t\t<$tdo><CENTER>\n};
			$html = $html.qq{<INPUT TYPE="$itype" NAME="grid${qlab}_$i" VALUE="$k">\n};
			$html = $html.qq{<INPUT TYPE="TEXT" NAME="grid${qlab}_${i}other">\n};
			$html = $html.qq{</CENTER></TD>\n};
			}
		$html = $html.qq{\t\t</TR>\n};
		$i++;
		}
	chop($list);
	$html = $html.'</TABLE>';	
	$validate = qq{data-validate="validate_grid($list)"};
	if ($rank_grid)
		{
		$validate = qq{data-validate="validate_rank($list)"}; 
		$instr = $instr.qq{ When ranking, remember to select one per row and one per column only};
		}
	$html;
	}
	
sub q_one
	{
	my $html = '';
#
# Build a list of the elements :-
#
	my $n = 0;
	my $ncols = (($len > 10) && ($others == 0))  ? 2 : 1;		
	foreach (@options)
		{
		$setvars = $setvars.qq{setvar('$vars[$n]',(document.triton.radio${qlab}[$n].checked == '1'));} if ($vars[$n] ne '');
		$next = $skips[$n];
		$next = -2 if ($q_no == $numq);

		$bits[$n] = qq{<INPUT NAME="radio$qlab" ID="radio${qlab}_$n" TYPE="radio" VALUE="$n" onclick="setskip($q_no,$next)">&nbsp;<LABEL FOR="radio${qlab}_$n">$options[$n]</LABEL>&nbsp;};
		$n++;
		}
	if ($others == 1)
		{
		$next = 0;
		$bits[$n] = qq{<INPUT NAME="radio$qlab" TYPE="radio" VALUE="$n" onclick="setskip($q_no,$next)">Other <I>(specify) : </I>};
		my $ix = $n;
		if ($ncols > 1)
			{
			$ix-- if (($n % 2) == 0);
			} 
		$bits[$n] = $bits[$n].qq{<INPUT TYPE="TEXT" SIZE="25" NAME="other$qlab" onchange="triton.radio$qlab\[$ix].checked = (this.value != '');"};
		$n++;
		}
#
# Now render them :-
#
	$html = $html.qq{<BLOCKQUOTE><TABLE CELLPADDING="$pad" cellspacing="$cellspacing">\n};
	if ($len < $KMAX_ONELINE)
		{
		$html = $html.qq{<$tro>\n};
		for ($i = 0;$i < $n-1;$i++)
			{
			$html = $html.qq{<$tdo>$bits[$i]</TD>\n};
			}
		$html = $html.qq{<$tro>\n};
		}
	else
		{
		my $loop = ($ncols > 1) ? int(($n+1)/$ncols) : $n;
		for ($i = 0;$i < $loop;$i++)
			{
			$j = $loop + $i;
			$html = $html.qq{<$tro><$tdo>$bits[$i]</TD>\n};
			$bit = $bits[$j];
			$bit = qq{} if ($j > $n);
			if ($ncols > 1)
				{
				$html = $html.qq{<$tdo>$bit</TD>};
				}
			$html = $html.qq{</TR>\n};
			}
		}
	$html = $html.qq{</TABLE></BLOCKQUOTE>\n};
	$validate = qq{data-validate="validate_one('radio$qlab','$others')"}; 
	$html;
	}
	
sub q_yesno
	{
	&q_one;
	}
	
sub q_written 
	{
	my $html = '';
#	$html = $html.qq{Enter response here : <BR>\n};
	$validate = qq{data-validate="validate_written('written$qlab')"};
	$html .= qq{<BLOCKQUOTE><TEXTAREA NAME="written$qlab"};
	$html .= qq{ WRAP="PHYSICAL" COLS="50" ROWS="8"></TEXTAREA><BR>\n};
#	$html .= qq{<INPUT TYPE="checkbox" name="written_na${qlab}" VALUE="1">Nothing</BLOCKQUOTE>};
	$html .= qq{<INPUT TYPE="checkbox" id="written_na${qlab}" name="written_na${qlab}" VALUE="1">\n};
	$html .= qq{<LABEL FOR="written_na${qlab}">Nothing</LABEL></BLOCKQUOTE>\n};
	}
	
sub q_percent 
	{
	my $html = '';
	my $list = '';
#
# Build a list of the elements :-
#
	foreach (@options)
		{
		$list = $list.qq{document.triton.number${qlab}_$i.value,};
		$bits[$i] = qq{<$tdo>&nbsp;$options[$i]</TD><$tdo> <INPUT NAME="number${qlab}_$i" TYPE="text" SIZE="12" ></TD>};
		$i++;
		}
#
# Now render them :-
#
	$html = $html.qq{<BLOCKQUOTE><TABLE CELLPADDING="$pad" cellspacing="$cellspacing">\n};
	if ($len < 1)
		{
		$html = $html.qq{<$tro>\n};
		for ($i = 0;$i < @bits;$i++)
			{
			$html = $html.qq{$bits[$i]\n};
			}
		$html = $html.qq{<$tro>\n};
		}
	else
		{
		$ncols = ($len > 10) ? 2 : 1;		
		$n = int((@bits+1)/$ncols);
		for ($i = 0;$i < $n;$i++)
			{
			$j = $n + $i;
			$html = $html.qq{<$tro>$bits[$i]\n};
			$bit = $bits[$j];
			$bit = qq{} if ($j > @bits);
			$html = $html.qq{$bit</TR>\n};
			}
		}
	chop($list);
	$validate = qq{data-validate="validate_perc(0,100,$list)"}; 
	$html = $html.qq{</TABLE></BLOCKQUOTE>\n};
	$html;
	}
	
sub q_instruct	
	{
	}
	
#
sub q_eval
	{
	my $html = '';
	$html = $html.qq{<I>You should never see this, as it is a decision point in the survey. If you do see it, simply click the button below.</I><BR><BR>\n};
	$html = $html.qq{<BUTTON name="eval$q_no" onclick="skipto('$lhs','$rhs',$skips[0],$skips[1],$skips[2])">Click me please !</BUTTON>\n};
	}
	
sub q_dollar
	{
	my $html = '';
#
# Set up currency pull-down
#
	$currency = qq{<SELECT NAME="currency" SIZE="1">};
	$currency = $currency.qq{<OPTION VALUE="1" SELECTED>US\$};
	$currency = $currency.qq{<OPTION VALUE="2">A\$};
	$currency = $currency.qq{<OPTION VALUE="3">HK\$};
	$currency = $currency.qq{<OPTION VALUE="4">YEN};
	$currency = $currency.qq{<OPTION VALUE="5">GB POUND};
	$currency = $currency.qq{</SELECT>};
#
# Build a list of the elements :-
#
	my $list = '';
	foreach (@options)
		{
		$bits[$i] = qq{<$tdo>&nbsp;$options[$i]</TD>};
		$bits[$i] = $bits[$i].qq{<$tdo> <INPUT NAME="number${qlab}_$i" TYPE="text" SIZE="12" ></TD>};
		$bits[$i] = $bits[$i].qq{<$tdo> $currency</TD>};
		$list = $list.qq{,} if ($i > 0);
		$list = $list.qq{document.triton.number${qlab}_$i.value};
		$i++;
		}
	$val = '';
	$total = qq{''} if ($total eq '');
	$validate = qq{data-validate="validate_number($limlo,$limhi,$val,$total,$list)"}; 
	$total = '';
#
# Now render them :-
#
	$html = $html.qq{<BLOCKQUOTE><TABLE CELLPADDING="$pad" cellspacing="$cellspacing">\n};
	if ($len < 1)
		{
		$html = $html.qq{<$tro>\n};
		for ($i = 0;$i < @bits;$i++)
			{
			$html = $html.qq{$bits[$i]\n};
			}
		$html = $html.qq{<$tro>\n};
		}
	else
		{
		$ncols = ($len > 10) ? 2 : 1;		
		$n = int((@bits+1)/$ncols);
		for ($i = 0;$i < $n;$i++)
			{
			$j = $n + $i;
			$html = $html.qq{<$tro>$bits[$i]\n};
			$bit = $bits[$j];
			$bit = qq{} if ($j > @bits);
			$html = $html.qq{$bit</TR>\n};
			}
		}
	$html = $html.qq{</TABLE></BLOCKQUOTE>\n};
	}
	
sub q_rating 
	{
	}
	
sub q_unknown 
	{
	}
	
sub q_firstm 
	{
	}
	
sub q_compare 
	{
	}
	
sub do_external
	{
	local $mix = 0;
	local @m_controls = ();
	$validate = 'bogus';
	my $file = qq{${htmldir}}.shift;
	print STDOUT qq{Reading in EXTERNAL HTML file: $file\n};
	if (!open (SRC,"<$file"))
		{
		print STDOUT qq{Error: [$!] reading template file: $file\n};
		if (!$no_wait)
			{	
			print STDOUT qq{\nPress <RETURN> to continue...};
			getc();
			}
		die qq{\n};
		}
	else
		{
		while (<SRC>)
			{
			chomp;
			my $buf = lc($_);
			next if ($buf =~ /<\/*html/);
			next if ($buf =~ /<\/*form/);
			next if ($buf =~ /<title/);
			next if ($buf =~ /<meta/);
			next if ($buf =~ /<\/*head/);
			next if ($buf =~ /<\/*body/);
			next if ($buf =~ /<link\s+rel=/);
			next if ($buf =~ /type="*hidden/);
#			if (($buf =~ /\<input/) && ($buf =~ /name=['"](m_\S++)["' ]/))
			if (($buf =~ /\<input/) && ($buf =~ /name=["']*(m_\w+)["']*/))
				{
				$m_controls[$mix++] = qq{'$1'};
				}
			while (/<%(\w+)%>/)
				{
				my $thing = $1;
				my $newthing = eval("\$$thing");
	#			$newthing = };//Unknown token: $thing} if ($newthing eq '');	# I Suppose we should log this substitution error somewhere
				$newthing = qq{} if ($newthing eq '');
				print STDOUT qq{<%$thing%> ==> $newthing\n} if ($d);
				s /<%$thing%>/$newthing/g;
				}
			last if ($buf =~ /end of form/);
			&add2body($_);
			}
		close (SRC);
		}
	if ($mix > 0)
		{
#		$validate = qq{data-validate="validate_mandatory(}.join(",",@m_controls).qq{)"});
		}
	}

	
sub do_q
	{
	$i = 0;
	$len = $#options + 1 + $others;
	$display = 'style="display:none"';
	$validate = qq{data-validate="validate('')"}; 
	if ($q_no > 1)
		{
		if ($ns)
			{
			$display = 'VISIBILITY="HIDDEN"';
			}
		else
			{
			$display = 'style="display:none"' ;
			}
		}
	if ($ns)
		{
		&add2body(qq{<LAYER NAME="section$q_no" $display>});
		&add2body(qq{<FORM NAME="form$q_no">});
		}
	else
		{
		&add2body(qq{<DIV ID="Section$q_no" $display>});
		&add2body(qq{<A NAME="A$q_no">});
		}
	if ($external ne '')
		{
		&do_external($external);
		}
	else
		{
		&add2body(qq{<SPAN class="prompt">$prompt</SPAN><BR>});
#		&add2single("$prompt<BR>") if ($q_no == 1);
		$pad = (($#options+$others) > 5) ? 2 : 4;
		$pad = 1 if (($#options+$others) > 9);
		$pad = 0;
		$setvars = '';
		undef @bits;
		my $html = '';
#		print qq{qtype=$qtype (number=QTYPE_NUMBER)\n} if ($d);
		$html .= &q_number if ($qtype == QTYPE_NUMBER);
		$html .= &q_multi if ($qtype == QTYPE_MULTI);
	    $html .= &q_yesno if ($qtype == QTYPE_YESNO);
	    $html .= &q_one if ($qtype == QTYPE_ONE_ONLY);	
	    $html .= &q_written if ($qtype == QTYPE_WRITTEN);
	    $html .= &q_percent if ($qtype == QTYPE_PERCENT);
	    $html .= &q_instruct if ($qtype == QTYPE_INSTRUCT);
	    $html .= &q_eval if ($qtype == QTYPE_EVAL);
	    $html .= &q_dollar if ($qtype == QTYPE_DOLLAR);
	    $html .= &q_rating if ($qtype == QTYPE_RATING);
	    $html .= &q_unknown if ($qtype == QTYPE_UNKNOWN);
	    $html .= &q_firstm if ($qtype == QTYPE_FIRSTM);
	    $html .= &q_compare if ($qtype == QTYPE_COMPARE);
	    $html .= &q_grid if ($qtype == QTYPE_GRID);
	    $html .= &q_opens if ($qtype == QTYPE_OPENS);
		print qq{html=$html\n} if ($d);
	    if ($html ne '')
	    	{
		    &add2body($html);
	    	if ($q_no == 1)
	    		{
	    		$html =~ s/onclick="setskip\(\d+\,\d+\)"//g;
#		    	&add2single($html) ;
		    	}
	    	}
	   	$instr = $def_instr[$qtype] if ($instr eq '');
		if ($instr ne '')
			{
		    &add2body(qq{<SPAN  class="instruction"><I>$instr</I></SPAN><BR>});
#	    	&add2single("<SPAN class="instruction"><I>$instr</I></SPAN><BR>}) if ($q_no == 1);
	    	}
	    }
	print TOC qq{<A HREF="javascript:parent.frames.body.jumptoq($q_no)">$qlab</A><BR>\n} if ($qtype != $QTYPE_EVAL);

	if ($btn || !$ns)
		{
		&add2body(qq{<DIV class="BTN">});
		&add2body(qq{<HR>});
		&add2body(qq{<TABLE>});
		&add2body(qq{<TR>});
		$next = $q_no + 1;
		$next = -2 if ($q_no == $numq);
		$prev = $q_no - 1;
		if ($ns)
			{
			&add2body(qq{<TD><IMG src="/pix/back.gif" ID="backbtn$q_no" alt="Back" onMouseUp="goback()"</TD>}) if ($prev > 0);
			&add2body(qq{<TD><IMG src="/pix/next.gif" ID="backbtn$q_no" alt="Next" onMouseUp="gofwd(this)"</TD>});
			}
		else
			{
			&add2body(qq{<TD><BUTTON ID="backbtn$q_no" data-tag="$prev" onclick="goback()"> &lt;&lt;BACK</BUTTON></TD>}) if ($prev > 0);
			&add2body(qq{<TD><BUTTON ID="nextbtn$q_no" data-tag="$next" $validate onclick="gofwd(this)" data-setvars="$setvars">NEXT &gt;&gt;</BUTTON></TD>});
			$setvars = '';
			}
		&add2body(qq{</TR></TABLE>});
		&add2body(qq{</DIV>});
		}
	&add2body(qq{</FORM>}) if ($ns);
	$tag = ($ns) ? 'LAYER' : 'DIV';
    &add2body(qq{</$tag>});
	}
#------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------
#
# Mainline starts here
#
	$plain = 1;
	$do_body = 1;
#	&die_usage('Insufficient parameters') if ($#ARGV < 1);
	$cmd = shift;
	$gen = ($cmd eq 'generate');
	print qq{cmd=$cmd\n} if $d;
	$ok = 1;
	&die_usage("Invalid command: $cmd") if (!$ok);
	$survey_id = ($cmd eq 'generate') ? shift : $cmd;
#	print STDOUT qq{sid=$survey_id\n};
	&die_usage('Survey_ID is required') if ($survey_id eq '');
	$config_dir = qq{$qt_root/$survey_id/config};
    &die_usage("Directory not found: $config_dir") if (! -d $config_dir);
    $filename = qq{$qt_root/$survey_id/config/qlabels.pl};
	print qq{qlabels=$filename\n} if $t;
    &debug("Requiring question labels: $filename");
  	my_require ($filename,1);
  	&get_config($survey_id);
#    $filename = qq{$qt_root/$survey_id/config/config.pl};
#   &debug("Requiring config file: $filename");
#  	my_require ($filename,0);
# 
	$toc = qq{12%} if ($toc ne '');

#
# Copy the standard template files :-
#
	$htmldir = qq{$qt_root/$survey_id/html/};
	print STDOUT qq{target directory = $htmldir \n} if ($t);
#	$browser = ($ns) ? 'ns' : 'ie';
	$src = qq{$qt_root/templates/};
	$goop = qq{nsgoop.js};
#	&xlate_copy("${src}$goop","${htmldir}$goop");
	$goop = qq{iegoop.js};
	$goop = qq{iegoop_$charset.js} if ($charset ne '');
	$code = qq{var numq = $numq;};
	&add_script("","JavaScript",$code);
#	&xlate_copy("${src}$goop","${htmldir}$goop");

	$src = qq{$qt_root/$survey_id/templates/} if (-d "$qt_root/$survey_id/templates/");
	
	opendir(DDIR,$src) || die ("Cannot open directory $src");
	my @files = grep (/\.htm/ || /\.css/ || /\.js/,readdir(DDIR));
	closedir(DDIR);
	foreach $file (@files)
		{
		next if $file =~ /^\./;
		&xlate_copy("$src$file","$htmldir$file");
		}
#
# Spit out the body document :-
#
	$style = 'plain' if ($style eq '');
	$singlename = qq{$htmldir/single.htm};
	print qq{opening single $singlename\n} if $d;
	open (SINGLE,">$singlename") || die qq{Cannot create output file: $singlename\n};  
	$htmlname = qq{$htmldir/body.htm};
	open (HTML,">$htmlname") || die qq{Cannot create output file: $htmlname\n};  
	$tocname = qq{$htmldir/toc.htm};
	open (TOC,">$tocname") || die qq{Cannot create output file: $tocname\n};  	
	my $tocbit = '';
	$tocbit = $tocbit.qq{<HTML><HEAD>\n};
	$tocbit = $tocbit.qq{<meta http-equiv="Content-Type" content="text/html; charset=$charset">} if ($charset ne '');
	$tocbit = $tocbit.qq{<TITLE>Triton Technology</TITLE>\n};
	$tocbit = $tocbit.qq{</HEAD>\n};
	$tocbit = $tocbit.qq{<link rel="stylesheet" href="style.css">\n};
	print SINGLE $tocbit;
	$tocbit = $tocbit.qq{<link rel="stylesheet" href="style.css">\n};
	$tocbit = $tocbit.qq{<BODY BGCOLOR="$bgcolor" TEXT="$textcolor" BACKGROUND="$background"  class="body" onload="resetme()">\n};
	$tocbit = $tocbit.qq{<B>Index</B><HR>\n};
	$tocbit = $tocbit.qq{<font COLOR="Blue"><U>};
	print TOC $tocbit;

	&add2hdr(qq{<link rel="stylesheet" href="style.css">});
	&add2hdr(qq{<STYLE title="localStyle">\n	.BTN {color: blue; display:}\n</STYLE>});
	&add2hdr(qq{<SCRIPT language="JavaScript" SRC="/$survey_id/$goop">});
	&add2hdr(qq{</SCRIPT>});
	&add2hdr(qq{<TITLE>Triton Technology</TITLE>});
	&add2hdr(qq{   <META NAME="Triton Technology"> });
	&add2hdr(qq{   <META NAME="Author" CONTENT="Mike King"> });
	&add2hdr(qq{   <META NAME="Copyright" CONTENT="Triton Technology 1995-2000, all rights reserved"> });
	
#	&add2body(qq{<BODY BGCOLOR="$bgcolor" TEXT="$textcolor" onload="resetme()" BACKGROUND="$background"  class="body" onload="resetme()">});
	&add2body(qq{<DIV ID="Start"><FONT size="+2" face="Arial, Helvetica, sans-serif"> Welcome to $survey_name<BR><BR>});
	&add2body(qq{Please wait a second while the survey loads...</font></DIV>});
	if (!$ns)
		{
		&add2body  (qq{<FORM NAME="triton" onsubmit="return false" ACTION="${virtual_cgi_bin}$go.$extension" ENCTYPE="www-x-formencoded" METHOD="POST">});
		}
#	&add2single(qq{<link rel="stylesheet" href="style.css">});
	&add2single(qq{<FORM NAME="q" ACTION="${virtual_cgi_bin}$go.$extension" ENCTYPE="www-x-formencoded" METHOD="POST"});
   	if ($one_at_a_time == 1)
   		{
   		&add2single(qq{		OnSubmit="return QValid()"});
   		}
	&add2single(">");

	&add2body  (qq{<INPUT NAME="survey_id" TYPE="hidden" VALUE="$survey_id">});
	&add2single(qq{<INPUT NAME="survey_id" TYPE="hidden" VALUE="$survey_id">});
    &add2single(qq{<INPUT NAME="jump_to" TYPE="hidden" VALUE="">});
	&add2body  (qq{<INPUT NAME="seqno" TYPE="hidden" VALUE="">});
	&add2single(qq{<INPUT NAME="seqno" TYPE="hidden" VALUE="">});
	&add2body  (qq{<INPUT NAME="q_no" TYPE="hidden" VALUE="1">});
	&add2single(qq{<INPUT NAME="q_no" TYPE="hidden" VALUE="1">});
#	&add2body  (qq{<INPUT NAME="survey_name" TYPE="hidden" VALUE="$survey_name">});
#	&add2single(qq{<INPUT NAME="survey_name" TYPE="hidden" VALUE="$survey_name">});

    $filename = qq{$qt_root/$survey_id/config/q1.pl};
	print qq{require q1.pl :$filename\n} if $d;
    &debug("Requiring $filename");
  	my_require ($filename,1);
#  	$prompt =~ s/^Q(\S+)\./<B>$1\.<\/B>/;
	$code = '';
	print qq{plain=$plain\n} if $d;
	# print 'survey2DHTML options '.Dumper \@options if $d;
	print qq{qtype=$qtype\n} if $d;
	&do_masking();
	my $q_html = &emit_q($plain);
	print qq{html = $q_html\n} if $d;
	&add2single($q_html);
#
# Header will most likely be in another frame
#
	
	for ($q_no = 1; $q_no <= $numq; $q_no++)
		{
		undef @options ;			# Make sure that they are cleaned out OK.
		undef $others;
		undef $rank_grid;
		undef $random_options;
		undef $external;			# Make sure this does not carry forward
		$max_multi_1_col = 10;
	    $filename = qq{$qt_root/$survey_id/config/q$q_no.pl};
	    &debug("Requiring $filename");
	  	my_require ($filename,1);
	  	$prompt =~ s/^Q(\S+)\./<B>$1\.<\/B>/;
	  	&do_q;
		}
	
	if ($ns)
		{
		&add2body(qq{<FORM name="triton" action="${virtual_cgi_bin}$go.$extension" method="POST">});
		}
	&add2body(qq{</FORM>});
	select(HTML);
	$load_script = qq{resetme};
	&dump_html;
	close HTML;
	$resp{'survey_id'} = $survey_id;		# This is a horrible hack, but will fix the immediate problem
	&add2single(&btn_by(0));
	&add2single('</FORM>');
#
	select SINGLE;
	$dhtml = 0;
	&dump_scripts;
	&dump_single;
	close SINGLE;
	$dhtml = 1;
	select;
	print TOC qq{</FONT></BODY>\n};
	close TOC;

	if (!$no_wait)
		{	
		print STDOUT qq{\nPress <RETURN> to continue...};
		getc();
		}
		
# Always try to be tidy
1;
