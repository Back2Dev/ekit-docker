#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Thu Feb 16 11:02:34 2012
#
$qtype = 7 ;
$prompt = '<IMG SRC="/MAP001/banner600.gif"><INPUT TYPE="HIDDEN" NAME="finish"><TABLE border="0"width="600"><TR><TD>You are now at the end of this form. If you are finished, please click the SUBMIT button to save your answers and submit them to the workshop leader. If you wish to correct or modify a responses you can re-enter the form and adjust your response. This must be done prior to <%duedate%>. <BR><BR><TABLE border=0 cellpadding="8"><TR><TH><INPUT type="SUBMIT" VALUE=" SUBMIT " onclick="document.q.finish.value=\'\';"></TD><TD>My responses are complete,  and I would like to submit them now.</TD></TR><TR><TD> <INPUT TYPE="BUTTON" VALUE="NOT YET" onclick="document.q.finish.value=\'0\';document.q.submit();"></TD><TD>My responses are not complete. I need to come back and review later before submission.</TD></TR><TR><TH> <INPUT TYPE="BUTTON" VALUE=" << BACK " tabindex="-1"  alt="BACK" onclick="history.back()"> <TD>Go back and review my responses.</tr></TABLE></TABLE>';
$qlab = 'QLAST';
$q_label = 'LAST';
undef $others;
$instr = '';
$buttons = '0';
$sscript = '../scripts/pwikit_prime_status.pl';
@skips = ();
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
