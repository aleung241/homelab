#!/bin/bash

vm_tarball="plex-vm.tar.bz2"
opt_tarball="plex-opt.tar.bz2"
plex_tarball="plex-pms.tar.bz2"
backup_destination="/transcode/backup"
nas_backup_destination="server-storage/backups/server-vm/plex-new"

start_backup() {    
    INFO "==================================="
    INFO "Staring backup process"

    create_backups
    create_new_tarballs
    teardown
    upload_to_gdrive

    INFO "Backup process finished"
}

create_backups() {
    copy_to_backup_folder
    cd "/$nas_backup_destination"
    backup $vm_tarball
    backup $opt_tarball
    backup $plex_tarball
}

copy_to_backup_folder() {
    cd /opt/scripts

    INFO "[01] Shutting down Plex Media Server for backup"
    systemctl stop plexmediaserver
    INFO "[02] Shutting down Secondary Plex Media Server for backup"
    /usr/bin/docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') stop plex

    INFO "[03] Copying files to backup folder"
    rsync -a --delete --include-from=backup_include.txt / $backup_destination
    DEBUG "Copy finished"

    INFO "[04] Starting Plex Media Server..."
    systemctl start plexmediaserver
    DEBUG "Plex Media Server started"
    INFO "[05] Starting Secondary Plex Media Server..."
    /usr/bin/docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') start plex
    DEBUG "Secondary Plex Media Server started"
}

backup() {
    if test -f "$1"; then
        INFO "[06] Backing up $1"
        mv "$1" backup_"$1"
    else
        WARN "$1 does not exist. Not backing up"
    fi
}

create_new_tarballs() {
    tar_vm
    tar_opt
    tar_plex
}

tar_vm() {
    INFO "[07] Creating $vm_tarball"
    tar -cjf $vm_tarball "$backup_destination/etc" "$backup_destination/root"
    DEBUG "$vm_tarball created"
}

tar_opt() {
    INFO "[08] Creating $opt_tarball"
    tar -cjf $opt_tarball "$backup_destination/opt"
    DEBUG "$opt_tarball created"
}

tar_plex() {
    INFO "[09] Creating $plex_tarball"
    tar -cjf $plex_tarball "$backup_destination/Plex"
    DEBUG "$plex_tarball created"
}

teardown() {
    INFO "[10] Teardown starting"

    remove_backup backup_$vm_tarball
    remove_backup backup_$opt_tarball
    remove_backup backup_$plex_tarball

    DEBUG "Teardown finished"
}

remove_backup() {
    INFO "[11] Removing $1 backup"
    if test -f "$1"; then
        rm "$1"
    else
        WARN "$1 backup does not exist. Not removing"
    fi
}

upload_to_gdrive() {
    INFO "[12] Uploading to GDrive"
    rclone copy --transfers 4 --drive-chunk-size 16M "/$nas_backup_destination" "remote-aleung:$nas_backup_destination"
    DEBUG "Upload finished"
}

INFO() {
    echo "[$(date '+%d/%m/%Y %T')] [INFO] $*" >> /var/log/backup.log
}

DEBUG() {
    echo "[$(date '+%d/%m/%Y %T')] [DEBUG] $*" >> /var/log/backup.log
}

WARN() {
    echo "[$(date '+%d/%m/%Y %T')] [WARN] $*" >> /var/log/backup.log
}

start_backup