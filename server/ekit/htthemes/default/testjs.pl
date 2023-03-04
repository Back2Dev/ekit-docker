#!/usr/bin/perl
# $Id: testjs.pl,v 1.1 2012-11-15 22:32:35 triton Exp $
#
# Kwik script to check the file config.js
#
use strict;
use File::Slurp;
use JSON;
use JSON::Parse 'json_to_perl';
use Data::Dumper;

if (0) {my $json = '{"a":1, "b":2}';
	my $perl = json_to_perl ($json);
	print "json=$json\n";
	print Dumper $perl, "\n";
}
#
# Open the JSON file and check it...
#
my $cfgfile = "config.js";
    print "Checking JSON file $cfgfile\n";
    my $json = read_file($cfgfile);
    print "json raw text = $json\n";
    my $jdata = json_to_perl($json);
#	my $jdata = decode_json($json);
    print "Transformed JSON text into a perl structure ...\n";
    print Dumper $jdata;

