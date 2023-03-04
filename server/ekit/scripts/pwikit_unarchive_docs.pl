#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# $Id: pwikit_archive_docs.pl,v 1.1 2005-06-26 04:40:32 triton Exp $
#
$copyright = "Copyright 2005 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Wrapper to unarchive documents for a respondent
#
#
require 'TPerl/qt-libdb.pl';
#
# Get the specific stuff we need
#
require 'TPerl/360-lib.pl';
require 'TPerl/pwikit_cfg.pl';
#
# Get the generic 360 list:
#
require 'TPerl/360_unarchive.pl';
1;


