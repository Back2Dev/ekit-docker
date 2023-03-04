#!/usr/bin/perl
# Sat Dec 29 11:02:55 2012
$survey_id = 'MAP001';
$window_title = 'MAP001 - Participant\'s Questionnaire';
$survey_name = 'Participant\'s Questionnaire';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '5 q1 1  ',
     '3',   '5 q2 1  ',
     '4',   '5 q3 1  ',
     '5',   '5 q4 1  ',
     '6',   '5 q5 1  ',
     '7',   '5 q6 1  ',
     '8',   '5 q7 1  ',
     '9',   '5 q8 1  ',
     '10',   '5 q9 1  ',
     '11',   '5 q10 1  ',
     '12',   '5 q11 1  ',
     '13',   '5 q12 1  ',
     '14',   '5 q13 1  ',
     '15',   '27 CHECK 0  ',
     '16',   '7 NODATA 0  ',
     '17',   '7 LAST 0  ',
);
$numq = 17;
%qlab2ix = (

  -1     => -1,
  -2     => -2,
  AA     => 1,
  CHECK  => 15,
  LAST   => 17,
  NODATA => 16,
  Q1     => 2,
  Q10    => 11,
  Q11    => 12,
  Q12    => 13,
  Q13    => 14,
  Q2     => 3,
  Q3     => 4,
  Q4     => 5,
  Q5     => 6,
  Q6     => 7,
  Q7     => 8,
  Q8     => 9,
  Q9     => 10,

);
1;
