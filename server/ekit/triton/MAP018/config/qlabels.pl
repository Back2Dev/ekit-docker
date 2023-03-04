#!/usr/bin/perl
# Sat Dec 29 11:02:59 2012
$survey_id = 'MAP018';
$window_title = 'Q18 - Hotel Reservation Form';
$survey_name = 'Hotel Reservation';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '27 AB 0  ',
     '3',   '7 A 0  ',
     '4',   '7 q1 0  ',
     '5',   '27 q1A 0  ',
     '6',   '7 q2 0  ',
     '7',   '7 q3 0  ',
     '8',   '27 CHECK 0  ',
     '9',   '7 NODATA 0  ',
     '10',   '7 LAST 0  ',
);
$numq = 10;
%qlab2ix = (

  -1     => -1,
  -2     => -2,
  A      => 3,
  AA     => 1,
  AB     => 2,
  CHECK  => 8,
  LAST   => 10,
  NODATA => 9,
  Q1     => 4,
  Q1A    => 5,
  Q2     => 6,
  Q3     => 7,

);
1;
