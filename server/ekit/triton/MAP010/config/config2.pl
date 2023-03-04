#!/usr/bin/perl
#
# Survey config.pl file - lives in $triton_root/XXX999/config directory
# (alongside qlabels.pl etc)
#
# This file is hand edited - it is created empty to start with
#
#	$thankyou_url = "thanks.htm";			# Where to re-direct to when we are done
#	$mailto = "info\@market-research.com";
#	$one_at_a_time = 1;						# Ask only one question at a time
#	$block_size = 10;						# Applies if above is zero,

#
# No matter what you do, leave this poor soldier intact on the last line
#
$allow_restart = 1;

$BTN_NEXT = " NEXT >> ";
$BTN_REFUSED = "NEXT (skips checking)";
$BTN_BACK = " << BACK ";
$show_back_button = 1;
@jump_index = (
				'A.q4',
				'q5.q9',
				'q10',
				'LAST.LAST',
				);
$ws_details = <<WSDETAILS;
<TABLE cellspacing=0 cellpadding=0 border=1 >
<TR><TD><TABLE cellspacing=0 cellpadding=1 border=0 width=596>
	<TR class="details"><TH align="RIGHT">&nbsp;Participant:&nbsp;<TD>&nbsp;<%id%> <%fullname%>&nbsp;<TD width=10>&nbsp; <TH align="RIGHT">&nbsp;Organization:&nbsp;<TD>&nbsp;<%company%>&nbsp;
	<TR class="details"><TH align="RIGHT">&nbsp;Workshop Date:&nbsp;<TD>&nbsp;<%workshopdate%>&nbsp;<TD>&nbsp;<TH align="RIGHT">&nbsp;Due Date:&nbsp;<TD>&nbsp;<%duedate%>&nbsp;
	<TR class="details"><TH align="RIGHT">&nbsp;Return Fax:&nbsp;<TD>&nbsp;<%returnfax%>&nbsp;<TD>&nbsp;<TH align="RIGHT">&nbsp;Appraiser:&nbsp;<TD>&nbsp;Anonymous&nbsp;
</TABLE></TABLE>
WSDETAILS
1;		# He tells the calling program that everything went well here !
