#!/bin/bash
# $Id: init_template,v 1.4 2011-08-10 03:07:04 triton Exp $
# Script to create stuff for ekit
#
cd /home/vhosts/ekit
mkdir logs
mkdir cvs
mkdir auth
#
# Update authdb...
#
export REMOTE_USER=ac
cd cgi-adm
perl aspupdate_htaccess.pl
cd ../scripts

#
# Create cvs stuff:
#
cvs -d /home/vhosts/ekit/cvs/ init
cd /usr/local/src/viewcvs-0.9.2
./viewcvs-install
#
# Copy our customised .conf file into place (replaces the default)
#
cd /home/vhosts/ekit/viewcvs-0.9.2
cp viewcvs.orig viewcvs.conf

cd /home/vhosts/ekit/scripts
