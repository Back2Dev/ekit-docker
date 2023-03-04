use strict;
use Time::localtime;
use TPerl::Survey;
use Data::Dumper;
use Mail::Sender;
use TPerl::Error;
use FindBin;
use File::Slurp;


my $err = new TPerl::Error;
my $tm = localtime;


		my @emails = ({
				job => 'MAP001',
				mail=>{	
					to=>'mikkel@market-research.com',
					from=>'ac@market-research.com',
					smtp=>'localhost',
					subject=>'Testing Mail::Sender'
				  },
			  },
			  );
	# print Dumper \@emails;
	foreach my $email (@emails){
		my $s = new TPerl::Survey($email->{job});
		my $m = new Mail::Sender ($email->{mail});
		$err->F("could not make Mail::Sender with ".Dumper $email->{mail}) unless ref $m;
		if ($email->{job}){
			# print 'Survey '.Dumper $s;
			# print 'mail '.Dumper $m;
			$err->I("Sending $email->{job} email to $email->{mail}->{to}");
			my $body = "Test email";
			$m->OpenMultipart;
			$m->Body;
			$m->Send ($body);
			$m->Close;
		}else{
			$err->E("No Job in this email record ".Dumper $email);
		}
	}
