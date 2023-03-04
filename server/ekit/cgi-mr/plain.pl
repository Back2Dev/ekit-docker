#!/usr/bin/perl
#
require 'TPerl/cgi-lib.pl';
#
# Start of main code 
#
&ReadParse(*input);
print &PrintHeader;
$os = $^O;
print <<EOF;
<html>
<head>
<title> test page</title>
</head>
<body>
<H2>Hello there $name - your CGI script works !!</H2>
Perl thinks your operating system is $os<BR>
<TABLE border=4><TR>
EOF
for ($i=0;$i<10;$i++)
	{
	print "<TD>$i</TD>\n";
	}
print "</TR></TABLE>\n";
foreach $key (keys (%input))
	{
	print "$key = $input{$key}<BR>\n";
	}
print "<HR>\n";

foreach $key (keys (%ENV))
	{
	print "$key = $ENV{$key}<BR>\n";
	}
print <<EOF
<A HREF="/cgi-mr/plain.pl">plain.pl</A>
</body>
</html>
EOF
