# plex server scripts

Deploy to `/opt/scripts` on the plex server:

```bash
scp -r scripts/ <user>@<server>:/opt/
chmod u+x /opt/scripts/*.sh
```

## Scripts

| Script | Description | Trigger |
|---|---|---|
| `backup.sh` | Stops Plex services, rsyncs key directories, creates zstd-compressed tarballs on the NAS, restarts Plex, then uploads to Google Drive via rclone | Cron |
| `start-all-docker.sh` | Pulls all images and starts all containers | Manual |

## Backup details

- **What's backed up**: Defined in `backup_include.txt` (`/etc/fstab`, systemd units, `/root/` dotfiles and scripts, `/opt/`, `/Plex/`)
- **Tarballs**: `plex-vm.tar.zst` (etc + root), `plex-opt.tar.zst` (opt), `plex-pms.tar.zst` (Plex data)
- **Logs**: `/var/log/backup.log`
- **Note**: Plex Media Server (systemd) and secondary Plex (Docker) are stopped during the rsync and restarted after, to ensure a consistent backup
