---
name: zfs-snapshot-manager
description: Automated ZFS snapshots + retention pruning for datasets using simple scripts and cron.
categories: [data, automation]
dependencies: [zfs]
---

# ZFS Snapshot Manager

Create, rotate, and prune ZFS snapshots without babysitting commands.

This skill gives you:
- Scheduled snapshots (`hourly`, `daily`, `weekly`)
- Per-class retention (`KEEP_HOURLY`, `KEEP_DAILY`, `KEEP_WEEKLY`)
- Safe dry-run mode before destructive prune operations

## Quick Start (5 minutes)

### 1) Install/check prerequisites
```bash
bash scripts/install.sh
```

### 2) Configure datasets
```bash
cp scripts/config-template.env ~/.config/zfs-snapshot-manager/config.env
nano ~/.config/zfs-snapshot-manager/config.env
```

Set at least one dataset:
```bash
DATASETS="tank/data"
```

### 3) Create first snapshot
```bash
bash scripts/run.sh --action snapshot --class hourly
```

### 4) Prune old snapshots
```bash
bash scripts/run.sh --action prune --dry-run
bash scripts/run.sh --action prune
```

## Core Workflows

### Snapshot now
```bash
bash scripts/run.sh --action snapshot --class hourly
bash scripts/run.sh --action snapshot --class daily
bash scripts/run.sh --action snapshot --class weekly
```

### View managed snapshots
```bash
bash scripts/run.sh --action status
```

### Retention cleanup
```bash
bash scripts/run.sh --action prune
```

## Cron Automation

Run `crontab -e` and add:

```cron
# Hourly snapshot at minute 5
5 * * * * cd /path/to/zfs-snapshot-manager && bash scripts/run.sh --action snapshot --class hourly >> /var/log/zfs-snapshot-manager.log 2>&1

# Daily snapshot at 02:15
15 2 * * * cd /path/to/zfs-snapshot-manager && bash scripts/run.sh --action snapshot --class daily >> /var/log/zfs-snapshot-manager.log 2>&1

# Weekly snapshot every Sunday 03:00
0 3 * * 0 cd /path/to/zfs-snapshot-manager && bash scripts/run.sh --action snapshot --class weekly >> /var/log/zfs-snapshot-manager.log 2>&1

# Prune old snapshots every day at 03:30
30 3 * * * cd /path/to/zfs-snapshot-manager && bash scripts/run.sh --action prune >> /var/log/zfs-snapshot-manager.log 2>&1
```

## Troubleshooting

### `zfs: command not found`
Install ZFS tools first.

Ubuntu/Debian:
```bash
sudo apt-get update && sudo apt-get install -y zfsutils-linux
```

### `cannot open 'tank/data': dataset does not exist`
Check dataset names:
```bash
zfs list -o name
```

### Want to verify prune safety
Always run:
```bash
bash scripts/run.sh --action prune --dry-run
```

## Files
- `scripts/install.sh` — setup + config bootstrap
- `scripts/run.sh` — snapshot/prune/status engine
- `scripts/config-template.env` — config template
- `examples/example-usage.md` — practical command cheatsheet
