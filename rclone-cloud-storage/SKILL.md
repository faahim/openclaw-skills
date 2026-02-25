---
name: rclone-cloud-storage
description: >-
  Sync, backup, and manage files across 40+ cloud providers (S3, Google Drive, Dropbox, Backblaze, SFTP, and more) using rclone.
categories: [data, automation]
dependencies: [rclone, bash, cron]
---

# Rclone Cloud Storage Manager

## What This Does

Manage files across 40+ cloud storage providers from your terminal. Sync local directories to the cloud, schedule automated backups, mount remote storage as local drives, and transfer between providers — all through rclone, the Swiss Army knife of cloud storage.

**Example:** "Backup /home/projects to Backblaze B2 every night, sync photos to Google Drive, mount S3 bucket as local folder."

## Quick Start (5 minutes)

### 1. Install Rclone

```bash
bash scripts/install.sh
```

### 2. Configure a Remote

```bash
bash scripts/manage-remote.sh add mycloud s3
# Follow prompts for provider-specific auth
# Or configure interactively:
rclone config
```

### 3. Start Syncing

```bash
# Sync a local folder to cloud
bash scripts/sync.sh /home/user/documents mycloud:my-bucket/documents

# Output:
# [2026-02-25 08:00:00] 📤 Syncing /home/user/documents → mycloud:my-bucket/documents
# [2026-02-25 08:00:15] ✅ Transferred: 42 files (128.5 MiB), Elapsed: 15s
```

## Core Workflows

### Workflow 1: One-Way Sync (Local → Cloud)

**Use case:** Keep a cloud copy of local files in sync

```bash
bash scripts/sync.sh /path/to/local remote:bucket/path

# Dry run first (see what would change):
bash scripts/sync.sh /path/to/local remote:bucket/path --dry-run

# With bandwidth limit (10 MiB/s):
bash scripts/sync.sh /path/to/local remote:bucket/path --bwlimit 10M
```

### Workflow 2: Bidirectional Sync

**Use case:** Keep two locations in sync (like Dropbox)

```bash
bash scripts/bisync.sh /path/to/local remote:bucket/path

# First run requires --resync:
bash scripts/bisync.sh /path/to/local remote:bucket/path --resync
```

### Workflow 3: Scheduled Backup with Retention

**Use case:** Nightly backup with 30-day retention

```bash
# Set up automated backup
bash scripts/backup.sh setup \
  --source /home/user/important \
  --dest remote:backups/important \
  --schedule "0 2 * * *" \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6

# Run backup manually
bash scripts/backup.sh run \
  --source /home/user/important \
  --dest remote:backups/important

# Output:
# [2026-02-25 02:00:00] 🔄 Starting backup: /home/user/important → remote:backups/important
# [2026-02-25 02:00:00] 📁 Snapshot: backups/important/2026-02-25T020000
# [2026-02-25 02:03:22] ✅ Backup complete: 1.2 GiB transferred, 3m22s elapsed
# [2026-02-25 02:03:23] 🗑️ Pruned 2 old snapshots (retention policy: 7d/4w/6m)
```

### Workflow 4: Mount Remote as Local Drive

**Use case:** Access cloud storage as if it were a local folder

```bash
bash scripts/mount.sh remote:bucket /mnt/cloud

# With caching for better performance:
bash scripts/mount.sh remote:bucket /mnt/cloud --vfs-cache-mode full

# Unmount:
fusermount -u /mnt/cloud
```

### Workflow 5: Cloud-to-Cloud Transfer

**Use case:** Migrate files between providers (e.g., Dropbox → S3)

```bash
bash scripts/sync.sh dropbox:Photos s3:my-bucket/photos
# Rclone handles the transfer server-side when possible
```

### Workflow 6: Encrypted Backup

**Use case:** Encrypt files before uploading

```bash
# Set up encrypted remote (wraps another remote)
bash scripts/manage-remote.sh add-crypt encrypted-backup mycloud:encrypted-data

# Now sync to encrypted remote — files are encrypted at rest
bash scripts/sync.sh /home/user/sensitive encrypted-backup:
```

## Configuration

### Supported Providers (40+)

| Provider | Type | Config Key |
|----------|------|------------|
| Amazon S3 | `s3` | Access key + secret |
| Google Drive | `drive` | OAuth token |
| Dropbox | `dropbox` | OAuth token |
| Backblaze B2 | `b2` | Application key |
| Microsoft OneDrive | `onedrive` | OAuth token |
| SFTP/SSH | `sftp` | Host + key/password |
| Google Cloud Storage | `gcs` | Service account |
| Azure Blob | `azureblob` | Account + key |
| Cloudflare R2 | `s3` | R2 credentials |
| Wasabi | `s3` | Access key + secret |
| MinIO | `s3` | Endpoint + credentials |
| FTP | `ftp` | Host + credentials |
| WebDAV | `webdav` | URL + credentials |
| Mega | `mega` | Email + password |
| pCloud | `pcloud` | OAuth token |

Full list: `rclone help backends`

### Environment Variables

```bash
# Global bandwidth limit
export RCLONE_BWLIMIT="10M"

# Default number of parallel transfers
export RCLONE_TRANSFERS="8"

# Config file location (default: ~/.config/rclone/rclone.conf)
export RCLONE_CONFIG="/path/to/rclone.conf"

# For S3-compatible (set per-remote or globally)
export RCLONE_S3_ACCESS_KEY_ID="your-key"
export RCLONE_S3_SECRET_ACCESS_KEY="your-secret"
export RCLONE_S3_ENDPOINT="https://s3.us-west-002.backblazeb2.com"
```

### Backup Config (YAML)

```yaml
# backup-config.yaml
backups:
  - name: documents
    source: /home/user/documents
    dest: b2:my-bucket/documents
    schedule: "0 2 * * *"  # 2 AM daily
    retention:
      daily: 7
      weekly: 4
      monthly: 12
    filters:
      - "- *.tmp"
      - "- .cache/**"
      - "+ **"

  - name: photos
    source: /home/user/photos
    dest: gdrive:Backups/photos
    schedule: "0 3 * * 0"  # 3 AM Sundays
    retention:
      daily: 3
      weekly: 8
    bandwidth: "5M"
```

## Advanced Usage

### Filter Files

```bash
# Exclude patterns
bash scripts/sync.sh /local remote:bucket \
  --exclude "*.tmp" \
  --exclude ".git/**" \
  --exclude "node_modules/**"

# Include only certain files
bash scripts/sync.sh /local remote:bucket \
  --include "*.jpg" \
  --include "*.png" \
  --exclude "*"

# Use filter file
bash scripts/sync.sh /local remote:bucket --filter-from filters.txt
```

### Check Integrity

```bash
# Verify files match between local and remote
rclone check /local remote:bucket

# Output:
# 2026/02/25 08:00:00 NOTICE: 0 differences found
# 2026/02/25 08:00:00 NOTICE: 1234 matching files
```

### Storage Usage Report

```bash
# Check remote storage usage
bash scripts/usage.sh remote:bucket

# Output:
# 📊 Storage Report: remote:bucket
# ├── Total files: 12,345
# ├── Total size: 45.6 GiB
# ├── Largest: videos/project.mp4 (2.1 GiB)
# └── By type:
#     ├── .jpg: 8,234 files (12.3 GiB)
#     ├── .mp4: 156 files (28.1 GiB)
#     └── .pdf: 892 files (5.2 GiB)
```

### Run as Cron Job

```bash
# Add automated backup to crontab
bash scripts/backup.sh setup \
  --source /home/user/data \
  --dest remote:backups \
  --schedule "0 3 * * *"

# Or manually add to crontab:
# 0 3 * * * /path/to/scripts/sync.sh /home/user/data remote:backups >> /var/log/rclone-backup.log 2>&1
```

## Troubleshooting

### Issue: "command not found: rclone"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
curl https://rclone.org/install.sh | sudo bash
```

### Issue: Permission denied on mount

**Fix:**
```bash
# Install FUSE
sudo apt-get install fuse3
# Allow non-root mounts
sudo sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf
```

### Issue: OAuth token expired (Google Drive, Dropbox)

**Fix:**
```bash
rclone config reconnect myremote:
# Follow browser auth flow
```

### Issue: Slow transfers

**Fix:**
```bash
# Increase parallel transfers (default 4)
bash scripts/sync.sh /local remote:bucket --transfers 16

# Use server-side copy when moving between same provider
rclone copy remote1:path remote2:path --s3-no-check-bucket
```

### Issue: Out of disk space during mount cache

**Fix:**
```bash
# Limit VFS cache size
bash scripts/mount.sh remote:bucket /mnt/cloud \
  --vfs-cache-mode full \
  --vfs-cache-max-size 5G
```

## Dependencies

- `rclone` (installed by scripts/install.sh)
- `bash` (4.0+)
- `cron` (for scheduled backups)
- `fuse3` (optional, for mounting)
- `jq` (for usage reports)
