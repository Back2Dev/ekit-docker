#Copyright Triton Technology 2002
#$Id: aspdns.pl,v 1.1 2003-06-16 05:41:08 triton Exp $
#This used to be misnamed as dyndns.pl
use strict;
use LWP::UserAgent;
use Data::Dumper;
use File::Slurp;
use TPerl::Error;
use HTTP::Cookies;
use HTML::Parser;
use TPerl::Error;
use File::Temp qw (mktemp);
use DNS::ZoneParse;
use TPerl::MyDB;
use TPerl::Dump;
use Getopt::Long;

my $pause = 1;
my $help = 0;
GetOptions (
	'pause!'=>\$pause,
	'help!'=>\$help,
) or usage ("Bad Options");

usage () if $help;
sub usage {
	print :join "\n",
	@_,
	"usage: perl $0 [options]",
	"\t-h help",
	"\t-[no]pause stop and ask for confirmation",
	;
	exit;
}


my $err = new TPerl::Error;
my $ua = new  LWP::UserAgent;
my $p = HTML::Parser->new( api_version => 3,
                        start_h => [\&start, "tagname, attr"],
						text_h	=> [\&text, "dtext"],
                        end_h   => [\&end,   "tagname"],
                        marked_sections => 1,
                      );  
$ua->cookie_jar(new HTTP::Cookies);

my $conf = getro TPerl::Dump('/etc/dyndns.conf') or 
	$err->F("Could not read /etc/dyndns.conf\n$@");



my $base = $conf->{base_url};
my $zone = $conf->{zones}->[0];
my $ip_numbers = qx {/sbin/ifconfig $conf->{NICs}->[0]};
$ip_numbers =~ s/^.*inet addr:(.*?)\s.*$/$1/s;

my $login_url = $base.'login_secure.asp';
my $get_zone_url = $base."dns_services_modify_raw.asp?dnsname=$zone";
my $update_zone_url = $base."dns_services_modify_complete_raw.asp";

$err->F("Could not find a numeric IP address from /sbin/ifconfig $conf->{NICs}->[0]") unless 
	$ip_numbers =~ /^\d+\.\d+\.\d+\.\d+$/;

$err->I("device $conf->{NICs}->[0] is $ip_numbers");

my @inputs = ();
my $intextarea = 0;
my @textareas = ();


if (1){
	$err->I("visiting login page to get session cookie");
	$err->F("Failed $login_url") unless save_content ($ua->get($login_url),'dns1.html');
	$err->I("Logging in at $login_url");
	$err->F("Failed $login_url") unless 
		save_content ($ua->post($login_url,{name=>'mikkel',password=>'Nautilus'}),'dns2.html');
	$err->I("Getting html for $zone");
	$err->F("Failed $get_zone_url") unless 
		my $zone_html = save_content ($ua->get($get_zone_url),'dns3.html');
	# print "$zone_html\n";
	$p->parse($zone_html);
}else{
	$p->parse_file('dns3.html');
}
# print Dumper \@inputs;
# print Dumper \@textareas;

my $expected_inputs = 11;
$err->F("there should be 1 textarea in  $get_zone_url") unless scalar (@textareas) == 1;
$err->F("there should be $expected_inputs inputs in $get_zone_url") unless scalar (@inputs) == $expected_inputs;

$err->I("Getting SID's and vhosts from ASP database");
my $dbh = dbh TPerl::MyDB (db=>'ib');
my $sql = 'select * from vhost,job where job.vid = vhost.vid and vhost.vdomain like ?';
my $SIDS = $dbh->selectall_hashref ($sql,'SID',{},"%$zone%") or $err->F("db trouble".Dumper {sql=>$sql,err=>$dbh->errstr});
my $VHOSTS = $dbh->selectall_arrayref ('select * from vhost',{Slice=>{}}) or
	$err->F("db trouble".Dumper {sql=>'select * from vhost',err=>$dbh->errstr});

## build up a hash of the hosts that need to exist.
my %hosts2add = ();
foreach my $SID (keys %$SIDS){
	my $sid_host = lc "$SID.$SIDS->{$SID}->{VDOMAIN}";
	$sid_host =~ s/(.*?):\d+/$1/;
	$hosts2add{$sid_host}++;
}
foreach my $vhost (@$VHOSTS){
	my $tvhost = $vhost->{VDOMAIN};
	$tvhost =~ s/(.*?):\d+/$1/;
	$hosts2add{$tvhost}++;
}
# print Dumper \%hosts2add;


my $zonetext = $textareas[0];
my $tfile = mktemp ("zonefileXXXXXX");
write_file $tfile,$zonetext;
$err->I("Parsing zonefile from temp file '$tfile'");
# $err->I($zonetext);
my $dns = new DNS::ZoneParse ($tfile);
unlink $tfile;

# $as is a reference to a list of the a recoreds that already exist.
my $as = $dns->a;

my $needs_update = undef;

### here we delete members of the host2add hash that already exist.
foreach (my $a=0;$a<=$#$as;$a++){
	#print "$a $as->[$a]->{host} $as->[$a]->{name}\n";
	my $host = "$as->[$a]->{name}.$zone";
	# print "$a $host\n";
	delete $hosts2add{lc($host)};
	# print Dumper $as->[$a];
}

foreach my $host (keys %hosts2add){
	next unless my ($name) = $host =~ /^(.*?)\.$zone/;
	if ($name =~ /_/){
		$err->E("hostnames with '_' are ileagal. skipping $name");
		next;
	}
	$err->I("Want to add $name $ip_numbers");
	push @$as,{ttl=>43200,class=>'IN',name=>$name,host=>$ip_numbers};
	$needs_update++;
}

unless ($needs_update){
	$err->I("Finished, nothing needs doing");
	exit;
}

my $newzone = $dns->PrintZone;
$newzone =~ s/^.*; Zone NS Records/;\n; Zone NS Records/s;
$newzone =~ s/\t/ /g;

my %formdata = ();
foreach my $input (@inputs){
	$formdata{$input->{name}} = $input->{value} if $input->{name};
}
$formdata{zonedata} = $newzone;
# print Dumper \%formdata;
if ($pause){
	$err->I("press enter to see the old zone file"); <STDIN>;
	$err->W("Old Zone File\n$zonetext");
	$err->I("press enter to see the new zone file"); <STDIN>;
	$err->W("New Zone Text\n$newzone");

	$err->W("press enter and i'll change it control-c otherwise");
	<STDIN>;
}


$err->F("Failed at $update_zone_url") unless 
	save_content ($ua->post($update_zone_url,\%formdata),'dns4.html');
$err->I("Posted Form Data");

sub text {
	my $text = shift;
	push @textareas,$text if $intextarea;
}
sub start { 
    # print Dumper \@_;
    my $tag = shift;
    my $attr = shift;
    if (lc($tag) eq 'input'){
        push @inputs,$attr;
    }
	if (lc($tag) eq 'textarea'){
		$intextarea = 1;
	}
}
sub end { 
    my $tag = shift;
	if (lc($tag) eq 'textarea'){
		$intextarea = 0;
	}
}

sub save_content {
	my $response = shift;
	my $file = shift;
	if ($response->is_success){
		my $cont = $response->content;
		write_file $file,$cont if $file;
		return $cont;
	}else{
		write_file $file,$response->error_as_HTML if $file;
		return undef
	}
}
