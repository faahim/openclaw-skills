---
name: system-cleanup
description: >-
  Automated system cleanup — reclaim disk space by purging temp files, old logs, package caches, Docker artifacts, and journal bloat.
categories: [automation, dev-tools]
dependencies: [bash, du, journalctl]
---

# System Cleanup & Maintenance

## What This Does

Reclaims disk space and keeps your server healthy by automatically cleaning temp files, old logs, package manager caches, Docker artifacts, and systemd journal bloat. Runs as a one-shot or scheduled via cron. Reports exactly what was cleaned and how much space was freed.

**Example:** "Free 4.2 GB by pruning Docker images, clearing apt cache, and rotating 90-day-old logs — in one command."

## Quick Start (2 minutes)

### 1. Check Current Disk Usage

```bash
bash scripts/cleanup.sh --dry-run
```

This shows what WOULD be cleaned without deleting anything.

### 2. Run Cleanup

```bash
bash scripts/cleanup.sh --all
```

### 3. Schedule Weekly Cleanup

```bash
# Add to crontab (Sunday 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * 0 cd $(pwd) && bash scripts/cleanup.sh --all --quiet >> /var/log/system-cleanup.log 2>&1") | crontab -
```

## Core Workflows

### Workflow 1: Full System Cleanup

```bash
bash scripts/cleanup.sh --all
```

Cleans ALL categories: temp files, package cache, old logs, Docker, journal.

**Sample output:**
```
🧹 System Cleanup Report — 2026-02-23T02:53:00Z
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Temp files:          142 MB freed
📦 Package cache:       891 MB freed
📜 Old logs (>30d):     234 MB freed
🐳 Docker prune:        2.1 GB freed
📓 Journal (>7d):       456 MB freed
🗑️  Trash:              89 MB freed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Total freed:         3.9 GB
💾 Disk after:          12.4 GB / 50.0 GB (24.8%)
```

### Workflow 2: Selective Cleanup

```bash
# Only clean Docker artifacts
bash scripts/cleanup.sh --docker

# Only clean package caches (apt/yum/brew)
bash scripts/cleanup.sh --packages

# Only rotate old logs
bash scripts/cleanup.sh --logs --log-age 60

# Only trim systemd journal
bash scripts/cleanup.sh --journal --journal-max 500M

# Combine specific targets
bash scripts/cleanup.sh --docker --packages --temp
```

### Workflow 3: Dry Run (Preview)

```bash
bash scripts/cleanup.sh --all --dry-run
```

Shows exactly what would be deleted and how much space would be freed — without touching anything.

### Workflow 4: Aggressive Mode (Low Disk Emergency)

```bash
bash scripts/cleanup.sh --aggressive
```

This runs all cleanups PLUS:
- Removes old kernel versions (keeps current + 1 previous)
- Clears pip/npm/cargo caches
- Removes orphaned packages
- Truncates large log files (>100MB) instead of just deleting old ones

## Configuration

### Command-Line Options

```
Usage: cleanup.sh [OPTIONS]

Targets (pick one or more, or --all):
  --all             Clean everything
  --temp            Clean /tmp, /var/tmp, ~/.cache/thumbnails
  --packages        Clean apt/yum/dnf/brew caches
  --logs            Remove old log files
  --docker          Prune Docker images, containers, volumes, networks
  --journal         Vacuum systemd journal
  --trash           Empty trash (~/.local/share/Trash)
  --npm             Clean npm cache
  --pip             Clean pip cache
  --cargo           Clean cargo cache

Options:
  --dry-run         Preview only (no deletions)
  --quiet           Minimal output (for cron)
  --aggressive      Maximum cleanup (removes old kernels, orphans)
  --log-age DAYS    Max log age in days (default: 30)
  --journal-max SIZE  Max journal size (default: 500M)
  --min-age DAYS    Min file age for temp cleanup (default: 7)
  --report FILE     Write JSON report to file
  --exclude PATTERN Skip paths matching pattern (repeatable)
```

### Environment Variables

```bash
# Override defaults via env
export CLEANUP_LOG_AGE=60          # Days before logs are deleted
export CLEANUP_JOURNAL_MAX=200M    # Max journal size
export CLEANUP_MIN_AGE=3           # Min age for temp file cleanup
export CLEANUP_EXCLUDE="/tmp/important,/var/log/audit"  # Comma-separated excludes
```

## Advanced Usage

### Run as OpenClaw Cron Job

The agent can schedule this via OpenClaw's cron system:

```
Schedule a weekly system cleanup every Sunday at 3 AM UTC.
Run: bash /path/to/scripts/cleanup.sh --all --quiet --report /tmp/cleanup-report.json
Then read the report and notify me if >1GB was freed or disk is >80% full.
```

### JSON Report Output

```bash
bash scripts/cleanup.sh --all --report /tmp/cleanup.json
cat /tmp/cleanup.json
```

```json
{
  "timestamp": "2026-02-23T03:00:00Z",
  "hostname": "myserver",
  "cleaned": {
    "temp": {"files": 342, "bytes_freed": 148897792},
    "packages": {"bytes_freed": 934281216},
    "logs": {"files": 28, "bytes_freed": 245366784},
    "docker": {"images": 5, "containers": 12, "bytes_freed": 2254857830},
    "journal": {"bytes_freed": 478150656}
  },
  "total_freed": 4061554278,
  "disk_after": {"used": 13312843776, "total": 53687091200, "percent": 24.8}
}
```

### Custom Exclusions

```bash
# Keep specific temp directories
bash scripts/cleanup.sh --all --exclude "/tmp/builds" --exclude "/var/log/nginx"
```

## Troubleshooting

### Issue: "Permission denied" on /var/log cleanup

**Fix:** Run with sudo for system-wide cleanup:
```bash
sudo bash scripts/cleanup.sh --all
```

User-level cleanup (no sudo needed):
```bash
bash scripts/cleanup.sh --temp --trash --npm --pip
```

### Issue: Docker not installed

The script auto-detects Docker. If not installed, `--docker` is silently skipped.

### Issue: apt/yum not found

The script auto-detects your package manager (apt, yum, dnf, pacman, brew). Only runs what's available.

## Dependencies

- `bash` (4.0+)
- `du`, `df`, `find` (coreutils — preinstalled everywhere)
- `journalctl` (optional — for journal cleanup)
- `docker` (optional — for Docker cleanup)
- `apt`/`yum`/`dnf`/`pacman`/`brew` (optional — auto-detected)

## Key Principles

1. **Safe by default** — dry-run shows everything before deleting
2. **Auto-detect** — finds your package manager, Docker, etc.
3. **Selective** — clean only what you want
4. **Reportable** — JSON output for monitoring/alerting
5. **Cron-ready** — quiet mode for scheduled runs
