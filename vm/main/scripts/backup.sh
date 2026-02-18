#!/bin/bash
set -o pipefail

LOG_FILE="/var/log/backup.log"

vm_tarball="main-vm.tar.zst"
opt_tarball="main-opt.tar.zst"
backup_destination="/backup"
nas_backup_destination="/server-storage/backups/server-vm/main"
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

copy_to_backup_folder() {
    INFO "[01] Copying files to backup folder"
    rsync -a --delete --include-from="$scripts_dir/backup_include.txt" / "$backup_destination" \
        || fail "rsync failed"
    DEBUG "Copy finished"
}

rotate_old_tarballs() {
    INFO "[02] Rotating old tarballs"
    for tarball in "$vm_tarball" "$opt_tarball"; do
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
    INFO "[03] Creating $vm_tarball"
    tar -cf - "$backup_destination/etc" "$backup_destination/root" | zstd -T0 -o "$nas_backup_destination/$vm_tarball" \
        || fail "Failed to create $vm_tarball"
    DEBUG "$vm_tarball created"

    INFO "[04] Creating $opt_tarball"
    tar -cf - "$backup_destination/opt" | zstd -T0 -o "$nas_backup_destination/$opt_tarball" \
        || fail "Failed to create $opt_tarball"
    DEBUG "$opt_tarball created"
}

teardown() {
    INFO "[05] Teardown starting"
    for tarball in "$vm_tarball" "$opt_tarball"; do
        if [ -f "$nas_backup_destination/backup_$tarball" ]; then
            rm "$nas_backup_destination/backup_$tarball"
            DEBUG "Removed backup_$tarball"
        fi
    done
    DEBUG "Teardown finished"
}

upload_to_gdrive() {
    INFO "[06] Uploading to GDrive"
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
