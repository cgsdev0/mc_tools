#!/bin/bash

PATH=$PATH:/home/sarah/bin
PATH=$PATH:/usr/local/bin

alert_and_exit() {
    echo "$@"
    alert "Minecraft backup failed!" "$@"
    exit 1
}

if [ -z "$1" ]; then
    alert_and_exit "no world specified"
fi

cd /home/minecraft/servers

# Sync backup with current
rsync -a -q \
    --exclude 'backups' \
    --exclude 'dynmap' \
    --exclude 'cache' \
    --exclude 'logs' \
    "$1/" ".$1-backup/"

test $? || alert_and_exit "rsync failed to run"

# Compress the backup
rm "backups/$1-backup-cloud.tar.gz"
tar -czf "backups/$1-backup-cloud.tar.gz" ".$1-backup"
test $? || alert_and_exit "tar failed to run"

# Upload to backblaze
b2_result=$(b2 upload-file --noProgress \
    coolgamrsms-minecraft-archives \
    "backups/$1-backup-cloud.tar.gz" \
    "$1.tar.gz" 2>&1)

code=$?
action=$(echo "$b2_result" | tail +3 | jq -r '.action')
(test $code && [[ "$action" == "upload" ]]) || alert_and_exit "$b2_result"

# Clean up
rm "backups/$1-backup-cloud.tar.gz"
