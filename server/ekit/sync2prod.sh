#!/bin/sh
# $Id: sync_template,v 1.6 2011-08-10 03:07:05 triton Exp $
# Sync the master area for ekit to the production server.
#
### Config
#
RSYNC='rsync -e ssh -turvzl --exclude=*.swp'
V_USER=triton
V_SERVER=new.mappwi.com
V_ROOT=ekit
M_ROOT=/home/vhosts/master/$V_ROOT
V_ROOT=/home/vhosts/$V_ROOT
#
# Check that we are in the right place
#
if [ ! -d $M_ROOT ]; then
	echo "M_ROOT $M_ROOT does not exist"
	exit
fi
#
# Now get on with the business:
#
cd $M_ROOT
#
SYNC="$RSYNC $M_ROOT/image/ $V_USER@$V_SERVER:$V_ROOT/"
echo $SYNC
$SYNC

