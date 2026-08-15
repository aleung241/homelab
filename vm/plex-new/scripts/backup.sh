#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/backup.log"

backup_date="$(date +%Y-%m-%d)"
vm_tarball="plex-vm_${backup_date}.tar.zst"
opt_tarball="plex-opt_${backup_date}.tar.zst"
plex_tarball="plex-pms_${backup_date}.tar.zst"
backup_destination="/transcode/backup"
nas_backup_destination="/server-storage/backups/server-vm/plex-new"
scripts_dir="/opt/scripts"
retention_days=35
plex_services_started=false

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo -e "[$(date '+%d/%m/%Y %T')] [$1] $2" >> "$LOG_FILE"
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

compose_files=$(find /opt/docker -maxdepth 1 -type f -name '*.yml' | sed 's|^|-f |')

stop_plex_services() {
    INFO "[01] Shutting down Plex Media Server for backup"
    systemctl stop plexmediaserver
    INFO "[02] Shutting down Secondary Plex Media Server for backup"
    /usr/bin/docker compose $compose_files stop plex
}

start_plex_services() {
    if [ "$plex_services_started" = true ]; then
        return 0
    fi
    plex_services_started=true

    INFO "[03] Starting Plex Media Server..."
    systemctl start plexmediaserver || WARN "Failed to start system Plex Media Server"
    DEBUG "Plex Media Server started"
    INFO "[04] Starting Secondary Plex Media Server..."
    /usr/bin/docker compose $compose_files start plex || WARN "Failed to start Docker Plex Media Server"
    DEBUG "Secondary Plex Media Server started"
}

restart_plex_services() {
    start_plex_services || true
}
trap restart_plex_services EXIT INT TERM

copy_to_backup_folder() {
    stop_plex_services

    INFO "[05] Copying files to backup folder"
    rsync -a --delete --include-from="$scripts_dir/backup_include.txt" / "$backup_destination" \
        || fail "rsync failed"
    DEBUG "Copy finished"
}

create_new_tarballs() {
    INFO "[06] Creating $vm_tarball"
    tar -cf - "$backup_destination/etc" "$backup_destination/root" | zstd -T0 -o "$nas_backup_destination/$vm_tarball.tmp" \
        || fail "Failed to create $vm_tarball"
    mv "$nas_backup_destination/$vm_tarball.tmp" "$nas_backup_destination/$vm_tarball"
    DEBUG "$vm_tarball created"

    INFO "[07] Creating $opt_tarball"
    tar -cf - "$backup_destination/opt" | zstd -T0 -o "$nas_backup_destination/$opt_tarball.tmp" \
        || fail "Failed to create $opt_tarball"
    mv "$nas_backup_destination/$opt_tarball.tmp" "$nas_backup_destination/$opt_tarball"
    DEBUG "$opt_tarball created"

    INFO "[08] Creating $plex_tarball"
    tar -cf - "$backup_destination/Plex" | zstd -T0 -o "$nas_backup_destination/$plex_tarball.tmp" \
        || fail "Failed to create $plex_tarball"
    mv "$nas_backup_destination/$plex_tarball.tmp" "$nas_backup_destination/$plex_tarball"
    DEBUG "$plex_tarball created"
}

upload_to_gdrive() {
    INFO "[09] Uploading to GDrive"
    rclone copy --transfers 4 --drive-chunk-size 16M "$nas_backup_destination" "remote-aleung:$nas_backup_destination" \
        || fail "rclone upload failed"
    DEBUG "Upload finished"
}

retain_backups() {
    INFO "[10] Pruning tarballs older than $retention_days days"
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
    INFO "Backup Script version: 27 Feb 2026"
    INFO "==================================="
    INFO "Starting backup process"

    copy_to_backup_folder
    start_plex_services
    create_new_tarballs
    upload_to_gdrive
    retain_backups

    INFO "Backup process finished"
}

start_backup
