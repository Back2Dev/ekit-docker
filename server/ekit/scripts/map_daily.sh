#!/bin/bash
#
#
# Run the numbers for the online MAP Post Workshop survey
#
perl statsplit.pl MAP026 --is=3
perl recode.pl MAP026 -ini=recode -ext=all
# Sort the file by date and fix the date format
perl tsv_sortfile.pl ../triton/MAP026/final/MAP026_all_recode.txt ../triton/MAP026/final/MAP026_all_recode_sort.txt
perl tpivot.pl MAP026 -ini=wsexperience.ini
perl tpivot.pl MAP026 -ini=wspresentation.ini
perl tpivot.pl MAP026 -ini=wsgeneral.ini
perl tpivot.pl MAP026 -ini=wsleader.ini
perl tpivot.pl MAP026 -ini=wsworkshop.ini

