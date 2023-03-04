#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:05:13 2012
#
$qtype = 14 ;
$prompt = '<%qbanner%><P><%q_label%> For each of the next group of statements, choose one of the following answers:<BR><BR>1. Nobody&nbsp;&nbsp;&nbsp;&nbsp;2. One or two people&nbsp;&nbsp;&nbsp;&nbsp;3. A few people&nbsp;&nbsp;&nbsp;&nbsp;4. Some people&nbsp;&nbsp;&nbsp;&nbsp;5. Many people&nbsp;&nbsp;&nbsp;&nbsp;6. Most people';
$qlab = 'Q3';
$q_label = '3';
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
@skips = ('','','','','','','','','','','','','6');
@scores = ('0','0','0','0','0','0','0','0','0','0','0','0','0');
@options = ('28. I like people to invite me to things.','29. I like people to act close and personal with me.','30. I try to influence strongly other people\'s actions.','31. I like people to invite me to join in their activities.','32. I like people to act close towards me.','33. I try to take charge of things when I am with people.','34. I like people to include me in their activities.','35. I like people to act cool and distant towards me.','36. I try to have other people do things the way I want them done.','37. I like people to ask me to participate in their discussions.','38. I like people to act friendly towards me.','39. I like people to invite me to participate in their activities.','40. I like people to act distant towards me.');
@vars = ('','','','','','','','','','','','','');
@setvalues = ('','','','','','','','','','','','','');
# I Like the number wun
1;
