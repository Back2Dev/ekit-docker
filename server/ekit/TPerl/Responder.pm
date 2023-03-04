#$Id: Responder.pm,v 1.19 2006-12-05 04:17:29 triton Exp $
package TPerl::Responder;
use strict;
use MIME::Parser;
use Data::Dumper;
use Email::Find;
# use File::lockf;
use Getopt::Long;
use Pod::Usage;
use File::Temp qw (tempdir);

# the ent that we get is either a MIME::Entity sub class or a Mail::Internet subclass
# from Mail::Audit
# You cannot call 'parts' on a mail::internet.

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {
		body_match_regexps=>[
			qr{https?://.*?/survey/start/(\w+)/(\w+)}i,
			qr{id=\w-(\w+)-(\w+)},
			qr{X_TID: (\w+)-(\w+)-(\w+)},
		],
	};
	bless $self,$class;
	return $self;
}
sub body_match {
    # does recurse

	my $self = shift;
    my %args = @_;

    my $ent = $args{ent};
    my $regexp = $args{regexp};
	my $debug = $args{debug};
	# $debug=1;
	
	print "Deb:body_match rex=$regexp\n" if $debug;
	
	if ($ent->get('MIME-Version')){
		if (my $body = $ent->bodyhandle){
			my $io = $body->open('r');
			while (my $line= $io->getline) {
				print "line:$line" if $debug;
				if (my (@matches) = $line=~/$regexp/i){
					return \@matches;
				}
			}
		}
		foreach my $part ($ent->parts){
			if (my $matches = $self->body_match (ent=>$part,regexp=>$regexp,debug=>$debug)){
				return $matches;
			}
		}
	}else{
		foreach my $line (@{$ent->body}){
		print "nomime-line:$line" if $debug;
			if (my (@matches) = $line=~/$regexp/i){
				return \@matches;
			}
		}
	}
    return undef;
}
sub header_match {
	my $self = shift;
    #does not recurse. by default

    my %args = @_;
    my $ent = $args{ent};
    my $regexps = $args{head_regexps};
	my $header = $args{header};
    my $no_top_level = $args{no_top_level_look};
    my $recurse = $args{recurse};
   
    unless ($no_top_level){
		my $val = $ent->head->get($header);
		# print "val=$val\n" if $recurse;
		foreach my $regexp ( @$regexps ){
			if (my (@matches) = $val =~ /$regexp/i ){
				return \@matches;
			}
		}
    }
    if ($recurse){
		if ($ent->get('MIME-Version')){
			foreach my $part ($ent->parts){
				if (my $matches = $self->header_match (recurse=>1,ent=>$part,head_regexps=>$regexps,header=>$header) ){
					return $matches
				}
			}
		}
    }
    return undef;
}

sub passwd {
	my $self = shift;
	my %args = @_;

	my $mail = $args{ent};
    #look in the headers...

	my ($SID,$pwd,$code);
	my $debug = 0;
	print "debugging passwd\n" if $debug;


	if (my $vers = $mail->get('MIME-Version')){
		print "Mime Version =$vers\n" if $debug;
		print "Parts ".$mail->parts ."\n" if $debug;
		my @parts = $mail->parts;
		if (@parts){
			foreach my $part (@parts){
				print "Found part ".$part->head->get('Content-Type') ."" if $debug;
				# next unless $part->head->get('Content-Type') =~ m#message/rfc822#;
				($SID,$pwd,$code) = $part->head->get('X-TID:') =~ /(\w+)-(\w+)-(\w+)/;
				return ($SID,$pwd,$code) if $pwd;
				foreach my $sub_part ($part->parts){
					print "Found a sub part\n" if $debug;
					($SID,$pwd,$code) = $sub_part->head->get('X-TID:') =~ /(\w+)-(\w+)-(\w+)/;
					return ($SID,$pwd,$code) if $pwd;
				}
			}
			# now do a body match in the parts to look for the survey/start/stuff.
			foreach my $part (@parts){
				print "doing Body match in part:\n" if $debug;
				my @match = $self->password_body_match($part);
				return @match if @match;
				foreach my $sp ($part->parts){
					print "Doing a body match in sub part\n" if $debug;
					my @match = $self->password_body_match($sp);
					return @match if @match;
				}
			}
		}else{
			print "No mime parts\n" if $debug;
			my $bod = $mail->as_string;
			($SID,$pwd,$code) = $bod =~  /X_TID:\s+(\w+)-(\w+)-(\w+)/m;
			return ($SID,$pwd,$code) if $pwd;
		}
	}
	my @match = $self->password_body_match($mail);
	return @match if @match;
    
	return undef;
}

sub password_body_match {
	my $self = shift;
	my $ent = shift;
    foreach my $reg (@{$self->{body_match_regexps}}){
        if (my $match = $self->body_match (ent=>$ent, regexp=>$reg,debug=>0)){
			return @$match;
		}
    }
	return ();

}
sub OOO {
	my $self = shift;
	my %args = @_;
	my $ent = $args{ent};

	my $subject = [ 
		'Out of Office',
		'out of the office',
		'Extended Absence Response',
		'Automatic reply from',
		'I am out working with',
		'is on vacation',
		'Thank You for your email',
		'Automated Reply',
		'Automatic response to your mail',
		'automated response',
		'Away from office',
		'Abwesenheitsnotiz',
		'Auto Reply Message',
		'auto-response',
		'Auto Response',
		'Auto-generated email response',
		'respond shortly',
		'away from my mail',
		'mail address change',
		'I will reply ASAP',
		'Annual leave',
	];
	my $from = [ 
		'via the vacation program',
		'auto reply',
		'^catchrest',
		'away from e-mail',
				];
	my $body = [
		'on Annual Leave',
		'out of the office ',
		'away from my desk',
		'return to the office',
		'I will be returning your message',
		'This is an automated response',
		'This is an automatic response',
		'currently on leave',
		'automated response',
		'away from the office',
		'returning to the office',
		'leave-of-absence',
		'autoresponder',
		'on vacation',
		'received your e-mail',
		'e-mail has been received',
		'Thank you for contacting us',
		'not available right now',
		'have received your e-mail',
		'(you|reply|email|respond) (as soon as possible|ASAP)',
		'presently off-line',
		'reply will follow',
		'responding back to you shortly',
		'Thank you for your inquiry',
		'contacting\s*you shortly',
		'very important to me',
		'I am away on business',
		'back to you with an answer within the next 24 hours',
		'endeavour to respond to requests for',
		'will be away till',
		'I am away from my office',
				];
                          
	return 1 if $self->header_match(ent=>$ent,head_regexps=>$subject,header=>'Subject');
	return 1 if $self->header_match(ent=>$ent,head_regexps=>$from,header=>'From');
	foreach (@$body){
		return 1 if $self->body_match (ent=>$ent,regexp=>$_);
	}
	return undef;
}

sub bounce {
	my $self = shift;
	my %args = @_;
	my $ent = $args{ent};

	my $warn_subject = [
		'^Warning:'
	];
	my $subject = [ 
		'Returned Mail' ,
		'Unrouteable Mail',
		'Undelivered Mail' ,
		'Mail delivery fail',
		'Undeliverable',
		'Mail System Error',
		'DELIVERY FAILURE:',
		'AUTOMATED RESPONSE',
		'Delivery Status Notification',
		'Message not deliverable',
		'unable to deliver',
		'This is a return mail',
		];
	my $from = [ 
		'Mail Delivery Subsystem', 
		 'Mail Delivery Service', 
		 'MAILER-DAEMON',
		 'System Administrator',
		 'Mail Delivery Service',
		 'Postmaster',
		 'Auto-reply',
		 'NONDELIVERY',
		 'Administrator',
		 '^nobody',
		 'notify@eGroups',
		 'FETCHMAIL-DAEMON',
		];
	
	my $body=[
	'Please check the email address',
	q{I'm afraid I wasn't able to deliver your message to the following},
	'is no longer available at this address',
	'Your email was incorrectly addressed',
	'has left the organisation',
	];
	
	my ($warn,$bounce,$msg);

	if ($self->header_match(ent=>$ent,head_regexps=>$warn_subject,header=>'Subject')){
		$warn=1;
	}else{
		if ($self->header_match(ent=>$ent,head_regexps=>$subject,header=>'Subject') ||
			$self->header_match(ent=>$ent,head_regexps=>$from,header=>'From') ){

			my $match = $self->body_match(debug=>0,ent=>$ent,regexp=>qr{\(reason:(.*?)\)}i);
			# print Dumper $match;
			$match->[0] =~ s/<//g;
			$match->[0] =~ s/>//g;
			$msg=$match->[0];
			$bounce=1;
		}
	}
	unless ($bounce ||$warn){
		foreach (@$body){
			$bounce= 1 if $self->body_match (ent=>$ent,regexp=>$_);
		}
	}
	if ($bounce || $warn){
		return {bounce=>$bounce,warn=>$warn,msg=>$msg};
	}
	return undef;
}
sub unsubscribe {
	my $self = shift;
	my %args = @_;
	my $ent = $args{ent};
	my $subject = [
		'unsub',
		'unsubscribe',
		'remove',
	];
	my $body = [
	'^\s*unsubscribe\s*$',
	'stop sending me',
	'DO NOT EMAIL ME',
	'Do not send',
	'take me off your email list',
	'take me off your mailing list',
	];
	return 1 if $self->header_match(ent=>$ent,head_regexps=>$subject,header=>'Subject');
	foreach (@$body){
		return 1 if $self->body_match (ent=>$ent,regexp=>$_);
	}
	return undef;
}

1;
