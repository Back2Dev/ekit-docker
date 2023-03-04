#!/usr/bin/perl
#
#
require 'TPerl/cgi-lib.pl';
require 'TPerl/qt-libdb.pl';
#
use CGI::Carp qw(fatalsToBrowser);
use TPerl::TSV;

our @batch_extra_cols = (qw{UNIVERSITY SCHOOL_NAME PROGRAM_NAME});
#
&ReadParse(*input);
print "Content-Type: text/html\n\n";				# Early on in the piece so that we can see debug output
$SID = $input{'survey_id'};
print <<HEAD;
<HTML>
<HEAD>
<link rel="stylesheet" href="/$SID/admin/style.css">
</HEAD>
<BODY class="body">
HEAD

&get_config($SID);		# Look for override for @batch_extra_cols

my $bcdir = "$qt_root/$SID/config";
opendir(BCD,$bcdir) || die "Error $! encountered while reading directory: $bcdir\n";
my @files = grep(/^broadcast\d+$/,readdir(BCD));
foreach my $f (@files)
	{
	if($f =~ /^broadcast(\d+)$/)
		{
		my $num = $1;
		my $ffile = "$qt_root/$SID/config/$f";
		my $ftsv = new TPerl::TSV (file=>$ffile,nocase=>1);
		my $row = $ftsv->row();									# Just pull out one row to get what we need
		$names{$num} = join("<TD>",map($row->{$_},@batch_extra_cols));
		}
	else
		{
		print STDERR "Warning: Invalid file name format: $f (should be broadcast<n>)\n";
		}
	}


print qq{<TABLE CELLPADDING="3" BORDER=0 CELLSPACING=1 class="mytable">\n};
#$dbt = 1;
&db_conn;
my %batchinfo = ();
my %reminfo = ();
$sql = "SELECT TAG,BID,SENT,WORK_TYPE,START_EPOCH,INSERT_EPOCH from EMAIL_WORK,BATCH where EMAIL_WORK.SID=BATCH.SID and EMAIL_WORK.BID=BATCH.BID and SID=?";
&db_do($sql,$SID);
while ($hr = $th->fetchrow_hashref())
	{
	$batchinfo{$$hr{BID}} = $hr if ($$hr{WORK_TYPE} == 1);
	$reminfo{$$hr{BID}} = $hr if ($$hr{WORK_TYPE} == 2);
	}
$th->finish;
$sql = "SELECT BATCHNO,COUNT(*) FROM $SID GROUP BY BATCHNO ORDER by BATCHNO DESC";
$ls = lc($sql);
$line = 0;
&db_do($sql);
my $options = "options";
my $prevname = '';
while ($hr = $th->fetchrow_hashref())
	{
	if ($line == 0)
		{
		print "<TR>\n";
		foreach $key (keys %$hr)
			{
			print "\t\t<TH class=\"heading\">$key</TH>";
			}
		print join("",map(qq{<TH class="heading">&nbsp;}.$_.qq{&nbsp;</td>},@batch_extra_cols));
		print qq{<TH class="heading">&nbsp;PROGID&nbsp;</td>};
		print qq{<TH class="heading">&nbsp;SENT&nbsp;</td>};
		print qq{<TH class="heading">&nbsp;SCHEDULE&nbsp;</td>};
		print qq{<TH class="heading">&nbsp;REMIND&nbsp;</td>};
		print qq{<TH class="heading">&nbsp;SCHEDULE&nbsp;</td>};
		print "</TR>\n";
		}

	if ($#batch_extra_cols != -1)
		{
		if ($prevname ne $names{$$hr{BATCHNO}})
			{
			$options = ($options eq 'options') ? "options2" : 'options';
			}
		}
	else
		{
		$options = ($line %2) ? "options2" : 'options';
		}
	print qq{<TR class="$options">\n};
	foreach $key (keys %$hr)
		{
		print qq{\t\t<TD class="$options" align="right">$$hr{$key}</TD>\n};
		}
	print qq{<TD class="$options" align="left">&nbsp;$names{$$hr{BATCHNO}}&nbsp;</td>} if ($#batch_extra_cols != -1);
	my $br = $batchinfo{$$hr{BATCHNO}};
	my $tag = $$br{TAG};
	print qq{<TD class="$options" align="left">&nbsp;$tag &nbsp;</td>};
	foreach my $br ($batchinfo{$$hr{BATCHNO}}, $reminfo{$$hr{BATCHNO}})
		{
		foreach my $key qw[SENT START_EPOCH]
			{
			$val = $$br{$key};
			$val = "&nbsp;" if ($val eq '');
			if ($val ne '&nbsp;')
				{
				if ($key =~ /EPOCH/i)
					{
					$val = localtime($val);
					$val =~ s/\d+:\d+:\d+ \d+$//;
					}
				if ($key =~ /WORK_TYPE/i)
					{
					$val = ($val == 1) ? 'Invite' : 'Reminder';
					}
				}
			print qq{<TD class="$options" align="left">&nbsp;$val &nbsp;</td>};
			}
		}
	print "</TR>\n";
	$prevname = $names{$$hr{BATCHNO}};
	$line++;
	}
$th->finish;
print "</TABLE>\n";

print "<P class=\"heading\">&nbsp;<BR>&nbsp;*** NO DATA ***&nbsp;<BR>&nbsp;</P>" if ($line == 0);

print "$form\n";
print <<EOF;
	<HR>
	</BODY>
	</HTML>
EOF
1;

