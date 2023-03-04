#!/usr/bin/perl
#$Id: escheme_work.pl,v 1.15 2007-09-25 02:08:41 triton Exp $
use strict;
use Data::Dumper;
use Getopt::Long;
use Carp qw(confess);

use TPerl::DBEasy;
use TPerl::Engine;
use TPerl::Error;
use TPerl::EScheme;
use TPerl::Event;
use TPerl::TritonConfig;
use TPerl::Sender;

my $e = new TPerl::Error( ts => 1 );
my $debug = 1;
my $data = {to => 'mikkel@market-research.com',
	fullname => 'Mike King',
	uid => '1234',
	password => '1234',
};

 my %args = (
	
  # mail merge template.
	
    # either or both of
    plain       =>     'Dear <%fullname%>, your horse and cart is ready',
    html       =>   'participant', # '<html><H1>Dear <%firstname%>....',

    # More formally 
    name       =>    'participant',  ##  Means the text or html above are ignored.
    SID        =>    'MAP001',    # mandatory if itype is set
    noplain     =>    1,           # html only
    nohtml    =>    1,           # text only
#    language   =>    'sp'         # language specifier.

  #Now some things about how we behave.  
    err        =>    $e,
    debug      =>    1,       # write debug info
    
  #Some stuff about how the Mail::Sender object behaves.
      smtp_host=>    'localhost',
	                              # can be overwritten.
	  mail_sender_debug_level => 1 # defaults to 4.
	);


 my $s = new TPerl::Sender(%args);
 # This always succeeds.  check
 
 if( my $res = $s->send(data=>$data)){
 print Dumper $res;
 }else{
  # some set up part failed.  no template, no from address etc..
  # no .hdr file, 
  die $s->err;
 }


 
