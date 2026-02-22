---
name: cloud-sync-backup
description: >-
  Sync and backup files to any cloud storage (S3, B2, GDrive, Dropbox, SFTP) using rclone with encryption and scheduling.
categories: [data, automation]
dependencies: [rclone, bash, cron]
---

# Cloud Sync & Backup

## What This Does

Automates file sync and encrypted backup to 40+ cloud storage providers using rclone. Supports AWS S3, Backblaze B2, Google Drive, Dropbox, DigitalOcean Spaces, MinIO, SFTP, and more. Set up once, schedule backups with compression and optional encryption — never lose data again.

**Example:** "Back up /home/projects to Backblaze B2 every night at 2am, encrypted, with 30-day retention."

## Quick Start (5 minutes)

### 1. Install rclone

```bash
bash scripts/install.sh
```

This installs rclone if not present and verifies the installation.

### 2. Configure a Remote

```bash
bash scripts/setup-remote.sh s3 \
  --provider "AWS" \
  --access-key "$AWS_ACCESS_KEY_ID" \
  --secret-key "$AWS_SECRET_ACCESS_KEY" \
  --region "us-east-1" \
  --bucket "my-backups"
```

Or for Backblaze B2:

```bash
bash scripts/setup-remote.sh b2 \
  --provider "B2" \
  --account "$B2_ACCOUNT_ID" \
  --key "$B2_APP_KEY" \
  --bucket "my-backups"
```

Or interactive setup:

```bash
rclone config
```

### 3. Run First Backup

```bash
bash scripts/backup.sh \
  --source /home/projects \
  --remote s3:my-backups/projects \
  --compress \
  --log /var/log/cloud-backup.log
```

### 4. Schedule Nightly Backups

```bash
bash scripts/schedule.sh \
  --source /home/projects \
  --remote s3:my-backups/projects \
  --cron "0 2 * * *" \
  --compress \
  --encrypt \
  --retention 30
```

## Core Workflows

### Workflow 1: Simple File Sync

**Use case:** Keep a local folder in sync with cloud storage

```bash
bash scripts/backup.sh \
  --source /home/data \
  --remote s3:bucket/data \
  --mode sync
```

**Output:**
```
[2026-02-22 02:00:00] 🔄 Starting sync: /home/data → s3:bucket/data
[2026-02-22 02:00:15] ✅ Transferred: 23 files (148.2 MB)
[2026-02-22 02:00:15] ⏱️  Duration: 15s | Speed: 9.9 MB/s
[2026-02-22 02:00:15] 📊 New: 3 | Updated: 2 | Deleted: 0 | Unchanged: 18
```

### Workflow 2: Compressed Encrypted Backup

**Use case:** Secure backup with compression

```bash
bash scripts/backup.sh \
  --source /home/projects \
  --remote b2:backups/projects \
  --compress \
  --encrypt \
  --password "$BACKUP_PASSWORD"
```

Creates a timestamped tar.gz.gpg archive on the remote.

### Workflow 3: Database Dump + Cloud Backup

**Use case:** Back up PostgreSQL/MySQL to cloud

```bash
bash scripts/backup.sh \
  --pre-cmd "pg_dump mydb > /tmp/mydb.sql" \
  --source /tmp/mydb.sql \
  --remote s3:backups/db/ \
  --compress \
  --post-cmd "rm /tmp/mydb.sql"
```

### Workflow 4: Multi-Directory Backup

**Use case:** Back up multiple paths in one run

```bash
bash scripts/backup.sh \
  --config backup-config.yaml \
  --log /var/log/cloud-backup.log
```

### Workflow 5: Restore from Backup

```bash
bash scripts/restore.sh \
  --remote s3:backups/projects/2026-02-22.tar.gz \
  --target /home/restored \
  --decrypt \
  --password "$BACKUP_PASSWORD"
```

### Workflow 6: List & Prune Old Backups

```bash
# List backups
bash scripts/manage.sh list --remote s3:backups/projects/

# Prune backups older than 30 days
bash scripts/manage.sh prune --remote s3:backups/projects/ --retention 30

# Check total size
bash scripts/manage.sh size --remote s3:backups/
```

## Configuration

### Config File Format (YAML)

```yaml
# backup-config.yaml
remotes:
  primary:
    type: s3
    bucket: my-backups
    region: us-east-1

jobs:
  - name: projects
    source: /home/projects
    remote: primary:projects
    schedule: "0 2 * * *"
    compress: true
    encrypt: true
    retention_days: 30
    exclude:
      - "node_modules/"
      - ".git/"
      - "*.log"

  - name: database
    pre_cmd: "pg_dump mydb > /tmp/mydb.sql"
    source: /tmp/mydb.sql
    remote: primary:db
    schedule: "0 */6 * * *"
    compress: true
    post_cmd: "rm /tmp/mydb.sql"
    retention_days: 14

  - name: configs
    source: /etc
    remote: primary:configs
    schedule: "0 3 * * 0"
    compress: true
    retention_days: 90
    include:
      - "nginx/**"
      - "ssh/**"
      - "crontab"
```

### Environment Variables

```bash
# AWS S3
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# Backblaze B2
export B2_ACCOUNT_ID="your-account"
export B2_APP_KEY="your-key"

# Encryption password
export BACKUP_PASSWORD="your-encryption-password"

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="bot-token"
export TELEGRAM_CHAT_ID="chat-id"
```

## Advanced Usage

### Bandwidth Limiting

```bash
bash scripts/backup.sh \
  --source /home/data \
  --remote s3:bucket/data \
  --bwlimit "10M"  # Limit to 10 MB/s
```

### Exclude Patterns

```bash
bash scripts/backup.sh \
  --source /home/projects \
  --remote s3:bucket/projects \
  --exclude "node_modules/" \
  --exclude ".git/" \
  --exclude "*.tmp"
```

### Dry Run (Preview)

```bash
bash scripts/backup.sh \
  --source /home/data \
  --remote s3:bucket/data \
  --dry-run
```

### Alert on Failure

```bash
bash scripts/backup.sh \
  --source /home/data \
  --remote s3:bucket/data \
  --alert telegram
```

Sends Telegram notification on backup failure or success.

## Supported Providers

rclone supports 40+ providers. Most common:

| Provider | Setup Flag | Notes |
|----------|-----------|-------|
| AWS S3 | `--provider AWS` | Standard S3 API |
| Backblaze B2 | `--provider B2` | Cheap storage ($5/TB/mo) |
| Google Drive | `--provider GDrive` | Needs OAuth |
| Dropbox | `--provider Dropbox` | Needs OAuth |
| DigitalOcean Spaces | `--provider DO` | S3-compatible |
| MinIO | `--provider MinIO` | Self-hosted S3 |
| SFTP | `--provider SFTP` | Any SSH server |
| Wasabi | `--provider Wasabi` | No egress fees |
| Cloudflare R2 | `--provider R2` | No egress fees |

## Troubleshooting

### Issue: "rclone: command not found"

```bash
bash scripts/install.sh
# Or manually: curl https://rclone.org/install.sh | sudo bash
```

### Issue: "access denied" on S3

Check:
1. Access key is valid: `rclone lsd remote:`
2. Bucket exists and key has write access
3. Region matches bucket region

### Issue: Backup too slow

```bash
# Increase transfer threads
bash scripts/backup.sh --source /data --remote s3:bucket --transfers 8

# Or use server-side copy for cloud-to-cloud
rclone copy remote1:source remote2:dest --server-side-across-configs
```

### Issue: Encrypted backup won't decrypt

Ensure you're using the EXACT same password:
```bash
echo -n "$BACKUP_PASSWORD" | md5sum  # Compare checksums
```

## Dependencies

- `rclone` (auto-installed by install.sh)
- `bash` (4.0+)
- `tar` + `gzip` (for compression)
- `gpg` (for encryption, usually pre-installed)
- `cron` (for scheduling)
- Optional: `yq` (for YAML config parsing)
