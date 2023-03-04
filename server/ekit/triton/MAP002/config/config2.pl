#!/usr/bin/perl
#
# Survey config.pl file - lives in $triton_root/XXX999/config directory
# (alongside qlabels.pl etc)
#
# This file is hand edited - it is created empty to start with
#
$login_page = '/cgi-mr/pwikit_login.pl?id=<%id%>&password=<%password%>';

$BTN_NEXT = " NEXT >> ";
$allow_restart=1;
$BTN_REFUSED = "NEXT (skips checking)";
$BTN_BACK = " << BACK ";
$show_back_button = 1;
@jump_index = (
				'q1.q4',
				'q5.q7',
				'LAST.LAST',
				);
#
# No matter what you do, leave this poor soldier intact on the last line
#
1;		# He tells the calling program that everything went well here !
