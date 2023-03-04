#!/usr/bin/perl
## $Id: upload_file.pl,v 1.7 2007-05-17 21:58:05 triton Exp $
#
# Kwik upload script
#
use strict;
use TPerl::CGI;
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw(strftime);

#
use TPerl::Engine;
use TPerl::TritonConfig;
#-----------------------------------------------------------------------------
#
# Mainline starts here
#
my $q = new TPerl::CGI;
my %args = $q->args();
my $prefix = ($args{prefix}) ? $args{prefix} : 'upload';

my $SID = $args{SID} or die("[F] Upload Server: You must supply a SID\n");

my $UFILE_DIR = getConfig('TritonRoot')."/$SID/data";
die "[F] Upload server: target directory does not exist: $UFILE_DIR\n" if ! -d $UFILE_DIR;
my $engine = new TPerl::Engine;
print "Content-type: text/html\n\n";
print <<HEAD;
<HTML>
<link rel="stylesheet" href="/$SID/style.css">
<BODY class="body">
HEAD
my $input_file = $args{filename};
my $fn = &upload_file($input_file) if ($input_file ne '');

print <<HEAD;
<p>
[I] Accepted file: $fn

</BODY>
</HTML>
HEAD


#----------------------------------------------------------------------------
#
# SUBROUTINES START HERE
#
# routine to load file to upload directory on server.
# accepts an 'upload' cgi file handle.  Return URL to
# the uploaded file.
#
sub upload_file
	{
	my ($ufile) = @_;
	my $ufilename = "\L$ufile";
	$ufilename = ~s/\\/\//g;
	
	my @dirs = split(/\//, $ufilename);
	my $batchno = $engine->nextnumber($SID,$prefix,100);
	my $dfile = "$UFILE_DIR/${prefix}_$batchno.txt";
#	print "File uploaded to [$dfile]<BR>\n";
	
	open(DEST,">$dfile") or die "[F] Upload server: Could not open $dfile: $!";
# If I don't use binmode on Windoze, I get a Unix file 
# (which is kind of non-sensical, unless Apache is doing that 4 us)
	binmode(DEST);
	binmode($ufile);
	my @src_content=<$ufile>;
	my $when = strftime "%a %b %e %H:%M:%S %Y", localtime;
	print "# Batchno=$batchno, File src=$ufile lines=$#src_content, date=$when\n";
	print DEST @src_content;
	close($ufile);
	close(DEST);

	$dfile;	
	}
	
sub upload_bin_file
	{
	my ($ufile) = @_;
	my $ufilename = "\L$ufile";
	$ufilename = ~s/\\/\//g;
	
	my @dirs = split(/\//, $ufilename);
	my $dfile = "$UFILE_DIR/$dirs[$#dirs]";
#	print "File uploaded to [$dfile]<BR>\n";
	
	open(DEST,">$dfile") or die "[F] Upload server: Could not open $dfile: $!";
	binmode(DEST);
	binmode($ufile);
	my @src_content=<$ufile>;
	print DEST @src_content;
	close($ufile);
	close(DEST);

	$dfile;	
	}

1;
