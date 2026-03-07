# Listing Copy: Disk Usage Analyzer

## Metadata
- **Type:** Skill
- **Name:** disk-usage-analyzer
- **Display Name:** Disk Usage Analyzer
- **Categories:** [automation, productivity]
- **Price:** $8
- **Dependencies:** [bash, ncdu, dust, duf]

## Tagline

Analyze disk usage, find space hogs, and reclaim storage with automated cleanup

## Description

Running out of disk space is the silent killer of servers and dev machines. By the time you notice, builds are failing, databases are crashing, and you're frantically deleting random files at 2am.

Disk Usage Analyzer installs lightweight analysis tools (duf, dust, ncdu) and gives your OpenClaw agent superpowers to find what's eating your storage. Beautiful treemap visualizations, large file hunting, stale file detection, and automated cleanup of caches, logs, and temp files — all from simple commands.

**What it does:**
- 📊 Beautiful disk overview across all filesystems
- 🔍 Find largest files and directories instantly
- 🌳 Visual directory treemaps showing space distribution
- 🗑️ Automated cleanup of caches, logs, temp files, Docker cruft
- 📸 Snapshot & compare — track disk growth over time
- 🔔 Alert when filesystems exceed usage thresholds
- ⏰ Schedule weekly cleanups and daily reports via cron
- 🐳 Docker image/network/build cache pruning

Perfect for developers, sysadmins, and anyone who's ever wondered "where did all my disk space go?"

## Quick Start Preview

```bash
# Install tools
bash scripts/install.sh

# See what's eating your disk
bash scripts/analyze.sh hogs /home 20

# Preview cleanup (safe — nothing deleted)
bash scripts/cleanup.sh --dry-run

# Actually clean up
bash scripts/cleanup.sh --execute
```

## Core Capabilities

1. Filesystem overview — Beautiful table of all mounts with usage percentages
2. Space hog finder — Top N largest files/directories in any path
3. Directory treemap — Visual size breakdown using dust
4. Large file hunter — Find files above any size threshold
5. Stale file detector — Find large files not accessed in N days
6. Automated cleanup — Safe removal of caches, logs, temp files
7. Docker cleanup — Prune dangling images, networks, build cache
8. Snapshot & compare — Track disk growth over days/weeks
9. Threshold alerts — Warn when filesystems get full
10. Cron scheduling — Automate weekly cleanups and daily reports

## Dependencies
- `bash` (4.0+)
- `duf` (installed automatically)
- `dust` (installed automatically)
- `ncdu` (installed automatically)

## Installation Time
**5 minutes** — One script installs everything
