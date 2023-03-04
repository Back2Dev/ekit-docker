#!/usr/local/bin/perl
# mkstatspage.pl
#
# File to quickly summarise the result data
#
require 'TPerl/qt-libdb.pl';
#
require 'TPerl/whatcore.pl';
#
$cmdline = 1;		# Tells qt-lib.pl that we are running from a command line, paths may differ
#
#-----------------------------------------------------------
#
# Main line start here
#
#-----------------------------------------------------------
sub die_usage
	{
	print "Usage: $0 [-v] [-t] [-h] AAA101\n" ;
	print "\t-h Display help\n";
	print "\t-v Display version no\n";
	print "\t-t Trace mode\n";
	print "\t-i input name extension\n";
	print "\t-o output name extension\n";
	print "\tAAA101 Survey ID\n";
	exit 0;
	}
if ($h)
	{
	&die_usage;
	}
if ($v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/mkwhatpage.pl,v 1.1 2004-05-19 12:45:59 triton Exp $'."\n";
	exit 0;
	}

#
# Check the parameter (The Survey ID)
#
$survey_id = $ARGV[0];
&get_root;

&die_usage if ($survey_id eq '');

$dir = "${qt_root}/${survey_id}/html/admin";
if (!(-d $dir))
	{
	mkdir($dir,0755) || die "Cannot create directory: $dir\n";
	}
my $filename = "$dir/what.html";
$filename = "$dir/what$o.html" if $o;
my $ifile = "$qt_root/$survey_id/final/$survey_id$i.txt";
if ($n && -e $ifile && -e $filename ){
    my $otime = (stat($filename))[9];
    my $itime = (stat($ifile))[9];
    if ($itime < $otime){
        print STDERR "Not re-making '$filename' becase '$ifile' is older\n";
        exit;
    }

#   my $ni = scalar(localtime($itime));
#   my $no = scalar(localtime($otime));
#   print STDERR "$ifile:in=$itime ($ni)\n$filename:out=$otime ($no)\n";
}


print STDERR "Creating file: $filename\n" if ($t);
open (OUT, ">$filename") || die "Error $!: Cannot create file: $filename\n";
select(OUT);
print "<HTML>\n";
&do_what($survey_id,$i);
$bgcolor = "#CCCCFF";
$do_body = 1;
$external = '';
$do_footer = 1;
&qt_Footer;
close(OUT);
