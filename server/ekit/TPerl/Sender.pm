# $Id: Sender.pm,v 1.20 2011-05-06 17:29:02 triton Exp $
package TPerl::Sender;
use strict;
use Carp qw(confess);
use File::Slurp;
use TPerl::Hash;
use Data::Dumper;
use TPerl::Template;
use TPerl::TritonConfig;
use Mail::Sender;
use File::Temp;
use DirHandle;
use Email::Valid;
use File::Basename;
use TPerl::Parser;

=head1 SYNOPSIS

This is meant to do all we can in the way of making email
bomb proof, and easy to use as well.  The TPerl::Sender
object holds lots of setup data, like mail merge templates,
and header information.    When you actually send a mail you
get a TPerl::Sender::Result back.  This contains information
about how things actually went, from as many sources as we
can get to.

 # quick and dirty usage.  See later for more stuff.
 
 my $sender = new TPerl::Sender (plain=>'Dear <%firstname%>..');

 # some data for the email.
 my $data = {
  # These are compulsory...
   from_name=>'Andrew Creer',
   from_email=>'goose@goose.com',
   subject=>'Your car is ready',
   to=>'recipient@goose.com'

  # these are specified in the template and become compulsory
   firstname=>'Andrew',
 };

 if (my $status=$sender->send(data=>{firstname=>'Andrew'}) )
  # TPerl::Sender now thinks it sent the message.
  print $status->info  # info about the message (sent mail to '$to' about 'subject' in lang ($lang)
  print $status->id    # the message id assigned by sendmail
  print $status->conversation # the cut down smtp conversation
 }else{
   # template is broken, 
   # smtp_host not defined,
   # mail sender error
   die "Some infrastructure is broken".$sender->err;
 }
 

=head1 Email Template files.

A note on email template files.  We are going to store email
templates files in their own called 'etemplate'.  The
filenames are in the form: $name_$lang.$ext  $lang must be 2
lowercase letters.  $ext must be either .txt .html .hdr for
the text version, the html version and the header file
respectively.

=head1 Multiple languages.

Each TPerl::Sender object deals with one particular set of
templates.  If you want to send mail to an english and
spanish versions, you'll need one TPerl::Sender object for
each one.


=head1 Mail Headers.

Header information and other data comes from 2 places only.  The data hash
supplied to send() or a .hdr file for the particular
template.  The data hash will override the .hdr file.

=head1 FORMAL USAGE

Firstly we need to set up some stuff.  There is an internal
argument handler function that will handle any or all of
these args passed to any of the TPerl::Sender functions.  It
will confess (die with a stack trace) if it does not
recognise any of the args, sort of programmer help to make
sure you don't mispell 'language' or use 'itype' when you
mean 'name', in the new order of things.

Specify the mail merge template to send to in a variety of
ways.  for quick stuff, you may just want to have a text
only email with the text in the script, but still want to
log what went on.  More formally you may want the spanish
version of invite1 from DOM...
 
 my %args = (
	
  # mail merge template.
	
    # either or both of
    plain       =>     'Dear <%firstname%>, your car is ready',
    html       =>    '<html><H1>Dear <%firstname%>....',

    # More formally 
    name       =>    'invite1',  ##  Means the text or html above are ignored.
    SID        =>    'ABC123',    # mandatory if itype is set
    noplain     =>    1,           # html only
    nohhtml    =>    1,           # text only
    language   =>    'sp'         # language specifier.

  #Now some things about how we behave.  
    err        =>    'A TPerl::Error object',
    debug      =>    1,       # write debug info
    
  #Some stuff about how the Mail::Sender object behaves.
      smtp_host=>    'goose.com', # usually comes from getConfig('smtp_host')
	                              # can be overwritten.
	  mail_sender_debug_level => 2 # defaults to 4.
	);


 my $s = new TPerl::Sender(%args);
 # This always succeeds.  check
 
 if( my $res = $s->send(data=>$data)){
  print $res->info;
  print $res->id;
  print $res->conversation;
 }else{
  # some set up part failed.  no template, no from address etc..
  # no .hdr file, 
  die $s->err;
 }

We use Mail::Sender to contruct email messages.  We use
debug_level=>1 to get debug output from the actual SMTP
conversation with the server.  This allows us to get the
unique (sendmail) id to be used later in trawling the
/var/log/mail logs to find any messages from sendmail.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;
    $self->_process_args(@_);
    return $self;
}

sub _process_args { 
    # Seeing we can accept many args in many places, lets do it all at once.
    # print "in _process_args:".Dumper \@_;
    my $self = shift;
    my %args = @_;

	my @accept = qw (data html plain lang debug name err 
		SID smtp_host mail_sender_debug_level noplain nohtml
		attach attach_name
		);

	my $acc_hash = {};
	$acc_hash->{$_}++ foreach @accept;

	my $bad_list = [];
	# print "acc_hash ".Dumper $acc_hash;
	# print "Args ".Dumper \%args;
	foreach my $a (keys %args){
		push @$bad_list,$a unless $acc_hash->{$a};
		if (ref $self){
			$self->{$a} = $args{$a} if exists $args{$a};
		}
	}
	confess "'@$bad_list' is/are not recognised: use '@accept'" if @$bad_list;
    return %args;
}

#$self->{err} is the TPerl::Error err object passed in.
sub err { my $self = shift;return $self->{err_msg} = $_[0] if @_;return $self->{err_msg} }
sub debug { my $self = shift; return $self->{debug} = $_[0] if @_; return $self->{debug}; }
sub plain { my $self = shift; return $self->{plain} = $_[0] if @_; return $self->{plain}; }
sub html { my $self = shift; return $self->{html} = $_[0] if @_; return $self->{html}; }
sub name { my $self = shift; return $self->{name} = $_[0] if @_; return $self->{name}; }
sub lang { my $self = shift; return $self->{lang} = $_[0] if @_; return $self->{lang}; }

#ro methods.
sub SID {my $self = shift; return $self->{SID}};
sub noplain {my $self = shift; return $self->{noplain}};
sub nohtml {my $self = shift; return $self->{nohtml}};
sub nosubchk { return $_[0]->{nosubchk}}


sub check_lang {
	my $self = shift;
	my $default_lang = 'en';  #Get this from TritonConfig later on???
	if (my $lang = $self->lang){
		$self->lang('') if $lang eq $default_lang;
		unless ($lang =~ /^[[:lower:]]{2}$/){
			$self->err("Language '$lang' must be 2 lowercase chars");
			return undef;
		}
	}
	return 1;
}

sub template_dir {
	my $self = shift;
    return $self->{template_dir} if ref($self) && $self->{template_dir};
    my $SID = $self->SID() or ($self->err("SID not set") && return undef);
    my $troot = getConfig('TritonRoot') || ($self->err("Could not get TritonRoot from getConfig") && return undef);
	my $td = join '/',$troot,$SID,'etemplate';
	($self->err("template_dir '$td' does not exist") && return undef) unless $td;
    $self->{template_dir} = $td;
    return $td;
}

sub headers {
	my $self = shift;
	if (@_){
		return $self->{loaded_headers} = $_[0];
	}else{
		return $self->{loaded_headers};
	}
}

sub header_save {
	my $self = shift;
	my $fn = $self->filenames('header') || return undef;
	my $headers = $self->headers;
	unless ($headers){
		$self->err("While saving headers, could not get headers".$self->err);
	}
	
	my $ini;
	if (-e $fn){
		$ini = new Config::IniFiles(-file=>$fn);
		unless ($ini){
			$self->err("Could not load '$fn' as an inifile");
			return undef;
		}
	}else{
		$ini = new Config::IniFiles();
		$ini->SetFileName($fn);
	}
	my $section = 'main';
	$ini->DeleteSection($section);
	$ini->AddSection($section);
	
	foreach my $k (keys %$headers){
		$ini->newval($section,$k,$headers->{$k});
	}
	unless ($ini->WriteConfig($fn)){
		$self->err("Could write header file '$fn':$!");
		return undef;
	}
	return $ini;
}

sub header_load {
    my $self = shift;
	return undef unless $self->check_lang;
    return  $self->{loaded_headers} if exists $self->{loaded_headers};

    my $data = {};
    tie %$data, 'TPerl::Hash';

    if (my $name = $self->name()){
		my $fn = $self->filenames('header') || return undef;
		if (-e $fn){
			my $ini = new Config::IniFiles(-file=>$fn);
			unless ($ini){
				$self->err("Could not load as ini file '$fn'");
				return undef;
			}
			my $section = 'main';
			foreach my $p ($ini->Parameters($section)){
				$data->{$p} = $ini->val($section,$p);
			}
		} else {

        $self->err("Header file does not exist '$fn'");
        return undef;
		}
    }
    $self->headers($data);
	return $data;
}

sub template_load {
	my $self = shift;
	my %args = @_;
	$self->check_lang || return undef;
	if (my $name = $self->name){
		unless ($self->nohtml){
			my $fn = $self->filenames('html') || return undef;
			if (-e $fn){
				if (-r $fn){
					my $content = read_file($fn);
					$self->html($content);
				}else{
					$self->err("Could not read html template '$fn'");
					return undef;
				}
			}else{
				$self->err("HTML template '$fn' does not exist");
				return undef;
			}
		}
		unless ($self->noplain){
			my $fn = $self->filenames('plain') || return undef;
			if (-e $fn){
				if (-r $fn){
					my $content = read_file($fn);
					$self->plain($content);
				}else{
					$self->err("Could not read plain template '$fn'");
				}
			}else{
				$self->err("Plain template '$fn' does not exist");
				return undef;
			}
		}
	}
	return 1;
}

# Have a file, and want to know the template and language? use this
# closely linked with the filenames hash below.
sub deparse_file {
	my $self = shift;
	my $file = shift;
	my ($name,$path,$suffix) = fileparse($file,qr/\.\w+$/);
	unless (grep $_ eq $suffix,qw( .txt .hdr .html)){
		$self->err("Bad suffix '$suffix' while deconstructing '$file'");
		return ;
	}
	my $ret = {name=>$name};
	if ($name =~ s/_([[:lower:]]{2}$)//){
		$ret->{lang} = $1;
	}
	return $ret;
}

sub filenames {
	my $self = shift;
	my $type = lc(shift);

	return undef unless $self->check_lang;
	my $lang = $self->lang;
	$lang = "_$lang" if $lang;
	my $td = $self->template_dir() || return undef;
	my $name = $self->name;
	unless ($name){
		$self->err("Can't do filenames if 'name' is not set");
		return undef;
	}

	if ($type eq 'plain'){
		return join '/',$td,"$name$lang.txt"
	}elsif ($type eq 'html'){
		return join '/',$td,"$name$lang.html";
	}elsif ($type eq 'header'){
		return join '/',$td,"$name$lang.hdr";
	}else{
		confess "First param must be 'plain' 'html' or 'header'";
	}
}

sub filenames_list {
	# returns a list of all the filenames associated with a template.
	my $self = shift;
	my $list = [];
	push @$list, $self->filenames('header') || return undef;
	push @$list, $self->filenames('html') unless $self->nohtml;
	push @$list, $self->filenames('plain') unless $self->noplain;
	return $list;
}


sub template_save {
	my $self = shift;
	my %args = @_;
	
	unless ($self->noplain){
		my $fn = $self->filenames('plain') || return undef;
		unless (overwrite_file($fn,{err_mode=>'quiet'},$self->plain)){
			$self->err("Could not same plain version in '$fn':$!");
			return undef;
		}
	}
	unless ($self->nohtml){
		my $fn = $self->filenames('html') || return undef;
		unless (overwrite_file($fn,{err_mod=>'quiet'},$self->html)){
			$self->err("Could not same html version in '$fn':$!");
			return undef;
		}
	}
	return 1;
}
sub template_list {
	my $self = shift;
	my %args = @_;

	my $td = $self->template_dir() || return undef;

	return $self->{template_list} if exists $self->{template_list};

	my $dh = new DirHandle ($td);
	unless ($dh){
		$self->err("Could not open template dir '$td':$!");
		return undef;
	}
	my $hsh = {};
	while (my $f = $dh->read){
		if (my ($title) = $f =~ /^(.*?)(_[[:lower:]]{2})?.hdr$/){
			$hsh->{$title}++;
		}
	}
	my @list = sort keys %$hsh;
	$self->{template_list} = \@list;
	return $self->{template_list};
}

sub template_hash {
	my $self = shift;
	my $list = $self->template_list || return undef;
	my $hsh = {};
	$hsh->{$_}++ foreach @$list;
	return $hsh;
}

sub send_process {
	## This is so you can do a dry run of assembly without actually sending the mail.
	## returns a hash with plain, html,data , attach, attach_name
	## the plain, html and data elements are fed through the template thingo.
	my $SID;
	my $self = shift;
	my %args = $self->_process_args(@_);

	my $attach = $args{attach};
	if ($attach && ! -f $attach){
		$self->err("Cannot find file for attaching: $attach");
		return undef;
	}
	my $attach_name = $args{attach_name};
	my $hdr = $self->header_load() or return undef;
	return undef unless $self->template_load();

    my $data = $args{data};
    unless ($data){
        $self->err("No data hash supplied");
        return undef;
    }

    # $temp is a deep copy of the data and headers into a case insensitive hash, so you
    # don't mangle what was sent in.  
    # Mike thinks that looking for headers should be simple.  The defaults come from the
    # hdr file, possible overwritten by the data hash
    my $temp = {};
    tie %$temp,'TPerl::Hash';

    # so the hdr file goes in.
    $temp->{$_} = $hdr->{$_} foreach keys (%$hdr);

    if (my $data = $args{data}){
        $temp->{$_} = $data->{$_} foreach keys %$data;
    }

	# Now we should be able to 'know' some default values.
	# We should probably check they are actually needed, before we 
	# pu them in, but that is hard given that we support recursion
	# in the substitutions.
	#
	# the list of defaults so far is:
	# SID - use the one in here if its there.
	# vhost - use the FQDN if its defined.
	# banner - use the /survey/banner/[%SID%]/[%password%]/ which will show a banner escheme
	# 	work will fix the banner for its purposes, and aspinvite in a different
	# 	way for its purposes
	# start - use http://[%vhost%]/survey/start/[%password%]/
	unless (exists $temp->{SID}){
		$temp->{SID} = $self->SID if $self->SID;
	}
	unless (exists $temp->{vhost}){
		$temp->{vhost} = getConfig('FQDN') if getConfig('FQDN');
	}
	# assuming the banner is bad.  Lets put it in only if there is a password and SID already
	if (exists ($temp->{SID}) and exists($temp->{password})){
		unless (exists $temp->{banner}){
			$temp->{banner} = qq{<img src="http://[%vhost%]/survey/banner/[%SID%]/[%password%]/" alt="banner">};
		}
		unless (exists $temp->{start}){
			my $url = q{http://[%vhost%]/survey/start/[%SID%]/[%password%]};
			$temp->{start} = qq{<a href="$url">$url</a>};
		}
	}

	my $plain = $self->plain;
	my $html = $self->html;

	# print "Plain=$plain\n";
	
	#lets defer returning undef and do all the errors at the end.
	my $errs = [];

	#Lets do template_processing of the things in the data hash.
    foreach my $k (keys %$temp){
        my $orig = $temp->{$k};
        my $new = $orig;
        if ($temp->{$k}){
            my $tt = new TPerl::Template (template=>$temp->{$k});
			unless ($tt->check_subs($temp)){
				push @$errs,"in '$k:($temp->{$k})':".$tt->err;
				#$self->err("in '$k:($temp->{$k})':".$tt->err);
				#return undef;
			}
            $new = $tt->process($temp);
            $self->debug_print("for $k changed '$orig' to '$new'") unless $orig eq $new;
        }
        $temp->{$k} = $new;
    }
	# now the text and plain bits.
	my $template_bit = " '".$self->name."' " if $self->name;
	$SID = $self->SID;
    if ($html){
        my $tt = new TPerl::Template (template=>$html);
        unless ($tt->check_subs($temp)){
            my $msg = "$SID${template_bit}HTML ".$tt->err;
            if ($self->nosubchk()){
                $self->debug_print($msg);
            }else{
				push @$errs,$msg;
				#$self->err($msg);
				#return undef;
            }
        }
        $html = $tt->process($temp);
    }else{
		push @$errs,"$SID${template_bit}HTML is blank" unless $self->nohtml;
	}
    if ($plain){
        my $tt = new TPerl::Template (template=>$plain);
        unless ($tt->check_subs($temp)){
            my $msg = "$SID${template_bit}PLAIN ".$tt->err;
            if ($self->nosubchk()){
                $self->debug_print($msg);
            }else{
				push @$errs,$msg;
				#$self->err($msg);
				#return undef;
            }
        }
        $plain = $tt->process($temp);
    }else{
		push @$errs,"$SID${template_bit}plain is blank" unless $self->noplain;
	}
    my $email = $temp->{to};
    my $password = $temp->{password};
    my $from_email = $temp->{from_email};
    my $from_name = $temp->{from_name};
    my $subject = $temp->{subject};

	$email =~ s/^\s*(.*?)\s*$/$1/;

	$SID = $self->SID;

	

    # After substitution is another chance to return undef.....
    push @$errs,"from_name not supplied to send_process()" unless $from_name;
	push @$errs,"No SUBJECT supplied to send_process()" unless $subject;
	if (defined $email){
		push @$errs,"Invalid 'to' email address '$email' supplied to send_process()" 
			unless Email::Valid->address($email);
	}else{
		push @$errs,"TO address not supplied to send_process()";
	}
	if ($from_email){
		push @$errs,"Invalid 'from_email' email address '$from_email' supplied to send_process()" unless
			Email::Valid->address($from_email);
	}else{
		push @$errs,"from_email not supplied to send_process()";
	}
	$from_email = Email::Valid->address($from_email);

	# Allow the smtp_host to be specified in the headers or ufile for testing
	# porpoises.  and to allow mail to different people to be sent from
	# different hosts.
	my $smtp_host = $temp->{smtp_host} || $self->{smtp_host} || getConfig('smtp_host');

	push @$errs,"Could not get smtp_host in send_process" unless $smtp_host;

	if (@$errs){
		$self->err($errs);
		return undef;
	}

    #These bits are always the same.
    my %common_sender_args = (
		smtp=>$smtp_host,
		to=>$email,
		from=>qq{$from_name <$from_email>},
		cc=>$temp->{cc},
		bcc=>$temp->{bcc},
		subject=>$temp->{subject},
		headers=>"X_TID: ${SID}-${password}-I\r\nX-Mailer: Triton Survey System"
    );
	# Replace the passed in data with this new version.
	$self->{data} = $temp;
	return {
		data=>$temp,
		plain=>$plain,
		html=>$html,
		attach=>$attach,
		attach_name=>$attach_name,
		common_args=>\%common_sender_args,
		password=>$password,
	};
}

sub cvs_import {
	my $self = shift;
	my %args = @_;

	my $cvsroot = '';
	if (exists($args{cvsroot})){
		$cvsroot = delete $args{cvsroot};
	}else{
		if ($args{hostroot}){
			$cvsroot = delete ($args{hostroot})."/cvs";
		}else{
			confess "Must send 'cvsroot' or 'hostroot'";
		}
	}
	my $SID = delete $args{SID} || $self->SID;
	unless ($SID){
		$self->err("No SID supplied");
		return;
	}
	confess "Not using these args ".Dumper \%args if %args;
	my @files = map $self->filenames($_),qw(plain html header);
	my $files = {};
	foreach my $f (@files) {
		# put the files in the module with shortened names.
		my ( $name, $path, $suffix ) = fileparse( $f, qr{\..*$} );
		$files->{$f} = "$SID/$name$suffix";
		# If this is the first time, the files wont exist. so we cant save them
		delete $files->{$f} unless -e $f;
	}
	my $p   = new TPerl::Parser;
	my $err = $p->cvs_import(
		cvsroot => $cvsroot,
		module  => 'etemplate',
		files   => $files
	);
	if ($err){
		$self->err($err);
		return;
	}
	return $files;
}

sub send {
	my $self = shift;
	
	my $processed = $self->send_process(@_) || return undef;
	# print "Processed ".Dumper $processed;
	my $html = $processed->{html};
	my $plain = $processed->{plain};
	my $sender_args = $processed->{common_args};
	my $attach = $processed->{attach};
	my $attach_name = $processed->{attach_name};

	# Fix up the mail sender.
	$Mail::Sender::NO_X_MAILER = 1;

	# some vars for debugging/logging purposes.
	my $subject = $sender_args->{subject};
	my $from = $sender_args->{from};
	my $to = $sender_args->{to};
	my $lang = $self->lang;
	my $password = $processed->{password};
	
	my $temp = new File::Temp;
	$sender_args->{debug}=$temp;
	$sender_args->{debug_level}=2;

	my $sender = new Mail::Sender($sender_args);
	unless (ref($sender)){
		$self->err("Could not make a Mail::Sender:$Mail::Sender::Error");
		return undef;
	}

	### Mail Sender can't build a mime message with text and plain and an attachment.
	# If there is an attachment, we send html or text with the attachment.
	if ($attach){
		my ($part,$type);
		if ($html){
			$part = $html;
			$type = 'html';
		}elsif ($plain){
			$part = $plain;
			$type = 'plain';
		}else{
			$self->err("Can't send an attachment without a plain or html part");
			return undef;
		}
		unless ($sender->OpenMultipart ( {boundary=>'-triton-lib-2004--', })){
			$self->err("Could not open Multipart:$Mail::Sender::Error");
			return undef;
		}
		$self->debug_print("$type part: ".substr($part,0,80)."...");
		my ($name,$path,$suffix) = fileparse($attach,qr{\.*$});       # Pull out the original name
		$name = $attach_name if $attach_name;
		$self->debug_print("Attachment: $attach, target name=$name");
		$sender->Part( { ctype => "text/$type; charset=us-ascii",
				encoding => '7bit',
				disposition => 'NONE' });
		$sender->SendEnc($part);
		
		$sender->SendFile(
		  {encoding => 'Base64',
		  disposition => "attachment; filename = $name",
		  file => $attach
		  });
		my $ret = $sender->Close;
		unless (ref($ret)){
			$self->err("Could not close multipart:$Mail::Sender::Error");
			return undef;
		}
	}else{
		if (($plain eq '') and ($html eq '')){
			$self->err("No plain template, no html template an no attachment.  Nothing to do");
			return undef;
		}
		if ($self->noplain || $plain eq ''){
			# HTML only
            $self->debug_print("Sending HTML only message to $to, subject=$subject, password=$password, from=$from");
            my $ret = $sender->MailMsg({
                    ctype=>"text/html",
                    encoding=>"7bit",
                    msg=>$html,
                    });

            unless (ref($ret)){
                $self->err("Mail Sender says:$Mail::Sender::Error");
                return undef;
            }
		}elsif ($self->nohtml || $html eq ''){
			# PLAIN only
            $self->debug_print("Sending PLAIN text only message to $to, subject=$subject, password=$password, from=$from");
            my $ret = $sender->MailMsg({ msg=>$plain, });
            unless (ref($ret)){
                $self->err("Mail Sender says:$Mail::Sender::Error");
                return undef;
            }
		}else{
            $self->debug_print("Opening multipart message to $to, subject=$subject, password=$password, from=$from");
            unless ($sender->OpenMultipart ( {  boundary=>'-triton-lib-2004--', subtype => 'alternative' } ) ){
                $self->err("Could not open Multipart:$Mail::Sender::Error");
                return undef;
            }
            $self->debug_print("Plain part: ".substr($plain,0,80)."...");
            $sender->Part ( {ctype=>"text/plain; charset=us-ascii",
                            encoding => '7bit',
                            disposition => 'NONE' });
            $sender->SendEnc($plain);
            $self->debug_print("HTML part: ".substr($html,0,80)."...");
            $sender->Part( { ctype => "text/html; charset=us-ascii",
                    encoding => '7bit',
                    disposition => 'NONE' });
            $sender->SendEnc($html);
            my $ret = $sender->Close ;
            unless (ref($ret)){
                $self->err("Could not close multipart:$Mail::Sender::Error");
                return undef;
            }
		}
	}
	my $template_bit = "template '".$self->name."'" if $self->name;
    my $mail_status = "Sending $template_bit email about '$subject' to $to";
	$mail_status .= " in language $lang" if $lang;
	$mail_status .= " : ";

    if ($Mail::Sender::Error){
        $self->err("$Mail::Sender::Error:$mail_status");
        return undef;
    }else{
        $mail_status .= 'OK';
		$temp->close or die "Could not close temp file $temp";
		my $content = read_file($temp->filename);
		# print $content;
		my $ret = make_a TPerl::Sender::Result(parent=>$self,info=>$mail_status,conversation=>$content);
		return $ret;
    }

}
sub debug_print
    {
    my $self = shift;
    my $msg = shift;
    # print "In debug:".Dumper @_;
    if ($self->{debug})
        {
        if ($self->{err})
            {$self->{err}->I($msg);}
        else
            {print "$msg\n";}
        }
    }



package TPerl::Sender::Result;
use TPerl::Event;
use Carp qw(confess);

sub make_a {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;
	my %args = @_;
	$self->{$_} = $args{$_} foreach keys %args;
	return $self;
}

sub conversation { my $self = shift; return $self->{conversation}};
sub info { my $self = shift; return $self->{info}};
sub err { my $self = shift;return $self->{err_msg} = $_[0] if @_;return $self->{err_msg} }
sub parent { my $self = shift;return $self->{parent}}

sub sendmail_id {
	my $self = shift;
	my $conv = $self->conversation;
	my $id;
	unless ($conv){
		$self->err("Object Creation Error:Could not get a converation");
		return undef;
	}
	my @two_fifies = grep /^>> 250/,split /\n/,$conv;
	unless (@two_fifies) {
		$self->err("Could not get any 250's from $conv");
		return undef;
	}
	my $last_250 = $two_fifies[-1];
	if ($id = $last_250 =~ /ok:  Message (\w+) accepted/){
		# gonzo 220 mail-iinet.icp-qv1-irony2.iinet.net.au ESMTP
		return $id;
	}elsif ($id = $last_250 =~ /(\w+) Message accepted for delivery/){
		#phoenix Sendmail 8.12.8/8.12.8;
		return $id;
	}elsif ($id = $last_250 =~ /Ok: queued as (\w+)/){
		#Pel postfix 
		return $id
	}else{
		# have not worked out what to do yet.
		return $last_250;
	}
}

sub do_event {
	## putting events into event log should be easy.
	my $self = shift;
	my %args = @_;

	# pwd is one of the things we don't need to send email.  everything else we can
	# get from ourself or our parent.
	my $pwd = $args{password};
	my $dbh = $args{dbh};
	my $extra = $args{extra};

	confess "dbh is a required arg" unless $dbh;

	my $parent = $self->parent;
	my $SID = $parent->SID;

	my $msg = sprintf("sendmail:%s %s $extra",$self->sendmail_id,$self->info);
	my $ev = new TPerl::Event (dbh=>$dbh);
	if (my $err = $ev->I(code=>20,msg=>$msg,
			SID=>$SID,
			email=>$parent->{data}->{to},
			pwd=>$pwd)){
		$self->err($err);
		return undef;
	}else{
		return 1;
	}
}


1;
