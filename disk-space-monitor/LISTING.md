# Listing Copy: Disk Space Monitor

## Metadata
- **Type:** Skill
- **Name:** disk-space-monitor
- **Display Name:** Disk Space Monitor
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, coreutils]

## Tagline

Monitor disk usage, find space hogs, auto-clean — never run out of space again.

## Description

Running out of disk space crashes databases, kills deployments, and ruins your day. By the time you notice, it's already an emergency. You need automated monitoring that catches problems before they become outages.

Disk Space Monitor checks all mounted partitions, alerts you when usage crosses configurable thresholds, finds the largest files and directories consuming space, and auto-cleans temp files, rotated logs, package caches, and Docker cruft. No external services needed — it runs entirely on your machine with standard Linux tools.

**What it does:**
- 📊 Check all disk partitions with color-coded status (OK / Warning / Critical)
- 🔍 Find the largest files and directories eating your space
- 🧹 Auto-clean temp files, old logs, apt/yum cache, Docker images, journal logs
- 📬 Alert via Telegram, email, or webhook when partitions get full
- 📈 Track usage over time and predict when you'll run out
- ⏰ Schedule hourly checks and nightly cleanups via cron
- 🛡️ Safe dry-run mode — preview what would be cleaned before deleting

**Perfect for:** Developers, sysadmins, and anyone running servers who wants automated disk monitoring without setting up Prometheus/Grafana.

## Quick Start Preview

```bash
# Full health check
bash scripts/disk-monitor.sh --check

# Find what's eating your space
bash scripts/disk-monitor.sh --find-large --top 20

# Preview cleanup (safe)
bash scripts/disk-monitor.sh --clean --targets apt,logs,tmp,docker --dry-run
```

## Core Capabilities

1. Partition monitoring — Check all mounted filesystems with percentage thresholds
2. Large file finder — Locate the biggest files consuming space
3. Directory analyzer — Find largest directories with configurable depth
4. Auto-cleanup — Safely remove temp files, old logs, caches, Docker cruft
5. Telegram alerts — Get notified instantly when space is critical
6. Usage history — Log to CSV and track trends over time
7. Trend prediction — Estimate when partition will be full at current growth rate
8. Dry-run mode — Preview all cleanup actions before executing
9. Multiple clean targets — apt, yum, logs, tmp, docker, journal, npm, pip
10. Cron-ready — One-liner to add hourly monitoring + nightly cleanup
11. JSON/CSV output — Machine-readable output for integration
12. Zero dependencies — Uses only standard Linux coreutils

## Dependencies
- `bash` (4.0+)
- `df`, `du`, `find`, `sort`, `awk` (coreutils — pre-installed)
- Optional: `curl` (Telegram/webhook alerts)
- Optional: `docker` (Docker cleanup)

## Installation Time
**2 minutes** — No installation needed, just run the script.
