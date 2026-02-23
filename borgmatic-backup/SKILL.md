---
name: borgmatic-backup
description: >-
  Encrypted, deduplicated backups with Borg and Borgmatic. Install, configure, schedule, verify, and restore.
categories: [data, automation]
dependencies: [borgbackup, borgmatic, cron]
---

# Borgmatic Backup Manager

## What This Does

Automate encrypted, deduplicated backups using [BorgBackup](https://www.borgbackup.org/) and [Borgmatic](https://torsion.org/borgmatic/). Backs up files, databases (PostgreSQL, MySQL, MongoDB), and Docker volumes to local or remote repositories. Deduplication means only changes are stored — 1TB of data with daily backups might use 50GB total.

**Example:** "Back up /home, /etc, and my PostgreSQL database to an encrypted Borg repo on a remote server every night at 2am, keep 7 daily + 4 weekly + 6 monthly snapshots, get Telegram alerts on failure."

## Quick Start (5 minutes)

### 1. Install Borg + Borgmatic

```bash
bash scripts/install.sh
```

### 2. Initialize a Repository

```bash
# Local repo
bash scripts/run.sh init --repo /mnt/backup/borg-repo --encryption repokey

# Remote repo (SSH)
bash scripts/run.sh init --repo ssh://user@backup-server/~/borg-repo --encryption repokey
```

You'll be prompted to set a passphrase. **Save it securely — without it, your backups are unrecoverable.**

### 3. Create Config

```bash
bash scripts/run.sh configure \
  --repo /mnt/backup/borg-repo \
  --source /home,/etc,/var/www \
  --passphrase-file /root/.borg-passphrase \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6
```

### 4. Run First Backup

```bash
bash scripts/run.sh backup
```

### 5. Schedule with Cron

```bash
bash scripts/run.sh schedule --cron "0 2 * * *"  # Daily at 2am
```

## Core Workflows

### Workflow 1: Back Up Files

```bash
# Quick backup with defaults
bash scripts/run.sh backup

# Backup specific config
bash scripts/run.sh backup --config /etc/borgmatic/myapp.yaml

# Dry run (see what would be backed up)
bash scripts/run.sh backup --dry-run
```

**Output:**
```
[2026-02-23 02:00:01] 🔒 Starting encrypted backup...
[2026-02-23 02:00:01] 📁 Sources: /home, /etc, /var/www
[2026-02-23 02:00:01] 📦 Repository: /mnt/backup/borg-repo
[2026-02-23 02:03:45] ✅ Backup complete: 2.3 GB processed, 48 MB added (deduplicated)
[2026-02-23 02:03:46] 🧹 Pruned: removed 2 old archives, kept 7d/4w/6m
[2026-02-23 02:03:47] ✔️ Integrity check passed
```

### Workflow 2: Back Up PostgreSQL Database

```bash
bash scripts/run.sh configure \
  --repo /mnt/backup/borg-repo \
  --source /home \
  --pg-host localhost --pg-user postgres --pg-db myapp,analytics \
  --passphrase-file /root/.borg-passphrase
```

This adds a `postgresql_databases` hook to borgmatic config. Database dumps are taken before file backup and included in the archive.

### Workflow 3: Back Up MySQL Database

```bash
bash scripts/run.sh configure \
  --repo /mnt/backup/borg-repo \
  --source /var/www \
  --mysql-host localhost --mysql-user root --mysql-db wordpress \
  --passphrase-file /root/.borg-passphrase
```

### Workflow 4: Back Up to Remote Server via SSH

```bash
# Set up SSH key (if not done)
ssh-copy-id user@backup-server

# Init remote repo
bash scripts/run.sh init --repo ssh://user@backup-server:22/~/borg-repo --encryption repokey

# Configure
bash scripts/run.sh configure \
  --repo ssh://user@backup-server:22/~/borg-repo \
  --source /home,/etc \
  --passphrase-file /root/.borg-passphrase
```

### Workflow 5: Restore Files

```bash
# List available archives
bash scripts/run.sh list

# Output:
# myhost-2026-02-23T02:00:01  Sun, 2026-02-23 02:00:01  [2.3 GB]
# myhost-2026-02-22T02:00:01  Sat, 2026-02-22 02:00:01  [2.3 GB]

# Restore entire archive to a directory
bash scripts/run.sh restore --archive latest --target /tmp/restore

# Restore specific path
bash scripts/run.sh restore --archive latest --path home/user/documents --target /tmp/restore
```

### Workflow 6: Verify Backup Integrity

```bash
# Quick check (verify metadata)
bash scripts/run.sh check

# Full verification (verify all data — slow but thorough)
bash scripts/run.sh check --full

# Output:
# [2026-02-23 12:00:01] 🔍 Checking repository integrity...
# [2026-02-23 12:00:45] ✅ Repository integrity OK (23 archives, 12.4 GB)
```

### Workflow 7: Alerts on Failure

```bash
bash scripts/run.sh configure \
  --repo /mnt/backup/borg-repo \
  --source /home \
  --alert-telegram --telegram-token "$TELEGRAM_BOT_TOKEN" --telegram-chat "$TELEGRAM_CHAT_ID" \
  --passphrase-file /root/.borg-passphrase
```

On failure:
```
🚨 Backup FAILED at 2026-02-23 02:03:45
Host: myhost
Error: Connection to backup-server refused
Repository: ssh://user@backup-server/~/borg-repo
```

## Configuration

### Borgmatic Config (YAML)

The `configure` command generates `/etc/borgmatic/config.yaml`. You can also edit directly:

```yaml
# /etc/borgmatic/config.yaml
repositories:
  - path: ssh://user@backup-server/~/borg-repo
    label: remote

source_directories:
  - /home
  - /etc
  - /var/www

exclude_patterns:
  - "*.pyc"
  - "*/.cache"
  - "*/node_modules"
  - "*/venv"

encryption_passphrase_file: /root/.borg-passphrase

retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 6
  keep_yearly: 1

postgresql_databases:
  - name: myapp
    hostname: localhost
    username: postgres

hooks:
  on_error:
    - bash /etc/borgmatic/hooks/alert-telegram.sh "{error}" "{repository}"
```

### Environment Variables

```bash
# Borg passphrase (alternative to passphrase file)
export BORG_PASSPHRASE="your-secure-passphrase"

# Remote repo via SSH
export BORG_RSH="ssh -i /root/.ssh/backup_key -o StrictHostKeyChecking=no"

# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"
```

## Advanced Usage

### Multiple Repositories (3-2-1 Strategy)

```yaml
# /etc/borgmatic/config.yaml
repositories:
  - path: /mnt/external-drive/borg
    label: local
  - path: ssh://user@offsite-server/~/borg
    label: offsite
```

### Exclude Large/Temp Files

```yaml
exclude_patterns:
  - "*.iso"
  - "*.vmdk"
  - "*/.cache"
  - "*/node_modules"
  - "*/__pycache__"
  - "*/venv"
  - "*.log"

exclude_if_present:
  - .nobackup
```

### Docker Volume Backup

```bash
# Back up named Docker volumes
bash scripts/run.sh configure \
  --repo /mnt/backup/borg-repo \
  --source /var/lib/docker/volumes \
  --passphrase-file /root/.borg-passphrase

# Or use pre-backup hooks to dump containers first
```

### Monitor Backup Status

```bash
# Show last backup info
bash scripts/run.sh status

# Output:
# Repository: ssh://user@backup-server/~/borg-repo
# Last backup: 2026-02-23 02:03:45 (6 hours ago)
# Archives: 23 total
# Repo size: 12.4 GB (original: 89.2 GB, dedup ratio: 7.2x)
# Next scheduled: 2026-02-24 02:00:00
```

## Troubleshooting

### Issue: "Repository not found"

**Fix:** Initialize the repo first:
```bash
bash scripts/run.sh init --repo /path/to/repo --encryption repokey
```

### Issue: "Passphrase incorrect"

**Fix:** Check your passphrase file or BORG_PASSPHRASE env var. If lost, the repo is unrecoverable (that's the point of encryption).

### Issue: SSH connection refused

**Fix:**
1. Check SSH access: `ssh user@backup-server echo OK`
2. Ensure borg is installed on remote: `ssh user@backup-server borg --version`
3. Check BORG_RSH if using non-standard SSH key

### Issue: "Lock timeout" (repo locked by another process)

**Fix:**
```bash
# Break stale lock (only if no other backup is running!)
borg break-lock /path/to/repo
```

### Issue: Backup too slow

**Fix:**
- Exclude large unnecessary files (node_modules, .cache, logs)
- Use `--compression lz4` for faster compression (default: lz4)
- For first backup, expect it to be slow (full copy). Subsequent backups are fast (deduplication)

## Dependencies

- `borgbackup` (1.2+) — core backup engine
- `borgmatic` (1.8+) — config + automation wrapper
- `python3` (3.8+) — borgmatic dependency
- `cron` — scheduled backups
- `ssh` — remote repositories (optional)
- `postgresql-client` / `mysql-client` — database dumps (optional)
