#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# $Id: pwikit_unarchive.pl,v 1.2 2007-01-28 07:45:44 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# pwikit_unarchive.pl - Brings back archived data
#
#
require 'TPerl/qt-libdb.pl';
#
# Get the specific stuff we need
#
require 'TPerl/360-lib.pl';
require 'TPerl/pwikit_cfg.pl';
#
# Get the generic 360 unarchive function:
#
require 'TPerl/360_unarchive.pl';
1;
