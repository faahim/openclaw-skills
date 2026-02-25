---
name: rsync-backup
description: >-
  Automated rsync-based backups with incremental snapshots, remote targets, retention policies, and failure alerts.
categories: [data, automation]
dependencies: [rsync, bash, ssh, cron]
---

# Rsync Backup Manager

## What This Does

Automate file and directory backups using rsync — the fastest, most reliable sync tool on Linux/Mac. Supports local-to-local, local-to-remote, and remote-to-local backups with incremental snapshots, configurable retention, bandwidth limiting, and failure alerts via Telegram or email.

**Example:** "Back up /var/www and /home every 6 hours to a remote server, keep 30 daily snapshots, alert me on Telegram if any backup fails."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# rsync is pre-installed on most systems. Check:
which rsync ssh cron || echo "Install missing tools: sudo apt install rsync openssh-client cron"

# Optional: Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
```

### 2. Run Your First Backup

```bash
# Local backup
bash scripts/rsync-backup.sh \
  --source /home/user/documents \
  --dest /mnt/backup/documents \
  --name "docs"

# Remote backup (via SSH)
bash scripts/rsync-backup.sh \
  --source /var/www \
  --dest user@backup-server:/backups/www \
  --name "website" \
  --ssh-key ~/.ssh/id_ed25519
```

### 3. Set Up Scheduled Backups

```bash
# Copy and edit the config
cp scripts/config-template.yaml config.yaml
# Edit config.yaml with your backup jobs

# Install cron schedule
bash scripts/rsync-backup.sh --install-cron --config config.yaml
```

## Core Workflows

### Workflow 1: Simple Local Backup

```bash
bash scripts/rsync-backup.sh \
  --source /home/user/projects \
  --dest /mnt/external/projects-backup \
  --name "projects"
```

**Output:**
```
[2026-02-25 22:00:00] 🔄 Starting backup: projects
[2026-02-25 22:00:00] Source: /home/user/projects
[2026-02-25 22:00:00] Dest:   /mnt/external/projects-backup/2026-02-25_220000
[2026-02-25 22:00:12] ✅ Backup complete: projects (1.2GB transferred, 12s)
[2026-02-25 22:00:12] 📊 Snapshot: /mnt/external/projects-backup/2026-02-25_220000
```

### Workflow 2: Remote Backup with SSH

```bash
bash scripts/rsync-backup.sh \
  --source /var/www/html \
  --dest deploy@10.0.0.5:/backups/web \
  --name "webserver" \
  --ssh-key ~/.ssh/backup_key \
  --bwlimit 5000  # Limit to 5MB/s
```

### Workflow 3: Incremental Snapshots with Retention

```bash
bash scripts/rsync-backup.sh \
  --source /home/user \
  --dest /mnt/backup/home \
  --name "home" \
  --snapshots \
  --retain 30  # Keep last 30 snapshots
```

Uses rsync `--link-dest` for space-efficient incremental snapshots. Each snapshot looks like a full backup but only stores changed files.

### Workflow 4: Backup with Exclusions

```bash
bash scripts/rsync-backup.sh \
  --source /home/user \
  --dest /mnt/backup/home \
  --name "home" \
  --exclude "node_modules" \
  --exclude ".cache" \
  --exclude "*.tmp" \
  --exclude ".git"
```

### Workflow 5: Restore from Backup

```bash
# List available snapshots
bash scripts/rsync-backup.sh --list --dest /mnt/backup/home

# Restore latest
bash scripts/rsync-backup.sh \
  --restore \
  --source /mnt/backup/home/latest \
  --dest /home/user \
  --dry-run  # Preview first

# Actually restore
bash scripts/rsync-backup.sh \
  --restore \
  --source /mnt/backup/home/latest \
  --dest /home/user
```

## Configuration

### Config File (YAML-style)

```yaml
# config.yaml
global:
  log_dir: /var/log/rsync-backup
  telegram_bot_token: "${TELEGRAM_BOT_TOKEN}"
  telegram_chat_id: "${TELEGRAM_CHAT_ID}"
  bwlimit: 0  # 0 = unlimited (KB/s)

jobs:
  - name: website
    source: /var/www/html
    dest: backup@10.0.0.5:/backups/web
    ssh_key: ~/.ssh/backup_key
    schedule: "0 */6 * * *"  # Every 6 hours
    snapshots: true
    retain: 30
    exclude:
      - "*.log"
      - ".cache"

  - name: databases
    source: /var/lib/postgresql/data
    dest: /mnt/backup/postgres
    schedule: "0 2 * * *"  # Daily at 2am
    snapshots: true
    retain: 14
    pre_script: "pg_dumpall > /tmp/pgdump.sql"

  - name: home
    source: /home/user
    dest: /mnt/external/home-backup
    schedule: "0 0 * * 0"  # Weekly Sunday midnight
    snapshots: true
    retain: 8
    exclude:
      - "node_modules"
      - ".cache"
      - "Downloads"
      - ".local/share/Trash"
```

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<bot-token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Email alerts (optional)
export SMTP_HOST="smtp.gmail.com"
export SMTP_USER="<email>"
export SMTP_PASS="<app-password>"
export ALERT_EMAIL="admin@example.com"

# Default SSH key (optional)
export RSYNC_SSH_KEY="~/.ssh/id_ed25519"
```

## Advanced Usage

### Pre/Post Scripts

Run commands before or after backup (e.g., dump database, stop service):

```bash
bash scripts/rsync-backup.sh \
  --source /var/lib/mysql \
  --dest /mnt/backup/mysql \
  --name "mysql" \
  --pre "mysqldump --all-databases > /tmp/all-dbs.sql" \
  --post "rm /tmp/all-dbs.sql"
```

### Dry Run (Preview Changes)

```bash
bash scripts/rsync-backup.sh \
  --source /home/user \
  --dest /mnt/backup/home \
  --name "home" \
  --dry-run
```

### Bandwidth Limiting

```bash
# Limit to 10MB/s (useful for remote backups)
bash scripts/rsync-backup.sh \
  --source /var/www \
  --dest remote:/backups/www \
  --bwlimit 10000
```

### Verify Backup Integrity

```bash
bash scripts/rsync-backup.sh \
  --verify \
  --source /home/user \
  --dest /mnt/backup/home/latest
```

## Troubleshooting

### Issue: "Permission denied" on remote backup

**Fix:** Set up SSH key authentication:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/backup_key -N ""
ssh-copy-id -i ~/.ssh/backup_key.pub user@remote-server
```

### Issue: "rsync: connection unexpectedly closed"

**Causes:** Network interruption, SSH timeout, disk full on target.
```bash
# Check disk space on target
ssh user@remote df -h /backups
# Retry with verbose output
bash scripts/rsync-backup.sh --source ... --dest ... --verbose
```

### Issue: Snapshots using too much disk space

**Fix:** Reduce retention or add more exclusions:
```bash
bash scripts/rsync-backup.sh --prune --dest /mnt/backup/home --retain 7
```

### Issue: Backup too slow

**Fix:**
```bash
# Use compression for remote backups
bash scripts/rsync-backup.sh --source ... --dest remote:... --compress
# Exclude large unnecessary files
bash scripts/rsync-backup.sh --source ... --dest ... --exclude "*.iso" --exclude "*.vmdk"
```

## Key Principles

1. **Incremental by default** — rsync only transfers changed bytes
2. **Snapshot history** — Hard-linked snapshots are space-efficient
3. **Fail loudly** — Alerts on any backup failure
4. **Idempotent** — Safe to run multiple times
5. **Bandwidth-aware** — Rate limiting for shared connections
6. **Atomic snapshots** — Uses temp dir + rename to prevent partial backups

## Dependencies

- `rsync` (3.0+) — Core sync engine
- `bash` (4.0+) — Script runtime
- `ssh` — Remote backup transport
- `cron` — Scheduled backups
- Optional: `curl` (Telegram alerts), `mailx` (email alerts)
