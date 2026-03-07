---
name: disk-usage-analyzer
description: >-
  Analyze disk usage, find space hogs, and clean up your system with interactive reports and automated cleanup rules.
categories: [automation, productivity]
dependencies: [bash, ncdu, dust, duf]
---

# Disk Usage Analyzer

## What This Does

Find what's eating your disk space and reclaim it. Installs lightweight disk analysis tools (ncdu, dust, duf), scans directories for space hogs, generates human-readable reports, and sets up automated cleanup rules for logs, caches, and temp files.

**Example:** "Scan /home, find the 20 largest files, show directory treemap, clean up files older than 30 days in /tmp and /var/log."

## Quick Start (5 minutes)

### 1. Install Tools

```bash
bash scripts/install.sh
```

This installs:
- **duf** — Beautiful disk usage overview (like `df` but better)
- **dust** — Intuitive directory size viewer (like `du` but better)
- **ncdu** — Interactive disk usage explorer

### 2. Get Disk Overview

```bash
bash scripts/analyze.sh overview
```

**Output:**
```
╭──────────────────────────────────────────────────╮
│ DISK USAGE OVERVIEW — 2026-03-07                  │
├──────────────────────────────────────────────────┤
│ Filesystem  Size   Used  Avail  Use%  Mounted on │
│ /dev/sda1   100G   67G   33G    67%   /          │
│ /dev/sdb1   500G   312G  188G   62%   /data      │
╰──────────────────────────────────────────────────╯
```

### 3. Find Space Hogs

```bash
bash scripts/analyze.sh hogs /home 20
```

Shows the 20 largest files/directories under /home.

## Core Workflows

### Workflow 1: Full Disk Report

**Use case:** Get a comprehensive report of disk usage across all mounted filesystems.

```bash
bash scripts/analyze.sh report
```

Generates `disk-report-YYYY-MM-DD.txt` with:
- Filesystem overview (duf)
- Top 20 largest directories
- Top 20 largest files
- Old files (>90 days, >100MB)
- Duplicate-size files (potential duplicates)
- Cache/tmp sizes

### Workflow 2: Find Large Files

**Use case:** Hunt down files eating your space.

```bash
# Find files >100MB in /home
bash scripts/analyze.sh find-large /home 100M

# Find files >1GB anywhere
bash scripts/analyze.sh find-large / 1G

# Find files >500MB modified more than 30 days ago
bash scripts/analyze.sh find-stale / 500M 30
```

**Output:**
```
 1.2G  /home/user/Downloads/ubuntu-24.04.iso
 856M  /home/user/.cache/pip/wheels/...
 534M  /var/log/journal/abc123/system.journal
 412M  /home/user/node_modules/.cache/...
```

### Workflow 3: Directory Treemap

**Use case:** Visualize which directories use the most space.

```bash
# Top-level breakdown
bash scripts/analyze.sh tree /home 3

# Deeper analysis
bash scripts/analyze.sh tree /var 5
```

**Output (using dust):**
```
 15G  ┌── node_modules │████████████████████  │  45%
 8.2G ├── .cache       │██████████           │  25%
 4.1G ├── Documents    │█████                │  12%
 2.8G ├── Downloads    │███                  │   8%
 1.9G ├── Pictures     │██                   │   6%
 1.3G └── .local       │█                    │   4%
 33G     /home/user
```

### Workflow 4: Automated Cleanup

**Use case:** Clean up known safe targets (logs, caches, tmp files).

```bash
# Dry run — see what would be cleaned
bash scripts/cleanup.sh --dry-run

# Actually clean
bash scripts/cleanup.sh --execute

# Clean with custom config
bash scripts/cleanup.sh --config cleanup.yaml --execute
```

**Default cleanup targets:**
- `/tmp/*` older than 7 days
- `/var/tmp/*` older than 30 days
- `/var/log/*.gz` (compressed old logs)
- `~/.cache/pip` (pip cache)
- `~/.cache/yarn` (yarn cache)
- `~/.npm/_cacache` (npm cache)
- Docker dangling images (`docker image prune -f`)
- Journald logs older than 7 days

### Workflow 5: Schedule Regular Cleanup

**Use case:** Keep your disk clean automatically.

```bash
# Add weekly cleanup cron (Sunday 3am)
bash scripts/analyze.sh schedule weekly

# Add daily report (emailed or logged)
bash scripts/analyze.sh schedule daily-report
```

### Workflow 6: Monitor Disk Growth

**Use case:** Track which directories are growing over time.

```bash
# Take a snapshot
bash scripts/analyze.sh snapshot /home

# Compare with previous snapshot (after some time)
bash scripts/analyze.sh compare /home
```

**Output:**
```
Directory Growth Report (7 days):
  +2.3G  /home/user/node_modules  (was 12.7G → now 15.0G)
  +890M  /home/user/.cache        (was 7.3G → now 8.2G)
  -1.2G  /home/user/Downloads     (was 4.0G → now 2.8G) ✅ cleaned
  ─────
  Net: +2.0G growth in 7 days
  At this rate: disk full in ~165 days
```

## Configuration

### Cleanup Config (YAML)

```yaml
# cleanup.yaml
targets:
  - path: /tmp
    max_age_days: 7
    description: "Temp files"

  - path: /var/tmp
    max_age_days: 30
    description: "Persistent temp files"

  - path: /var/log
    pattern: "*.gz"
    max_age_days: 30
    description: "Compressed logs"

  - path: ~/.cache/pip
    max_age_days: 60
    description: "Pip cache"

  - path: ~/.npm/_cacache
    max_age_days: 30
    description: "NPM cache"

  - path: ~/node_modules/.cache
    max_age_days: 14
    description: "Webpack/build caches"

docker:
  prune_images: true
  prune_volumes: false  # dangerous — disabled by default
  prune_networks: true

journal:
  max_age_days: 7
  max_size: 500M
```

### Environment Variables

```bash
# Report output directory
export DISK_ANALYZER_REPORTS="/var/log/disk-reports"

# Snapshot storage
export DISK_ANALYZER_SNAPSHOTS="/var/lib/disk-analyzer"

# Alert threshold (percentage)
export DISK_ALERT_THRESHOLD=85
```

## Troubleshooting

### Issue: "command not found: dust"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: cargo install du-dust
# Mac: brew install dust
# Or download binary from https://github.com/bootandy/dust/releases
```

### Issue: "Permission denied" scanning system directories

**Fix:** Run with sudo:
```bash
sudo bash scripts/analyze.sh hogs / 20
```

### Issue: Cleanup removed something important

**Safety:** The cleanup script NEVER touches:
- Home directories (except caches)
- `/etc`, `/usr`, `/bin`, `/sbin`
- Running process files in `/proc`, `/sys`
- Database files

Always use `--dry-run` first.

## Dependencies

- `bash` (4.0+)
- `find`, `sort`, `du` (coreutils — always available)
- `duf` (installed by scripts/install.sh)
- `dust` (installed by scripts/install.sh)
- `ncdu` (installed by scripts/install.sh)
- Optional: `docker` (for container cleanup)
