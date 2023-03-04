#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:05:13 2012
#
$qtype = 14 ;
$prompt = '<%qbanner%><P><%q_label%> For each statement below, decide which of the following answers best applies to you. <BR>Select your answer to the right of the statement.  <BR>Please be as honest as you can.<BR><BR>1. Never&nbsp;&nbsp;&nbsp;&nbsp;2. Rarely&nbsp;&nbsp;&nbsp;&nbsp;3. Occasionally&nbsp;&nbsp;&nbsp;&nbsp;4. Sometimes&nbsp;&nbsp;&nbsp;&nbsp;5. Often&nbsp;&nbsp;&nbsp;&nbsp;6. Usually';
$qlab = 'Q1';
$q_label = '1';
undef $others;
$instr = '';
undef @scale_words;
$dk = '';
$middle = '';
$left_word = '';
$right_word = '';
@scale_words = ('Never','Rarely','Occasionally','Sometimes','Often','Usually');
$scale = '6';
$required = 'all';
@skips = ('','','','','','','','','','','','','','','','4');
@scores = ('0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0');
@options = ('1. I try to be with people.','2. I let other people decide what to do.','3. I join social groups.','4. I try to have close relationships with people.','5. I tend to join social organizations when I have an opportunity.','6. I let other people strongly influence my actions.','7. I try to be included in informal social activities.','8. I try to have close, personal relationships with people.','9. I try to include other people in my plans.','10. I let other people control my actions.','11. I try to have people around me.','12. I try to get close and personal with people.','13. When people are doing things together I tend to join them.','14. I am easily led by people.','15. I try to avoid being alone.','16. I try to participate in group activities.');
@vars = ('','','','','','','','','','','','','','','','');
@setvalues = ('','','','','','','','','','','','','','','','');
# I Like the number wun
1;
