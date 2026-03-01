---
name: kopia-backup
description: >-
  Install and manage Kopia — a fast, encrypted, deduplicated backup tool with support for S3, B2, SFTP, Google Cloud, Azure, and local storage.
categories: [data, automation]
dependencies: [bash, curl]
---

# Kopia Backup Manager

## What This Does

Installs and configures [Kopia](https://kopia.io), a modern backup tool with built-in encryption, deduplication, and compression. Backs up files to local storage, S3, Backblaze B2, SFTP, Google Cloud Storage, or Azure Blob — all from a single CLI.

**Example:** "Back up /home and /etc to Backblaze B2 every 6 hours, encrypted with AES-256, keep 30 daily + 12 monthly snapshots, get alerts on failure."

## Quick Start (5 minutes)

### 1. Install Kopia

```bash
bash scripts/install.sh
```

This auto-detects your OS (Linux amd64/arm64, macOS) and installs the latest Kopia binary.

### 2. Create a Local Repository

```bash
# Initialize a local backup repository
kopia repository create filesystem --path /backup/kopia-repo

# Set a strong password when prompted (or use KOPIA_PASSWORD env var)
export KOPIA_PASSWORD="your-strong-password"
```

### 3. Take Your First Snapshot

```bash
# Back up your home directory
kopia snapshot create /home/$(whoami)

# List snapshots
kopia snapshot list
```

## Core Workflows

### Workflow 1: Local Backup

**Use case:** Back up directories to an external drive or local path.

```bash
# Create repository on external drive
kopia repository create filesystem --path /mnt/external/backups

# Snapshot important directories
kopia snapshot create /home/user/documents
kopia snapshot create /home/user/projects
kopia snapshot create /etc

# List all snapshots
kopia snapshot list --all
```

### Workflow 2: S3/Backblaze B2 Backup

**Use case:** Off-site encrypted backups to cloud storage.

```bash
# Connect to S3
kopia repository create s3 \
  --bucket my-backup-bucket \
  --access-key "$AWS_ACCESS_KEY_ID" \
  --secret-access-key "$AWS_SECRET_ACCESS_KEY" \
  --region us-east-1

# Connect to Backblaze B2
kopia repository create b2 \
  --bucket my-b2-bucket \
  --key-id "$B2_KEY_ID" \
  --key "$B2_APPLICATION_KEY"

# Snapshot with compression
kopia snapshot create /home/user --compression=zstd
```

### Workflow 3: SFTP Backup

**Use case:** Back up to a remote server via SSH/SFTP.

```bash
kopia repository create sftp \
  --path /backups/kopia \
  --host backup-server.example.com \
  --username backup \
  --keyfile ~/.ssh/id_ed25519
```

### Workflow 4: Scheduled Backups (Cron)

**Use case:** Automated recurring backups with retention policies.

```bash
# Copy the backup script
cp scripts/backup.sh /usr/local/bin/kopia-backup.sh
chmod +x /usr/local/bin/kopia-backup.sh

# Edit config
cp scripts/config-template.env /etc/kopia-backup.env
# Set KOPIA_PASSWORD, BACKUP_PATHS, NOTIFICATION_URL in the env file

# Add to crontab — every 6 hours
(crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/kopia-backup.sh >> /var/log/kopia-backup.log 2>&1") | crontab -
```

### Workflow 5: Restore Files

**Use case:** Recover files from a backup snapshot.

```bash
# List snapshots
kopia snapshot list

# Mount a snapshot to browse files
kopia mount all /mnt/kopia-snapshots &

# Or restore specific snapshot to a directory
kopia restore <snapshot-id> /tmp/restored/

# Restore a single file
kopia restore <snapshot-id>/path/to/file.txt /tmp/file.txt
```

### Workflow 6: Retention Policies

**Use case:** Automatically prune old snapshots.

```bash
# Set global retention policy
kopia policy set --global \
  --keep-latest 10 \
  --keep-daily 30 \
  --keep-weekly 12 \
  --keep-monthly 24 \
  --keep-annual 5

# Set per-directory policy
kopia policy set /home/user/documents \
  --keep-daily 60 \
  --compression zstd-fastest

# View current policies
kopia policy show --global
```

## Configuration

### Environment Variables

```bash
# Repository password (required)
export KOPIA_PASSWORD="your-strong-password"

# For S3 backends
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

# For B2 backends
export B2_KEY_ID="..."
export B2_APPLICATION_KEY="..."

# For notifications (optional)
export TELEGRAM_BOT_TOKEN="..."
export TELEGRAM_CHAT_ID="..."
```

### Backup Script Config (/etc/kopia-backup.env)

```bash
# Paths to back up (space-separated)
BACKUP_PATHS="/home /etc /var/lib/important-data"

# Repository password
KOPIA_PASSWORD="your-strong-password"

# Notification webhook (Telegram, Slack, ntfy, etc.)
NOTIFICATION_URL=""

# Compression (none, gzip, zstd, zstd-fastest, s2-default)
COMPRESSION="zstd"

# Max parallel uploads
PARALLEL=4
```

## Advanced Usage

### Encryption & Security

```bash
# Kopia encrypts ALL data by default (AES-256-GCM)
# Check repository status
kopia repository status

# Change password
kopia repository change-password
```

### Bandwidth Limiting

```bash
# Limit upload speed (useful for metered connections)
kopia snapshot create /home/user --max-upload-speed=10M
```

### Ignore Patterns

```bash
# Set ignore rules (like .gitignore)
kopia policy set /home/user \
  --add-ignore "*.tmp" \
  --add-ignore "node_modules/" \
  --add-ignore ".cache/" \
  --add-ignore "*.log"
```

### Repository Maintenance

```bash
# Run maintenance (deduplication cleanup, index optimization)
kopia maintenance run --full

# Check repository integrity
kopia repository validate-client

# Show repository stats (size, dedup ratio, etc.)
kopia content stats
```

### Multiple Repositories

```bash
# Connect to a different repository
kopia repository connect s3 \
  --bucket offsite-backup \
  --access-key "$AWS_KEY" \
  --secret-access-key "$AWS_SECRET"

# Disconnect and switch back
kopia repository disconnect
kopia repository connect filesystem --path /backup/local-repo
```

## Troubleshooting

### Issue: "repository not connected"

**Fix:** Connect to your repository first:
```bash
kopia repository connect filesystem --path /path/to/repo
# Or for S3:
kopia repository connect s3 --bucket my-bucket --access-key ... --secret-access-key ...
```

### Issue: "permission denied" on backup paths

**Fix:** Run with sudo or adjust permissions:
```bash
sudo kopia snapshot create /etc
```

### Issue: Slow backups

**Fix:** Enable compression and parallelism:
```bash
kopia policy set --global --compression zstd-fastest
kopia snapshot create /home/user --parallel 8
```

### Issue: Repository too large

**Fix:** Run maintenance and check retention:
```bash
kopia maintenance run --full
kopia policy show --global  # Check retention settings
kopia snapshot list --all   # Review what's stored
```

## Key Principles

1. **Encrypted by default** — All data encrypted with AES-256-GCM before leaving your machine
2. **Deduplicated** — Only stores unique data blocks (saves 50-90% space over time)
3. **Compressed** — zstd compression reduces backup size significantly
4. **Incremental** — After first backup, only changed data is uploaded
5. **Multi-backend** — Same tool works with local disk, S3, B2, SFTP, GCS, Azure
6. **Fast restores** — Mount snapshots as virtual filesystem for instant file access

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- Internet access (for cloud backends)
- Kopia binary (installed by scripts/install.sh)
