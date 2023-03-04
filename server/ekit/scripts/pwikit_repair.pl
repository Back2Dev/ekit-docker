#!/usr/bin/perl
# $Id: pwikit_repair.pl,v 1.1 2005-06-26 04:48:09 triton Exp $
#
# Look for discrepancies in ufiles/database etc
#
require 'TPerl/qt-libdb.pl';
#
# Get the specific stuff we need
#
require 'TPerl/360-lib.pl';
require 'TPerl/pwikit_cfg.pl';

require 'TPerl/360_repair.pl';

1;
