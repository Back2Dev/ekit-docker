#!/bin/bash
#
# Kwik script to pull the ekit data from the production machine
#
SRC="old.mappwi.com"
RSYNC="rsync -e ssh -rtuvzg"
#
for m in pwikit MAP001 MAP002 MAP003 MAP004 MAP005 MAP006 MAP007 MAP008 MAP010 MAP010A MAP011 MAP012 MAP018 MAP026;
do 
$RSYNC $SRC:/home/vhosts/ekit.mappwi.com/triton/$m/* ../triton/$m/
done

$RSYNC $SRC:/home/vhosts/ekit.mappwi.com/triton/PARTICIPANT/* ../triton/PARTICIPANT/


