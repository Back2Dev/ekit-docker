#!/usr/bin/perl
#$Id: aspjobedit.pl,v 1.7 2004-05-31 03:55:23 triton Exp $
use strict;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::TritonConfig;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::LookFeel;
use File::Basename;

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;
my %args = $q->Vars;
my $SID= $args{SID};
my $VID = $args{VID};
$args{UID} = $ENV{REMOTE_USER};

my $pinf = $ENV{PATH_INFO};
unless ($SID){
	print $q->noSID;
 	exit;
}

# print $q->header,$q->start_html,$q->env;
# exit;
unless ($pinf){
	my $qs = "?SID=$SID";
	print $q->frameset(top_qs=>$qs,left_qs=>$qs,right_qs=>$qs,left_width=>'50%');
	exit;
}

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);

print $q->header;
print $q->start_html (-title=>"Editing Job $SID",-style=>{src=>dirname($ENV{SCRIPT_NAME}).'/style.css'});
top() if $pinf eq '/top' ;
left() if $pinf eq '/left';
right() if $pinf eq '/right';
print "\n",$q->end_html;

sub top {
	print join "\n",
		$q->img({-align=>'bottom',-src=>'/pix/TOrange.jpg'}),
		"$SID Editing Page",
		'';
}
sub right { 
	# print $q->dumper( \%args );
	print join "\n",
		'<center>',
		$q->img({-align=>'bottom',-src=>'/pix/TOrange.jpg'}),
		'</center>';
	my $rsec = $sec->read_security($args{UID});
	$VID ||=$rsec->{vids}->{$SID};
	unless ($VID){
        my @vids  = keys %{$rsec->{vaccesses}};
        if (scalar @vids ==1 ){
            $VID = $vids[0];
        }else{
            foreach (@vids){
                $VID = $_ if uc($rsec->{vaccesses}->{$_}->{VDOMAIN}) eq uc($ENV{SERVER_NAME});
            }
        }
        unless ($VID){
            foreach (@vids){
                $VID = $_ if $rsec->{vaccesses}->{$_}->{J_CREATE};
            }
        }
	}
	if ($rsec->{jobs}->{$VID}->{$SID}){
		#the usual...
		my $ret = $sec->survey_text (%args,do_textarea=>0,poutrows=>25),;
# 		unless ($args{textfile}){
# 			print $q->err("Please use this form the Inviter:notextfile");
# 			exit;
# 		}
		# print $q->dumper(\%args);
		if (my $msg = $ret->{deny} || $ret->{err} ){
			print $q->err($msg);
		}else{
			print $ret->{parser};
		}
	}else{
		# print $q->env;
		# print "making job '$SID' on host '$VID'";
		my $cre = $sec->create($args{UID},%args,rsec=>$rsec,VID=>$VID,new=>2,action=>"$ENV{SCRIPT_NAME}/right");
		if ($cre->{success}){
			print $q->msg("Made job '$SID'");
			#do the usual here too...
			my $ret = $sec->survey_text (%args,do_textarea=>0,poutrows=>25),;
			if (my $msg = $ret->{deny} || $ret->{err} ){
				print $q->err($msg);
			}else{
				print $ret->{parser};
			}
		}elsif ($cre->{form}){
			print $cre->{form};
		}elsif ($cre->{deny}){
			print $q->err($cre->{deny});
		}else{
			print $q->err($q->dumper ($cre));
		}
	}
	# print '</center>';
}

sub left { 
	my $ret = $sec->survey_text (%args,target=>'right',action=>"$ENV{SCRIPT_NAME}/right");
	# print $q->dumper( $ret );
	if (my $msg = $ret->{deny} || $ret->{err} ){
		print $q->err($msg);
	}else{
		print $ret->{textform};
	}
}

