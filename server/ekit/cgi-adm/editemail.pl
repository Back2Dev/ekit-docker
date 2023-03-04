#!/usr/bin/perl
# $Id: editemail.pl,v 1.6 2005-04-05 22:36:27 triton Exp $
# Copyright Triton Technology 2004
# Edit email messages in web page. File editemail.htm is needed to partner with this file
#

use strict;

use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::TSV;
use TPerl::LookFeel;
use Template;
use TPerl::TritonConfig;
use TPerl::MyDB;
use TPerl::Error;


my $troot = getConfig ('TritonRoot');
my $SID = 'EMBADIR';
my $uid = $ENV{REMOTE_USER};
my $q = new TPerl::CGI;
my %args = $q->args;
our %data;

my ($crap,$pwd,$rest) = split (/\//,$ENV{PATH_INFO},3);
print $q->header;
my @errors = '';

#
# HTML definitions
#
my $vhost = $ENV{HTTP_HOST};
if ($vhost eq '')
	{
	$vhost = $ENV{SERVER_NAME};
	$vhost .= ":$ENV{SERVER_PORT}" if ($ENV{SERVER_PORT} ne '80');
	}
my $html_hdr = <<HDR;
  <!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
  <html>
  <head>
  <title>Survey invitation</title>
<!--  <link type="text/css" rel="stylesheet" href= "http://$vhost/$SID/style.css"> not USED - SEE INLINE STYLESHEET THAT FOLLOWS -->
  <STYLE TYPE="text/css">
.prompt {  font-family: Arial, Helvetica, sans-serif; font-size: 10pt; font-style: normal;  }
.qlabel {  color: darkslateblue;font-weight: bold; font-family: Arial, Helvetica, sans-serif; font-size: 10pt; font-style: normal;  }
.heading { background-color: darkslateblue; color:white; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: bold; }
.options { background-color: lightcyan; color:#000000; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: bold; }
.options2 { background-color: lightblue; color:#000000; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: bold; }
.instruction {  font-family: Arial, Helvetica, sans-serif; font-style: italic; font-size: 9pt; }
.default {  }
.links {  font-family: Arial, Helvetica, sans-serif; font-size: 9pt}
.body { background-color: white; font-family: Arial, Helvetica, sans-serif; font-size: 9pt}
.mytable { background-color: darkslateblue; color:yellow; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: bold; border-width:2px; border-color:darkslateblue; border-style:solid;}
.notes { background-color: #FFFFFF; font-family: Arial, Helvetica, sans-serif; font-size: 7pt}
  </STYLE>
  </head>
  <body class="body">
HDR
my $html_ftr = <<HDR;

  </body>
  </html>
HDR
#
# Now get on with the main business
#

if ($q->param('SID') eq '')
	{
	push @errors,'Please enter a SID';
	}
else
	{
	$data{SID} = $q->param('SID');
	my $file = "invitation-html1";
	my $pfile = "invitation-plain1";
	my $msg = $q->param('email_msg');
	if ($msg =~ /^(\D+)(\d+)$/)
		{
		$file = "$1-html$2";
		$pfile = "$1-plain$2";
		$data{"${msg}_checked"} = "CHECKED";
		}
	elsif ($msg eq 'other')
		{
		$data{other_email} = $q->param('other_email');
		$file = "$data{other_email}-html";
		$pfile = "$data{other_email}-plain";
		$data{"${msg}_checked"} = "CHECKED";
		}
	else
		{
		push @errors,"Could not deal with message type: $msg, loading default invitation" if ($msg ne '');
		$data{invitation1_checked} = "CHECKED";
		}
# Save HTML email to file
	my $email_file = "$troot/$data{SID}/config/$file";
	if ($q->param('email_html') ne '')
		{
		push @errors,qq{Saving to file: $email_file};
		if (open(EMAIL,">$email_file"))
			{            
			print EMAIL $html_hdr;
			my $stuff = $q->param('email_html');
			$stuff =~ s/\r//g;
			while ( $stuff =~ /\[%(\w+)%\]/)
				{
				my $thing = $1;
				$stuff =~ s/\[%${thing}%\]/<%${thing}%>/;
				}
			$stuff =~ s/<BR>/<BR>\n/g;
			print EMAIL "$stuff";
			print EMAIL $html_ftr;
			close EMAIL;
			}
		else
			{ push @errors,"Error $! encountered while saving HTML email file: $email_file";}
		}
# Save PLAIN TEXT email to file
	my $plain_file = "$troot/$data{SID}/config/$pfile";
	if ($q->param('email_text') ne '')
		{
		push @errors,qq{Saving to file: $plain_file};
		if (open(EMAIL,">$plain_file"))
			{
			my $stuff = $q->param('email_text');
			$stuff =~ s/\r//g;
			while ( $stuff =~ /\[%(\w+)%\]/)
				{
				my $thing = $1;
				$stuff =~ s/\[%${thing}%\]/<%${thing}%>/;
				}
			print EMAIL "$stuff";
			close EMAIL;
			}
		else
			{ push @errors,"Error $! encountered while saving PLAIN email file: $plain_file";}
		}
# Read in HTML email (if it exists)
	if (-f $email_file)
		{
		push @errors,qq{Read in file: $email_file};
		my $email_html = '';
		if (open(EMAIL,"<$email_file"))
			{
			while (<EMAIL>)
				{
				$email_html .= $_;
				}
			close EMAIL;
			while ( $email_html =~ /<%(\w+)%>/)
				{
				my $thing = $1;
				$email_html =~ s/<%${thing}%>/\[%${thing}%\]/;
				}
			$data{email_html} = $email_html;
			}
		else
			{ push @errors,"Error $! encountered while reading HTML email file: $email_file";}
		}
	else
		{
		push @errors,qq{File does not exist: $email_file};
		}
# Read in PLAIN TEXT email (if it exists)
	if (-f $plain_file)
		{
		push @errors,qq{Read in file: $plain_file};
		my $email_text = '';
		if (open(EMAIL,"<$plain_file"))
			{
			while (<EMAIL>)
				{
				$email_text .= $_;
				}
			close EMAIL;
			while ( $email_text =~ /<%(\w+)%>/)
				{
				my $thing = $1;
				$email_text =~ s/<%${thing}%>/\[%${thing}%\]/;
				}
			$data{email_text} = $email_text;
			}
		else
			{ push @errors,"Error $! encountered while reading PLAIN email file: $plain_file";}
		}
	else
		{
		push @errors,qq{File does not exist: $plain_file};
		}
	}
$data{errormsg} = join("<BR>",@errors);
$data{errormsg} .= "<BR>" if ($data{errormsg} ne '');
my $file = 'editemail.htm';
my $tt = new Template;
$tt->process ($file,\%data)
			or $q->mydie($tt->error);
