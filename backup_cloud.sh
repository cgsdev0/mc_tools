#!/bin/bash

PATH=$PATH:$HOME/bin
PATH=$PATH:/usr/local/bin

alert_and_exit() {
    echo "$@"
    alert "Minecraft backup failed!" "$@"
    exit 1
}

if [ -z "$1" ]; then
    alert_and_exit "no world specified"
fi

if [ -z "$2" ]; then
    alert_and_exit "no port specified"
fi

if [ ! -f "$HOME/.rcon_password" ]; then
    alert_and_exit "no rcon password file found"
fi

RCON="$HOME/go/bin/rcon-cli --port "$2" --password $(cat $HOME/.rcon_password)"

cd $HOME/minecraft

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
$RCON say Cloud backup starting... || alert_and_exit "failed to connect to rcon: say"

$RCON save-all || alert_and_exit "failed to connect to rcon: save-all"
$RCON save-off || alert_and_exit "failed to connect to rcon: save-off"

# Sync backup with current
rsync -a -q \
    --exclude 'backups' \
    --exclude 'dynmap' \
    --exclude 'plugins' \
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
