#!/bin/bash
#  $Id: mkmydb_template,v 1.5 2011-08-10 03:07:05 triton Exp $
# Mysql Database creation script
#
mysql mysql -e "create database IF NOT EXISTS vhost_MYDBNAME; grant all on vhost_MYDBNAME.* to triton@localhost; flush privileges;"
#
# Now do the table creation stuff
#
cd /home/vhosts/ekit/scripts
#
perl asptables.pl --create
perl asptables.pl --tpeople
#
# Tell the user what comes next:
#
echo "Now you should run /home/vhosts/ekit/scripts/init.sh"

