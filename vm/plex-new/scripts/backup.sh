#!/bin/bash
set -o pipefail

LOG_FILE="/var/log/backup.log"

vm_tarball="plex-vm.tar.zst"
opt_tarball="plex-opt.tar.zst"
plex_tarball="plex-pms.tar.zst"
backup_destination="/transcode/backup"
nas_backup_destination="/server-storage/backups/server-vm/plex-new"
scripts_dir="/opt/scripts"

log() {
    echo "[$(date '+%d/%m/%Y %T')] [$1] $2" >> "$LOG_FILE"
}

INFO()  { log "INFO"  "$*"; }
DEBUG() { log "DEBUG" "$*"; }
WARN()  { log "WARN"  "$*"; }
ERROR() { log "ERROR" "$*"; }

fail() {
    ERROR "$1"
    ERROR "Backup process FAILED"
    exit 1
}

stop_plex_services() {
    INFO "[01] Shutting down Plex Media Server for backup"
    systemctl stop plexmediaserver
    INFO "[02] Shutting down Secondary Plex Media Server for backup"
    /usr/bin/docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') stop plex
}

start_plex_services() {
    INFO "[04] Starting Plex Media Server..."
    systemctl start plexmediaserver
    DEBUG "Plex Media Server started"
    INFO "[05] Starting Secondary Plex Media Server..."
    /usr/bin/docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') start plex
    DEBUG "Secondary Plex Media Server started"
}

copy_to_backup_folder() {
    stop_plex_services

    INFO "[03] Copying files to backup folder"
    rsync -a --delete --include-from="$scripts_dir/backup_include.txt" / "$backup_destination" \
        || { start_plex_services; fail "rsync failed"; }
    DEBUG "Copy finished"

    start_plex_services
}

rotate_old_tarballs() {
    INFO "[06] Rotating old tarballs"
    for tarball in "$vm_tarball" "$opt_tarball" "$plex_tarball"; do
        if [ -f "$nas_backup_destination/$tarball" ]; then
            mv "$nas_backup_destination/$tarball" "$nas_backup_destination/backup_$tarball" \
                || fail "Failed to rotate $tarball"
            DEBUG "Rotated $tarball"
        else
            WARN "$tarball does not exist. Nothing to rotate"
        fi
    done
}

create_new_tarballs() {
    INFO "[07] Creating $vm_tarball"
    tar -cf - "$backup_destination/etc" "$backup_destination/root" | zstd -T0 -o "$nas_backup_destination/$vm_tarball" \
        || fail "Failed to create $vm_tarball"
    DEBUG "$vm_tarball created"

    INFO "[08] Creating $opt_tarball"
    tar -cf - "$backup_destination/opt" | zstd -T0 -o "$nas_backup_destination/$opt_tarball" \
        || fail "Failed to create $opt_tarball"
    DEBUG "$opt_tarball created"

    INFO "[09] Creating $plex_tarball"
    tar -cf - "$backup_destination/Plex" | zstd -T0 -o "$nas_backup_destination/$plex_tarball" \
        || fail "Failed to create $plex_tarball"
    DEBUG "$plex_tarball created"
}

teardown() {
    INFO "[10] Teardown starting"
    for tarball in "$vm_tarball" "$opt_tarball" "$plex_tarball"; do
        if [ -f "$nas_backup_destination/backup_$tarball" ]; then
            rm "$nas_backup_destination/backup_$tarball"
            DEBUG "Removed backup_$tarball"
        fi
    done
    DEBUG "Teardown finished"
}

upload_to_gdrive() {
    INFO "[11] Uploading to GDrive"
    rclone copy --transfers 4 --drive-chunk-size 16M "$nas_backup_destination" "remote-aleung:$nas_backup_destination" \
        || fail "rclone upload failed"
    DEBUG "Upload finished"
}

start_backup() {
    INFO "==================================="
    INFO "Starting backup process"

    copy_to_backup_folder
    rotate_old_tarballs
    create_new_tarballs
    teardown
    upload_to_gdrive

    INFO "Backup process finished"
}

start_backup
