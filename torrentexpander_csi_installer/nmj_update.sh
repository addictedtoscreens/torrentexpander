#!/bin/sh

# This script can be executed to update NMJ database.
if [ "$(pgrep scannerx)" == "" ]; then 
	echo "Start updating NMJ"
	wget --delete-after "http://localhost:8008/metadata_database?arg0=scanner_start&arg1=SATA_DISK/nmj_database/media.db&arg2=background&arg3=" >/dev/null 2>&1
else 
	echo "Update already started" 
fi