###$Id: recode.pl,v 2.13 2005-09-01 00:32:04 triton Exp $
use strict;
use FileHandle;
use Getopt::Long;
use File::Basename;
use Carp::Heavy;							#perl2exe
use TPerl::TritonConfig qw(getConfig);
use TPerl::ConfigIniFiles;
use Data::Dumper;
use TPerl::Error;
use Math::Round;
use TPerl::Dump;
use TPerl::Survey;
use TPerl::Hash;
use TPerl::Recode;
use TPerl::TSV;
use TPerl::DBEasy;
#
# These 2 are for Windoze benefit:
#
use File::Spec;							#perl2exe
use	File::Spec::Win32;					#perl2exe

use Date::Manip;
#Date::Manip::Date_SetConfigVariable("TZ","EST");
#Date_Init ("DateFormat=non-US");


my $file = undef;
my $debug = 0;
my $help = 0;
my $dst = undef;
my $ini = undef;
my $statuses = [];
my $ext = undef; ### Use this to specify an ext for the final/SID_ext.txt

#### names of the sections in the ini file.
my $recode_str = 'recode';
my $extract_str = 'extract';
my $filter_str = 'filter';
my $mail_str = 'mail';
my $calc_str = 'calc';
my $print_ver = 0;
my $head_sep = 0;
my $version = q{$Id: recode.pl,v 2.13 2005-09-01 00:32:04 triton Exp $};

#globals 
my $root = getConfig ('TritonRoot');

GetOptions (
	'file:s'=>\$file,
	'debug!'=>\$debug,
	help=>\$help,
	'ini:s'=>\$ini,
	'status:i'=>$statuses,
	'version!'=>\$print_ver,
	'header_seperate!'=>\$head_sep,
	'ext:s'=>\$ext,
) or usage ("Bad Command Line options");

my $err = new TPerl::Error(ts=>$debug);
usage ($version) if $print_ver;
usage () if $help;
my $SID = shift;
usage ("No SURVEY_ID") unless $SID;

if ($file){
	if ($ext){
		$err->E("Ignoring ext '$ext' when file option present");
	}
	unless (-e $file){
		$file = join '/',$root,$SID,'final',$file;
	}
}else{
	### if you are using a different source file don't 
	# automagically use the ini files from the config dir
	$ext = "_$ext" if $ext and $ext !~ /^_/;
	$file = join '/',$root,$SID,'final',"$SID$ext.txt";
}
## find an extract.ini or a recode.ini...
$ini ||='extract';

usage ("Source file '$file' does not exist") unless -e $file;

#### Put the dest file in the same dir as the source file
# call the dest file the base as the source but with _ini_file_name.txt on the end
my $dst_base =  basename ($file,'.txt','.csv') . '_' . basename ($ini,'.ini');
my $dst_head = undef;

# print "dst_base=$dst_base\n";
$dst_head = dirname ($file).'/'.$dst_base."_head.txt" if $head_sep;
$dst = dirname ($file). "/$dst_base.txt" ;

$err->I("Recoding $SID into $dst_base.txt");

if ($debug){
	# $err->D( "Survey_id=$SID");
	$err->D( "Input=$file");
	$err->D( "Output=$dst");
	$err->D( "Header=$dst_head") if $head_sep;
	$err->D( "Ini=".join '|',$ini);
}

####INI file reading 
# my $cfg = new Config::Ini ('') ;
my $rec = new TPerl::Recode(SID=>$SID,err=>$err,ini=>$ini,source=>$file);
my $cfg = $rec->ini || $err->F("Could not load ini file:".$rec->err);
unless ($cfg) {
	$err->E("Could not parse $ini");
	$err->E("Line $_") foreach @Config::IniFiles;
	exit;
}
$err->D("Finished parsing $ini") if $debug;

###sanity checking and laziness correction for the extract section of the ini file
# and building of rename hash
# The rename hash is where you look up the new name of an existing column
   	$rec->columns || $err->F($rec->err);
    my @extract = @{$rec->columns};
	my $rename = $rec->renames();
	
##### build the recode hash
	# foreach variable the new 
	my $recode = $rec->recodes;
	
	# print 'recode '.Dumper $recode;
	# print 'rename '.Dumper $rename;
##### build the calc hash


##### build the lastmonth or yesterday  or thismonth dates.
	my ($before,$after) = (undef,undef);
$cfg->E("Not handling [$filter_str]") if $cfg->SectionExists($filter_str);
# 	if (my $when = $cfg->get([$filter_str,'when']) ){
# 		if ($when =~/lastmonth/i){
# 			$after = ParseDate ('midnight last month');
# 			$after = Date_SetDateField($after,'d',1,1);
# 			$before = ParseDate ('midnight today');
# 			$before = Date_SetDateField($before,'d',1,1);
# 			$before = DateCalc ($before,"- 1 second");
# 		}elsif ($when =~/thismonth/i){
# 			$after = ParseDate ('midnight today');
# 			$after = Date_SetDateField($after,'d',1,1);
# 			$before = ParseDate ('midnight next month');
# 			$before = Date_SetDateField($before,'d',1,1);
# 			$before = DateCalc ($before,"- 1 second");
# 		}elsif ($when =~ /yesterday/i){
# 			$after = ParseDate ('midnight 2 days ago');
# 			$before = ParseDate ('midnight yesterday');
# 			$before = DateCalc ($before,"- 1 second");
# 		}else{
# 			$err->W("unrecognised [$filter_str] entry when=$when");
# 		}
# 	}else{
# 		my $before = $cfg->get([$filter_str,'before']);
# 		my $after = $cfg->get([$filter_str,'after']);
# 	}

$err->D("dates after '$after' and before '$before'") if ($after || $before) && $debug;

#open the in and out files
my $tsv = new TPerl::TSV(file=>$file,nocase=>1);

my $out = new FileHandle (">$dst") or $err->F( "Could not open output file '$dst'");
my $out_head;
if ($head_sep){
	$out_head = new FileHandle (">$dst_head") or  $err->F( "Could not open output file '$dst_head'");
}

my $inlab = $tsv->header_hash() || $err->F("Could not get headers:".$tsv->err);
foreach my $l (keys %$inlab){
	$err->E("Column $l is repeated $inlab->{$l} times in $file") if $inlab->{$l}>1;
}

my $calcs = $rec->calcs(vars=>$tsv->header) || $err->F("Error with [calcs]".$rec->err);


my @out_lab = ();
my $used_labs = {};
tie %$used_labs,'TPerl::Hash';
# Do some sanity checking
# print "rename:".Dumper $rename;
# print "calcs:".Dumper $calcs;
# print "inlab:".Dumper $inlab;
foreach my $e (@extract){
	$err->W("Label $e from [extract] does not exist in [calcs] or $file") if !$inlab->{uc($e)} and !$calcs->{$e};
	my $new = $rename->{$e};
	if ($used_labs->{$new}){
		$err->E("$e cannot be named $new as $used_labs->{$new} is using this");
	}else{
		push @out_lab,$rename->{$e};
		$used_labs->{$new} = $e;
	}
	if ($inlab->{uc $e} && $calcs->{$e}){
		$err->E("Removing $e from [calcs] as it is already in $file");
		delete $calcs->{$e};
	}
}
# print "calcs:".Dumper $calcs;
if ($head_sep){
	print $out_head "$_\n" foreach @out_lab;
}else{
	print $out join ("\t", @out_lab)."\n";
}
{
	my $s = getro TPerl::Dump (survey_file TPerl::Survey ($SID));
	if ($s){
		if (my $rf = $s->options->{rf_code}){
			$err->I("Adding a row of refused '$rf' to $dst");
			my @R = map $rf,@out_lab;
			print $out join ("\t", @R)."\n";
		}else{
		}
	}else{
		$err->E("Could not open ".survey_file TPerl::Survey ($SID));
	}
}

##Do the rest of the lines;
my $lines = 0; ##Count lines fro some reason...
# print "recodes ".Dumper $recode;
my $ez = new TPerl::DBEasy;
while (my $line = $tsv->row){
	$lines++;
	if ($before || $after){
		my $time = ParseDate (sprintf "$line->{YEAR} $line->{MONTH} $line->{DAY} $line->{HOUR}:%02d",$line->{MIN});
		$err->W(
			"Could not understand date y=$line->{YEAR} m=$line->{MONTH} d=$line->{DAY} h=$line->{HOUR} mn=$line->{MIN}"
			) unless $time;
		if ($after || $before){
			next unless Date_Cmp ($time,$after) > 0;
			next unless Date_Cmp ($time,$before) < 0;
		}
		if (@$statuses){
			next unless grep $line->{STATUS} == $_,@$statuses;
		}
	}
	##recode all the values
	# Do all the recodes. they may not be in the [extract] but they may be steps
	foreach my $f (keys %$recode){
		my $ff = uc $f;
		my $orig = $line->{$ff};
		$line->{$ff} = $recode->{$ff}->{$orig} if exists $recode->{$ff}->{$orig};
	}
	### do any calcs  These may not be in the output file, but may be steps.
	foreach my $field (sort {$calcs->{$a}->{order} <=> $calcs->{$b}->{order} } keys %$calcs){
		if (exists $line->{$field}){
			$err->W("Not doing [calcs] for $field. It already exists");
		}else{
			$line->{$field} = $ez->field2val(row=>$line,field=>$calcs->{$field},no_nbsp=>1)
		}
	}
	
	my @output = ();  # this is the output line
	foreach my $f (@extract){
		push @output,$line->{uc $f};
	}
	print $out join ("\t",@output)."\n";
}
close $out;

####Mail file if necessary
if (my $mailto = join ',',$cfg->val($mail_str,'mailto')){
	my $detail = {from=>'mikkel@market-research.com',smtp=>'localhost'};
	if (my $sender = new Mail::Sender ($detail)){
		my $subject = $cfg->val($mail_str,'subject') || "$SID DataFile";
		my $cc = $cfg->get([$mail_str,'cc']);
		$err->D("Sending $lines lines to $mailto,$cc |Subject=$subject");
		$sender->OpenMultipart({ to=>$mailto,subject=>$subject, cc=>$cc });
		$sender->SendFile( 
				{encoding=>'Base64',
				disposition => "attachment; filename = $dst_base",
				file => $dst
				});
		$sender->Body();
		$sender->Send (<<END);
Attached is the data file as requested by you from the Horizon Research Corporation web site.
Please note that the contents of this file are the subject of International Copyright law, and are the copyright of Horizon Research Corporation.
Reception of this file does not give you the right to access the contents.
If you have wrongly received this file, please forward it to info\@market-research.com
Horizon Research Corporation (USA) ph: (213) 627 7100
Horizon Research Corporation (Australia) ph: +61 3 9689 5299
END
	}else{
		$err->E("Mailer Error $Mail::Sender::Error");
	}
}

sub usage {
	my $msg = shift;
	print STDERR "  $msg\n";
	print STDERR 
	qq{ Usage recode [options] SURVEY_ID
	  options include
	  	file 		Change the source file.
		help 		show this
		debug 		show debug information
		ini 		use this instead of the default ini file
		status      status to include (-s=4 -s=3 for more than one status)
		ext			use final/SURVEY_ID_ext.txt as an input
	};
	die "\n";
}
