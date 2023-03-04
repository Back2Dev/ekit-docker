#!/usr/bin/perl
# $Id: pwikit_sleep.pl,v 1.2 2007/01/28 07:45:43 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# pwikit_sleep.pl - Sleeps a participant (or makes them inactive)
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
require 'TPerl/360_sleep.pl';
1;
