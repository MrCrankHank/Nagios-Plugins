#!/bin/bash
#
# Author: MrCrankHank
#

function usage() {
        echo "./check_proxmox_backup.sh <STORAGE> <VMID> <MAX_OLD_DAYS>"
        echo
        echo "STORAGE:  Name of your proxmox backup storage"
        echo "VMID:             VMID of the vm you want to check"
        echo "MAX_OLD_DAYS:     The script will trigger a critical alert if the backup is older then the days specified in this var."
        echo
        echo "The user nagios executes the pvesm binary via sudo. For this to work you have to modify your /etc/sudoers. E.g:"
        echo "  'nagios ALL=NOPASSWD: /usr/sbin/pvesm list *'"
        exit 1
}

if [[ -z $1 || -z $2 || -z $3 ]]; then
        usage
fi

# pvesm bin
PVESM=/usr/sbin/pvesm

# Temp file for pvesm output
LIST=/tmp/pvesmlist

# Name of your proxmox backup storage
BACKUP_STORAGE=$1

# vmid of the vm you want to check
ID=$2

# The script triggers an critical alert if the last backup is older than $MAX_OLD_DAYS days
MAX_OLD_DAYS=$3

sudo $PVESM list $BACKUP_STORAGE | grep "vzdump-qemu-$ID" > $LIST
COUNT=$(wc -l < $LIST)

if [ $COUNT -eq 0 ]; then
        echo "Critical - No backups of vm $ID"
        exit 2
fi

line=$(cat $LIST | tail -1)

# Really, really ugly, but gets the job done. If you have a better way, please don't hesitate to contact me.
size=$(echo $line | tr -d "[A-Z][a-z][.][:][/][\-]" | cut -c 4- | sed 's/[^ ]* //' | tr -d "[ ]")
size="$(( $size / 1024 ))"
size="$(( $size / 1024 ))"
year=$(echo $line | tr -d "[A-Z][a-z][.][:][/]" | cut -c 7- | cut -d' ' -f1 | grep -oP "[0-9]{4}")
month=$(echo $line | tr -d "[A-Z][a-z][.][:][/]" | cut -d' ' -f1 | cut -c 12-)
month=$(echo ${month::2})
day=$(echo $line | tr -d "[A-Z][a-z][.][:][/]" |  cut -d' ' -f1 | cut -c 15-)
day=$(echo ${day::2})
hour=$(echo $line | tr -d "[A-Z][a-z][.][:][/]" |  cut -d' ' -f1 | cut -c 18-)
hour=$(echo ${hour::2})
minute=$(echo $line | tr -d "[A-Z][a-z][.][:][/]" |  cut -d' ' -f1 | cut -c 21-)
minute=$(echo ${minute::2})
second=$(echo $line | tr -d "[A-Z][a-z][.][:][/]" |  cut -d' ' -f1 | cut -c 24-)

##############################################################################################################

date="$month/$day/$year"
DATE_LOG=$(date +%m/%d/%y -d "$date + $MAX_OLD_DAYS day")
DATE_LOG_SEC=$(date -d $DATE_LOG '+%s')
TODAY=`date +%m/%d/%y`
TODAY=$(date -d "$TODAY" '+%s')

if [ -f $LIST ]; then
        rm $LIST
fi

if [ $TODAY -ge $DATE_LOG_SEC ]; then
        echo "Critical - $COUNT total backups of vm $ID. Last backup is from $date ${hour}:${minute}:${second}. Size: $size MB"
        exit 2
else
        echo "OK - $COUNT total backups of vm $ID. Last backup is from $date ${hour}:${minute}:${second}. Size: $size MB"
        exit 0
fi