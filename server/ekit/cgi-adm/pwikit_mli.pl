#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: pwikit_mli.pl,v 1.3 2012-03-07 05:04:59 triton Exp $
#
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# go.pl - starts off a survey
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
require 'TPerl/360_mli.pl';
1;
