#!/usr/local/bin/perl
# what.pl
#
# File to quickly summarise who said what from the Internet version
#
# Assumes require of qt-lib.pl done already
#
$do_footer = 0;
$no_methods = 1;
$plain=1;
use Data::Dumper;
use FileHandle;

#-----------------------------------------------------------------------
#
# Main sub starts here (no main line - this is a slave)
#
sub do_what
	{
	my $survey_id = shift;
	my $data_file_ext = shift;
    &add2hdr("   <TITLE>$survey_id Survey Statistics</TITLE>");
    &add2hdr("   <META NAME=\"Author\" CONTENT=\"Mike King\">");
    &add2hdr("   <META NAME=\"Copyright\" CONTENT=\"$survey_id Survey Systems\">");
    &add2hdr(qq{   <link rel="stylesheet" href="/$survey_id/style.css">});

    &add2body("<H2>$survey_id Survey Systems, Online Statistics");
    &add2body("Verbatim Repsonses</H2>");
#
# Check the parameter (The Survey ID)
#

	if (! -d "${qt_root}/${survey_id}") 
		{
		&add2body("Cannot find directory ${qt_root}/${survey_id}<BR>"); 
		}
	else
		{
		$data_dir = "${qt_root}/${survey_id}/web";
		$config_dir = "${qt_root}/${survey_id}/config";
		my $final_dir = "${qt_root}/${survey_id}/final";
		if (! -d $data_dir )
			{
			&add2body("Cannot find directory $data_dir<BR>");
			}
		else
			{
			if (! opendir(DDIR,$data_dir))
				{
				&add2body("Cannot open directory $data_dir<BR>");
				}
			else
				{
				&my_require("$config_dir/qlabels.pl",1);
				@files = grep (/^D[0-9]+\.pl$/,readdir(DDIR));
				closedir(DDIR);
				### ac limits the @files to those mentioned in the data file in the $i variable..
				if ($data_file_ext){
					my $acfile = "$final_dir/$survey_id$data_file_ext.txt";
					my %ackeep_files = ();
					if (my $acfh = new FileHandle("< $acfile")){
						print STDERR "Reading from $acfile\n";
						my $achead = <$acfh>;
						chomp $achead;
						my @achead =split /\t/,$achead;
						while (my $acline = <$acfh>){
							chomp $acline;
							my @acline = split /\t/,$acline;
							my %acline = ();
							@acline{@achead}=@acline;
							# print STDERR Dumper \%acline;
							$ackeep_files{$acline{Seqno}}++;
						}
						# print STDERR 'Keeping these sqqno '.Dumper \%ackeep_files;
						my @newfiles = ();
						foreach my $acf (@files){
							if (my ($acseq) = $acf =~ /^D(\d+)\.pl$/){
								# print STDERR "dfile $acf seq=$acseq\n";
								push @acnewfiles,$acf if $ackeep_files{$acseq};
							}
						}
						print STDERR "limit from ".scalar(@files) .' to ' .scalar(@acnewfiles) ." Dfiles\n";
						@files = @acnewfiles;
					}else{
						die "can't open $acfile";
					}
					
				}
				$thdr = qq{ <TR class="heading">\n  <TH VALIGN=TOP>Case<BR> No.</TH>};
				$thdr .= qq{ <TH VALIGN=TOP ALIGN=left>When.</TH>};
				$thdr .= qq{<TH VALIGN="TOP">  Q<BR> No.} if ($sort);
  				$thdr .= qq{ </TH>};
				$thdr .= qq{   <TH VALIGN=TOP ALIGN=LEFT> };
				$thdr .= qq{  What they said};
  				$thdr .= qq{ </TH>};
				$thdr .= qq{</TR>};
  				my @qt = ();
  				my %stuff = ();
				for ($q_no=1; $q_no<=$numq; $q_no++)
					{
					my @qlab = split (/\s+/,$qlabels{$q_no});
					next if ($qlab[0] != $QTYPE_WRITTEN);
				    my $filename = "$qt_root/$survey_id/config/q$q_no.pl";
				  	my_require ($filename,0);
					$qt{$qlab[1]} = $prompt;			# grab Question prompt
					$stuff{$qlab[1]} = [];				# Add a stack
					}
				
			#
			# Now read in each regular data file :-
			#
				for (@files)
					{
					$file = $_;
#					&add2body("Reading file $_<BR>");
					&my_require ("$data_dir/$_",1);
					if ($file =~ /[Dd]([0-9]+)\.pl/)
						{
						foreach $lab (keys %qt)
							{
							my $value = '';
							$value = get_data($q,$q_no,$lab);
							$value =~ s/\\n/\n/g;
							$value =~ s/\r//g;
							$value =~ s/&/&amp;/g;
							$value =~ s/</&lt;/g;
							$value =~ s/>/&gt;/g;
							next if (length($value) <= 1);
							$when = localtime($resp{modified});
							push @{$stuff{$lab}}, qq{<tr class="options"><TD VALIGN=TOP>$resp{seqno}</TD><TD nowrap VALIGN=TOP>$when</TD><TD VALIGN=TOP>$value</TD></tr>\n};
							}
						}
					}
				foreach $lab (sort keys %qt)
					{
					add2body(qq{<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=5 class="mytable">});
					add2body(qq{ <TR class="heading">\n  <TH ALIGN=LEFT VALIGN=TOP colspan=3>Question: $qt{$lab}<HR></TH></TR>});
					add2body($thdr);
					while (my $line = pop @{$stuff{$lab}})
						{ 
						add2body($line);
						}
					add2body(qq{</TABLE><BR><BR>});
					}
				}
			}
		}
	}

