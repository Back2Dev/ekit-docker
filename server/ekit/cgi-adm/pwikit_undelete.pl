#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# $Id: pwikit_undelete.pl,v 1.2 2007/01/28 07:45:44 triton Exp $
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# pwikit_batches.pl - Lists batches
#
#
require 'TPerl/qt-libdb.pl';
require 'TPerl/360-lib.pl';
#
# Get the specific stuff we need
#
require 'TPerl/pwikit_cfg.pl';
#
# Get the generic 360 list:
#
require 'TPerl/360_undelete.pl';
1;
