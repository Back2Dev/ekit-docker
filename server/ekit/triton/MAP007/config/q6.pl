#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:05:13 2012
#
$qtype = 14 ;
$prompt = '<%qbanner%><P><%q_label%> For each of the next group of statements, please choose one of the following answers:<BR><BR>1. Never&nbsp;&nbsp;&nbsp;&nbsp;2 .Rarely&nbsp;&nbsp;&nbsp;&nbsp;3. Occasionally&nbsp;&nbsp;&nbsp;&nbsp;4. Sometimes&nbsp;&nbsp;&nbsp;&nbsp;5. Often&nbsp;&nbsp;&nbsp;&nbsp;6. Usually';
$qlab = 'Q4';
$q_label = '4';
undef $others;
$instr = '';
$buttons = '1';
undef @scale_words;
$dk = '';
$middle = '';
$left_word = '';
$right_word = '';
@scale_words = ('Never','Rarely','Occasionally','Sometimes','Often','Usually');
$scale = '6';
$required = 'all';
@skips = ('','','','','','','','','','','','','','7');
@scores = ('0','0','0','0','0','0','0','0','0','0','0','0','0','0');
@options = ('41. I try to be the dominant person when I\'m with people.','42. I like people to invite me to things.','43. I like people to act close towards me.','44. I try to have other people do things I want done.','45. I like people to invite me to join their activities.','46. I like people to act cool and distant towards me.','47. I try to influence strongly other people\'s actions.','48. I like people to include me in their activities.','49. I like people to act close and personal with me.','50. I try to take charge of things when I\'m with people.','51. I like people to invite me to participate in their activities.','52. I like people to act distant towards me.','53. I try to have other people do things the way I want them done.','54. I take charge of things when I\'m with people.');
@vars = ('','','','','','','','','','','','','','');
@setvalues = ('','','','','','','','','','','','','','');
# I Like the number wun
1;
