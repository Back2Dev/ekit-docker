#!/usr/bin/perl
#
#
require 'TPerl/cgi-lib.pl';
require 'TPerl/qt-libdb.pl';
#$db_isib = 1;

#
use CGI::Carp qw(fatalsToBrowser);
#
&ReadParse(*input);
print "Content-Type: text/html\n\n";				# Early on in the piece so that we can see debug output
my $path = 'admin';
$path = "$input{'SID'}/admin" if ($input{'SID'} ne "");
print <<HEAD;
<HTML>
<HEAD>
<link rel="stylesheet" href="/$path/style.css">
</HEAD>
<BODY class="body">
HEAD

$form =  <<EOF;
	<FORM ACTION="/cgi-adm/dbquery.pl" METHOD="POST">
	<TABLE CELLPADDING="5" cellspacing=0 class="mytable">
	<TR><TD>Please enter SQL:</TD><TD><INPUT name="sql" size="60" value="$input{'sql'}"></TD></TR>
	</TABLE>
	</FORM>
EOF

if ($input{'sql'} ne '')
	{
	print qq{<TABLE CELLPADDING="3" CELLSPACING="1" BORDER="0" class="mytable">\n};
#$dbt = 1;
	&db_conn;
	$sql = $input{'sql'};
    if ($sql =~ /<NOW\s*-\s*(\d+)>/i)
        {
        my $when = time() - ($1*24*60*60);
        $sql =~ s/<NOW\s*-\s*\d+>/$when/i;
        }
	$ls = lc($sql);
	$line = 0;
	&db_do($sql);
	while ($hr = $th->fetchrow_hashref())
		{
		if ($line == 0)
			{
			print "<TR>\n";
			foreach $key (keys %$hr)
				{
				$key ='When' if (lc($key) eq 'ts');
				print "\t\t<TH class=\"heading\">$key</TH>";
				}
			print "</TR>\n";
			}
		print "<TR>\n";
		foreach $key (keys %$hr)
			{
			$thing = $$hr{$key};
			$thing = localtime($$hr{$key}) if (lc($key) eq 'ts');
			print "\t\t<TD class=\"options\">$thing</TD>";
			}
		print "</TR>\n";
		$line++;
		}
	print "</TABLE>\n";
	}
print "<P class=\"heading\">&nbsp;&nbsp;*** NO DATA ***&nbsp;&nbsp;</P>" if ($line == 0);

print "$form\n" if (($input{'show_sql'} ne '') && ($input{'show_sql'} ne '0'));
print <<EOF;
	<HR>
	</BODY>
	</HTML>
EOF
1;

