#!/usr/bin/perl
# Sat Dec 29 11:35:24 2012
$survey_id = 'MAP005';
$window_title = 'MAP005 - Key Outside Influences';
$survey_name = 'Key Outside Influences List';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 A 0  ',
     '3',   '7 q1 0  ',
     '4',   '2 q2 20  ',
     '5',   '8 BREAK 0  ',
     '6',   '7 SENT 0  ',
     '7',   '27 CHECK 0  ',
     '8',   '7 NODATA 0  ',
     '9',   '7 LAST 0  ',
);
$numq = 9;
%qlab2ix = (

  -1 => -1,
  -2 => -2,
  A => 2,
  AA => 1,
  BREAK => 5,
  CHECK => 7,
  LAST => 9,
  NODATA => 8,
  Q1 => 3,
  Q2 => 4,
  SENT => 6,

);
1;
