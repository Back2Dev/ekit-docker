#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:57 2012
#
$qtype = 29 ;
$prompt = '<%qbanner%><P><%q_label%> Vital Financial Information';
$qlab = 'Q1';
$q_label = '1';
undef $others;
$caption = 'Vital Financial Factors';
$instr = '* if applicable';
undef @scale_words;
$dk = '';
$middle = '';
$left_word = 'Prior years';
$right_word = 'Current';
@scale_words = ('1','2','3','4','5');
$scale = '-5';
$limlo = "''";
$limhi = "999999999";
@skips = ('','','','','','','','','','','','','','','','');
$grid_type = 'number';
@scores = ('0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0');
@options = ('FYE (i.e., 2005, 2006, 2007, etc.)','Sales/Revenue','Cost of sales *','Gross profit','General & administrative (plus selling costs) *','Net profit / (loss) *','Accounts receivable','Accounts payable','Inventory *','Total current assets','Fixed assets','Total assets','Current liabilities','Long-term liabilities','Total liabilities','Net worth');
@vars = ('','','','','','','','','','','','','','','','');
@setvalues = ('','','','','','','','','','','','','','','','');
# I Like the number wun
1;
