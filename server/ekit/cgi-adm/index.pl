#!/usr/bin/perl 
#$Id: index.pl,v 1.10 2011-07-29 21:39:25 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::TritonConfig;
use Data::Dumper;

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);
my $q = new TPerl::CGI;
my $uid = $ENV{REMOTE_USER} || $q->mydie('Not doing anything without a .htaccess files ($ENV{REMOTE_USER})');

my $security = $sec->read_security ($ENV{REMOTE_USER});

my $creates = {}; # a hash that contins the form if they are allowed to create.
if (%{$security->{contracts}}){
    foreach my $vid (keys %{$security->{vaccesses}}){
        my $vh = $security->{vaccesses}->{$vid};
        my $create = 'No';
        $create = 'Yes' if $vh->{J_CREATE};
        if ($vh->{J_CREATE} && $vh->{ACTIVE_CONTRACT}){
            $create = join ("\n",
                $q->startform (-action=>"aspjobcreate.pl",-method=>'POST'),
                $q->hidden(-name=>'VID',-value=>$vh->{VID}),
                $q->hidden(-name=>'new',-value=>1),
                $q->submit(-name=>'submit',-value=>'Create new job'),
                $q->endform,
            );
            $creates->{$vid}->{button} = $create;
        }
    }
}
my $jscript = q{
function confirm_delete(VID,SID)
    {
    if (confirm('Delete survey '+SID+' ?\n (This cannot be undone)'))
        {
        document.location.href = 'aspjobdelete.pl?VID='+VID+'&SID='+SID+'&delete=2';
        }
    }
function confirm_edit(VID,SID)
    {
    document.location.href = 'aspjobedit.pl?VID='+VID+'&SID='+SID;
    }
};
my $client = $security->{client};

my @joblist = ();
push @joblist,values %{$security->{jobs}->{$_}} foreach keys %{$security->{jobs}};
@joblist = sort {$a->{SID} cmp $b->{SID}} @joblist;

my %vhlist = ();
$vhlist{$_->{VID}}++ foreach @joblist;
$vhlist{$_}++ foreach keys %$creates;

# die Dumper \%vhlist;
{
	my %newvh= ();
	foreach my $vh (keys %{$security->{vaccesses}}){
		$newvh{$vh}++ if uc($security->{vaccesses}->{$vh}->{VDOMAIN}) eq uc($ENV{SERVER_NAME}); 
		# $newvh{$vh} = uc($security->{vaccesses}->{$vh}->{VDOMAIN});
	}
	%vhlist = %newvh if (%newvh);
}


print join "\n",
	$q->header,
	$q->start_html (-title=>'ASP',-style=>{src=>'style.css'},-script=>$jscript),
	"<h2>Current Jobs accessible by $client->{FIRSTNAME} $client->{LASTNAME} of $client->{CLNAME}",
	q{<TABLE BORDER="0" cellpadding="5" cellspacing="1" class="mytable">
		<TR class="heading">
			<TH> SID </TH>
			<TH> Email </TH>
			<TH> Edit </TH>
			<TH> Del</TH>
		</TR>};
			# <TH> Stats </TH>
# crudeness to reduce the vhlist to only the current server,A


foreach my $vh ( keys %vhlist){
	my $dom_span = 10;
	my $button = qq{<TD colspan="3">$creates->{$vh}->{button}</TD>} if $creates->{$vh};
	$dom_span = 1 if $creates->{$vh};
	print qq{<TR class="heading" ><TD colspan="$dom_span">$security->{vaccesses}->{$vh}->{VDOMAIN} $button</TD></TR>\n};
	foreach my $j (sort {$a->{SID} cmp $b->{SID} } @joblist){
		next if ($j->{VID} ne $vh);
		my $use = 'No';
		$use = 'Edit' if $j->{J_USE};
		$use = join (" ",
				$q->startform (-action=>"edit.html",-method=>'POST'),
				#$q->hidden(-name=>'VID',-value=>$j->{VID}),
				$q->hidden(-name=>'SID',-value=>$j->{SID}),
				$q->submit(-name=>'submit',-value=>'Edit'),
				$q->endform,
			) if $j->{J_USE} && $j->{ACTIVE_CONTRACT};
		#$use = qq{<IMG src="http://www.triton-tech.com/pix/edit.gif" alt="Edit survey"  onclick="confirm_edit('$j->{VID}','$j->{SID}')">} if $j->{J_USE} && $j->{ACTIVE_CONTRACT};
		$use = qq{<a href="aspjobedit.pl?SID=$j->{SID}&VID=$j->{VID}" target="_blank"><IMG border="0" src="http://www.triton-tech.com/pix/edit.gif" alt="Edit survey"></a>} if $j->{J_USE} && $j->{ACTIVE_CONTRACT};

		my $delete = 'No';
		$delete = 'Delete' if $j->{J_DELETE};
		$delete = join ("\n",
				$q->startform (-action=>"delete.html",-method=>'POST'),
				#$q->hidden(-name=>'VID',-value=>$j->{VID}),
				$q->hidden(-name=>'SID',-value=>$j->{SID}),
				$q->hidden(-name=>'delete',-value=>1),
				$q->submit(-name=>'submit',-value=>'Delete'),
				$q->endform,
			) if $j->{J_DELETE} && $j->{ACTIVE_CONTRACT};
		$delete = qq{<IMG src="http://www.triton-tech.com/pix/clear.gif" alt="Delete survey" onclick="confirm_delete('$j->{VID}','$j->{SID}')">} if $j->{J_DELETE} && $j->{ACTIVE_CONTRACT};
		my $link = qq{ <A HREF="http://$j->{VDOMAIN}/$j->{SID}/main.htm" target="viewer">$j->{SID}</A> };
		my $stats = qq{<A href="stats/jobstats.pl?SID=$j->{SID}" target="_blank">Stats</A>};

		print qq{
			<TR class="options">
				<TD>$link</TD>
				<TD>$j->{EMAIL}</TD>
				<TD>$use</TD>
				<TD>$delete</TD>
			</TR>
		};
				#<TD>$stats</TD>
	}
}

print '</table>';
# print $q->dumper($security);
print $q->end_html;

