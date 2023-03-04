#!/usr/bin/perl
## $Id: strings-en.pl,v 2.10 2011-09-14 05:43:06 triton Exp $
#
# GENERATED FILE: DO NOT EDIT ! 
#
# CONTAINS LANGUAGE STRINGS FOR ERROR MESSAGES
#
# TO MAINTAIN, SEE StringsMaster.txt
#
%sysmsg = (
	ERRSTR_E1a => qq{We would really appreciate it if you could say something here },
	ERRSTR_E2a => qq{Please fill in all answers},
	ERRSTR_E2b => qq{Please fill in at least %d answer(s)},
	ERRSTR_E3a => qq{The answer %s is not a number},
	ERRSTR_E4a => qq{The answer %d is too low, it should be at least %d},
	ERRSTR_E5a => qq{The answer %d is too high, it should be no more than %d},
	ERRSTR_E6a => qq{Sorry, this answer does not make sense (the number should be greater than or equal to %d)},
	ERRSTR_E7a => qq{You must select at least %d item(s)},
	ERRSTR_E7b => qq{You must select at least %d or select the %s option},
	ERRSTR_E8a => qq{Sorry, this answer does not make sense (the number should be less than or equal to %d)},
	ERRSTR_E9a => qq{Sorry, these numbers must add up to %d (you have %d)},
	ERRSTR_E10a => qq{You have selected other items as well as %s Please make up your mind!},
	ERRSTR_E11a => qq{You should select no more than %d items},
	ERRSTR_E11b => qq{You should select no more than one item},
	ERRSTR_E12a => qq{Please select one of the items in the list},
	ERRSTR_E13a => qq{Please select one from the drop down list},
	ERRSTR_E14a => qq{Percentages must add up to 100 (you have %d% so far)},
	ERRSTR_E15a => qq{Please complete all answers for %s},
	ERRSTR_E15b => qq{Please select recency code for %s},
	ERRSTR_E15c => qq{Please select at least %d answers},
	ERRSTR_E15d => qq{Please select at least %d answers for %s},
	ERRSTR_E16a => qq{Error: please make one choice from each row},
	ERRSTR_E17a => qq{Please make a selection from the list above},
	ERRSTR_E18a => qq{Error: Please choose a different number for each place that reflects your order of preference.},
	ERRSTR_E19a => qq{Error: you have given the same ranking to multiple items},
	ERRSTR_E20a => qq{Error: you cannot choose the same one twice},
	ERRSTR_E21a => qq{Invalid question type - please contact support},
	ERRSTR_E22a => qq{You selected 'other', please tell me what the other thing is},
	ERRSTR_E22b => qq{You selected 'other', please tell me what the other thing is},
	ERRSTR_E22c => qq{You selected 'other', please tell me what the other thing is for %s},
	ERRSTR_E22d => qq{You entered something, but did not select 'other', please correct it},
	ERRSTR_E22e => qq{You rated 'other', please specify it (or erase the response)},
	ERRSTR_E22f => qq{You specified the 'other', please rate it (or erase the response)},
	ERRSTR_E23a => qq{Please fill in at least %d answers},
	ERRSTR_E23b => qq{Please fill in at least one answer},
	ERRSTR_E24 => qq{Possibly within 12 months - please ask...},
	ERRSTR_E25 => qq{Error: Respondent is only },
	ERRSTR_E26 => qq{Please select at least one for %s},
	ERRSTR_E27a => qq{This year of birth (},
	ERRSTR_E27b => qq{) does not seem possible for a },
	ERRSTR_E27c => qq{ year old !\n Perhaps it should be },
	ERRSTR_E27d => qq{ ?},
	ERRSTR_E28 => qq{I'm sorry, it doesn't make sense to REFUSE and DON'T KNOW at the same time},

	ERRSTR_E29 => qq{Please drag all items across to 'Your selections' box}, 	 
	ERRSTR_E29a => qq{Please drag}, 	 
	ERRSTR_E29b => qq{items across to 'Your selections' box}, 	 
	ERRSTR_E30a => qq{You should have only}, 	 
	ERRSTR_E30b => qq{items in the 'Your selections' box},
	 
	ERRSTR_I1 => qq{ENTER A WHOLE NUMBER},
	ERRSTR_I2 => qq{SELECT AS MANY AS APPLY},
	ERRSTR_I3 => qq{SELECT ONE ONLY},
	ERRSTR_I4 => qq{PLEASE TYPE YOUR RESPONSE},
	ERRSTR_I5 => qq{ENTER PERCENTAGES, MUST TOTAL 100%},
	ERRSTR_I6 => qq{ENTER AMOUNT IN WHOLE DOLLARS},
	ERRSTR_I7 => qq{INVALID QUESTION TYPE},
	ERRSTR_I8 => qq{SELECT ONE ITEM PER ROW},
	ERRSTR_I9 => qq{SELECT ONE ITEM IN EACH COLUMN FOR EACH ROW},
	ERRSTR_I30 => qq{DRAG THE POINTER ALONG THE SCALE TO PROVIDE YOUR RATING},
#
# Button texts
#
	BTN_NEXT => qq{Next},
	BTN_REFUSED => qq{Refused},
	BTN_SUBMITTING => qq{Submitting..},
	BTN_BACK => qq{Back},
	BTN_DK => qq{Don't know},
#
	TXT_DAY => qq{Day},
	TXT_MONTH => qq{Month},
	TXT_YEAR => qq{Year},
	TXT_HOWLONG => qq{How long ago},
	TXT_AGE => qq{Age},
	TXT_OTHER_SPEC => qq{Other (specify:)},
	TXT_QS => qq{Q's},
	TXT_ITEM => qq{Item},
	TXT_AGE_ONS => qq{Age ons.},
	TXT_AGE_REC => qq{Age rec.},
	TXT_TICK => qq{Tick},
	TXT_NOTES => qq{Notes:},
	TXT_COUNT => qq{Count},
	TXT_NOTHING => qq{Nothing},

	TXT_YOURS => qq{Your selections}, 	 
	TXT_AVAIL => qq{Available selections},
	TXT_JS1 => qq{We have a problem!},
	TXT_JS2 => qq{Your browser doesn't have javascript enabled. This is a problem because the survey uses advanced HTML features that require Javascript to be turned on.},
	TXT_JS3 => qq{How to fix it},
	TXT_JS4 => qq{ You can either use a different browser which has Javascript enabled, or get instructions on how to turn it on here:},
	TXT_JS5 => qq{How do I know when I have fixed it?},
	TXT_JS6 => qq{Once you have turned it on, come back to this page and refresh it. If this error message does not appear, the problem is fixed.},
);
# Default Prompts
#
@def_instr = 	(
		qq{Invalid question type - please contact support},
		"($sysmsg{ERRSTR_I1})",				# Number
		"($sysmsg{ERRSTR_I2})",
		"($sysmsg{ERRSTR_I3})",
		"($sysmsg{ERRSTR_I3})",
		"($sysmsg{ERRSTR_I4})",
		"($sysmsg{ERRSTR_I5})",
		"",
		"",
		"($sysmsg{ERRSTR_I6})",
		"($sysmsg{ERRSTR_I3})",
		"($sysmsg{ERRSTR_I7})",
		"($sysmsg{ERRSTR_I3})",
		"",
		"($sysmsg{ERRSTR_I8})",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",										# Spares are defensive
		"($sysmsg{ERRSTR_I30})",
		);

#
# Even if you have to edit this file, please leave this soldier on the last line
#
1;
