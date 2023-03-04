#!/usr/bin/perl 
#$Id: aspjobdelete.pl,v 1.4 2011-07-29 21:38:25 triton Exp $
use strict;
use TPerl::CGI;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::Dump;
use TPerl::TritonConfig;
use Data::Dumper;
use TPerl::LookFeel;

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);
my $q = new TPerl::CGI;
my %args = $q->Vars;
my $uid = $ENV{REMOTE_USER};
my $lf = new TPerl::LookFeel;

my $page = join "\n",
	$q->header,
	$q->start_html (-title=>"Deleting $args{SID}",-style=>{src=>'style.css'} ),'';

my $security = $sec->read_security($ENV{REMOTE_USER});
my $client = $security->{client};
my $delete = $args{delete};
my $SID = $args{SID};
my $VID = $security->{vids}->{$SID};
my $vacces = $security->{vaccesses}->{$VID};

if ($SID){
    if ($vacces){
        if ($vacces->{J_DELETE} && $vacces->{ACTIVE_CONTRACT}){
            if (my $job = $security->{jobs}->{$VID}->{$SID}){
                my $ez = new TPerl::DBEasy;
                if ($delete==2){
                    my $err = $asp->rm_job (SID=>$SID,VID=>$VID,leave_fs=>1);
                    if ($err){
                        print $page,$q->dumper ($err);
                    }else{
						print $q->dir_redirect;
						exit;
                    }
                }elsif ($delete ==3 ){
					print $q->dir_redirect;
					exit;
                }else{
                   	print join ("\n",$page,
						$lf->sbox("Really Delete $SID"),
                        $q->start_form (-action=>$ENV{SCRIPT_NAME},-method=>'POST'),
                        $q->popup_menu (-name=>'delete',-values=>[2,3],-labels=>{2=>'Yes',3=>'No'}),
                        # $q->hidden (-name=>'VID',-value=>$VID),
                        $q->hidden (-name=>'SID',-value=>$SID),
                        '<BR>',
                        $q->submit (-name=>'submit',-value=>"Delete $SID"),
						$q->end_form,
						$lf->ebox,
                    );
					# print $q->redirect ("$ENV{SCRIPT_NAME}?SID=$SID&delete=1");
					# exit;
					# print join "\n",$page,$q->err( "delete needs to be 1,2 or 3");
                }
            }else{
				print join "\n",$page,$q->err("no job '$SID' on host $vacces->{VDOMAIN}");
            }
        }else{
            print join "\n",$page,$q->err("You cannot delete surveys on $vacces->{VDOMAIN}");
        }
    }else{
        print join "\n",$page,$q->err("JOB $SID does not exist");
    }
}else{
    print $q->noSID;
}
