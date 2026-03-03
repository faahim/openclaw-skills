# Listing Copy: BTRFS Snapshot Manager

## Metadata
- **Type:** Skill
- **Name:** btrfs-snapshot-manager
- **Display Name:** BTRFS Snapshot Manager
- **Categories:** [automation, data]
- **Price:** $12
- **Icon:** 📸
- **Dependencies:** [btrfs-progs, bash, cron]

## Tagline

Automate BTRFS snapshots — scheduled creation, retention policies, and instant rollback

## Description

Manually managing filesystem snapshots is tedious and error-prone. Miss a backup before a risky update, and you're stuck recovering from scratch. Forget cleanup, and snapshots silently eat your disk.

BTRFS Snapshot Manager automates the entire lifecycle: create read-only snapshots on schedule (hourly/daily/weekly/monthly), enforce retention policies so old snapshots get cleaned up automatically, and roll back to any previous state in seconds. No external services, no complex setup — just a single bash script and a YAML config.

**What it does:**
- 📸 Create labeled, read-only snapshots with one command
- ⏱️ Scheduled snapshots via cron (hourly, daily, weekly, monthly)
- 🗑️ Automatic cleanup with configurable retention policies
- ⏪ Instant rollback to any previous snapshot (with safety backup)
- 📊 Diff between snapshots to see exactly what changed
- 📤 Send snapshots to remote machines (incremental backups via SSH)
- 🔔 Telegram alerts on snapshot failures
- 📈 Disk usage monitoring for snapshot overhead

**Who it's for:** Developers, sysadmins, and Linux power users running BTRFS who want automated, reliable filesystem snapshots without the complexity of Snapper or Timeshift.

## Quick Start Preview

```bash
# Take a snapshot before upgrading
sudo bash scripts/btrfs-snap.sh snap /home --label before-upgrade

# Set up automatic hourly snapshots
sudo bash scripts/btrfs-snap.sh install-cron config.yaml

# Roll back if something breaks
sudo bash scripts/btrfs-snap.sh rollback /home 2026-03-03_before-upgrade
```

## Core Capabilities

1. One-command snapshots — `snap /home --label my-backup`
2. Scheduled automation — Hourly/daily/weekly/monthly via cron
3. Retention policies — Keep N snapshots per tier, auto-delete rest
4. Instant rollback — Restore any snapshot with safety backup
5. Snapshot diffing — See exactly what changed between two snapshots
6. Remote send/receive — Incremental backups over SSH
7. Disk monitoring — Track snapshot overhead and free space
8. Telegram alerts — Get notified on failures
9. YAML config — Simple, readable configuration
10. Zero dependencies — Just bash + btrfs-progs (already on most systems)

## Dependencies
- `btrfs-progs` (BTRFS tools)
- `bash` (4.0+)
- `cron` (scheduling)
- `ssh` (optional, remote backups)

## Installation Time
**5 minutes** — Install btrfs-progs, copy config, run
