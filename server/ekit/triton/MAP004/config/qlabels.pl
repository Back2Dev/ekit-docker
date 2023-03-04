#!/usr/bin/perl
# Sat Dec 29 11:02:56 2012
$survey_id = 'MAP004';
$window_title = 'Q4 - Professional Career Summary';
$survey_name = 'Professional Career Summary';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 q1 0  ',
     '3',   '5 q2 1  ',
     '4',   '5 q3 1  ',
     '5',   '5 q4 1  ',
     '6',   '5 q5 1  ',
     '7',   '5 q6 1  ',
     '8',   '5 q7 1  ',
     '9',   '8 q7A 0  ',
     '10',   '7 q8 0  ',
     '11',   '27 CHECK 0  ',
     '12',   '7 NODATA 0  ',
     '13',   '20 BREAK 0  ',
     '14',   '7 LAST 0  ',
);
$numq = 14;
%qlab2ix = (

  -1     => -1,
  -2     => -2,
  AA     => 1,
  BREAK  => 13,
  CHECK  => 11,
  LAST   => 14,
  NODATA => 12,
  Q1     => 2,
  Q2     => 3,
  Q3     => 4,
  Q4     => 5,
  Q5     => 6,
  Q6     => 7,
  Q7     => 8,
  Q7A    => 9,
  Q8     => 10,

);
1;
