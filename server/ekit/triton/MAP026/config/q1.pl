#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:59 2012
#
$qtype = 14 ;
$prompt = '<%qbanner%><%qscale%> Please rate the following aspects of your experience with MAP:';
$qlab = 'Q1';
$q_label = '1';
undef $others;
$instr = '';
undef @scale_words;
$dk = 'NA';
$middle = '';
$left_word = 'Poor';
$right_word = 'Excellent';
@scale_words = ('1','2','3','4','5','6','7','8','9');
$scale = '-9';
$required = 'all';
@skips = ('','','');
@scores = ('0','0','0');
@options = ('1. The overall MAP experience so far','2. Pre-workshop communication','3. Feedback from within your organization');
@vars = ('','','');
@setvalues = ('','','');
# I Like the number wun
1;
