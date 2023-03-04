#!/usr/bin/perl
#
use CGI::Carp qw(fatalsToBrowser);
use TPerl::ASP;
use TPerl::MyDB;
use TPerl::DBEasy;
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::TritonConfig;

sub human_size {
    my $num = shift;
    my $dec = shift || 1;
    my $thousand = 1024;
    my $labels = {0=>'',1=>'K',2=>'M',3=>'G',4=>'T'};

    my $order = 1;
    my $ans = $num;
    while (1){
        my $div = $thousand ** $order;
        if ($num < $div){
            return "$ans$labels->{$order-1}";
        }
        $ans = sprintf ('%2.0f',$num / $div);
        return "$ans$labels->{$order}" unless $labels->{$order};
        $order++;
    }
}

my $q = new TPerl::CGI;
my %args = $q->args;
my $survey_id = $args{survey_id} || $args{SID};
my $thedir = $args{dir};
my $filter = $args{filter};
my $limit = $args{limit} ||20;
$args{table} ||= 'BATCH' if grep $_ eq $thedir, 'incoming','rejects';
my $table = $args{table};
my $label_rex = $args{label_rex};

print $q->header,$q->start_html(-style=>{-src=>"/$survey_id/style.css"}, -class=>"body");
my $qt_root = getConfig('TritonRoot');

my $dir = join '/',$qt_root,$survey_id,'html','admin',$thedir;


my ($labels,$batchlist) = {};
# if (grep $_ eq $thedir, 'incoming','rejects'){
# 	my $dbh = dbh TPerl::MyDB () or die "Could not connect to database".TPerl::MyDB->err;
# 	my $asp = new TPerl::ASP (dbh=>$dbh);
# 	$batchlist = $asp->batch_list (SID=>$survey_id) or die "Could not get batchlist:".$asp->err();
# 	$labels->{$batchlist->{$_}->{NAMES_FILE}} = $batchlist->{$_}->{TITLE} foreach keys %$batchlist;
# 	# print $q->dumper ($batchlist);
# 	# print $q->dumper ($labels);
if ($table){
	my $dbh = dbh TPerl::MyDB () or die "Could not connect to database".TPerl::MyDB->err;
	my $sql = ($args{sql}) ? $args{sql} : "select * from $table";
	my $res = $dbh->selectall_hashref ($sql,'BID') or $q->mydie({sql=>$sql,dbh=>$dbh});
	$labels->{$_} = "$res->{$_}->{TITLE} ($_)" foreach keys %$res;
#	print $q->dumper ($labels);
}
my $line = 0;
if (-d $dir)
	{
	opendir(DDIR,$dir) || die "Error $! while scanning directory $dir\n";
	
	print "Directory listing of $dir:<HR>\n";
	@files = readdir(DDIR);
	@files = grep !/^\./,@files;
	@files = grep (/$filter/,@files) if $filter;

	my $rows = [];
	my $fields = {	WHEN=>{name=>'WHEN',pretty=>'Modified'},
					FILE=>{name=>'FILE',pretty=>'File'},
					SIZE=>{order=>5,name=>SIZE,pretty=>'Size (bytes)'},
					};
	foreach my $f (@files){
		my $fn = join '/',$dir,$f;
		my $row = {};
		my @stat = stat($fn);
		$row->{MODIFIED} = $stat[9];
		$row->{FILESIZE} = $stat[7];
		$row->{WHEN} = localtime ($row->{MODIFIED});
		$row->{SIZE} = human_size($row->{FILESIZE});
		### Use the batch list to replace the batch number with the title in the rejects list.
		my ($id) = $f =~ /(\d+)/;
		my $lab = $labels->{$id} || $f;
		$row->{NAME} = $lab;
		$row->{FILE} = qq{<A HREF="/$survey_id/admin/$thedir/$f">$lab</A>};
		push @$rows,$row;
	}
# 	print $q->dumper ($rows);
	my $stype = $args{sorta} ? 'a' : 'n';
	if ($stype eq 'n')
		{
		my $sortfield = ($args{sortn}) ? uc($args{sortn}) : 'MODIFIED';
#		print "sortby $sortfield";
		if (!$args{desc})
			{@$rows = sort {$a->{$sortfield} <=> $b->{$sortfield}} @$rows;}
		else
			{@$rows = sort {$b->{$sortfield} <=> $a->{$sortfield}} @$rows;}
		}
	else
		{
		my $sortfield = ($args{sorta}) ? uc($args{sorta}) : 'MODIFIED';
#		print "sortby $sortfield";
		if (!$args{desc})
			{@$rows = sort {$a->{$sortfield} cmp $b->{$sortfield}} @$rows;}
		else
			{@$rows = sort {$b->{$sortfield} cmp $a->{$sortfield}} @$rows;}
		}	

	my $ez = new TPerl::DBEasy ();
	my $lf = new TPerl::LookFeel;
	my $page = $args{next} if $args{submit} =~ /next/i;
	$page = $args{previous} if $args{submit} =~ /prev/i;
	$page = $args{page} if $args{submit} =~ /go/i;
	
	my $state = {survey_id=>$survey_id,dir=>$thedir,table=>$table,sql=>$args{sql},limit=>$limit};
	$lf->trow_properties(align=>['left','left']);
	my $lister =  $ez->lister (rows=>$rows,fields=>$fields,look=>$lf,
		limit=>$limit,form=>1,form_hidden=>$state,page=>$page);
	if ($lister->{count}){
		print "$lister->{count} Files(s)";
		print join '',@{$lister->{html}};
		print join '',@{$lister->{form}};
	}elsif ($lister->{err}){
		my $q = new TPerl::CGI ('');
		print $q->err($lister);
	}else{
		print "No Files<BR>";
	}

	}
else
	{
	print qq{Error: Cannot find directory [$dir]<BR>\n};
	}
print <<EOF;
	<HR>
	</BODY>
	</HTML>
EOF
1;

