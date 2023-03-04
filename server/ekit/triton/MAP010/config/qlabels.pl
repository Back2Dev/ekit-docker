#!/usr/bin/perl
# Sat Dec 29 11:02:57 2012
$survey_id = 'MAP010';
$window_title = 'Q10 - Key Personnel Questionnaire';
$survey_name = 'Key Personnel Questionnaire';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 A 0  ',
     '3',   '5 q1 1  ',
     '4',   '5 q2 1  ',
     '5',   '5 q3 1  ',
     '6',   '5 q4 1  ',
     '7',   '5 q5 1  ',
     '8',   '5 q6 1  ',
     '9',   '5 q7 1  ',
     '10',   '5 q8 1  ',
     '11',   '5 q9 1  ',
     '12',   '14 q10 18  ',
     '13',   '27 CHECK 0  ',
     '14',   '7 NODATA 0  ',
     '15',   '20 BREAK 0  ',
     '16',   '7 LAST 0  ',
     '17',   '27 LAST1 0  ',
);
$numq = 17;
%qlab2ix = (

  -1     => -1,
  -2     => -2,
  A      => 2,
  AA     => 1,
  BREAK  => 15,
  CHECK  => 13,
  LAST   => 16,
  LAST1  => 17,
  NODATA => 14,
  Q1     => 3,
  Q10    => 12,
  Q2     => 4,
  Q3     => 5,
  Q4     => 6,
  Q5     => 7,
  Q6     => 8,
  Q7     => 9,
  Q8     => 10,
  Q9     => 11,

);
1;
