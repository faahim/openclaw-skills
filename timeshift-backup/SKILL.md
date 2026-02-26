---
name: timeshift-backup
description: >-
  Install and configure Timeshift for automated Linux system snapshots. Create, schedule, and restore full system backups with one command.
categories: [automation, data]
dependencies: [timeshift, bash]
---

# Timeshift System Backup

## What This Does

Automates Linux system backup using Timeshift — the "Time Machine for Linux." Creates incremental system snapshots on schedule, so you can restore your entire system to any previous state if something breaks.

**Example:** "Take daily system snapshots, keep 7 daily + 4 weekly, auto-delete old ones. Restore to yesterday's snapshot when an update breaks things."

## Quick Start (5 minutes)

### 1. Install Timeshift

```bash
bash scripts/install.sh
```

### 2. Create Your First Snapshot

```bash
bash scripts/run.sh --create --comment "Initial backup"
```

### 3. Enable Scheduled Snapshots

```bash
bash scripts/run.sh --schedule --daily 7 --weekly 4 --monthly 2
```

## Core Workflows

### Workflow 1: Create Manual Snapshot

**Use case:** Before a risky update or config change

```bash
bash scripts/run.sh --create --comment "Before kernel update"
```

**Output:**
```
[2026-02-26 13:00:00] 📸 Creating snapshot...
[2026-02-26 13:00:45] ✅ Snapshot created: 2026-02-26_13-00-00 (Before kernel update)
[2026-02-26 13:00:45] 💾 Size: 2.3 GB | Device: /dev/sda1
```

### Workflow 2: List All Snapshots

```bash
bash scripts/run.sh --list
```

**Output:**
```
# | Snapshot                 | Comment              | Size
1 | 2026-02-26_13-00-00     | Before kernel update | 2.3 GB
2 | 2026-02-25_00-00-00     | Scheduled: Daily     | 2.1 GB
3 | 2026-02-24_00-00-00     | Scheduled: Daily     | 2.1 GB
```

### Workflow 3: Restore a Snapshot

**Use case:** System broke after an update — roll back

```bash
bash scripts/run.sh --restore --snapshot 2026-02-25_00-00-00
```

**⚠️ Warning:** This replaces system files. You'll be prompted to confirm.

### Workflow 4: Delete Old Snapshots

```bash
# Delete a specific snapshot
bash scripts/run.sh --delete --snapshot 2026-02-24_00-00-00

# Delete all snapshots older than 30 days
bash scripts/run.sh --prune --older-than 30
```

### Workflow 5: Check Snapshot Health

```bash
bash scripts/run.sh --status
```

**Output:**
```
Timeshift Status
================
Mode:       RSYNC
Device:     /dev/sda1 (ext4)
Snapshots:  5 total (8.2 GB used)
Schedule:   Daily (keep 7) | Weekly (keep 4) | Monthly (keep 2)
Next run:   2026-02-27 00:00:00
Disk free:  45.3 GB (85% free)
```

## Configuration

### Schedule Options

```bash
# Daily snapshots, keep last 7
bash scripts/run.sh --schedule --daily 7

# Daily + weekly + monthly
bash scripts/run.sh --schedule --daily 7 --weekly 4 --monthly 2

# Disable scheduled snapshots
bash scripts/run.sh --schedule --disable
```

### Snapshot Type

```bash
# RSYNC mode (works on any filesystem) — DEFAULT
bash scripts/run.sh --mode rsync

# BTRFS mode (faster, needs btrfs filesystem)
bash scripts/run.sh --mode btrfs
```

### Exclude Directories

```bash
# Add directories to exclude from snapshots
bash scripts/run.sh --exclude /home/user/Downloads,/var/log,/tmp

# View current excludes
bash scripts/run.sh --show-excludes
```

### Target Device

```bash
# Use a specific device for snapshots
bash scripts/run.sh --device /dev/sdb1

# List available devices
bash scripts/run.sh --list-devices
```

## Advanced Usage

### Run as Cron Job (Alternative to Built-in Scheduler)

```bash
# Add to root crontab — snapshot at 2am daily
echo "0 2 * * * /path/to/scripts/run.sh --create --comment 'Cron: Daily'" | sudo tee -a /var/spool/cron/crontabs/root
```

### Pre-Update Snapshot Hook

```bash
# Auto-snapshot before apt upgrades (Debian/Ubuntu)
sudo cp scripts/pre-apt-snapshot.sh /etc/apt/apt.conf.d/80-timeshift-snapshot
```

### Monitor Disk Usage

```bash
# Alert if snapshot disk usage exceeds 80%
bash scripts/run.sh --check-disk --threshold 80
```

**Output on threshold breach:**
```
⚠️ ALERT: Snapshot disk at 82% capacity!
Consider pruning old snapshots: bash scripts/run.sh --prune --older-than 14
```

### Snapshot to External Drive

```bash
# Mount external drive and use it for snapshots
bash scripts/run.sh --device /dev/sdb1 --mount /mnt/backup
```

## Troubleshooting

### Issue: "timeshift: command not found"

**Fix:** Run the install script:
```bash
bash scripts/install.sh
```

### Issue: "No space left on device"

**Fix:** Prune old snapshots:
```bash
bash scripts/run.sh --prune --older-than 7
# Or delete specific snapshots
bash scripts/run.sh --list
bash scripts/run.sh --delete --snapshot <name>
```

### Issue: BTRFS mode not available

**Check:** Your root filesystem must be btrfs:
```bash
df -T / | awk 'NR==2 {print $2}'
```
If not btrfs, use RSYNC mode (default).

### Issue: Restore fails on running system

**Fix:** For full system restore, boot from a live USB and run:
```bash
sudo timeshift --restore --snapshot <name> --target /dev/sda1
```

## Dependencies

- `timeshift` (installed by `scripts/install.sh`)
- `bash` (4.0+)
- `rsync` (for RSYNC mode — usually pre-installed)
- Root/sudo access (required for system snapshots)

## Key Principles

1. **Snapshot before changes** — Always create a snapshot before updates/installs
2. **Keep rotation lean** — 7 daily + 4 weekly is plenty for most systems
3. **Monitor disk space** — Snapshots eat disk; prune regularly
4. **Test restores** — Periodically verify snapshots actually work
5. **Separate drive recommended** — Keep snapshots on a different drive than your system
