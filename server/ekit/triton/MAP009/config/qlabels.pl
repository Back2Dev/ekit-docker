#!/usr/bin/perl
# Sat Dec 29 11:02:57 2012
$survey_id = 'MAP009';
$window_title = 'Q9 - Spreadsheet of Vital Financial Factors';
$survey_name = 'Spreadsheet of Vital Financial Factors';
%qlabels = (
     '1',   '20 AA 0  ',
     '2',   '7 A 1  ',
     '3',   '29 q1 80  ',
     '4',   '29 q2 15  ',
     '5',   '29 q3 10  ',
     '6',   '1 q4 1  ',
     '7',   '27 CHECK 0  ',
     '8',   '7 NODATA 0  ',
     '9',   '20 BREAK 0  ',
     '10',   '7 LAST 0  ',
);
$numq = 10;
%qlab2ix = (

  -1 => -1,
  -2 => -2,
  A => 2,
  AA => 1,
  BREAK => 9,
  CHECK => 7,
  LAST => 10,
  NODATA => 8,
  Q1 => 3,
  Q2 => 4,
  Q3 => 5,
  Q4 => 6,

);
1;
