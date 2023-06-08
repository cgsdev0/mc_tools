#!/bin/bash

# Fail if anything goes wrong
set -e

if [ -z "$1" ]; then
    echo "Specify a world to backup."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Specify a port to use for rcon."
    exit 1
fi

RCON="/usr/bin/rcon -a 127.0.0.1:$2 -p $(cat /home/minecraft/.rcon_password) -t rcon"

cd /home/minecraft/servers

function cleanup() {
    rv=$?

    if [ $rv -ne 0 ]; then
        $RCON say Backup failed!
    else
        $RCON say Backup completed.
    fi

    # Always attempt to re-enable disk writes
    $RCON save-on
    exit $rv
}

trap cleanup EXIT

# Announce backup
$RCON say Local backup starting...

# Save current world
$RCON save-all

# Disable disk writes temporarily
$RCON save-off

# Sync backup with current
rsync -a -q \
    --exclude 'backups' \
    --exclude 'dynmap' \
    --exclude 'plugins' \
    --exclude 'cache' \
    --exclude 'logs' \
    "$1"/ ".$1-backup/"

# Compress the backup
tar -czf "backups/$1-backup-$(date +%m-%d-%y_%H:%M).tar.gz" ".$1-backup"

# Delete backups older than 24 hours
find /home/minecraft/backups -type f -mmin +720 -delete;


