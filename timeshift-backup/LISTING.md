# Listing Copy: Timeshift System Backup

## Metadata
- **Type:** Skill
- **Name:** timeshift-backup
- **Display Name:** Timeshift System Backup
- **Categories:** [automation, data]
- **Icon:** 📸
- **Dependencies:** [timeshift, bash, rsync]

## Tagline

Automated Linux system snapshots — Roll back your entire OS in seconds

## Description

One bad `apt upgrade` or misconfigured file can break your entire Linux system. Without backups, you're looking at hours of reinstalling and reconfiguring. You need automated snapshots that just work.

Timeshift System Backup installs and configures Timeshift — the "Time Machine for Linux." It creates incremental system snapshots on a schedule you control, so you can restore your entire system to any previous state with a single command. Supports both RSYNC (any filesystem) and BTRFS (instant snapshots) modes.

**What it does:**
- 📸 Create manual snapshots before risky changes
- 📅 Schedule daily, weekly, and monthly automatic snapshots
- 🔄 Restore your entire system to any previous snapshot
- 🧹 Auto-prune old snapshots to save disk space
- 💾 Monitor disk usage with configurable alerts
- 🔧 Works on Ubuntu, Debian, Fedora, Arch, openSUSE
- 🚀 Setup in under 5 minutes — running with one command

Perfect for developers, sysadmins, and anyone running Linux who wants peace of mind before system changes.

## Quick Start Preview

```bash
# Install Timeshift
bash scripts/install.sh

# Create first snapshot
sudo bash scripts/run.sh --create --comment "Initial backup"

# Enable daily snapshots (keep 7)
sudo bash scripts/run.sh --schedule --daily 7 --weekly 4
```

## Core Capabilities

1. One-command install — Detects distro, installs Timeshift automatically
2. Manual snapshots — Checkpoint before risky updates or config changes
3. Scheduled backups — Daily, weekly, monthly with configurable retention
4. Instant restore — Roll back entire system to any snapshot
5. Smart pruning — Auto-delete snapshots older than N days
6. Disk monitoring — Alert when snapshot storage exceeds threshold
7. Exclude directories — Skip /home/Downloads, /tmp, etc.
8. RSYNC + BTRFS — Works on any Linux filesystem
9. External drive support — Store snapshots on separate media
10. Pre-update hooks — Auto-snapshot before apt/dnf upgrades
