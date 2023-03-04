#!/usr/bin/perl
## $Id: qt-libemba.pl,v 1.2 2007-05-25 06:23:37 triton Exp $

#@@@@@@@@@@@@@@@@@@@@ DEPRECATED, %embacfg has moved to TPerl::EMBA @@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@ DEPRECATED, %embacfg has moved to TPerl::EMBA @@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@ DEPRECATED, %embacfg has moved to TPerl::EMBA @@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@ DEPRECATED, %embacfg has moved to TPerl::EMBA @@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@ DEPRECATED, %embacfg has moved to TPerl::EMBA @@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@ DEPRECATED, %embacfg has moved to TPerl::EMBA @@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@ DEPRECATED, %embacfg has moved to TPerl::EMBA @@@@@@@@@@@@@@@@@@@@@@@@@@@@



%embacfg = (
#-----------------2006
# Entry survey 06
		STSIGN06	=>	{
						related	=> 'START06',	url	=> 'entry',		register	=> 'studententryregister',	progress_report => 0, peer=>'PENTRY06',
						},
# Mid survey 06
		MDSIGN06	=>	{
						related	=> 'MID06',		url	=> 'mid',		register	=> 'studentmidregister',	progress_report => 0, peer=>'PMID06',
						},
# Exit survey 06
		SIGN06	=>	{
						related	=> 'EMBA06',	url	=> 'exit',		register	=> 'studentexitregister',	progress_report => 5, peer=>'PEXIT06',
						},
#-----------------2007
# Entry survey 07
		ENTRYREG07	=>	{
						related	=> 'ENTRY07',	url	=> 'entry',		register	=> 'studententryregister',	progress_report => 0, peer=>'PENTRY07',
						},
# Mid survey 07
		MIDREG07	=>	{
						related	=> 'MID07',		url	=> 'mid',		register	=> 'studentmidregister',	progress_report => 0, peer=>'PMID07',
						},
# Exit survey 07
		SIGN07	=>	{
						related	=> 'EMBA07',	url	=> 'exit',		register	=> 'studentexitregister',	progress_report => 5, peer=>'PEXIT07',
						},
		EXITREG07	=>	{
						related	=> 'EXIT07',	url	=> 'exit',		register	=> 'studentexitregister',	progress_report => 5, peer=>'PEXIT07',
						},
#-----------------2008
# Entry survey 08
		ENTRYREG08	=>	{
						related	=> 'ENTRY08',	url	=> 'entry',		register	=> 'studententryregister',	progress_report => 0, peer=>'PENTRY08',
						},
# Mid survey 08
		MIDREG08	=>	{
						related	=> 'MID08',		url	=> 'mid',		register	=> 'studentmidregister',	progress_report => 0, peer=>'PMID08',
						},
# Exit survey 08
		EXITREG08	=>	{
						related	=> 'EXIT08',	url	=> 'exit',		register	=> 'studentexitregister',	progress_report => 5, peer=>'PEXIT08',
						},
#-----------------2009
# Entry survey 09
		ENTRYREG09	=>	{
						related	=> 'ENTRY09',	url	=> 'entry',		register	=> 'studententryregister',	progress_report => 0, peer=>'PENTRY09',
						},
# Mid survey 09
		MIDREG09	=>	{
						related	=> 'MID09',		url	=> 'mid',		register	=> 'studentmidregister',	progress_report => 0, peer=>'PMID09',
						},
# Exit survey 09
		EXITREG09	=>	{
						related	=> 'EXIT09',	url	=> 'exit',		register	=> 'studentexitregister',	progress_report => 5, peer=>'PEXIT09',
						},
			);
#
# This is required to live in the perl library
#
1;
