#!/bin/bash
# $Id: apt-perl-modules.sh,v 1.14 2011-08-30 02:55:34 triton Exp $
# This is the apt version of the get-cpan-modules.pl
# we include a few things that are used by the CPAN.pm initialisation.
# With Etch, there is nothing that can't be got from aptitude wich is nice.
aptitude install \
	links \
	lynx \
	elinks \
	zip \
	unzip \
	ncftp2 \
	ncftp \
	telnet \
	cvs \
	locate \
	subversion \
	libdigest-sha1-perl \
	libcgi-perl \
	liburi-perl \
	libmailtools-perl \
	libmime-perl \
	libdbi-perl \
	libdate-manip-perl \
	libconvert-binhex-perl  \
	libio-stringy-perl  \
	libtimedate-perl \
	libemail-filter-perl \
	libemail-filter-perl \
	libconfig-inifiles-perl\
	libfile-slurp-perl \
	libstring-approx-perl \
	libappconfig-perl \
	libfile-rsync-perl \
	libtime-modules-perl \
	liblockfile-simple-perl \
	libmail-sender-perl \
	libtemplate-perl	\
	libtemplate-perl-doc \
	libgd-gd2-perl \
	libgd-text-perl \
	libgd-graph-perl \
	libcompress-zlib-perl \
	libtext-csv-perl \
	libspreadsheet-writeexcel-perl \
	libdbd-mysql \
	libtie-ixhash-perl \
	libarchive-zip-perl \
	libtext-diff-perl \
	libfile-touch-perl \
	libdata-dump-perl \
	libemail-valid-perl \
	dh-make-perl \
	liblist-moreutils-perl\
	libreadonly-perl\
	libproc-processtable-perl \
	imagemagick \
	perlmagick \
	libgetopt-euclid-perl \
	libcurses-ui-perl \
	libnumber-format-perl \
	libconfig-inihash-perl \
	libtree-dagnode-perl \
	libwww-mechanize-perl  \
	libmodule-build-perl \
	libtext-template-perl \
	libxml-rss-perl \
	libhtml-parser-perl \
	libmime-tools-perl \
	liblocale-maketext-lexicon-perl \
	libtext-csv-xs-perl \
	libclass-container-perl \
	templatetoolkit-perl \
	liblocale-maketext-fuzzy-perl \
	libapache-dbi-perl \
	libregexp-common-perl \
	libtext-autoformat-perl \
	libmath-round-perl \
	libhtml-format-perl \
	libdatetime-timezone-perl \
	libapache-request-perl \
	libtest-inline-perl \
	libdigest-perl \
	libhtml-tree-perl \
	liberror-perl \
	libdevel-stacktrace-perl \
	libhtml-tagset-perl \
	libipc-sharelite-perl \
	libparse-recdescent-perl \
	libdatetime-locale-perl \
	libmodule-versions-report-perl \
	libclass-singleton-perl \
	libmldbm-perl \
	libtree-simple-perl \
	libio-all-perl \
	libfont-afm-perl \
	libclass-data-inheritable-perl \
	libhtml-mason-perl \
	libmail-mboxparser-perl \
	libwant-perl \
	libterm-readkey-perl \
	libfile-tail-perl \
	libunicode-map-perl \
	libhtml-treebuilder-xpath-perl \
	libunicode-string-perl \
	libemail-find-perl \
	libtext-wrapper-perl \
	libfile-path-perl \
	libfile-temp-perl \
	libclass-factory-util-perl \
	libhtml-entities-numbered-perl \
	libfreezethaw-perl \
	libcache-cache-perl \
	libproc-background-perl \
	libconfig-ini-perl \
	libtext-reform-perl \
	libxml-parser-perl \
	libtext-quoted-perl \
	libdns-zoneparse-perl \
	libfile-spec-perl \
	libmail-perl \
	libclass-returnvalue-perl \
	libtemplate-plugin-dbi-perl \
	libparams-validate-perl \
	libfcgi-perl \
	libsub-uplevel-perl \
	libexception-class-perl \
	libtime-local-perl \
	libmail-spamassassin-perl \
	libapache-session-perl \
	libhtml-scrubber-perl \
	libtest-manifest-perl \
	libtest-harness-perl \
	liblog-dispatch-perl \
	libstorable-perl \
	libspreadsheet-parseexcel-perl \
	libtest-exception-perl \




#	mail-audit-tools \		#depricated no longer available - replaced by mail-audit-tools
#	libmail-audit-perl \	#depricated no longer available - replaced by libmail-audit-perl
#	ncftp is now ncftp2 and ncft2 (named) is no longer a valid package name in ubuntu
#	libcgi-perl modules are now part of default perl and so this is not installable in ubuntu
