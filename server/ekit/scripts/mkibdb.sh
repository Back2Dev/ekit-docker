#!/bin/bash
# $Id: mkibdb_template,v 1.5 2011-08-10 03:07:05 triton Exp $
# Script to create Interbase database for ekit
#
#
echo >/tmp/mkibdb.sql "commit;";
echo >/tmp/mkibdb.sql "create database '/home/vhosts/ekit/triton/db/triton.gdb';";
echo >>/tmp/mkibdb.sql "exit;";
isql -u sysdba -p masterkey </tmp/mkibdb.sql
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
