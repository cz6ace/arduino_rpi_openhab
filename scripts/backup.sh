#!/bin/bash
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
notify "$NOTIFY" "Backup $0 done"
