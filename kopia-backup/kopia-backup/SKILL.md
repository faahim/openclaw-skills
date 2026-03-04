---
name: kopia-backup
description: >-
  Install and manage Kopia — fast, encrypted, deduplicated backups with snapshot scheduling, integrity verification, and multi-cloud storage support.
categories: [data, automation]
dependencies: [bash, curl, kopia]
---

# Kopia Backup Manager

## What This Does

Installs and manages [Kopia](https://kopia.io), a modern backup tool with client-side encryption, deduplication, compression, and support for local, S3, GCS, Azure, B2, SFTP, and rclone-based storage. Schedule automatic snapshots, verify backup integrity, restore files, and manage retention policies — all from the command line.

**Example:** "Back up /home and /etc to S3 every 6 hours, keep 7 daily + 4 weekly + 12 monthly snapshots, verify integrity weekly."

## Quick Start (5 minutes)

### 1. Install Kopia

```bash
bash scripts/install.sh
```

### 2. Create a Local Repository

```bash
# Initialize a local backup repository
kopia repository create filesystem --path /backup/kopia-repo

# Or connect to an existing one
kopia repository connect filesystem --path /backup/kopia-repo
```

### 3. Take Your First Snapshot

```bash
# Snapshot a directory
kopia snapshot create /home/user

# List snapshots
kopia snapshot list
```

## Core Workflows

### Workflow 1: Local Backup

**Use case:** Back up directories to a local or mounted drive.

```bash
# Create repository
kopia repository create filesystem --path /mnt/backup/kopia

# Snapshot home directory
kopia snapshot create /home

# Snapshot with custom description
kopia snapshot create /var/www --description "Web server backup"

# List all snapshots
kopia snapshot list --all
```

### Workflow 2: S3/Cloud Backup

**Use case:** Back up to Amazon S3, MinIO, or S3-compatible storage.

```bash
# Create S3 repository
kopia repository create s3 \
  --bucket my-backup-bucket \
  --region us-east-1 \
  --access-key "$AWS_ACCESS_KEY_ID" \
  --secret-access-key "$AWS_SECRET_ACCESS_KEY" \
  --password "$KOPIA_PASSWORD"

# For Backblaze B2
kopia repository create b2 \
  --bucket my-b2-bucket \
  --key-id "$B2_KEY_ID" \
  --key "$B2_APPLICATION_KEY"

# For Google Cloud Storage
kopia repository create gcs \
  --bucket my-gcs-bucket \
  --credentials-file /path/to/service-account.json

# Take snapshot
kopia snapshot create /home /etc /var/www
```

### Workflow 3: Scheduled Snapshots

**Use case:** Automatic backups on a schedule.

```bash
# Set snapshot policy — every 6 hours
kopia policy set /home --snapshot-interval 6h

# Or use cron for more control
bash scripts/schedule.sh /home "0 */6 * * *"

# Set retention: 7 daily, 4 weekly, 12 monthly, 3 yearly
kopia policy set /home \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --keep-annual 3
```

### Workflow 4: Verify & Restore

**Use case:** Check backup integrity and restore files.

```bash
# Verify all snapshots
kopia snapshot verify

# Verify specific content
kopia content verify

# List snapshot contents
kopia ls <snapshot-id>

# Restore to a directory
kopia restore <snapshot-id> /tmp/restored/

# Restore specific file
kopia restore <snapshot-id>/path/to/file /tmp/restored-file
```

### Workflow 5: Monitor Backup Health

**Use case:** Get backup status reports and alerts.

```bash
# Run health check
bash scripts/health-check.sh

# Output:
# ✅ Repository: connected (filesystem:/backup/kopia)
# ✅ Last snapshot: 2026-03-04 12:00:00 (2 hours ago)
# ✅ Content verified: 1,234 blobs OK
# ✅ Storage used: 12.3 GB (dedup ratio: 3.2x)
# ⚠️ Retention: 3 snapshots pending cleanup
```

## Configuration

### Environment Variables

```bash
# Repository password (required for encrypted repos)
export KOPIA_PASSWORD="your-secure-password"

# S3 credentials (for cloud storage)
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# B2 credentials
export B2_KEY_ID="your-key-id"
export B2_APPLICATION_KEY="your-app-key"

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

### Compression & Encryption

```bash
# Set compression algorithm (default: zstd)
kopia policy set /home --compression zstd-better-compression

# Options: none, gzip, zstd, zstd-better-compression, pgzip, s2
# Encryption is always on (AES-256-GCM) — set password at repo creation

# Exclude patterns
kopia policy set /home \
  --add-ignore "node_modules" \
  --add-ignore ".cache" \
  --add-ignore "*.tmp" \
  --add-ignore ".git"
```

### Bandwidth Limits

```bash
# Limit upload speed (useful for cloud backups)
kopia policy set /home --upload-limit 10485760  # 10 MB/s
```

## Advanced Usage

### Multiple Repositories

```bash
# Connect to different repos using config profiles
kopia repository connect filesystem --path /backup/local --config-file ~/.config/kopia/local.config
kopia repository connect s3 --bucket cloud-backup --config-file ~/.config/kopia/cloud.config

# Snapshot to specific repo
kopia --config-file ~/.config/kopia/cloud.config snapshot create /home
```

### Server Mode (Web UI)

```bash
# Start Kopia server with web UI
kopia server start --address 0.0.0.0:51515 --insecure

# Access at http://localhost:51515
# For production, use --tls-cert-file and --tls-key-file
```

### Pre/Post Snapshot Hooks

```bash
# Run command before snapshot (e.g., dump database)
kopia policy set /var/lib/postgres \
  --before-snapshot-root-action "pg_dumpall > /var/lib/postgres/dump.sql"

# Run command after snapshot
kopia policy set /home \
  --after-snapshot-root-action "echo 'Backup complete' | mail -s 'Kopia' admin@example.com"
```

### Maintenance

```bash
# Run maintenance (garbage collection, compaction)
kopia maintenance run --full

# Check repository status
kopia repository status

# Show storage stats
kopia content stats
```

## Troubleshooting

### Issue: "repository not connected"

**Fix:**
```bash
# Reconnect to repository
kopia repository connect filesystem --path /path/to/repo
# Enter password when prompted
```

### Issue: Slow backups

**Fix:**
```bash
# Increase parallelism
kopia policy set /home --parallel 8

# Use faster compression
kopia policy set /home --compression s2  # fastest, lower ratio
```

### Issue: Out of disk space

**Fix:**
```bash
# Run maintenance to clean expired snapshots
kopia maintenance run --full

# Check what's using space
kopia content stats
```

### Issue: "kopia: command not found"

**Fix:**
```bash
# Re-run installer
bash scripts/install.sh
# Or add to PATH
export PATH="$PATH:/usr/local/bin"
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation and cloud uploads)
- `kopia` (installed by scripts/install.sh)
- Optional: `cron` (for scheduled snapshots)
- Optional: Telegram bot (for alerts)
