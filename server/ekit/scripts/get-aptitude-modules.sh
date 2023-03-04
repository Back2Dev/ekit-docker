#!/bin/bash
#$Id: get-aptitude-modules.sh,v 1.9 2011-08-30 02:55:34 triton Exp $
#
# This has evolved from get-cpan-modules.pl.
#
# Aptitude does a better job of checking dependencies to make the whole 
# experience smoother, and less order dependent. Some of these entries 
# are probably unnecessary, as the dependencies would pick them up anyway.
# Some are commented out, because it wasnt obvious using aptitude search
# which modules would work - this may necessitate some maintenance to fine 
# tune this script.

# WATCH OUT ALSO FOR:
# Win32/TieRegistry.pm - This is just a dummy
# Config/Ini.pm - This is defunct but we still use it
# DDB/Interbase - Doesnt install easily ? Mysql seems to be taking over anyway.


# this is should not be alphabetised.
#aptitude -y install libposix-perl
aptitude -y install libdigest-perl
#aptitude -y install libcgi-perl
#aptitude -y install libfindbin-perl
aptitude -y install libhtml-tagset-perl
aptitude -y install libhtml-parser-perl
aptitude -y install liburi-perl
#aptitude -y install libbundlelwp-perl
#aptitude -y install libio-stringy-perl
aptitude -y install libmail-perl
#aptitude -y install libmailheader-perl
#aptitude -y install libmailinternet-perl
aptitude -y install libmime-tools-perl
aptitude -y install libio-all-perl
aptitude -y install libtest-harness-perl
#aptitude -y install libtestmore-perl
#aptitude -y install libappconfig-perl
aptitude -y install libdbi-perl
aptitude -y install libapache-dbi-perl
aptitude -y install libapache-session-perl
aptitude -y install libdns-zoneparse-perl
aptitude -y install libstorable-perl
aptitude -y install libfile-slurp-perl
aptitude -y install libfile-rsync-perl
aptitude -y install libtime-local-perl
aptitude -y install libdate-manip-perl
#aptitude -y install liblistutil-perl
aptitude -y install libstring-approx-perl
aptitude -y install libtie-ixhash-perl
aptitude -y install libdata-dump-perl
aptitude -y install liblockfile-simple-perl
aptitude -y install libemail-valid-perl
aptitude -y install libmail-sender-perl
aptitude -y install templatetoolkit-perl
aptitude -y install libtemplate-plugin-dbi-perl

#aptitude -y install # libdbdinterbase-perl
#aptitude -y install # libdbdmysql-perl
aptitude -y install libemail-find-perl
#aptitude -y install libfilelockf-perl
#aptitude -y install libmailaudit-perl
aptitude -y install libconfig-inifiles-perl
aptitude -y install libconfig-ini-perl
aptitude -y install libmath-round-perl
aptitude -y install libtext-csv-xs-perl
aptitude -y install libtext-csv-perl
aptitude -y install libparse-recdescent-perl
aptitude -y install libspreadsheet-writeexcel-perl
aptitude -y install libspreadsheet-parseexcel-perl
aptitude -y install libdigest-sha1-perl
aptitude -y install libmail-spamassassin-perl
aptitude -y install libfile-path-perl
#aptitude -y install libgetopt-long-perl
aptitude -y install libmail-mboxparser-perl
#aptitude -y install libfile-handle-perl
#aptitude -y install libdir-handle-perl
aptitude -y install libhtml-entities-numbered-perl
aptitude -y install libfile-temp-perl
#aptitude -y install libhttp-cookies-perl
#aptitude -y install libcwd-perl
#aptitude -y install #filecopy-perl
aptitude -y install libfile-spec-perl
#aptitude -y install libtime-localtime-perl
#aptitude -y install # libcarp-perl
#aptitude -y install libio-socket-perl
#aptitude -y install libio-select-perl
aptitude -y install libunicode-map-perl
aptitude -y install libunicode-string-perl
aptitude -y install libfile-tail-perl
#aptitude -y install # libpodusage-perl
aptitude -y install libproc-processtable-perl
#aptitude -y install #filebasename-perl
aptitude -y install libterm-readkey-perl
#aptitude -y install libio-wraptie-perl
aptitude -y install libproc-background-perl
aptitude -y install libfile-touch-perl
#aptitude -y install # libcarpheavy-perl
#aptitude -y install libenv-perl
aptitude -y install libparams-validate-perl
#aptitude -y install #podman-perl
#aptitude -y install libgetopt-std-perl
#aptitude -y install libio-scalararray-perl
aptitude -y install libclass-factory-util-perl
aptitude -y install libclass-singleton-perl
aptitude -y install libmodule-build-perl
aptitude -y install libdatetime-locale-perl
aptitude -y install libdatetime-timezone-perl
#aptitude -y install libnet-pop3-perl

aptitude -y install libipc-sharelite-perl
aptitude -y install liberror-perl
aptitude -y install libcache-cache-perl
aptitude -y install libdevel-stacktrace-perl
aptitude -y install libclass-data-inheritable-perl
aptitude -y install libexception-class-perl
#aptitude -y install libapache-test-perl
aptitude -y install libapache-request-perl
aptitude -y install libclass-container-perl
aptitude -y install libhtml-mason-perl
aptitude -y install libmldbm-perl
aptitude -y install libfreezethaw-perl
aptitude -y install libtest-manifest-perl
aptitude -y install libxml-parser-perl
aptitude -y install libxml-rss-perl
aptitude -y install libfont-afm-perl
aptitude -y install libhtml-tree-perl
aptitude -y install libhtml-treebuilder-xpath-perl
aptitude -y install libhtml-format-perl
aptitude -y install libtest-inline-perl
aptitude -y install libclass-returnvalue-perl
aptitude -y install libwant-perl
#aptitude -y install libcache-simpletimedexpiry-perl
#aptitude -y install libdbixinstall-builder-perl
aptitude -y install libsub-uplevel-perl
#aptitude -y install libtest-buildertester-perl
aptitude -y install libtest-exception-perl
aptitude -y install libtext-reform-perl
aptitude -y install libtext-template-perl
aptitude -y install libhtml-scrubber-perl
aptitude -y install liblog-dispatch-perl
aptitude -y install liblocale-maketext-lexicon-perl
aptitude -y install liblocale-maketext-fuzzy-perl
aptitude -y install libtext-wrapper-perl
#aptitude -y install libtime-parsedate-perl
aptitude -y install libtext-autoformat-perl
aptitude -y install libtext-quoted-perl
aptitude -y install libtree-simple-perl
aptitude -y install libmodule-versions-report-perl
aptitude -y install libregexp-common-perl
aptitude -y install libtest-inline-perl
aptitude -y install libwww-mechanize-perl
aptitude -y install libfcgi-perl
aptitude -y install libcompress-zlib-perl
aptitude -y install libarchive-zip-perl
aptitude -y install libtree-dagnode-perl
aptitude -y install libconfig-inihash-perl
aptitude -y install libnumber-format-perl
aptitude -y install  libcurses-ui-perl
aptitude -y install  libgetopt-euclid-perl
aptitude -y install libreadonly-perl
aptitude -y install libtime-modules-perl
aptitude -y install libtimedate-perl
aptitude -y install libconvert-binhex-perl
aptitude -y install unzip
aptitude -y install lynx
aptitude -y install ncftp
aptitude -y install libio-stringy-perl
aptitude -y install links
aptitude -y install libmailtools-perl
aptitude -y install perlmagick
aptitude -y install imagemagick
aptitude -y install liblist-moreutils-perl
aptitude -y install zip
aptitude -y install libgd-graph-perl
aptitude -y install libgd-text-perl
aptitude -y install libcgi-perl
aptitude -y install libdbd-mysql
aptitude -y install libdbd-sybase
aptitude -y install libtext-diff-perl
aptitude -y install subversion
aptitude -y install libemail-filter-perl
aptitude -y install cvs
aptitude -y install elinks
aptitude -y install libappconfig-perl
aptitude -y install libmime-perl
aptitude -y install libtemplate-perl
aptitude -y install dh-make-perl
aptitude -y install libtemplate-perl-doc
aptitude -y install telnet
aptitude -y install libgd-gd2-perl
aptitude -y install ncftp2
aptitude -y install locate

#
# aptitude -y install  libstring-crc32-perl
wget http://search.cpan.org/CPAN/authors/id/F/FA/FAYS/Digest-Crc32-0.01.tar.gz
echo "You now need to unpack and install Digest-Crc32"
