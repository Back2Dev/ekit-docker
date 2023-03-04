#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Wed Feb 15 23:51:18 2012
#
$qtype = 7 ;
$prompt = '<BOGUS><table border=0 cellpadding=0 cellspacing=0 style="margin:0;"><tr><TD style="background-image: url(\'/themes/ekit/maplogo.png\');background-repeat:no-repeat;" width="60px" height="90px" >&nbsp;<TD width="50px" >&nbsp;<tr><TD style="background-image:url(\'/themes/ekit/bluebar.png\');font-family:Calibri;font-size:14pt; color:white;" height="30px" width=600px> &nbsp;&nbsp; Participant\'s Questionnaire<TH style="background-image:url(\'/themes/ekit/bluebar.png\');font-family:Calibri;font-size:14pt; color:white;">Q1</table><INPUT TYPE="HIDDEN" NAME="finish"><TABLE border="0"width="600"><TR><TD>You are now at the end of this form. If you are finished, please click the SUBMIT button to save your answers and submit them to the workshop leader. If you wish to correct or modify a responses you can re-enter the form and adjust your response. This must be done prior to <%duedate%>. <BR><BR><TABLE border=0 cellpadding="8"><TR><TH><INPUT type="SUBMIT" VALUE=" SUBMIT " onclick="document.q.finish.value=\'\';"></TD><TD>My responses are complete,  and I would like to submit them now.</TD></TR><TR><TD> <INPUT TYPE="BUTTON" VALUE="NOT YET" onclick="document.q.finish.value=\'0\';document.q.submit();"></TD><TD>My responses are not complete. I need to come back and review later before submission.</TD></TR><TR><TH> <INPUT TYPE="BUTTON" VALUE=" << BACK " tabindex="-1"  alt="BACK" onclick="history.back()"> <TD>Go back and review my responses.</tr></TABLE></TABLE>';
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
