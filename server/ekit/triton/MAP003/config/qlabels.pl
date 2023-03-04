#!/usr/bin/perl
# Sat Dec 29 11:02:55 2012
$survey_id = 'MAP003';
$window_title = 'Q3 - Time Allocation';
$survey_name = 'Time Allocation';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 q1 0  ',
     '3',   '27 CHECK 0  ',
     '4',   '7 NODATA 0  ',
     '5',   '7 LAST 0  ',
);
$numq = 5;
%qlab2ix = (
 -1 => -1, -2 => -2, AA => 1, CHECK => 3, LAST => 5, NODATA => 4, Q1 => 2 
);
1;
