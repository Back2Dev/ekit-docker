#!/bin/bash
#
for m in MAP002 MAP003 MAP004 MAP005 MAP006 MAP007 MAP008 MAP009 MAP010 MAP010A MAP011 MAP012 MAP018;
do 
cp ../triton/MAP001/html/nodata.htm ../triton/$m/html/
cp ../triton/MAP001/html/thanks.htm ../triton/$m/html/
done
