#!/usr/bin/perl
## $Id: strings-en-local.pl,v 2.0 2004-03-29 03:09:30 triton Exp $
#
# Local strings for PWIKit
#
$ws_details = <<WSDETAILS;
<TABLE cellspacing=0 cellpadding=0 border=1 >
<TR><TD><TABLE cellspacing=0 cellpadding=1 border=0 width=596>
	<TR class="details"><TH align="RIGHT">&nbsp;Participant:&nbsp;<TD>&nbsp;<%id%> <%fullname%>&nbsp;<TD width=10>&nbsp; <TH align="RIGHT">&nbsp;Organization:&nbsp;<TD>&nbsp;<%company%>&nbsp;
	<TR class="details"><TH align="RIGHT">&nbsp;Workshop Date:&nbsp;<TD>&nbsp;<%workshopdate%>&nbsp;<TD>&nbsp;<TH align="RIGHT">&nbsp;Due Date:&nbsp;<TD>&nbsp;<%duedate%>&nbsp;
	<TR class="details"><TH align="RIGHT">&nbsp;Return Fax:&nbsp;<TD>&nbsp;<%returnfax%>&nbsp;<TD>&nbsp;<TH align="RIGHT">&nbsp;Appraiser:&nbsp;<TD>&nbsp;<%who%>&nbsp;
</TABLE></TABLE>
WSDETAILS
$warning = <<WARNING;
<TABLE width="600" cellspacing=0 cellpadding=5>
	<TR ><TD class="warning" border=1 >
	<B>Warning:</B> If you use the back button on your browser's tool bar you will lose your 
	data on this page. Please use the navigation buttons at the bottom of each page to move from page 
	to page. Doing this will save your responses automatically in our database as you go through each page.</TD></TR></table>
WARNING

#
# Even if you have to edit this file, please leave this soldier on the last line
#
1;
