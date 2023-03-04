#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:05:13 2012
#
$qtype = 14 ;
$prompt = '<%qbanner%><P><%q_label%> For each of the next group of statements, choose one of the following answers:<BR><BR>1. Nobody&nbsp;&nbsp;&nbsp;&nbsp;2. One or two people&nbsp;&nbsp;&nbsp;&nbsp;3. A few people&nbsp;&nbsp;&nbsp;&nbsp;4. Some people&nbsp;&nbsp;&nbsp;&nbsp;5. Many people&nbsp;&nbsp;&nbsp;&nbsp;6. Most people';
$qlab = 'Q2';
$q_label = '2';
undef $others;
$instr = '';
undef @scale_words;
$dk = '';
$middle = '';
$left_word = '';
$right_word = '';
@scale_words = ('Nobody','One or two people','A few people','Some people','Many people','Most people');
$scale = '6';
$required = 'all';
@skips = ('','','','','','','','','','','5');
@scores = ('0','0','0','0','0','0','0','0','0','0','0');
@options = ('17. I try to be friendly to people.','18. I let other people decide what to do.','19. My personal relations with people are cool and distant.','20. I let other people take charge of things.','21. I try to have close relationships with people.','22. I let other people strongly influence my actions.','23. I try to get close and personal with people.','24. I let other people control my actions.','25. I act cool and distant with people.','26. I am easily led by people.','27. I try to have close, personal relationships with people.');
@vars = ('','','','','','','','','','','');
@setvalues = ('','','','','','','','','','','');
# I Like the number wun
1;
