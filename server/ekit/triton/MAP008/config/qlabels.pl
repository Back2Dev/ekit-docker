#!/usr/bin/perl
# Sat Dec 29 11:02:57 2012
$survey_id = 'MAP008';
$window_title = 'Q8 - Organizational Summary';
$survey_name = 'Organizational Summary';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 A 0  ',
     '3',   '15 q1 4  ',
     '4',   '5 q2 1  ',
     '5',   '5 q3 1  ',
     '6',   '15 q4 3  ',
     '7',   '15 q5 3  ',
     '8',   '7 q6 1  ',
     '9',   '7 q7 0  ',
     '10',   '7 q8 0  ',
     '11',   '27 CHECK 0  ',
     '12',   '7 NODATA 0  ',
     '13',   '7 LAST 0  ',
);
$numq = 13;
%qlab2ix = (

  -1     => -1,
  -2     => -2,
  A      => 2,
  AA     => 1,
  CHECK  => 11,
  LAST   => 13,
  NODATA => 12,
  Q1     => 3,
  Q2     => 4,
  Q3     => 5,
  Q4     => 6,
  Q5     => 7,
  Q6     => 8,
  Q7     => 9,
  Q8     => 10,

);
1;
