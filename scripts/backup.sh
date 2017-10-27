#!/bin/bash
#
# backup script of openhab/homegear
#
# can be installed like this (there cannot be a dot inside the cron scripta):
# cd /etc/cron.weekly
# ln -s /home/pi/arduino_rpi_openhab/scripts/backup.sh backup_rpi
#
notify() {
  if [ ! -z "$1" ]; then
    "$1" "$2"
  fi
}
workdir=$(dirname $(readlink -f $0))
if [ -e ${workdir}/backup.conf ]; then
  . ${workdir}/backup.conf
fi
DESTDIR=${DESTDIR:-/mnt/nas}
if [ ! -d $DESTDIR ]; then
  msg="Destintion directory $DESTDIR does not exist" 1>&2
  echo "$msg" 1>&2
  notify "$NOTIFY" "$msg"
  exit 1
fi
echo Backup to $DESTDIR, called from $workdir
date=$(date +%F)
tar -vczf ${DESTDIR}/backup-$date.tgz --files-from=${workdir}/backuplist.txt
if [ $? -eq 0 ]; then
  notify "$NOTIFY" "Backup $0 done"
else
  notify "$NOTIFY" "Backup $0 failed"
fi
