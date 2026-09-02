#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/backup.log"

backup_date="$(date +%Y-%m-%d)"
vm_tarball="main-vm_${backup_date}.tar.zst"
opt_tarball="main-opt_${backup_date}.tar.zst"
backup_destination="/backup"
nas_backup_destination="/server-storage/backups/server-vm/main"
scripts_dir="/opt/scripts"
retention_days=35

mkdir -p "$(dirname "$LOG_FILE")"

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

cleanup_on_interrupt() {
    ERROR "Backup interrupted"
    exit 130
}
trap cleanup_on_interrupt INT TERM

copy_to_backup_folder() {
    INFO "[01] Copying files to backup folder"
    rsync -a --delete --include-from="$scripts_dir/backup_include.txt" / "$backup_destination" \
        || fail "rsync failed"
    DEBUG "Copy finished"
}

create_new_tarballs() {
    INFO "[02] Creating $vm_tarball"
    tar -cf - "$backup_destination/etc" "$backup_destination/root" "$backup_destination/var" | zstd -T0 -o "$nas_backup_destination/$vm_tarball.tmp" \
        || fail "Failed to create $vm_tarball"
    mv "$nas_backup_destination/$vm_tarball.tmp" "$nas_backup_destination/$vm_tarball"
    DEBUG "$vm_tarball created"

    INFO "[03] Creating $opt_tarball"
    tar -cf - "$backup_destination/opt" | zstd -T0 -o "$nas_backup_destination/$opt_tarball.tmp" \
        || fail "Failed to create $opt_tarball"
    mv "$nas_backup_destination/$opt_tarball.tmp" "$nas_backup_destination/$opt_tarball"
    DEBUG "$opt_tarball created"
}

upload_to_gdrive() {
    INFO "[04] Uploading to GDrive"
    rclone copy --transfers 4 --drive-chunk-size 16M "$nas_backup_destination" "remote-aleung:$nas_backup_destination" \
        || fail "rclone upload failed"
    DEBUG "Upload finished"
}

retain_backups() {
    INFO "[05] Pruning tarballs older than $retention_days days"
    pruned_files=$(find "$nas_backup_destination" -maxdepth 1 -type f -name '*.tar.zst' -mtime +"$retention_days" -print)
    if [ -n "$pruned_files" ]; then
        while IFS= read -r file; do
            basename_file="$(basename "$file")"
            remote_file="remote-aleung:${nas_backup_destination}/${basename_file}"
            rclone deletefile "$remote_file" || WARN "Failed to delete $remote_file from Google Drive"
            rm "$file" || WARN "Failed to delete $file locally"
            DEBUG "Pruned and removed remote copy of $basename_file"
        done <<< "$pruned_files"
    else
        DEBUG "No tarballs to prune"
    fi
}

start_backup() {
    INFO "==================================="
    INFO "Starting backup process"

    copy_to_backup_folder
    create_new_tarballs
    upload_to_gdrive
    retain_backups

    INFO "Backup process finished"
}

start_backup
