#!/usr/bin/perl
# Sat Dec 29 11:12:03 2012
$survey_id = 'MAP010A';
$window_title = 'Q10A - Key Personnel List';
$survey_name = 'Key Personnel List';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 A 0  ',
     '3',   '7 q1 0  ',
     '4',   '27 q1A 0  ',
     '5',   '27 q1B 0  ',
     '6',   '2 q2A 20  ',
     '7',   '27 q2B 0  ',
     '8',   '7 SENT 0  ',
     '9',   '27 CHECK 0  ',
     '10',   '7 NODATA 0  ',
     '11',   '7 LAST 0  ',
);
$numq = 11;
%qlab2ix = (

  -1     => -1,
  -2     => -2,
  A      => 2,
  AA     => 1,
  CHECK  => 9,
  LAST   => 11,
  NODATA => 10,
  Q1     => 3,
  Q1A    => 4,
  Q1B    => 5,
  Q2A    => 6,
  Q2B    => 7,
  SENT   => 8,

);
1;
