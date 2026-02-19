# main server scripts

Deploy to `/opt/scripts` on the main server:

```bash
scp -r scripts/ <user>@<server>:/opt/
chmod u+x /opt/scripts/*.sh
```

## Scripts

| Script | Description | Trigger |
|---|---|---|
| `backup.sh` | Rsyncs key directories to a local backup folder, creates zstd-compressed tarballs on the NAS, then uploads to Google Drive via rclone | Cron |
| `todrive.sh` | Interactive rclone upload to Google Drive. Prompts for folder selection and transfer count | Manual |
| `start-all-docker.sh` | Pulls all images and starts all containers | Manual |

## Backup details

- **What's backed up**: Defined in `backup_include.txt` (`/etc/fstab`, systemd units, `/root/` dotfiles and scripts, `/opt/`)
- **Tarballs**: `main-vm.tar.zst` (etc + root), `main-opt.tar.zst` (opt)
- **Logs**: `/var/log/backup.log`
