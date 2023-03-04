#$Id: StatSplit.pm,v 1.7 2005-03-21 22:15:29 triton Exp $
package TPerl::StatSplit;
use strict;
use Config::IniFiles;
use TPerl::LookFeel;
use TPerl::TritonConfig;

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	$self->{def_split_prefix} = $args{def_split_prefix} || 'Split';
	$self->{SID} = $args{SID};
	return $self;
}
sub err { my $self = shift; return $self->{err} = $_[0] if @_; return $self->{err}; }
sub def_split_prefix { my $self = shift; return $self->{def_split_prefix}; }
sub SID {my $self = shift; return $self->{SID};}
sub ini {my $self = shift; return $self->{ini} || $self->getIni();}

sub getIni {
	# returns a Config::IniFiles object
	my $self = shift;
	my %args = @_;
	my $inifile = $args{file};
	unless ($inifile){
		my $SID = $self->SID;
		my $troot = getConfig ('TritonRoot');
		$inifile = join '/',$troot,$SID,'config','statsplit.ini';
	}
	unless (-r $inifile){
		my $newini = new Config::IniFiles(-nocase=>1);
		my $s = 'Split All';
		$newini->AddSection ($s);
		# $newini->newval($s,'pretty','All');
		# $newini->newval($s,'start',scalar(localtime));
		# $newini->newval($s,'end','tomorrow');
		# $newini->newval($s,'ext','_all');
		$newini->newval($s,'whatpage',1);
		$newini->newval($s,'out2ini',0);
		$newini->newval($s,'custom',0);
		$newini->newval($s,'#cat_tsv','upload_data');
		$newini->newval($s,'#iprocess','-is=3');
		$newini->newval($s,'#recode','extract');
		$self->putCustomStats(ini=>$newini);
		$newini->newval('custom_stats','menu_link',0);

		unless ($newini->WriteConfig($inifile) ){
			$self->err("Could not make file '$inifile'");
			return undef;
		}
	}
	my $ini = new Config::IniFiles (-file=>$inifile,-nocase=>1);
	if ($ini){
		$self->{ini} = $ini;
		return $ini;
	}else{
		$self->err(join "\n", @Config::IniFiles::errors);
		return undef;
	}
}

sub fixSplits {
	# traverses the split groups in the ini file and sets the defaults
	my $self = shift;
	my $ini = $self->ini;
	return undef unless $ini;
	my %args = @_;
	my $sg = $args{group_prefix} || $self->def_split_prefix;
	unless ($ini){
		$self->err("No ini file object");
		return undef
	}
	if (my @groups = $ini->GroupMembers ($sg)){
		foreach my $group (@groups){
			my $base = $group;
			$base =~ s/$sg//i;
			$base =~ s/^\s*(.*?)\s*$/$1/;
			# print "group=$group base=$base\n";
			### Fix pretty
			my $pretty = $ini->val($group,'pretty');
			$pretty ||= $base;
			$ini->newval($group,'pretty',ucfirst($pretty));
			### Fix ext
			my $ext = $ini->val($group,'ext');
			$ext ||= lc($base);
			$ext =~ s/\s+//g;
			$ext = "_$ext" unless $ext =~ /^_/;
			$ini->newval($group,'ext',$ext);
			$ini->newval ($group,'start','1970') unless $ini->val($group,'start');
			$ini->newval ($group,'end','tomorrow') unless $ini->val($group,'end');
		}
		return $sg;
	}else{
		$self->err("No Split groups for $sg");
		return undef;
	}
}

sub countSplits {
	# fixes and counts the number of splits;
	# returns the name of the split grouup and the number of groups.
	my $self = shift;
	my %args = @_;
	
	my $ini = $self->ini() or return undef;
	my $sg = $self->fixSplits(%args) or return undef;
	my $count = 0;
	$count++ foreach $ini->GroupMembers($sg);
	return ($count,$sg);
}

sub ini2menu {
	my $self = shift;
	my %args = @_;
	my $target = $args{target} || 'right';
	my $sg = $args{group_prefix} || $self->def_split_prefix;
	my $SID = $args{SID} ||$self->SID;
	my $link_base = $args{link_base};
	my $ini = $self->ini();
	return undef unless $ini;

	if (my @groups = $ini->GroupMembers ($sg)){
		my @out = ();
		my $first;
		my $count = 0;
		foreach my $group (@groups){
			my $pretty = $ini->val($group,'pretty');
			my $is_cust = @{$self->getCustomStats(ini=>$ini)};
			my $out2ini = $ini->val($group,'out2ini');
			my $rec = $ini->val($group,'recode');
			my $ext = $ini->val($group,'ext');
			$ext .= '_cat' if $ini->val($group,'cat_tsv');
			my $rec_ext = "_$rec" if $rec;
			$first = "$link_base$SID$ext.html" unless $count;
			my $line = qq{\n<A target="$target" href="$link_base$SID$ext$rec_ext.html">$pretty</a>};
			$line .= qq{\n| <A target="$target" href="${link_base}what$ext$rec_ext.html">Verbatims</a>} if
				$ini->val($group,'whatpage');
			$line .= qq{\n| <A target="$target" href="${link_base}custom$ext$rec_ext.html">Custom</a>} if
				$ini->val($group,'custom') and $is_cust;
			$line .= qq{\n| <A target="_blank" href="${link_base}chart$ext$rec_ext.html">Charts</a>} if $out2ini;
			push @out,$line;
			$count++;
		}
		my $custom_mnu = join "\n",
			'<BR>',
			'<BR>',
			qq{<a href="aspcustomstatspage.pl?SID=$SID" target="right">Edit Custom Page</a>} if $ini->val('custom_stats','menu_link');


		return {menu=>join ('<BR>',@out),first=>$first,edit_custom_link=>$custom_mnu};
	}else{
		$self->err("No Split groups for $sg");
		return undef;
	}
}

sub getCustomStats {
	my $self = shift;
	my %args = @_;
	my $ini = $args{ini} || $self->getIni();
	unless ($ini){
		$self->err("Could not get ini:".$self->err());
		return undef;
	}
	my $vartxt = $ini->val('custom_stats','questions');
	return [split /,/,$vartxt];
}

sub putCustomStats {
	my $self = shift;
	my %args = @_;
	my $graphs = $args{graphs};
	my $ini = $args{ini} || $self->getIni();
	unless ($ini){
		$self->err("Could not get ini:".$self->err());
		return undef;
	}
	my $filename = $args{filename} || $ini->GetFileName();
	unless ($filename){
		$self->err("Could not get Filename to save inifile");
		return undef;
	}
	my $vartxt = join ',',@$graphs;
	$ini->newval('custom_stats','questions',$vartxt);
	if ($ini->WriteConfig($filename)){
		return 1;
	}else{
		$self->err("Could not write '$filename':$!");
		return undef;
	}
}

1;
