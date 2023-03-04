#!/usr/bin/perl
# $Id: previewemail.pl,v 1.6 2007-08-23 01:06:50 triton Exp $
# Copyright Triton Technology 2004
# Preview email messages in web page. File previewemail.htm is needed to partner with this file
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
# Now get on with the main business
#

if ($q->param('SID') eq '')
	{
	push @errors,'Please enter a SID';
	}
else
	{
	$data{SID} = $q->param('SID');
	my $file = "invitation.html";
	my $pfile = "invitation.txt";
	my $msg = $q->param('email_msg');
	if (0)			#($msg =~ /^(\D+)(\d+)$/)
		{
		$file = "$1-html$2";
		$pfile = "$1-plain$2";
		$data{"${msg}_checked"} = "CHECKED";
		if (!grep (/$1/,('invitation','reminder')))
			{
			$data{other_email} = $msg;
			$data{other_checked} = "CHECKED";
			}
		}
	elsif ($msg eq 'other')
		{
		$data{other_email} = $q->param('other_email');
		$file = "$data{other_email}.html";
		$pfile = "$data{other_email}.txt";
		$data{"${msg}_checked"} = "CHECKED";
		if (0)			#($data{other_email} =~ /^(\D+)(\d+)$/)
			{
			$file = "$1-html$2";
			$pfile = "$1-plain$2";
			}
		}
	else
		{
		push @errors,"Unknown message type: $msg, loading default invitation" if ($msg ne '');
		$data{"invitation1_checked"} = "CHECKED";
		}
	my $email_file = "$troot/$data{SID}/etemplate/$file";
	my $plain_file = "$troot/$data{SID}/etemplate/$pfile";
# Read in HTML email (if it exists)
	my $hdr_done = 0;
	if (-f $email_file)
		{
#		push @errors,qq{Read in file: $email_file};
		my $email_html = '';
		if (open(EMAIL,"<$email_file"))
			{
			while (<EMAIL>)
				{
				if (/<body/i)
					{
					$hdr_done++;
					next;
					}
				next if (!$hdr_done);
				next if (/<\/body/i);
				next if (/<\/html/i);
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
#		push @errors,qq{Read in file: $plain_file};
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
			$email_text =~ s/\n/<BR>\n/g;
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
my $file = 'previewemail.htm';
my $tt = new Template;
$tt->process ($file,\%data)
			or $q->mydie($tt->error);
