#!/usr/bin/perl
# $Id: activate_vhost.pl.template,v 1.14 2011-08-30 23:48:55 triton Exp $
# $Author: JELLO
#
# Script to activate a vhost once it has been moved from the production server to the live host
# Replaces kickstart.sh
# Builds from a template

use strict;
use Getopt::Long;

#print "\n>START \n\n";

my $opt_help;
my $opt_version;
my $opt_verbose;
my $dbPass;
my $dbEngine;

my $host = "ekit";   
my $moduleName = "ekit";
my $serverName = "new.mappwi.com";



my $version = " activate_vhost.pl\n _____________________\n Version: 1.0 \n Original Author: JELLO 1-30-09\n Last revision: JELLO 1-30-09\n\n";

GetOptions ('help|h'        => \$opt_help,
			'version|v'     => \$opt_version,
			'verbose'		=> \$opt_verbose) or die_usage ( "Bad command line options");
			
if ($opt_help) {
	&usage;
}

if ($opt_version) {
	die "$version";
}

#lets move to the vhost root directory
chdir("../");

#update the server.ini file with some more information that is needed for the vhost that is not included with the template
&updateServerIniFile;

#install perl modules
&installPerlModules;

# Build Fonts catalogue for Image Magick
&buildIMFonts;

#create symbolic links
&createSymbolic;

#create .htaccess and .htdigest files in new vhost root
# Actually htdigest is a better (more secure form of authentication, and we SHOULD be using it!
	#&createHtdigest;   #aparently no longer used... htpassdb used instead
&createHtpassDB;
&createHtaccess;

#install chosen database
&installDatabase;
&updateTPeople;			# Put our people into .htaccess file

#init
&runInit;

#fix vhost template apache file
&fixVhostTemplateFile;

#install viewvc
&installViewvc;

#copy vhost file to sites-available (debian only)
&copyVhostTemplate;

#symlink the vhost file to sites-enabled (debian only)
&symlinkApacheVhost;

#restart apache (debian only)
&restartApache;

#remove the admin directory because if it is no longer going to be used
	#&removeAdminDirectory;

print "\ndone\n\n";


#-----------------------SUBS--------------------------------------------
sub usage {
    print "\n Usage: $0 [-help] [-version] [-verbose] [-target] \n\n";
	print "-help           Displays this help \n";
    print "-version        Display version information \n";
    print "-verbose        Enable verbose mode \n"; 
	print "This script initialized a new VHOST on a production server. \n";
	print "This script should be run as the same user as the default web server account. Typically this is 'triton'.\n";
    exit;
}

sub updateServerIniFile {
	if ($opt_verbose) {print "opening triton/cfg/server.ini file\n";}
	my $file = "triton/cfg/server.ini";
	my $tz = `date +%Z`;
	
	print "You must choose a DB engine for this new vhost\n";
	print "This script will NOT install the database, it must already be installed\n";
	$dbEngine = lc(&promptUser("Do you want to use MySQL (M) or Interbase (I) databases?","M"));
	if ($dbEngine eq "m") {
		$dbPass = &promptUser("You must enter a password to be used by the triton user for this vhost MySQL databse\n");
	}
	if ($dbEngine eq "i") {
		#$dbPass = &promptUser("You must enter a password to be used by the sysdba user for this vhost MySQL databse\n");
		print "For the purposes of this installation it is assumed you have a firebird DB installed with the appropriate password for the default 'sysdba' account.\n";
		print "If the DB is not properly setup it will fail here.\n\n";
	}	
	my $smtpServer = &promptUser("\n \nEnter the SMTP server for this Vhost","localhost");
	open (FILE, "<$file")|| die "Unable to open file to read: $file $!\n";
	my @lines = <FILE>;
	close FILE;
	open (FILE, ">$file")|| die "Unable to open file to write: $file $!\n";
	foreach my $line (@lines) {
		$_ = $line;
		if (/smtp_host/) {
			$line =~ s/$line/smtp_host=$smtpServer\n/;
		}		
		if (/TZ/) {
			$line =~ s/$line/TZ=$tz/;
		}
		if ($dbEngine eq "m" && /EngineDB/) {
			$line =~ s/ib/mysql/;
		}
		if ($dbEngine eq "m" && /mysql_db_password/) {
			$line =~ s/=.*/=$dbPass/;
		}		
		if ($dbEngine eq "i" && /EngineDB/) {
			$line =~ s/mysql/ib/;
		}	
		#print $line;
		print FILE $line;
	}
	close FILE;
}

sub installSystem {
	if ($opt_verbose) {print "Installing system modules\n";}
	print "If this is your first vhost on this server you may have to install the required system software (fonts, utilities etc)\n";
	print "You must have the sudo root password for this function\n";
	my $installSys = lc(&promptUser("Do you want to install required system software (y/n)","n"));
	print "\n";
	if ($installSys eq "y") {
		my $command = "sudo sh scripts/system-setup.sh";
		system($command) == 0 or die "Unable to install system software: $command failed: $?";
	}
}

sub installPerlModules {
	if ($opt_verbose) {print "Installing perl modules\n";}
	print "If this is your first vhost on this server you may have to install the required perl modules\n";
	print "You must have the sudo root password for this function\n";
	my $installPM = lc(&promptUser("Do you want to install required perl modules (y/n)","n"));
	print "\n";
	if ($installPM eq "y") {
		my $command = "sudo sh scripts/apt-perl-modules.sh";
		system($command) == 0 or die "Unable to install perl modules: $command failed: $?";
	}
}

sub buildIMFonts {
	if ($opt_verbose) {print "Building Font catalogue for ImageMagick \n";}
	print "\n";
	mkdir "~/.magick" if (!-d "~/.magick");
	if (!-f "~/.magick/type.xml") {
		my $command = qq{perl scripts/im.font.gen.pl >~/.magick/type.xml};
		system($command) == 0 or die "Unable to set up font catalogue : $command failed: $?";
	}
}

sub installDatabase {
	#extended from scripts/mkmydb.sh and scripts/mkibdb.sh
	if ($opt_verbose) {print "Installing chosen database\n";}
	if ($dbEngine eq "m") {
		my $mysqlPass = &promptUser("\n \nEnter the root password for your MySQL database");
		my $command = "mysql -u root -p$mysqlPass mysql -e \"CREATE USER 'triton'\@'localhost' IDENTIFIED BY '$dbPass';\"";
		system($command) == 0 or print "Ignore error here if the user triton already exists \n \n";
		#print "command: $command \n";
		$command = "mysql -u root -p$mysqlPass mysql -e \"create database IF NOT EXISTS vhost_$moduleName; grant all on vhost_$moduleName.* to triton\@localhost; flush privileges;\"";
		system($command) == 0 or print "Ignore error here if the mysql datebase for this vhost already exists \n \n";
	}
	if ($dbEngine eq "i") {
		print "Need to change the directory ownership so firebird can write the new db to it\nChanging to root user\n";
		my $command = "su -c \"chown firebird:firebird /home/vhosts/$host/triton/db/\" root";
		system($command) == 0 or die "Unable to change ownership of triton/db directory for firebird user: $command failed: $?";
		my $file = "/tmp/mkibdb.sql";
		open (FILE, ">$file")|| die "Unable to open file to write: $file $!\n";
		print FILE "create database 'localhost:/home/vhosts/$host/triton/db/triton.gdb';";
		print FILE "exit;";
		close FILE;
		my $command = "isql -u sysdba -p masterkey </tmp/mkibdb.sql";
		system($command) == 0 or print "Ignore error here if the firebird datebase for this vhost already exists: $command \n \n";
	}
	chdir("scripts/");
	my $command = "perl asptables.pl --create";
	print "Press ctrl+c when prompted 'About to try connection to rt database' to skip rt user reading\n";
	system($command) == 0 or die "Unable to work with database: $command failed: $?";
	$command = "perl asptables.pl --tpeople	";
	system($command) == 0 or die "Unable to work with database: $command failed: $?";
	chdir("../");
}

sub runInit {
	#extended from scripts/init.sh
	if ($opt_verbose) {print "Finishing running of scripts\n";}
	chdir("cgi-adm/");
	my $command = "perl aspupdate_htaccess.pl";
	system($command) == 0 or die "Unable to work with aspupdate: $command failed: $?";
	chdir("../");
	$command = "cvs -d /home/vhosts/$host/cvs/ init";
	system($command) == 0 or die "Unable to initialize cvs repository: $command failed: $?";
}

sub fixVhostTemplateFile {
	if ($opt_verbose) {print "Fixing apache Vhost file from template\n";}
	my $file = "triton/cfg/vhost.conf";
	my $IP = &promptUser("\n \nEnter the IP address and port number for the new Vhost","173.203.207.11:80");
	#my $alias = &promptUser("\n \nEnter a server alias for the new Vhost","www." . $host . "");
	open (FILE, "<$file")|| die "Unable to open file to read: $file $!\n";
	my @lines = <FILE>;
	close FILE;
	open (FILE, ">$file")|| die "Unable to open file to write: $file $!\n";
	foreach my $line (@lines) {
		$_ = $line;
		if (/VirtualHost/) {
			$line =~ s/206.131.250.16:80/$IP/;
		}
		#print $line;
		print FILE $line;
	}
	close FILE;	
}

sub installViewvc {
	if ($opt_verbose) {print "Installing viewvc from latest package on devel.triton-tech.com\n";}
	my $getVc = lc(&promptUser("\n \nDo you want to download viewVC for this vhost (requires triton user password if ssh keys not set up)? (y/n)","y"));
	if ($getVc eq "y") {
#		print "\nUser: triton\n";
		my $command = "scp -r triton\@devel.triton-tech.com:/home/vhosts/devel.triton-tech.com/viewvc-latest .";
		system($command) == 0 or die "Unable to get viewvc files from devel.triton-tech.com source: $command failed: $?";
		my $installVc = lc(&promptUser("\n \nViewVC Download complete.\n \nDo you want to install viewVC for this vhost? (y/n)","y"));
		if ($installVc eq "y") {
			my $command = "python viewvc-latest/viewvc-install --prefix=/home/vhosts/$host/viewvc/ --destdir=";
			system($command) == 0 or die "Unable to install viewvc: $command failed: $?";
			my $command = "rm -Rf viewvc-latest";
			system($command) == 0 or die "Unable to remove viewvc pre-build source directory: $command failed: $?";
			my $file = "viewvc/viewvc.conf";
			open (FILE, "<$file")|| die "Unable to open file to read: $file $!\n";
			my @lines = <FILE>;
			close FILE;
			open (FILE, ">$file")|| die "Unable to open file to write: $file $!\n";
			foreach my $line (@lines) {
				$_ = $line;
				if (/cvs_roots =/) {
					$line =~ s/$line/cvs_roots = Development : \/home\/vhosts\/$host\/cvs\n/;
				}		
				if (/default_root =/) {
					$line =~ s/$line/default_root = Development\n/;
				}
				print FILE $line;
			}
			close FILE;			
		}
	}
}

sub copyVhostTemplate {
	if ($opt_verbose) {print "Copy vhost file to apache site-available\n";}
	print "Debian only - Requires root user password\n";
	my $copy = lc(&promptUser("\n \nDo you want to copy the vhost template file to apache sites-available (y/n)","y"));
	if ($copy eq "y") {
		print "Writing this file to the apache directory requires root privileges\nChanging to root user\n";
		my $command = "su -c \"cp triton/cfg/vhost.conf /etc/apache2/sites-available/$host\" root";
		system($command) == 0 or die "Unable to copy vhost apache config file to apache directory: $command failed: $?";		
	}
}

sub symlinkApacheVhost {
	if ($opt_verbose) {print "Symlink vhost file to apache site-enabled\n";}
	print "Debian only - Requires root user password\n";
	my $symlink = lc(&promptUser("\n \nDo you want to symlink this file to apache sites-enabled (y/n)","y"));
	if ($symlink eq "y") {
		print "Writing this symlink to the apache directory requires root privileges\nChanging to root user\n";
		my $command = "su -c \"ln -s /etc/apache2/sites-available/$host /etc/apache2/sites-enabled/\" root";
		system($command) == 0 or die "Unable to symlink vhost apache config file to apache enabled directory: $command failed: $?";		
	}
}

sub restartApache {
	if ($opt_verbose) {print "Restarting Apache\n";}
	print "Debian only - Requires root user password\n";
	my $restart = lc(&promptUser("\n \nDo you want to restart apache (y/n)","y"));
	if ($restart eq "y") {
		print "Restarting apache requires root privileges\nChanging to root user\n";
		my $command = "su -c \"/usr/sbin/apache2ctl -k restart\" root";
		system($command) == 0 or die "Unable to restart the apache server: $command failed: $?";		
	}
	print "Testing machine users: edit /etc/hosts to view this VirtualHost locally \nThe entry should be \"127.0.0.1	$host\"\n\n";
}

sub removeAdminDirectory {
	if ($opt_verbose) {print "\n-------------\n removing Admin directory if present\n";}
	if (-e "admin/") {
		my $command = "rm -rf admin/";
		system($command) == 0 or die "Unable to export repository-- system command: $command failed: $?";
	}
	if ($opt_verbose) {print " admin directory removed\n-------------\n\n";}
}

sub updateTPeople {
	if (-e "cgi-adm/") {
		if ($opt_verbose) {print "\n-------------\n Updating authdb with tpeople\n";}
		my $cmd = qq{export REMOTE_USER=ac;perl cgi-adm/aspupdate_htaccess.pl};
		system($cmd) == 0 or die "Unable to update authdb with tpeople -- system command: $cmd failed: $?";
		if ($opt_verbose) {print " authdb updated for tpeople\n-------------\n\n";}
	}
}

sub createHtaccess {
	if (-e "cgi-adm/") {
		if ($opt_verbose) {print "creating .htaccess file \n";}
# Tweak .htaccess file for mobile user
		my $valid_user = ('triton' =~ /mobile/i) ? qq{
<FilesMatch "!(stationid_ssh\.pl)">
        require valid-user
</FilesMatch>
<FilesMatch "index.pl|stationidadmin.pl|aspjobcreate.pl|aspjobedit.pl|aspjobdelete.pl|aspcontrolpanel.pl|aspadmin.pl|aspupdate_htaccess.pl|datalist.pl|remote_test.pl">
        require valid-user
</FilesMatch>
} : qq{require valid-user};

		my $settings = qq {AuthUserFile /home/vhosts/$host/auth/authdb 
AuthName "$host Control Panel"
AuthType Basic
$valid_user
}; 

		my $htaFile = "cgi-adm/.htaccess";
		open (HTAFILE,">$htaFile") || die "Error $! encountered while writing file: $htaFile\n";
		print HTAFILE $settings;
		close HTAFILE;
		if ($opt_verbose) {print " file $htaFile created \n";}
	} else {
		print "not creating .htaccess file b/c cgi-adm directory not found.\n";
	}
}

sub createSymbolic {
	if ($opt_verbose) {print "\n-------------\n creating symbolic links\n";}
	if (-e "scripts") {
		chdir("scripts");
		symlink("../TPerl", "TPerl");
		chdir("../");
	}
	if (-e "cgi-mr") {
		chdir("cgi-mr");
		symlink("../TPerl", "TPerl");
		chdir("../");
	}
	if (-e "cgi-adm") {
		chdir("cgi-adm");
		symlink("../TPerl", "TPerl");
		chdir("../");
	}
	if (-e "dw") {
		chdir("dw");
		symlink("../TPerl", "TPerl");
		chdir("../");
	}
	#symlink(".htaccess", "dw/.htaccess");
	if ($opt_verbose) {print " symbolic links made\n-------------\n\n";}
}

sub createHtpassDB {
	my $command;
	print "Enter .htaccess user information for the new vhost (tpeople should already be there)\n";
	my $userName = &promptUser("Username", "tester");
	my $password = &promptUser("Password", "12345");
	my $htpasswd = '/usr/bin/htpasswd';
	my $htFile = "auth/authdb";
	if (!-e $htFile) {
		$command = "$htpasswd -c -b $htFile $userName $password";
	} else {
		$command = "$htpasswd -b $htFile $userName $password";
	}
	if ($opt_verbose) {print " creating apache htpasswd file for the new vhost command: $command \n";}
	system($command) == 0 or die "Unable to create apache htpasswd file-- system command: $command failed: $?";
	my $more = lc(&promptUser("Would you like to add another user y/n ?\n","n"));
	if ($more eq "y") {
		&createHtpassDB;
	} else {
		print "\n";
	}
}

sub promptUser {
   my($promptString,$defaultValue) = @_;
   if ($defaultValue) {
      print "$promptString ", "[", $defaultValue, "]: ";
   } else {
      print "$promptString ", ": ";
   }
   $| = 1;               # force a flush after our print
   $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)
   chomp;
   if ("$defaultValue") {
      return $_ ? $_ : $defaultValue;    # return $_ if it has a value
   } else {
      return $_;
   }
}

1;
