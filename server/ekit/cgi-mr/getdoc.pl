#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: getdoc.pl,v 2.2 2007-08-22 02:03:45 triton Exp $
#
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# getdoc.pl - retrieves a document
#
#

use Date::Parse;
use Time::Piece;
require 'TPerl/cgi-lib.pl';
require 'TPerl/qt-libdb.pl';
#
#
$do_body = 1;
$plain = 1;
$form = 1;
#
# Start of main code 
#
&ReadParse(*input);


#
$survey_id = $input{sid};
#
# This little block is for Office 2003 compatibility, because it mangles the URL for us :(
# 
if ($input{sid} =~ /\&/)
	{
	my @bits = split(/\&/,$input{sid});
	foreach my $bit (@bits)
		{
		if ($bit =~ /=/)
			{
			my @param = split(/=/,$bit);
			$input{$param[0]} = $param[1];
			}
		else
			{
			$input{sid} = $bit;
			}
		}
	$survey_id = $input{sid};
	}
# # #  End of hack
#
$id = $input{id};
$doc = $input{doc};
$pwd = $input{token};
$seqno = $input{seqno};
$resp{survey_id} = $survey_id;

&db_conn;

$wsdate = 0;

my $sql = "SELECT PWI_STATUS.WSDATE FROM PWI_STATUS WHERE PWI_STATUS.PWD='$pwd'";
my $th = &db_do($sql);
while (@row = $th->fetchrow_array())
	{
	($wsdate) = @row;
	}


open my $skiphandle, '<', '/home/vhosts/ekit/htekit/surveyshutdown';
chomp(my @lines = <$skiphandle>);
close $skiphandle;

$found = 0;
$time = str2time($wsdate);
foreach (@lines) {
		@values = split(/:/,$_);
				$time2 = str2time(@values[1]);
				if ($time2 lt $time)
				{
						$found = 1;
				}
}

	if ($doc eq "PWIKit")
	{
		$doc = "PWIKit2";
	}
	if ($doc eq "PWIKitNew")
	{
		$doc = "PWIKitNew2";
	}


$dbt=0;		# This buggers things up if it is on !
my $seq = ($seqno eq '' ) ? &db_get_user_seq($survey_id,$id,$pwd,$no_uid) : $seqno;
&debug("located seq=$seq");
my $docfile = "$qt_droot/$resp{'survey_id'}/doc/$seq.rtf";
$docfile = "$qt_droot/$input{sid}/templates/$doc.rtf" if (($doc ne '') && (-f "$qt_droot/$input{sid}/templates/$doc.rtf"));
$docfile = "$qt_droot/$input{sid}/doc/$doc.rtf" if (($doc ne '') && (-f "$qt_droot/$input{sid}/doc/$doc.rtf"));

my $error = "1";

if ($error eq "1")
{

if (-f $docfile)
	{
	if (!open (DOC,"<$docfile"))
		{
		print &PrintHeader;
		print "<HTML>\n";
		&add2body("Error $! opening file: $docfile");
		&qt_Footer;
		}
	else
		{
		$ufile = "$qt_droot/$resp{'survey_id'}/web/u$pwd.pl";
		if (-f $ufile)
			{
			&my_require($ufile,0);
			}
#		print "Content-Type: text/richtext\n\n";
		print "Content-Type: application/rtf\n\n";
		while (<DOC>)
			{
			while (/<(\w+)>/)
				{
				my $thing = $1;
				my $ting = lc($thing);
				my $newthing = $ufields{$ting};
				&debug("Replacing <$thing> with [$newthing]");
				s /<$thing>/$newthing/g;
				}
			print;
			}
		close(DOC);
		}
	}
else
	{
	print &PrintHeader;
	print "<HTML>\n";
	&add2body("Sorry, I cannot open that file: $docfile");
	&qt_Footer;
	}


}

else
{
	print &PrintHeader;
	print "<HTML>\n";
	&add2body("Sorry, I cannot open that file: $docfile");
	&qt_Footer;

}
&db_disc;
1;
