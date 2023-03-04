#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# $Id: pwikit_delete_id.pl,v 1.1 2005/11/13 00:04:35 triton Exp $
#
$copyright = "Copyright 2005 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Wrapper to delete a respondent
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
require 'TPerl/360_delete_id.pl';
1;


