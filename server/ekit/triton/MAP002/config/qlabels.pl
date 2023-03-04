#!/usr/bin/perl
# Sat Dec 29 11:02:55 2012
$survey_id = 'MAP002';
$window_title = 'Q2 - Management and Leadership Inventory: Participant';
$survey_name = 'Management and Leadership Inventory: Participant';
%qlabels = (
     '1',   '20 A 0  ',
     '2',   '14 q1 7  ',
     '3',   '14 q2 5  ',
     '4',   '14 q3 5  ',
     '5',   '14 q4 6  ',
     '6',   '14 q5 5  ',
     '7',   '14 q6 4  ',
     '8',   '14 q7 18  ',
     '9',   '27 CHECK 0  ',
     '10',   '7 NODATA 0  ',
     '11',   '8 BREAK 0  ',
     '12',   '7 LAST 0  ',
);
$numq = 12;
%qlab2ix = (

  -1 => -1,
  -2 => -2,
  A => 1,
  BREAK => 11,
  CHECK => 9,
  LAST => 12,
  NODATA => 10,
  Q1 => 2,
  Q2 => 3,
  Q3 => 4,
  Q4 => 5,
  Q5 => 6,
  Q6 => 7,
  Q7 => 8,

);
1;
