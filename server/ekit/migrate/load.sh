#!/bin/bash
#
# Kwik script to load database from dump
#
gunzip -f ekit.dump.sql.gz 
mysql -f vhost_ekit <ekit.dump.sql -p

