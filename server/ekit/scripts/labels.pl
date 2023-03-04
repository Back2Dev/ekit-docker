#$Id: labels.pl,v 2.27 2005-03-17 04:29:23 triton Exp $
#copyright Triton Technology 2002;

use strict;
use FileHandle;                         #perl2exe
use Data::Dumper;                       #perl2exe
use Getopt::Long;                       #perl2exe
use TPerl::TritonConfig qw(getConfig);  #perl2exe
use DirHandle;                          #perl2exe
use TPerl::Error;						#perl2exe
use TPerl::Dump;
use Getopt::Long;
use TPerl::TSV;
use TPerl::ConfigIniFiles;
use TPerl::Survey;
use Carp qw(confess);
use TPerl::Recode;

#
# These 2 are for Windoze benefit:
#
use File::Spec;							#perl2exe
use	File::Spec::Win32;					#perl2exe


my $ext = '';
my $cols_in_labels = undef;
my $do_splus = 1;
my $do_sql = 1;
my $debug = 0;
my $src = '';
my %wantvars = ();
my $nlab = 0;
GetOptions (
	'extension:s'=>\$ext,
	'cols-in-labels'=>\$cols_in_labels,
	'splus!'=>\$do_splus,
	'sql!'=>\$do_sql,
	'debug!'=>\$debug,
	'src:s'=>\$src,
) or usage ("Bad Options");

$ext = "_$ext" if $ext && $ext !~ /^_/;
$src = "_$src" if $src && $src !~ /^_/;

sub usage {
	my $msg = shift;

	print qq{$msg\n\nUsage: $0 [options] XXX123
  where options include
    --extract which recode ini file to use
};
}

sub notag {
	my $str = shift;
	$str =~ s/<br>/ /gi;
	$str =~ s/<.*?>//gs;
	$str =~ s/&nbsp;//ig;
	return $str;
}
my $max_line = 230; #this is beause SAS needs each line to be less than 255 chars....
sub clean_work {
	my $str = shift;
	$str = notag($str);
	$str =~ s/^\s*(.*?)\s*$/$1/;
	$str =~ s/\n//mg;
	$str =~ s/\.//g;
	# $str =~ s/"/'/g;
	$str =~ s/^&//;  #sas does not like starting labs with &
	$str =~ s/--/-/g;
	$str =~ s/-$//;
	$str =~ s/\*//;
	$str =~ s/^-//;
	return $str;
}

sub clean {
	my $str = shift;
	$str = clean_work($str);
	$str = substr($str,0,$max_line);
}
my $max_sql = 250; #this is beause SAS needs each line to be less than 255 chars....
sub sqlclean {
	my $str = shift;
	$str = clean_work($str);
	$str =~ s/'/\\'/g;		# Escape quotes
	$str = substr($str,0,$max_sql);
}

sub splus_print {
	
	my %args = @_;

	my $svar = $args{col};
	my $vallabs = $args{vallab};
	my $svarlab = $args{varlab} || ucfirst($svar);
	my $fh = $args{fh} or confess ("Must send an fh arg");
	my $tb_fh = $args{tb_fh}  or confess ("Must send an tb_fh arg");
	my $sdata = $args{data} || qq{parser( ADATA, "$svar", WHERE=-1 )};
	my $collabs = $args{collabs};

	my $svallab = undef;
	

	if ($vallabs){
		my @vls = ();
		my @lbs = ();
		foreach my $vl (sort {$a<=>$b} keys %$vallabs){
			push @vls,$vl;
			push @lbs,clean_work($vallabs->{$vl});
		}
		@lbs = map qq{"$_"},@lbs;
		$svallab = sprintf qq{cbind(c(%s),c(%s))},join (',',@vls),join (',',@lbs);
	}
	my $collab_line = undef;
 	if ($collabs){
 		my @cl = map qq{"$_"},@$collabs;
 		$collab_line = "colLab = (".join (',',@cl).')';
 	}

	my $svarlab_sh = $svarlab;
	$sdata = "data = $sdata" if $sdata;
	$svarlab = qq{varLab = "$svarlab"} if $svarlab;
	$svallab = qq{valLab = $svallab} if $svallab;

	my @lines = grep $_,$sdata,$svallab,$svarlab,$collab_line;
	@lines = map clean_work ($_),@lines;
	@lines = map "  $_",@lines;
	my $lines = join ",\n",@lines;

	$svar = clean_work($svar);
	$svarlab_sh = clean_work($svarlab_sh);
	print $fh "\n# ----\n#  $svar. $svarlab_sh\n# ----\n";
	print $fh "\n $svar = CreateTD(\n$lines\n\t)\n",;
	
	print $tb_fh "\n# ----\n#  $svar. $svarlab_sh\n# ----\n";
	print $tb_fh qq{\twrite.TAB(
\tTAB( $svar,BX=BX,BXLAB=BXLAB,NB=NB,FOOT=FOOT,
\tFUN=CC ("perc" ,all=T, test=TEST, sort=SORT),),
\tfile = paste ( TAB.PATH, sep="", "TAB_$svar.txt")
)
};

}

# get 'global' variables
	my $troot = getConfig ('TritonRoot');
	my $config = 'config';
	my $final = 'final';
	my $doc = 'doc';

my $survey_id = uc(shift);
my $e = new TPerl::Error;

$e->F ("No Survey ID on command line") unless $survey_id;


my $s_file = join '/',$troot,$survey_id,'config',$survey_id.'_survey.pl';
$e->F("Survey file $s_file does not exist:$!") unless -e $s_file;
my $s = getro TPerl::Dump $s_file;
my $standards = {
	status=>{tlen=>3,codes=>{4=>'Complete',3=>'In Progress',0=>'Ready',2=>'Terminated',1=>'Refused'}},
	seqno=>{tlen=>10,label=>'Sequence Number'},
	token=>{tlen=>8,label=>'Password'},
	id=>{tlen=>20,label=>'Unique ID'},
	surveyid=>{tlen=>12,label=>'Survey ID'},
	duration=>{tlen=>14},
	year=>{tlen=>4},
	month=>{tlen=>3},
	day=>{tlen=>3},
	weekday=>{tlen=>3},
	hour=>{tlen=>3},
	min=>{tlen=>3},
	email=>{label=>'Email Address',tlen=>100},
	ipaddr=>{label=>'IP Address',tlen=>20},
};

$standards->{status}->{codes} = { 3=>'In Progress',4=>'Self Edit',5=>'Edit Review',6=>'Recontact',7=>'Final',8=>'Deleted' } if
	$s->options->{ivor_interview};

my $dkrf = {};

my $columns = []; # that need labels
my $ini = new TPerl::ConfigIniFiles;
my $ini_vallabs = {}; # recodes from the ext from the [values] section of the extract.ini

my $rec = new TPerl::Recode (SID=>$survey_id,ext=>$ext);

if ($ext){
	$ini = $rec->ini() or $e->F($rec->err());
	$e->I("Lables for [extract] section in ".$ini->GetFileName());
	$columns = $rec->columns() or $e->F($rec->err());
	$ini_vallabs = $rec->ini_vallabs() or $e->F($rec->err());
}else{
	my $final_file = join '/',$troot,$survey_id,'final',"$survey_id$src.txt";
	$e->I("Labels for columns in $final_file");
	$e->F("Final file $final_file does not exist") unless -e $final_file;
	my $tsv = new TPerl::TSV (file=>$final_file);
	my $head = $tsv->header or $e->F("Could not get header:".$tsv->err);
	push @$columns, $_ foreach @$head;
}
foreach (qw( dk rf)){
	$dkrf->{$_} = $s->options->{$_.'_code'};
	$e->I("Adding $_=$dkrf->{$_} to each set of codes") if $dkrf->{$_};
}

my $codesfile = join '/',$troot,$survey_id,'final',$survey_id .'_Codes_2.txt';
$e->F("You want to run iprocess to make a $codesfile") unless -e $codesfile;
$e->D("Using Codes file $codesfile") if $debug;
my $codes = getro TPerl::Dump ($codesfile);

# print 'ini_vallabs '.Dumper $ini_vallabs;

my $ext_vallabs = $ini_vallabs;
## Now the info from the external pages is in the survey anyway.  All the WUS/Trauma/NAGS 
## interviews use the ini file anyway...
# my $ext_file = join '/',$troot,$survey_id,$config,'external_vars.txt';
# if (-e $ext_file){
# 	my $externals = getro TPerl::Dump ($ext_file);
# 	foreach my $page (@{$externals->{order}}){
# 		my $names = $externals->{pages}->{$page}->{names};
# 		foreach my $evar (@$names){
# 			if (my $vals = $externals->{pages}->{$page}->{values}->{$evar}){
# 				# print "Found vals for $evar ".Dumper $vals;
# 				foreach my $val (@$vals){
# 					my $lab = $ini_vallabs->{"ext_$evar"}->{$val} || $externals->{pages}->{$page}->{labels}->{$evar}->{$val} || $val;
# 					# print "for $evar $val is $lab\n";
# 					$ext_vallabs->{"ext_$evar"}->{$val} = $lab;
# 				}
# 			}
# 		}
# 	}
# }
# print Dumper $ext_vallabs;
# print Dumper \@$columns;
# print "recodes ".Dumper $recodes;

my $docdir = join '/',$troot,$survey_id,$doc;
mkdir($docdir,0777) || die "Cannot create directory: $docdir\n" if (!-d $docdir);
my $spss_filename = "$docdir/${survey_id}$src${ext}_labels.sps";
my $spss_fh = new FileHandle ("> $spss_filename") or $e->F ("Cannot create file '$spss_filename' :$!");

my $sql_filename = "$docdir/${survey_id}$src${ext}_labels.sql";
my $sql_varfilename = "$docdir/${survey_id}$src${ext}_var.txt";
my $sql_vlfilename = "$docdir/${survey_id}$src${ext}_vl.txt";
my $sql_loadfilename = "$docdir/${survey_id}$src${ext}_load_sql.pl";
my $sql_wantedfilename = "$docdir/${survey_id}_wanted.pl";
my $sql_fh = undef;
my $sql_varfh = undef;
my $sql_vlfh = undef;
my $sql_plfh = undef;
my $sql_wantedh = undef;
if ($do_sql){
	$sql_fh = new FileHandle ("> $sql_filename") or $e->F ("Cannot create file '$sql_filename' :$!");
	$sql_wantedh = new FileHandle ("> $sql_wantedfilename") or $e->F ("Cannot create file '$sql_wantedfilename' :$!");
	$sql_varfh = new FileHandle ("> $sql_varfilename") or $e->F ("Cannot create file '$sql_varfilename' :$!");
	$sql_vlfh = new FileHandle ("> $sql_vlfilename") or $e->F ("Cannot create file '$sql_vlfilename' :$!");
}

my $splus_filename = "$troot/$survey_id/$doc/${survey_id}${src}_labels.ssc";
my $splus_tb_filename = "$troot/$survey_id/$doc/${survey_id}${src}_tables.ssc";

my $splus_fh = undef;
my $splus_tb_fh = undef;
if ($do_splus){
	$splus_fh = new FileHandle ("> $splus_filename") or $e->F ("Cannot create file '$splus_filename' :$!");
	$splus_tb_fh = new FileHandle ("> $splus_tb_filename") or $e->F ("Cannot create file '$splus_tb_filename' :$!");
}

my $sas_filename = "$docdir/${survey_id}$src${ext}_formats.sas";
my $sasf_fh = new FileHandle ("> $sas_filename") or $e->F ("Cannot create file '$sas_filename':$!");
$sas_filename = "$docdir/${survey_id}$src${ext}_procformat.sas";
my $saspf_fh = new FileHandle ("> $sas_filename") or $e->F ("Cannot create file '$sas_filename':$!");
$sas_filename = "$docdir/${survey_id}$src${ext}_label.sas";
my $saslab_fh = new FileHandle ("> $sas_filename") or $e->F ("Cannot create file '$sas_filename':$!");

my $fixed = [qw(Status Seqno SurveyID Email Ipaddr Duration Year Month Day Weekday hour min Token)];
my $when = scalar (localtime);

###SPSS header
	print $spss_fh "#  Descriptor record for King Triton Survey system\n";
	print $spss_fh "#  Copyright 2002 \n";
	print $spss_fh "#  $when\n";
	print $spss_fh ".\n";
	print $spss_fh "GET TRANSLATE\n";
	my $file = "$troot\\$survey_id\\$final\\$survey_id.txt";
	$file =~ s#/#\\#g;
	print $spss_fh qq{\tFILE = "$file"\n};
	print $spss_fh "TYPE=TAB /MAP /FIELDNAMES . \n";
	print $spss_fh "FORMATS seqno,status,duration,year,month,day,weekday,hour,min,";

###SQL header

	print  $sql_fh <<SQLCODE;
/*  Descriptor record for Triton Survey system
 *  Copyright 2002-5 
 *  $when
 */
USE triton;
DROP TABLE IF EXISTS ${survey_id}_VAR;
CREATE TABLE ${survey_id}_VAR (Q varchar(12),  Label varchar(250),  SortOrder integer );
DROP TABLE IF EXISTS ${survey_id}_VL;
CREATE TABLE ${survey_id}_VL (Q varchar(12),  Value integer,  Label  varchar(250),  SortOrder integer );
DROP TABLE IF EXISTS ${survey_id}_SD;
CREATE TABLE ${survey_id}_SD (Q varchar(12),  Value integer,  seqno integer );
SQLCODE

print $sql_varfh join("\t",(qw{Q Label SortOrder}))."\n";
print $sql_vlfh join("\t",(qw{Q Value Label SortOrder}))."\n";

####SPLUS HEADER
if ($do_splus){
    print $splus_fh q{# Descriptor record for King Triton Survey system }."\n";
    print $splus_fh q{# Copyright King Triton Survey Systems 1995-2000 }."\n";
    print $splus_fh q{# $when}."\n";
    print $splus_fh q{# Please note that this file is generated, and should not be edited }."\n";
    print $splus_fh qq{\n};
    print $splus_fh q{This line prevents the script from auto-running}."\n";
    print $splus_fh qq{\n};
    print $splus_fh qq{#====================================================================\n};
    print $splus_fh qq{#\n};
    print $splus_fh qq{#       Data Processing  $survey_id\n};
    print $splus_fh qq{#\n};
    print $splus_fh qq{#====================================================================\n};
    print $splus_fh qq{\n};
    print $splus_fh qq{#--------------------------------------------------------------------\n};
    print $splus_fh qq{#       Reading File/ Cleaning \n};
    print $splus_fh qq{#--------------------------------------------------------------------\n};
    print $splus_fh qq{\n};
	print $splus_fh qq{\t.attach ("[project_folder]\\\\splus",1)\n};
	print $splus_fh qq{\tPATH\t=\t"[project_folder]\\\\"\n\tTrPATH\t=\t"[triton_folder]\\\\final"\n};
	print $splus_fh qq{\tADATA\t=\tread.table( paste( TrPATH, sep="", "$survey_id" ),sep="\\t", header=T, row.names=NULL, stringsAsFactors=F )\n};
	print $splus_fh qq{\tKeep\t=\tivp( ADATA[,"Status"] == 4 & ADATA[,"UID"] < 9000, BN=F )\n};
	print $splus_fh qq{\tADATA\t=\t ADATA[ Keep, ]\n};
	print $splus_fh qq{\tnr(ADATA)\n};
	
	print $splus_tb_fh qq{
# -------
#   Banner info
# -------

    BX  =   NULL
    BXLAB   =   NULL
    FOOT    =   NULL
    TAB.PATH    =   paste(PATH, "Tabs\\\\", sep="")
    TEST    =   NULL
    NB  =   0
    FOOT    =   NULL
    TRIM    =   .2
    SORT    =   1

};
}

#print $spss_fh join (',',@cols)." (F8)\n";
	for (my $i=0;$i<=$#$columns;$i++){
		print $spss_fh qq{\n\t} unless $i % 9;
		print $spss_fh qq{$$columns[$i] (F8),};
		# $e->W ("Variable label too long: $$columns[$i]") if (length($$columns[$i]) > 8);
	}
print $spss_fh ".\n";
# print $spss_fh q{FORMATS SurveyID (A8).
# VARIABLE LABELS duration "Time to conduct interview".
# VARIABLE LABELS status "Interview completion status".
# VALUE LABELS status 1 "Refused" 2 "Terminated" 3 "Aborted" 4 "Completed" 5 "Incomplete".
# };

#### sas header
	print $sasf_fh join "\n",
		qq{/* # SAS formats for $survey_id},
		qq{# Copyright Triton Technology 2002 },
		qq{# Generated on $when */},
		'',
		'';
	print $saspf_fh join "\n",
		qq{/* # SAS proc format statements for $survey_id},
		qq{# Copyright Triton Technology 2002 },
		qq{# Generated on $when */},
		'',
		'';
	print $saslab_fh join "\n",
		qq{/* # SAS labels for $survey_id},
		qq{# Copyright Triton Technology 2002 },
		qq{# Generated on $when */},
		'',
		'';

my $format_number = 1;
my $pf_nums = {};  #reuse pf if possible;

my $colinfo = {};
## Go through the survey object, looking for the column names etc.
foreach my $q (@{$s->questions}){
	foreach my $ci (@{$q->getDataInfo(codes=>$codes,dk_code=>$dkrf->{dk},rf_code=>$dkrf->{rf})}){
		my $h ={ci=>$ci,q=>$q};
		$colinfo->{$ci->{var}} = $h;
	}
}


my $pf_printed = {};
my $warned_clash = {};

# now do the work....
$e->I("Including varnames in labels") if $cols_in_labels;

### This loop is for spss and sas, where the labeling is simpler.

### Do per column labels for splus.
my $splus_simple = 0;
$splus_simple=1 if $s->options->{ivor_interview};

foreach my $col (@$columns){
	my $tlen=3;
	my $varlabel;
	my $new_var =$col;
	my $vallabs;
	my $lab;
	
	if (my $h = $colinfo->{$col}){
		my $q = $h->{q};
		my $ci = $h->{ci};
		my $qtype=$q->qtype;
		$lab = $q->label;
		$tlen = 3;
		$tlen = 255 if $qtype == 14 and !exists $ci->{val_if_true};
		$tlen = 10 if grep $qtype ==$_,1,18,29;
		$tlen = 20 if grep $qtype ==$_,16;
		$tlen = 255 if grep $qtype ==$_,5,15,24;
		if ($qtype ==7){
			$tlen = 255 if $ci->{type} eq 'text';
			$tlen = $ci->{length} if $ci->{length};
		}
 		$vallabs = $ci->{val_label} if $ci->{val_label};
		$varlabel = $ci->{var_label};

	}elsif (my $s = $standards->{lc($col)}){
		$tlen = $s->{tlen};
		$varlabel=$s->{label};
		$vallabs=$s->{codes};
		$lab=$col;
	}else{
		$vallabs = $ext_vallabs->{$col};
		$lab = $col;
		# print "col=$col".Dumper $vallabs;

	}
	if ($ext){
		$new_var = $_ if $_ = $ini->val('extract',$col);
		$varlabel = $_ if $_ = $ini->val('label',$col);
		$tlen = $_ if $_ = $ini->val('length',$col);
		$vallabs = $rec->new_vallabs(err=>$e,col=>$col,vallabs=>$vallabs,warn=>$warned_clash);
	}
	$varlabel = clean($varlabel);
	$varlabel ||=$new_var;
	if ($cols_in_labels){
		$varlabel = "$new_var $varlabel";
		$varlabel = clean($varlabel);
	}

	# print out the splus stuff.
	if ($splus_simple){
		my $svar = $col;
		my $sdata = qq{parser( ADATA, "$svar", WHERE=-1 )};
		my $svallab = undef;
		my $svarlab = $varlabel;

		if ($vallabs){
			my @vls = ();
			my @lbs = ();
			foreach my $vl (sort {$a<=>$b} keys %$vallabs){
				push @vls,$vl;
				push @lbs,clean($vallabs->{$vl});
			}
			@lbs = map qq{"$_"},@lbs;
			$svallab = sprintf qq{cbind((%s),c(%s))},join (',',@vls),join (',',@lbs);
		}

		my $svarlab_sh = $svarlab;
		$sdata = "data\t=\t$sdata" if $sdata;
		$svarlab = qq{varLab\t=\t"$svarlab"} if $svarlab;
		$svallab = qq{valLab\t=\t$svallab} if $svallab;

		my @lines = grep $_,$sdata,$svallab,$svarlab;
		@lines = map "\t\t\t\t$_",@lines;
		my $lines = join ",\n",@lines;
		if ($do_splus){
			print $splus_fh "\n# ----\n#  $svar. $svarlab_sh\n# ----\n";
			print $splus_fh "\n\t$svar\t\t=\tCreateTD(\n$lines\n\t\t\t\t)\n",;
			
			print $splus_tb_fh "\n# ----\n#  $svar. $svarlab_sh\n# ----\n";
			print $splus_tb_fh qq{\twrite.TAB(
\t\tTAB( $svar,BX=BX,BXLAB=BXLAB,NB=NB,FOOT=FOOT,
\t\t\tFUN=CC ("perc" ,all=T, test=TEST, sort=SORT),
\t\t),
\t\tfile = paste ( TAB.PATH, sep="", "TAB_$svar.txt")
\t)
};
		}

	}
	print $saslab_fh qq{LABEL $new_var="$varlabel";\n} ;
	print $saslab_fh qq{ Length $new_var \$$tlen;\n} if $tlen;
	print $spss_fh qq{\nVARIABLE LABELS $new_var "$varlabel".\n};
	if ($vallabs){
		foreach (keys %$vallabs){
			$vallabs->{$_} = clean($vallabs->{$_});
			$e->W("Value label for $col:$_ is $vallabs->{$_}") if $_ eq $vallabs->{$_} and $col =~ /^ext_/;
		}
		#reuse pf (proc_format).
		my $pf = join '',map qq{  "$_"="$vallabs->{$_}"\n}, sort {$a<=>$b} keys %$vallabs;
		next unless $pf;
		$pf_nums->{$pf} ||= $format_number++;
		my $pfn = $pf_nums->{$pf};
		print $sasf_fh 	qq{format $new_var \$f${pfn}f.;\n};
		unless ($pf_printed->{$pfn}){
			print $saspf_fh qq{proc format;\n value \$f${pfn}f\n};
			print $saspf_fh qq{$pf;\n};
			$pf_printed->{$pfn}++;
		}
		print $spss_fh qq{VALUE LABELS $new_var\n};
		print $spss_fh map qq{ $_ "$vallabs->{$_}"\n}, sort {$a<=>$b} keys %$vallabs;
		print $spss_fh ".\n";
	}
}

# Now loop through Survey Object doing splus stuff.

if (!$splus_simple and $do_splus){
	my $s_order = {
		status=>100, seqno=>99, token=>98, surveyid=>97, duration=>96, year=>95, month=>94, day=>93, 
		weekday=>92, hour=>91, min=>90, email=>89, ipaddr=>88,
	};
	# first do the 'standards'
# John: No, we NEVER use those variables, except in very special cases, and we can get the variables we need manually.  It just creates a lot of clutter in the script file.
# 	foreach my $snam (sort {$s_order->{$b} <=> $s_order->{$a}} keys %$standards){
# 		my $s = $standards->{$snam};
# 		splus_print (col=>$snam,fh=>$splus_fh,tb_fh=>$splus_tb_fh,
# 			varlab=>$s->{label},vallab=>$s->{codes});
# 	}
	# do the questions in the survey.
	foreach my $q (@{$s->questions}){
		my $oths = $q->specify_n + $q->others;
		### if more than one other do other columns independantly....
		if (($q->qtype() eq 2) and ($oths<=1) ){
			# treat multi's differently.
			my $lab = $q->varlabel || $q->prompt();
			my $var= $q->varname || $q->label();
			$var = "Q$var" if $var =~ /^\d/;
			my $vls = undef;
			my $non_oth_cnt = 0;
			my $auto_code = undef;

			# John does not want specifies in the multis. but he does want the 'Other specify'.
			$vls->{$auto_code+1} = 'OtherSpecify' if $auto_code ne '';
			# foreach my $ci (@{$q->getDataInfo(codes=>$codes,dk_code=>$dkrf->{dk},rf_code=>$dkrf->{rf})}){
			foreach my $ci (@{$q->getDataInfo(codes=>{},dk_code=>$dkrf->{dk},rf_code=>$dkrf->{rf})}){
				$non_oth_cnt++ if $ci->{autocode_after} eq '';
				$auto_code = $ci->{autocode_after} if $ci->{autocode_after} > $auto_code;
				my $vl = $ci->{val_label};
				foreach my $v (keys %$vl){
					if (exists $vls->{$v}){
						if ($vls->{$v} eq $vl->{$v}){
							$e->E("Val label '$vl->{$v}' same as '$vls->{$v}' in '$var'");
						}else{
							$e->E("Val label for '$v' ($vl->{$v}) in $ci->{var} clashes with '$vls->{$v}' in '$var'");
						}
					}else{
						$vls->{$v} = $vl->{$v} if $vl->{$v} ne '';
					}
				}
			}
			my $other = sprintf (", ov=1:$non_oth_cnt, nv=1:$non_oth_cnt, other=%d",$auto_code+1) if $auto_code;
			my $rec_s = 'recode (' if $auto_code;
			my $rec_e = ')' if $auto_code;
			my $data = qq{collapse.mat( $rec_s parser( ADATA, "$var*", WHERE=-1 ) $other $rec_e )};
			splus_print (fh=>$splus_fh,tb_fh=>$splus_tb_fh,col=>$var,data=>$data,
				varlab=>$lab,vallab=>$vls
				);
		}elsif ($q->qtype() == 14){
			my $lab = $q->varlabel || $q->prompt();
			my $var= $q->varname || $q->label();
			$var = "Q$var" if $var =~ /^\d/;
			my $vls = $q->getDataInfo()->[0]->{val_label};
			my $data = qq{collapse.mat( recode( parser( ADATA, "$var*", WHERE=-1 ) ) )};
			splus_print (fh=>$splus_fh,tb_fh=>$splus_tb_fh,col=>$var,data=>$data,
				varlab=>$lab,vallab=>$vls,collabs=>$q->attributes,
				);

		}else{
			# use the normal stuff
			foreach my $ci (@{$q->getDataInfo(codes=>$codes,dk_code=>$dkrf->{dk},rf_code=>$dkrf->{rf})}){
				# print Dumper $ci if $ci->{var} eq 'B1';
 				splus_print (fh=>$splus_fh,tb_fh=>$splus_tb_fh,col=>$ci->{var},
 					varlab=>$ci->{var_label},vallab=>$ci->{val_label}
 					);
			}
		}
	}
}
#
# Do the SQL label generation:
if ($do_sql){
	# do the questions in the survey.
	foreach my $q (@{$s->questions}){
		my $oths = $q->specify_n + $q->others;
		### if more than one other do other columns independantly....
		if (($q->qtype() eq 2) and ($oths<=1) ){
			# treat multi's differently.
			my $lab = $q->varlabel || $q->prompt();
			my $var= $q->varname || $q->label();
			$var = "Q$var" if $var =~ /^\d/;
			my $vls = undef;
			my $non_oth_cnt = 0;
			my $auto_code = undef;

			# John does not want specifies in the multis. but he does want the 'Other specify'.
			$vls->{$auto_code+1} = 'OtherSpecify' if $auto_code ne '';
			# foreach my $ci (@{$q->getDataInfo(codes=>$codes,dk_code=>$dkrf->{dk},rf_code=>$dkrf->{rf})}){
			foreach my $ci (@{$q->getDataInfo(codes=>{},dk_code=>$dkrf->{dk},rf_code=>$dkrf->{rf})}){
				$non_oth_cnt++ if $ci->{autocode_after} eq '';
				$auto_code = $ci->{autocode_after} if $ci->{autocode_after} > $auto_code;
				my $vl = $ci->{val_label};
				foreach my $v (keys %$vl){
					if (exists $vls->{$v}){
						if ($vls->{$v} eq $vl->{$v}){
							$e->E("Val label '$vl->{$v}' same as '$vls->{$v}' in '$var'");
						}else{
							$e->E("Val label for '$v' ($vl->{$v}) in $ci->{var} clashes with '$vls->{$v}' in '$var'");
						}
					}else{
						$vls->{$v} = $vl->{$v} if $vl->{$v} ne '';
					}
				}
			}
			my $other = sprintf (", ov=1:$non_oth_cnt, nv=1:$non_oth_cnt, other=%d",$auto_code+1) if $auto_code;
			my $rec_s = 'recode (' if $auto_code;
			my $rec_e = ')' if $auto_code;
			my $data = qq{collapse.mat( $rec_s parser( ADATA, "$var*", WHERE=-1 ) $other $rec_e )};
			sql_print (fh=>$sql_fh,varfh=>$sql_varfh,vlfh=>$sql_vlfh,col=>$var,data=>$data,
				varlab=>$lab,vallab=>$vls
				);
		}elsif ($q->qtype() == 14){
			my $lab = $q->varlabel || $q->prompt();
			my $var= $q->varname || $q->label();
			$var = "Q$var" if $var =~ /^\d/;
			my $vls = $q->getDataInfo()->[0]->{val_label};
			my $data = qq{collapse.mat( recode( parser( ADATA, "$var*", WHERE=-1 ) ) )};
			sql_print (fh=>$sql_fh,varfh=>$sql_varfh,vlfh=>$sql_vlfh,col=>$var,data=>$data,
				varlab=>$lab,vallab=>$vls,collabs=>$q->attributes,
				);

		}else{
			# use the normal stuff
			foreach my $ci (@{$q->getDataInfo(codes=>$codes,dk_code=>$dkrf->{dk},rf_code=>$dkrf->{rf})}){
 				sql_print (fh=>$sql_fh,varfh=>$sql_varfh,vlfh=>$sql_vlfh,col=>$ci->{var},
 					varlab=>$ci->{var_label},vallab=>$ci->{val_label}
 					);
			}
		}
	}
print $sql_wantedh "\@wanted_vars=(qw{".join(" ",sort keys %wantvars)."});\n";
}

sub sql_print {
	
	my %args = @_;

	my $svar = $args{col};
	my $vallabs = $args{vallab};
	my $svarlab = $args{varlab} || ucfirst($svar);
	my $fh = $args{fh} or confess ("Must send an fh arg");
	my $varfh = $args{varfh} or confess ("Must send an varfh arg");
	my $vlfh = $args{vlfh} or confess ("Must send an vlfh arg");
	my $collabs = $args{collabs};

	my $svallab = undef;
	my $svarlab_sh = $svarlab;
	$svarlab_sh = clean($svarlab_sh);
	
	my @sql = (); 
	my @sqlvar = ();
	my @sqlvl = ();
 	if ($collabs){
 		my $colno = 1;
		my $varlab = sqlclean($svarlab);
		my $cmd = qq{INSERT INTO ${survey_id}_VAR (Q,Label,SortOrder) VALUES ("$svar","$varlab",$nlab);};
		push @sqlvar,join("\t",($svar,$varlab,$nlab));
		push @sql,$cmd;
		$nlab++;
 		foreach my $col (@$collabs){
			my $varlab = sqlclean($col);
			my $varname = "${svar}x$colno";
 			push @sql,qq{/* ${svar}x$colno: $col */};
			my $cmd = qq{INSERT INTO ${survey_id}_VAR (Q,Label,SortOrder) VALUES ("$varname","$varlab",$nlab);};
			push @sqlvar,join("\t",($varname,$varlab,$nlab));
			push @sql,$cmd;
			$nlab++;
			$wantvars{$varname}++;
			if ($vallabs){
				my @vls = ();
				my @lbs = ();
				foreach my $vl (sort {$a<=>$b} keys %$vallabs){
					my $sortorder = $vl;
					my $val = $vl;
					my $vlc = clean($vallabs->{$vl});
					my $cmd = qq{INSERT INTO ${survey_id}_VL (Q,Value,Label,SortOrder) VALUES ("$varname","$vl","$vlc",$sortorder);};
					push @sqlvl,join("\t",($varname,$vl,$vlc,$sortorder));
					push @sql,$cmd;
				}
			}
			$colno++;
		}
 	}else{
		if ($vallabs){
			my @vls = ();
			my @lbs = ();
			my $varlab = sqlclean($svarlab);
			my $cmd = qq{INSERT INTO ${survey_id}_VAR (Q,Label,SortOrder) VALUES ("$svar","$varlab",$nlab);};
			push @sqlvar,join("\t",("$svar","$varlab",$nlab));
			push @sql,$cmd;
			$nlab++;
			foreach my $vl (sort {$a<=>$b} keys %$vallabs){
				my $sortorder = $vl;
				my $val = $vl;
				my $vlc = clean($vallabs->{$vl});
				$wantvars{$svar}++;
				my $cmd = qq{INSERT INTO ${survey_id}_VL (Q,Value,Label,SortOrder) VALUES ("$svar","$vl","$vlc",$sortorder);};
				push @sqlvl,join("\t",("$svar","$vl","$vlc",$sortorder));
				push @sql,$cmd;
			}
		}
 	}

	$svar = clean($svar);
	my $cresql = join "\n",@sql;
	print $fh "\n/* ----\n *  $svar. $svarlab_sh\n * ----*/\n";
#	print $fh "\n/*\t$svar\t\t=\tCreateTD(\n$lines\n\t\t\t\t)*/\n",;
	print $fh "\n$cresql\n",;
	print $varfh join("\n",@sqlvar)."\n";
	print $vlfh join("\n",@sqlvl)."\n";
}
