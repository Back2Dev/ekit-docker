# Copyright Triton Technology 2001
# $Id: Email.pm,v 1.12 2005-10-11 06:13:33 triton Exp $#
use strict;
package TPerl::Email;
use Carp;
use Data::Dumper;
use Data::Dump qw(dump);
use TPerl::TritonConfig;
use FileHandle;
use File::Basename;
use Mail::Sender;
use File::Slurp;
use Config::IniFiles;
use TPerl::Hash;
use TPerl::Template;

=head1 SYNOPSIS 

Sends email messages

 my $em = new TPerl::Email(debug=>1);

 $em->send_email(	
			SID=>'EMBA',								# Survey ID (mandatory)
			itype=>'invite',							# Invitation type (mandatory)
														# Looks for $itype.txt or $itype-plain for TEXT part
														# Looks for $itype.htm or $itype-html for HTML part
														# If it starts with <HTML> it is taken as a literal string
			fmt=>'', 									# =0 or missing:HTML+Text, 
														# =1:HTML Only, 
														# =2:Text Only
														# =3:HTML + attachment
			data=>\%datahash,							# Data for merge fields
			attach=>'/path/to/attachment',				# Source document from your file system
			attach_name=>'filename.doc',				# Filename for document in email
			);
The following parameters need to appear in the data hash, rather than supplied as parameters to the send_email sub. I think they can also be picked up from
The .hdr file (if it exists!!). 
			uid=>'',									# UID
			pwd=>'1234',								# Password
			to=>'mikkel@market-research.com',			# Addressee (mandatory)
			cc=>'',										# Carbon copy to (optional)
			bcc=>'',									# Blind copy to
			from_email=>'mikkel@market-research.com',	# From address (mandatory)
			from_name=>"Michael King", 					# From name (mandatory)
			subject=>'Testing email send', 				# Message subject (mandatory)

=cut
 
sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};#name => 'TPerl::Email'};
	bless $self,$class;
	$self->_process_args(@_);
	return $self;
}

sub err {
    # returns the last error message for this object
    my $self = shift;
    return $self->{err} = $_[0] if @_;
    return $self->{err};
}

sub _process_args {
	# Seeing we can accept many args in many places, lets do it all at once.
	# print "in _process_args:".Dumper \@_;
	my $self = shift;
	my %args = @_;
	$self->{debug} = $args{debug} if exists ($args{debug});
	$self->{err} = $args{err} if exists ($args{err});
	$self->{itype} = $args{itype} if exists ($args{itype});
	$self->{fmt} = $args{fmt} if exists ($args{fmt});
	$self->{SID} = $args{SID} if exists ($args{SID});
	$self->{nosubchk} = $args{nosubchk} if exists ($args{nosubchk});
	$self->{smtp_host} = $args{smtp_host} if exists ($args{smtp_host});
	$self->{mail_sender_debug} = $args{mail_sender_debug} if exists ($args{mail_sender_debug});
	$self->{mail_sender_debug_level} = $args{mail_sender_debug_level} if exists ($args{mail_sender_debug_level});
	return %args;
}

#### These values come from args

sub itype { return $_[0]->{itype}}
sub fmt { return $_[0]->{fmt}}
sub SID { return $_[0]->{SID}}
sub nosubchk { return $_[0]->{nosubchk}}

## These bits are holders for stuff.
sub pretty_itype { my $self = shift; return $self->{pretty_itype} = @_[0] if @_; return $_[0]->{pretty_itype}}
sub html { my $self = shift; return $self->{html} = @_[0] if @_; return $self->{html}}
sub plain { my $self = shift; return $self->{plain} = @_[0] if @_; return $self->{plain}}


sub cfg_dir {
	my $self = shift;
	return $self->{cfg_dir} if $self->{cfg_dir};
	my $SID = $self->SID() or ($self->err("SID not set") && return undef);
	my $troot = getConfig('TritonRoot') || ($self->err("Could not get TritonRoot from getConfig") && return undef);
	$self->{cfg_dir} = join '/',$troot,$SID,'config';
	return $self->{cfg_dir};
}

sub _fmt4text { return ('','0','2'); }
sub _fmt4html { return ('','1','0','3'); }
sub is_custom_html {
	# if you pass an itype beginning with <HTML>, then you are not going to read any <HTML>
	my $self = shift;
	my $itype = $self->itype() or ($self->err("itype not set") && return undef);
	return $self->{is_custom_html} if exists ($self->{is_custom_html});
	$self->{is_custom_html} = $itype =~ /\s*<HTML>/i;
}

sub header_load {
	my $self = shift;
	my $itype = $self->itype() or ($self->err("itype not set") && return undef);
	return  $self->{loaded_headers} if exists $self->{loaded_headers};
		
	if ($self->is_custom_html()){
		return {};
	}
	my $data = {};
	tie %$data, 'TPerl::Hash';
	my $fn = join '/',$self->cfg_dir,"$itype.hdr";
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

		$self->err("Warning: Header file does not exist '$fn'");		
		# This err messgae will never be seen if you don't check it, 
		# and you're unlikely to check it if you return true....

		$self->debug("Warning: Header file does not exist '$fn'");		
		# It is possible to survive without this header file as long as the
		# relevant parameters are passed in the data hash, So let's see if we
		# can be a bit more robust this way: 
		
		# return undef;
	}
	$self->{loaded_headers} = $data;
}


sub template_load {
	# Loads the templates/custom html into the 
	# 	fmt=>'', 									# =0 or missing:HTML+Text, 
													# =1:HTML Only, 
													# =2:Text Only
													# =3:HTML + attachment
	# itype can be some custom html...
		
	my $self = shift;
	my $cfg_dir = $self->cfg_dir or return undef;
	my $itype = $self->itype() or ($self->err("itype not set") && return undef);
	my $fmt = $self->fmt() ;  # fmt is not compulsory.

	# This was in email_send...
	# pretty_itype for debug messages.
	$self->debug("Starting template_load with fmt=$fmt itype=$itype");
	
	if ($self->is_custom_html()){
		$fmt = $self->{fmt} = 1;		# Force HTML only if HTML supplied in itype
		$self->pretty_itype('CUSTOM');
		$self->debug("Found custom html");
		$self->html($itype);
	}else{
		# now we are reading from config files.
		# $self->debug("Looking for template file - not custom html");
		$self->pretty_itype(lc($itype));
		my @tfmts = $self->_fmt4text();
		if (grep $fmt eq $_,@tfmts){
			# $self->debug("Looking for a text template");
			my $choices = $self->_poss_text_template_files();
			my $found = 0;
			foreach my $ch (@$choices){
				my $fn = "$cfg_dir/$ch";
				if (-e $fn){
					if (my $content = read_file($fn)){
						$self->plain($content);
						$found++;
						$self->debug("Loaded plain template '$fn'");
					}else{
						$self->err("Could not load plain template '$fn'");
						return undef;
					}
					last;
				}
			}
			unless ($found){
				$self->err("Could not find any text template '@$choices' in '$cfg_dir'");
				return undef;
			}
		}
		my @hfmts = $self->_fmt4html();
		if (grep $fmt eq $_,@hfmts){
			$self->debug("Looking for a html template");
			## Mike does not want to look for "$itype.htm". # That's an odd thing to say, because I think it should
			my $choices = $self->_poss_html_template_files();
			my $found = 0;
			foreach my $ch (@$choices){
				my $fn = "$cfg_dir/$ch";
				if (-e $fn){
					if (my $content = read_file($fn)){
						$self->html($content);
						$found++;
						$self->debug("Loaded html template '$fn'");
					}else{
						$self->err("Could not load html template '$fn'");
						return undef;
					}
					last;
				}
			}
			unless ($found){
				$self->err("Could not find any html template '@$choices' in '$cfg_dir'");
				return undef;
			}
		}
	}
	return 1;
}

sub _poss_html_template_files {
	my $self = shift;
	my $itype = $self->itype;
	return undef unless $itype;
	return ["$itype.html","$itype.htm","$itype-html1"];			# Added .htm into the search list as a compatibility step until we straighten this out.
}

sub _poss_text_template_files {
	my $self = shift;
	my $itype = $self->itype;
	return undef unless $itype;
	return  ["$itype.txt","$itype-plain1"];
}

sub debug
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

sub my_die
	{
	die @_;
	}


sub send_email ()
	{
	my $self = shift;
	my %args = $self->_process_args(@_);

	my $SID = $self->SID;
	$self->debug("send_email(".join(",",@_));
	my $fmt = $self->fmt();
	my $itype = $self->itype();

	# Some checks here. Some after the headers are loaded, some just before sending email.
	# These should not just die...
# 	my_die("FATAL ERROR: SID not supplied to send_email() routine\n") if ($SID eq '');
# 	my_die("FATAL ERROR: itype (invite type) not supplied to send_email() routine\n") if ($itype eq '');
# 	my_die("FATAL ERROR: To address not supplied to send_email() routine\n") if ($args{to} eq '');
# 	my_die("FATAL ERROR: From EMAIL not supplied to send_email() routine\n") if ($args{from_email} eq '');
# 	my_die("FATAL ERROR: From NAME not supplied to send_email() routine\n") if ($args{from_name} eq '');
# 	my_die("FATAL ERROR: SUBJECT not supplied to send_email() routine\n") if ($args{subject} eq '');
# 	my_die("FATAL ERROR: Cannot find attached file: $args{attach}\n") if ((!-f $args{attach}) && ($args{attach} ne ''));
	
	unless ($SID){ $self->err("No SID supplied to send_email()");return undef; }
	unless ($itype) {$self->err("itype (invite type) not supplied to send_email()");return undef;}

	# Check 
	if ( ($args{attach} ne '') && (!-f $args{attach}) ) {$self->err("Cannot find attached file: $args{attach}");return undef;}

	# The headers from the param file.
	# this is already ci
	my $hdr = $self->header_load() or return undef;
	
	my $data = $args{data};
	unless ($data){
		$self->err("No data hash supplied");
		return undef;
	}
	
	# $temp is a deep copy of the data into a case insensitive hash, so you
	# don't mangle what was sent in.  and so everthing is case insensitive.
	# Mike thinks that looking for headers should be simple.  The defaults come from the
	# hdr file, possible overwritten by the data hash
	my $temp = {};
	tie %$temp,'TPerl::Hash';

	# so the hdr file goes in.
	$temp->{$_} = $hdr->{$_} foreach keys (%$hdr);

	if (my $data = $args{data}){
		$temp->{$_} = $data->{$_} foreach keys %$data;
	}

	# now load the templates. and do the processing.
	$self->{fmt} = $fmt = 3 if ($args{attach} ne '');		# TEMPORARY ???: Override type if there's an attachment - Need to fix this later :-)

	return undef unless $self->template_load();
	my $hbuf = $self->html;
	my $tbuf = $self->plain;
	# $self->debug("hbuf=$hbuf");
	if ($hbuf){
		my $tt = new TPerl::Template (template=>$hbuf);
		unless ($tt->check_subs($temp)){
			my $msg = "HTML ".$tt->err;
			if ($self->nosubchk()){
				$self->debug($msg);
			}else{
				$self->err($msg);
				return undef;
			}
		}
		$hbuf = $tt->process($temp);
	}
	if ($tbuf){
		my $tt = new TPerl::Template (template=>$tbuf);
		unless ($tt->check_subs($temp)){
			my $msg = "PLAIN ".$tt->err;
			if ($self->nosubchk()){
				$self->debug($msg);
			}else{
				$self->err($msg);
				return undef;
			}
		}
		$tbuf = $tt->process($temp);
	}

	my $smtp_host = $self->{smtp_host} || getConfig('smtp_host') or  my_die("FATAL ERRROR: Could not get smtp_host");
	my $cfg_dir = $self->cfg_dir;

	# we might as well do substitions in all of the data hash now.
	# rather than just subject, from_email from_name etc
	foreach my $k (keys %$temp){
		my $orig = $temp->{$k};
		my $new = $orig;
		if ($temp->{$k}){
			my $tt = new TPerl::Template (template=>$temp->{$k});
			$new = $tt->process($temp);
			$self->debug("for $k changed '$orig' to '$new'") unless $orig eq $new;
		}
		$temp->{$k} = $new;
	}
	
	my $email = $temp->{to};
	my $password = $temp->{password};
	my $from_email = $temp->{from_email};
	my $from_name = $temp->{from_name};
	my $subject = $temp->{subject};

	# After substitution is another chance to return undef.....
	unless ($from_email) {$self->err("from_email not supplied to send_email()");return undef;}
	unless ($from_name) {$self->err("from_name not supplied to send_email()");return undef;}
	unless ($email) {$self->err("TO address not supplied to send_email()");return undef;}
	unless ($subject) {$self->err("No SUBJECT supplied to send_email()");return undef;}


	#These bits are always the same.
	my %common_sender_args = (
								smtp=>$smtp_host,
								to=>$email,
								from=>qq{$from_name <$from_email>},
								cc=>$temp->{cc},
								bcc=>$temp->{bcc},
								subject=>$temp->{subject},
								headers=>"X_TID: ${SID}-${password}-I\r\nX-Mailer: Triton Survey System");

# 	if ($self->{debug} || $self->{mail_sender_debug}){
# 		$common_sender_args{debug}=$self->{mail_sender_debug} || '/tmp/mail_sender_debug.log';
# 		$common_sender_args{mail_sender_debug_level} $self->{mail_sender_debug_level} if exists $self->{mail_sender_debug_level};
# 	}

	if ($fmt == 1)	# HTML only
		{
			$self->debug("Sending HTML only message to $email, subject=$subject, password=$args{password}, from=$from_name <$from_email>");
			my $ret = (new Mail::Sender)->MailMsg({
					%common_sender_args,
					ctype=>"text/html",
					encoding=>"7bit",
					msg=>$hbuf,
					});

			unless (ref($ret)){
				$self->err("Mail Sender says:$Mail::Sender::Error");
				return undef;
			}
		}
	elsif ($fmt == 2)	# Text only
		{
			$self->debug("Sending PLAIN text only message to $email, subject=$subject, password=$args{password}, from=$from_name <$from_email>");
			my $ret = (new Mail::Sender)->MailMsg({
										%common_sender_args,
										msg=>$tbuf,
										}) ;
			unless (ref($ret)){
				$self->err("Mail Sender says:$Mail::Sender::Error");
				return undef;
			}

		}
	elsif  ($fmt == 3)	# HTML AND ATTACHMENT
		{
			my $sender = new Mail::Sender	 (	{ %common_sender_args });
			unless (ref ($sender)){
				$self->err("Could not make a Mail::Sender:$Mail::Sender::Error");
				return undef;
			}
			$Mail::Sender::NO_X_MAILER = 1;
			$self->debug("Opening multipart message to $email, subject=$subject, password=$args{password}, from=$from_name <$from_email>");
			unless ($sender->OpenMultipart ( {		boundary=>'-triton-lib-2004--', } ) ){
				$self->err("Could not open Multipart:$Mail::Sender::Error");
				return undef;
			}
	#		print "Sending HTML...\n";
			$self->debug("HTML part: ".substr($hbuf,0,80)."...");
			$sender->Part( { ctype => "text/html; charset=us-ascii",
					encoding => '7bit',
					disposition => 'NONE' });
			$sender->SendEnc($hbuf);
			if ($args{attach})
				{
				my ($name,$path,$suffix) = fileparse($args{attach},qr{\.*$});		# Pull out the original name
				my $name = "$name$suffix";
				$name = $args{attach_name} if ($args{attach_name});					# Use the [optional] supplied target file name
				$self->debug("Attachment: $args{attach}, target name=$name");
				$sender->SendFile(
						  {encoding => 'Base64',
						  disposition => "attachment; filename = $name",
						  file => $args{attach}
						  });
				}
			my $ret = $sender->Close;
			unless (ref($ret)){
				$self->err("Could not close multipart:$Mail::Sender::Error");
				return undef;
			}
		}
	else 	# 2-part message, HTML+Text
		{
			my $sender = new Mail::Sender	 (	{%common_sender_args});
			unless (ref ($sender)){
				$self->err("Could not make a Mail::Sender:$Mail::Sender::Error");
				return undef;
			}
			$Mail::Sender::NO_X_MAILER = 1;
			$self->debug("Opening multipart message to $email, subject=$subject, password=$args{password}, from=$from_name <$from_email>");
			unless ($sender->OpenMultipart ( {	boundary=>'-triton-lib-2004--', subtype => 'alternative' } ) ){
				$self->err("Could not open Multipart:$Mail::Sender::Error");
				return undef;
			}

			$self->debug("Plain part: ".substr($tbuf,0,80)."...");
			$sender->Part ( {ctype=>"text/plain; charset=us-ascii",
							encoding => '7bit',
							disposition => 'NONE' });
			$sender->SendEnc($tbuf);
			$self->debug("HTML part: ".substr($hbuf,0,80)."...");
			$sender->Part( { ctype => "text/html; charset=us-ascii",
					encoding => '7bit',
					disposition => 'NONE' });
			$sender->SendEnc($hbuf);
			my $ret = $sender->Close ;
			unless (ref($ret)){
				$self->err("Could not close multipart:$Mail::Sender::Error");
				return undef;
			}
		}

 	my $mail_status = sprintf "Sending %s email about '$subject' to $email: ",$self->pretty_itype;

	if ($Mail::Sender::Error){
		$self->err("$Mail::Sender::Error:$mail_status");
		return undef;
	}else{
		$mail_status .= 'OK';
	}
	# $self->debug($mail_status);
	# Return mail status
	$mail_status;
}

sub best_fmt {
	# See if there is an html, plain or both.  returns the fmt value
	# 	fmt=>'', 									# =0 or missing:HTML+Text, 
													# =1:HTML Only, 
													# =2:Text Only
													# =3:HTML + attachment
	### In this case a return of undef means that nuthing was found.
	my $self = shift;
	$self->_process_args(@_);
	my $itype = $self->itype();
	unless ($itype){
		$self->err("itype not set");
		return undef;
	}
	if ($self->is_custom_html()){
		return 1; # Force HTML only if HTML supplied in itype
	}
	my $cfg_dir = $self->cfg_dir;
	my ($h,$t);
	
	my $hchoices = $self->_poss_html_template_files;
	foreach my $ch (@$hchoices){
		my $fn = "$cfg_dir/$ch";
		$h++ if -e $fn;
	}
	my $tchoices = $self->_poss_text_template_files;
	foreach my $ch (@$tchoices){
		my $fn = "$cfg_dir/$ch";
		$t++ if -e $fn;
	}
	if ($t && $h){	
		return 0;
	}elsif ($t){
		return 2;
	}elsif ($h){
		return 1;
	}else{
		$self->err("none of @$hchoices @$tchoices exist in $cfg_dir");
		return undef;
	}
}

1;
