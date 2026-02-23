---
name: restic-backup
description: >-
  Encrypted, deduplicated backups with restic — local, S3, B2, SFTP, and more.
categories: [data, automation]
dependencies: [restic, bash, cron]
---

# Restic Backup Manager

## What This Does

Installs and configures [restic](https://restic.net) for encrypted, deduplicated backups. Supports local disk, S3, Backblaze B2, SFTP, and REST server backends. Handles repo initialization, scheduled backups, retention policies, and restore operations.

**Example:** "Back up /home and /etc to S3 every night at 2am, keep 7 daily + 4 weekly + 12 monthly snapshots, get Telegram alerts on failure."

## Quick Start (5 minutes)

### 1. Install Restic

```bash
bash scripts/install.sh
```

### 2. Initialize a Backup Repository

```bash
# Local repository
bash scripts/run.sh init --repo /mnt/backups/myserver --password "your-secure-password"

# S3 repository
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
bash scripts/run.sh init --repo s3:s3.amazonaws.com/bucket-name/restic --password "your-secure-password"

# SFTP repository
bash scripts/run.sh init --repo sftp:user@host:/backups/restic --password "your-secure-password"

# Backblaze B2
export B2_ACCOUNT_ID="your-account-id"
export B2_ACCOUNT_KEY="your-account-key"
bash scripts/run.sh init --repo b2:bucket-name:/restic --password "your-secure-password"
```

### 3. Run Your First Backup

```bash
bash scripts/run.sh backup \
  --repo /mnt/backups/myserver \
  --password "your-secure-password" \
  --paths "/home,/etc,/var/www"
```

## Core Workflows

### Workflow 1: Backup Specific Directories

```bash
bash scripts/run.sh backup \
  --repo s3:s3.amazonaws.com/mybucket/restic \
  --password "your-secure-password" \
  --paths "/home/user/projects,/etc,/var/lib/postgresql" \
  --exclude "*.tmp,node_modules,.cache,__pycache__"
```

**Output:**
```
[2026-02-23 02:00:00] 🔄 Starting backup to s3:s3.amazonaws.com/mybucket/restic
[2026-02-23 02:00:45] ✅ Backup complete — 1.2 GB processed, 85 MB added (deduplicated)
  Files new: 142 | changed: 38 | unmodified: 24,891
  Snapshot: 8a3b2c1d
```

### Workflow 2: Schedule Automated Backups

```bash
# Install cron job — daily at 2am
bash scripts/run.sh schedule \
  --repo s3:s3.amazonaws.com/mybucket/restic \
  --password-file /root/.restic-password \
  --paths "/home,/etc,/var/www" \
  --cron "0 2 * * *" \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12
```

This creates a cron entry that:
1. Runs backup at 2am daily
2. Prunes old snapshots (keeps 7 daily, 4 weekly, 12 monthly)
3. Logs to `/var/log/restic-backup.log`
4. Sends Telegram alert on failure (if configured)

### Workflow 3: Restore Files

```bash
# List snapshots
bash scripts/run.sh snapshots --repo /mnt/backups/myserver --password "your-secure-password"

# Restore entire snapshot to /tmp/restore
bash scripts/run.sh restore \
  --repo /mnt/backups/myserver \
  --password "your-secure-password" \
  --snapshot latest \
  --target /tmp/restore

# Restore specific files
bash scripts/run.sh restore \
  --repo /mnt/backups/myserver \
  --password "your-secure-password" \
  --snapshot latest \
  --target /tmp/restore \
  --include "/etc/nginx/nginx.conf"
```

### Workflow 4: Check Backup Integrity

```bash
bash scripts/run.sh check --repo /mnt/backups/myserver --password "your-secure-password"
```

**Output:**
```
[2026-02-23 10:00:00] 🔍 Checking repository integrity...
[2026-02-23 10:01:30] ✅ Repository OK — 45 snapshots, 12.8 GB total, no errors
```

### Workflow 5: Prune Old Snapshots

```bash
bash scripts/run.sh prune \
  --repo /mnt/backups/myserver \
  --password "your-secure-password" \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --keep-yearly 2
```

## Configuration

### Environment Variables

```bash
# Repository password (required — use ONE method)
export RESTIC_PASSWORD="your-secure-password"
# OR use a password file:
export RESTIC_PASSWORD_FILE="/root/.restic-password"

# S3 credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Backblaze B2 credentials
export B2_ACCOUNT_ID="your-account-id"
export B2_ACCOUNT_KEY="your-account-key"

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

### Config File (YAML)

```yaml
# restic-backup.yaml
repository: s3:s3.amazonaws.com/mybucket/restic
password_file: /root/.restic-password

backup:
  paths:
    - /home
    - /etc
    - /var/www
    - /var/lib/postgresql
  exclude:
    - "*.tmp"
    - "node_modules"
    - ".cache"
    - "__pycache__"
    - "*.log"

schedule:
  cron: "0 2 * * *"  # Daily at 2am

retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 12
  keep_yearly: 2

alerts:
  telegram:
    bot_token_env: TELEGRAM_BOT_TOKEN
    chat_id_env: TELEGRAM_CHAT_ID
    on_failure: true
    on_success: false  # Set true for daily confirmation
```

```bash
# Run with config file
bash scripts/run.sh backup --config restic-backup.yaml
```

## Advanced Usage

### Multiple Backup Targets (3-2-1 Rule)

```bash
# Local backup
bash scripts/run.sh backup --repo /mnt/external/restic --password-file /root/.restic-pw --paths "/home,/etc"

# Offsite S3 backup
bash scripts/run.sh backup --repo s3:s3.amazonaws.com/mybucket/restic --password-file /root/.restic-pw --paths "/home,/etc"

# Schedule both
bash scripts/run.sh schedule --config local-backup.yaml --cron "0 2 * * *"
bash scripts/run.sh schedule --config s3-backup.yaml --cron "0 3 * * *"
```

### Database Dump + Backup

```bash
# Pre-backup hook: dump database, then back up
bash scripts/run.sh backup \
  --repo s3:s3.amazonaws.com/mybucket/restic \
  --password-file /root/.restic-pw \
  --paths "/home,/etc,/tmp/db-dumps" \
  --pre-hook "pg_dumpall -U postgres > /tmp/db-dumps/postgres-$(date +%Y%m%d).sql"
```

### Bandwidth Limiting

```bash
# Limit upload to 5 MB/s (useful for remote backends)
bash scripts/run.sh backup --repo s3:... --password "..." --paths "/home" --limit-upload 5120
```

### Mount Snapshots (Browse Backups)

```bash
# Mount all snapshots as a filesystem
bash scripts/run.sh mount --repo /mnt/backups/myserver --password "..." --mountpoint /mnt/restic-browse

# Browse: ls /mnt/restic-browse/snapshots/latest/home/
```

## Troubleshooting

### Issue: "restic: command not found"

```bash
bash scripts/install.sh
# Or manually: sudo apt install restic / brew install restic
```

### Issue: "repository does not exist"

```bash
# Initialize it first
bash scripts/run.sh init --repo <your-repo> --password "..."
```

### Issue: S3 "Access Denied"

Check:
1. `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set
2. IAM policy allows `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`, `s3:DeleteObject`
3. Bucket exists and region is correct

### Issue: Backup is slow

```bash
# Check what's being backed up (dry run)
bash scripts/run.sh backup --repo ... --password "..." --paths "/home" --dry-run

# Exclude large unnecessary files
--exclude "*.iso,*.vmdk,*.qcow2,node_modules,.cache"
```

### Issue: Repository locked (stale lock from crashed backup)

```bash
bash scripts/run.sh unlock --repo <your-repo> --password "..."
```

## Dependencies

- `restic` (installed via scripts/install.sh)
- `bash` (4.0+)
- `cron` (for scheduled backups)
- Optional: `curl` + `jq` (for Telegram alerts)
