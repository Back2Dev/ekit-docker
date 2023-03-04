#!/usr/bin/perl
# $Id: map_cms_par_upload.pl,v 1.31 2012-09-06 03:28:02 triton Exp $
# Script to read participant/workshop data from the CMS system and xfer it to the eKit Server.
# It uploads it to [par_upload_target] (in the server.ini file), which simply accepts the
# upload and saves the file
#
# The 2nd half of script runs on eKit Server: scripts/pwikit_cms_par_import.pl, which
# will run as a cron job on a regular basis to do the logic of importing the data
# and then working out which actions are necessary.
#
use strict;
use DBI;
use Date::Manip;                                                        #perl2exe
use Getopt::Long;                                                       #perl2exe
use HTTP::Request::Common;                                      #perl2exe
use LWP::UserAgent;                                                     #perl2exe
use Data::Dumper;                                                       #perl2exe

use TPerl::Error;                                                       #perl2exe
use TPerl::TSV;                                                         #perl2exe
use TPerl::MyDB;                                                        #perl2exe
use TPerl::Dump;                                                        #perl2exe
use TPerl::MAP;                                                         #perl2exe


 my $delta = "+6w +3d";
        my $today = &ParseDate('today');
        my $todayplus6 = &DateCalc($today,$delta);
        my @params = (UnixDate($today,"20%y-%m-%d"),UnixDate($todayplus6,"20%y-%m-%d"));
print @params
