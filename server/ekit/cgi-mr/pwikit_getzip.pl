#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: pwikit_getzip.pl,v 1.1 2012-04-04 01:50:12 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# pwikit_getzip.pl - Assembles and retrieves a zip archive of completed forms
# 					Works for boss and participant, as it relies on id and password
#
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Date::Parse;
use Time::Piece;
require 'TPerl/cgi-lib.pl';
require 'TPerl/qt-libdb.pl';
require 'TPerl/pwikit_cfg.pl';
#
# Start of main code 
#
&ReadParse(*input);
#
$SID = $input{SID};
$id = $input{id};
$pwd = $input{token};

$dbt = $input{debug};
&db_conn;
my @mylist;
@mylist = (@{$config{selflist}},@{$config{newlist}},$config{post}) if ($SID eq 'MAP001');
@mylist = (@{$config{bosslist}}) if ($SID eq 'MAP011');
my %docs;

my $sql = "SELECT max(PWI_STATUS.WSDATE) FROM PWI_STATUS WHERE PWI_STATUS.UID = '$id'";
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
$found = 0;
foreach (@lines) {
		@values = split(/:/,$_);
		if (@values[0] eq $survey_id)
		{

				$time2 = str2time(@values[1]);
				if ($time2 lt $time)
				{
						$found = 1;
				}
		}
}

if ($found == 1)
{
#	 $doc =~ s/"PWIKitNew.rtf"/"PWIKitNew2.rtf"/g;

}

foreach my $survey_id (@mylist)
	{
	my $seq = &db_get_user_seq($survey_id,$id,$pwd);		# Any data ?
	my $f = "$qt_root/$survey_id/doc/$seq.rtf";					

		if ($survey_id eq "MAP007") {
			#$docs{$survey_id} = $f if (-f $f);		
		} else {
			$docs{$survey_id} = $f if (-f $f);
		}

	}
my @mydocs;
foreach my $key (keys %docs)
	{
	push @mydocs,$config{snames}{$key};
	}
my $doclist = join("<BR>",@mydocs) || "No forms completed yet";
my $zipfile = "$qt_root/$SID/doc/$id.zip";
if (@mydocs)
	{
# Create a Zip file
	my $zip = Archive::Zip->new();

   # Add files from disk
	foreach my $key (keys %docs)
		{
		my $file_member = $zip->addFile($docs{$key}, $config{snames}{$key}.".rtf" );
		}

# Save the Zip file
   unless ( $zip->writeToFileNamed($zipfile) == AZ_OK ) 
   		{
		die "Error writing zip file: $zipfile\n";
    	}
	if (!open (ZIP,"<$zipfile"))
		{
		print &PrintHeader;
		print "<HTML>Error '$!' encountered while opening file: $zipfile\n";
		}
	else
		{
		print "Content-Type: application/zip\n\n";
		binmode(ZIP);
		binmode(STDOUT);
		my @src_content=<ZIP>;
		print @src_content;
		close(ZIP);
# Remove the zip file (no longer needed)
		unlink $zipfile unless $input{keep};
		}
	}
else
	{
	print &PrintHeader;
	print <<HTML;
<HTML>
<BODY class="body">
<h2>No data found yet</h2>
I'm sorry, we couldn't find any completed forms for you. 

<P>Please go back and complete the forms.
</body></html>
HTML
	} 
# Disconnect from database
&db_disc;
1;
