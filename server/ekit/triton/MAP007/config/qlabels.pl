#!/usr/bin/perl
# Sat Dec 29 11:05:13 2012
$survey_id = 'MAP007';
$window_title = 'Q7 - FIRO-B';
$survey_name = 'FIRO-B';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 A 1  ',
     '3',   '14 q1 16  ',
     '4',   '14 q2 11  ',
     '5',   '14 q3 13  ',
     '6',   '14 q4 14  ',
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
  CHECK => 7,
  LAST => 9,
  NODATA => 8,
  Q1 => 3,
  Q2 => 4,
  Q3 => 5,
  Q4 => 6,

);
1;
