#!/usr/bin/perl
# Sat Dec 29 11:02:58 2012
$survey_id = 'MAP011';
$window_title = 'Q11 - Questionnaire for supervising manager or partner';
$survey_name = 'Questionnaire for supervising manager or partner';
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
     '12',   '5 q10 1  ',
     '13',   '5 q11 1  ',
     '14',   '5 q12 1  ',
     '15',   '5 q13 1  ',
     '16',   '27 CHECK 0  ',
     '17',   '7 NODATA 0  ',
     '18',   '7 LAST 0  ',
);
$numq = 18;
%qlab2ix = (

  -1     => -1,
  -2     => -2,
  A      => 2,
  AA     => 1,
  CHECK  => 16,
  LAST   => 18,
  NODATA => 17,
  Q1     => 3,
  Q10    => 12,
  Q11    => 13,
  Q12    => 14,
  Q13    => 15,
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
