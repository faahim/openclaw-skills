---
name: btrfs-snapshot-manager
description: >-
  Automate BTRFS filesystem snapshots with scheduled creation, retention policies, and instant rollback.
categories: [automation, data]
dependencies: [btrfs-progs, bash, cron]
---

# BTRFS Snapshot Manager

## What This Does

Automates BTRFS snapshot creation, cleanup, and rollback for any BTRFS filesystem. Create snapshots on schedule (hourly/daily/weekly), enforce retention policies to prevent disk bloat, and roll back to any previous snapshot instantly.

**Example:** "Take hourly snapshots of /home, keep 24 hourly + 7 daily + 4 weekly, auto-delete older ones, roll back to yesterday's snapshot in 5 seconds."

## Quick Start (5 minutes)

### 1. Verify BTRFS Filesystem

```bash
# Check if your filesystem is BTRFS
df -Th | grep btrfs

# If no output, this skill requires a BTRFS filesystem
# Convert ext4 to BTRFS (BACKUP FIRST): btrfs-convert /dev/sdX
```

### 2. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y btrfs-progs

# Fedora/RHEL
sudo dnf install -y btrfs-progs

# Arch
sudo pacman -S btrfs-progs
```

### 3. Create Your First Snapshot

```bash
# Make the script executable
chmod +x scripts/btrfs-snap.sh

# Take a snapshot of /home
sudo bash scripts/btrfs-snap.sh snap /home

# Output:
# [2026-03-03 23:00:00] ✅ Snapshot created: /home/.snapshots/2026-03-03_23-00-00
```

### 4. Set Up Automatic Snapshots

```bash
# Copy config
cp scripts/config-template.yaml config.yaml
# Edit config.yaml with your subvolumes and retention policy

# Install cron jobs
sudo bash scripts/btrfs-snap.sh install-cron config.yaml

# Output:
# ✅ Cron installed: hourly snapshots for /home
# ✅ Cron installed: daily cleanup (retention policy)
```

## Core Workflows

### Workflow 1: Manual Snapshot

**Use case:** Before a risky operation (system update, config change)

```bash
sudo bash scripts/btrfs-snap.sh snap /home --label "before-upgrade"
# [2026-03-03 23:00:00] ✅ Snapshot: /home/.snapshots/2026-03-03_23-00-00_before-upgrade
```

### Workflow 2: List Snapshots

```bash
sudo bash scripts/btrfs-snap.sh list /home

# Output:
# BTRFS Snapshots for /home
# ─────────────────────────────────────────────
#  #  Snapshot                                    Size    Label
#  1  2026-03-03_23-00-00_before-upgrade          1.2G    before-upgrade
#  2  2026-03-03_22-00-00                         1.1G    hourly
#  3  2026-03-03_21-00-00                         1.1G    hourly
#  4  2026-03-03_00-00-00                         1.0G    daily
```

### Workflow 3: Rollback to a Snapshot

**Use case:** Something broke, need to restore

```bash
# Rollback /home to a specific snapshot
sudo bash scripts/btrfs-snap.sh rollback /home 2026-03-03_23-00-00_before-upgrade

# Output:
# ⚠️  Rolling back /home to snapshot: 2026-03-03_23-00-00_before-upgrade
# 📸 Creating safety snapshot of current state: /home/.snapshots/2026-03-03_23-05-00_pre-rollback
# ✅ Rollback complete. Reboot recommended for root subvolumes.
```

### Workflow 4: Cleanup Old Snapshots

```bash
# Apply retention policy: keep 24 hourly, 7 daily, 4 weekly
sudo bash scripts/btrfs-snap.sh cleanup /home --hourly 24 --daily 7 --weekly 4

# Output:
# [2026-03-03 23:00:00] 🗑️  Deleted 12 expired snapshots
# [2026-03-03 23:00:00] 💾 Retained: 24 hourly, 7 daily, 4 weekly (35 total)
# [2026-03-03 23:00:00] 📊 Freed ~8.5G disk space
```

### Workflow 5: Snapshot Diff

**Use case:** See what changed between two snapshots

```bash
sudo bash scripts/btrfs-snap.sh diff /home 2026-03-03_21-00-00 2026-03-03_23-00-00

# Output:
# Changes between snapshots:
# +  /home/user/.config/app/settings.json
# ~  /home/user/projects/myapp/src/index.js  (modified)
# -  /home/user/tmp/old-file.txt  (deleted)
# 📊 3 changes (1 added, 1 modified, 1 deleted)
```

## Configuration

### Config File Format (YAML)

```yaml
# config.yaml
subvolumes:
  - path: /home
    snapshot_dir: /home/.snapshots
    schedule:
      hourly: true
      daily: true
      weekly: true
    retention:
      hourly: 24
      daily: 7
      weekly: 4
      monthly: 6
    pre_snapshot_cmd: ""    # Optional: run before snapshot
    post_snapshot_cmd: ""   # Optional: run after snapshot

  - path: /var/log
    snapshot_dir: /var/log/.snapshots
    schedule:
      daily: true
    retention:
      daily: 14

alerts:
  on_failure: true
  method: telegram    # telegram, email, webhook
  telegram_bot_token: "${TELEGRAM_BOT_TOKEN}"
  telegram_chat_id: "${TELEGRAM_CHAT_ID}"
```

### Environment Variables

```bash
# Optional: Telegram alerts on snapshot failure
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Optional: custom snapshot directory
export BTRFS_SNAP_DIR="/mnt/snapshots"
```

## Advanced Usage

### Send Snapshots to Remote (Incremental Backup)

```bash
# Send snapshot to remote machine via SSH
sudo bash scripts/btrfs-snap.sh send /home 2026-03-03_23-00-00 \
  --remote user@backup-server:/mnt/backups/home

# Incremental send (much faster after first full send)
sudo bash scripts/btrfs-snap.sh send /home 2026-03-03_23-00-00 \
  --parent 2026-03-03_22-00-00 \
  --remote user@backup-server:/mnt/backups/home
```

### Monitor Snapshot Disk Usage

```bash
sudo bash scripts/btrfs-snap.sh status /home

# Output:
# BTRFS Snapshot Status for /home
# ────────────────────────────────
# Filesystem:    /dev/sda2
# Total:         500G
# Used:          312G (62%)
# Snapshots:     35 (estimated 42G exclusive)
# Oldest:        2026-02-25_00-00-00 (6 days ago)
# Newest:        2026-03-03_23-00-00 (just now)
# Next cleanup:  2026-03-04 00:00 (cron)
```

### Run as Cron Job (Manual Setup)

```bash
# Hourly snapshots
0 * * * * /path/to/scripts/btrfs-snap.sh snap /home --label hourly >> /var/log/btrfs-snap.log 2>&1

# Daily cleanup at midnight
0 0 * * * /path/to/scripts/btrfs-snap.sh cleanup /home --hourly 24 --daily 7 --weekly 4 >> /var/log/btrfs-snap.log 2>&1
```

## Troubleshooting

### Issue: "ERROR: not a btrfs filesystem"

**Fix:** This tool only works on BTRFS filesystems.
```bash
# Check filesystem type
df -Th /home | awk 'NR==2 {print $2}'
# Must show "btrfs"
```

### Issue: "Cannot create snapshot: Permission denied"

**Fix:** Snapshots require root access.
```bash
sudo bash scripts/btrfs-snap.sh snap /home
```

### Issue: Disk filling up despite retention policy

**Fix:** Check if cleanup cron is running:
```bash
sudo crontab -l | grep btrfs-snap
# Should show cleanup job
```

Also check exclusive space used by snapshots:
```bash
sudo btrfs filesystem du -s /home/.snapshots/*/
```

### Issue: Rollback didn't take effect

**Fix:** For root (`/`) subvolumes, you must reboot after rollback. For non-root subvolumes, unmount and remount:
```bash
sudo umount /home && sudo mount /home
```

## Key Principles

1. **Always create safety snapshot before rollback** — Never lose current state
2. **Retention policies prevent disk bloat** — Set and forget
3. **Incremental sends are fast** — Only send changes to remote
4. **Read-only snapshots by default** — Immutable, safe from accidental modification
5. **Labels help you find snapshots** — Use `--label` for manual snapshots

## Dependencies

- `btrfs-progs` (BTRFS userspace tools)
- `bash` (4.0+)
- `cron` (for scheduled snapshots)
- `ssh` (optional, for remote send/receive)
- `jq` (optional, for JSON output)
