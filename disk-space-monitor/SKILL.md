---
name: disk-space-monitor
description: >-
  Monitor disk usage across partitions, find large files, alert on low space, and auto-clean temp files.
categories: [automation, dev-tools]
dependencies: [bash, df, du, find]
---

# Disk Space Monitor

## What This Does

Monitors disk usage across all mounted partitions, alerts when space drops below configurable thresholds, finds the largest files/directories consuming space, and optionally auto-cleans temp files, old logs, and package caches. Runs as a one-shot check or scheduled via cron.

**Example:** "Check all disks, alert if any partition is >85% full, show top 20 largest files, clean apt/yum cache if space is critical."

## Quick Start (2 minutes)

### 1. Check Disk Usage Now

```bash
bash scripts/disk-monitor.sh --check
```

**Output:**
```
=== Disk Space Report (2026-02-22 04:53:00 UTC) ===

PARTITION          SIZE    USED   AVAIL  USE%  STATUS
/dev/sda1          50G     42G    5.8G   84%   ⚠️  WARNING
/dev/sdb1          200G    89G    101G   45%   ✅ OK
tmpfs              3.9G    12M    3.9G   1%    ✅ OK

⚠️  1 partition(s) above warning threshold (80%)
```

### 2. Find Large Files

```bash
bash scripts/disk-monitor.sh --find-large --path / --top 20
```

**Output:**
```
=== Top 20 Largest Files ===
  4.2G  /var/log/syslog.1
  2.1G  /home/user/.cache/thumbnails
  1.8G  /var/lib/docker/overlay2/abc123/merged
  1.2G  /tmp/large-download.iso
  ...
```

### 3. Auto-Clean (Safe Mode)

```bash
bash scripts/disk-monitor.sh --clean --dry-run
```

Shows what WOULD be cleaned without deleting anything. Remove `--dry-run` to execute.

## Core Workflows

### Workflow 1: Full Health Check

**Use case:** Daily disk health check with alerts

```bash
bash scripts/disk-monitor.sh \
  --check \
  --warn-threshold 80 \
  --critical-threshold 95 \
  --find-large --top 10 \
  --output json
```

### Workflow 2: Monitor + Alert via Telegram

```bash
bash scripts/disk-monitor.sh \
  --check \
  --critical-threshold 90 \
  --alert telegram \
  --telegram-token "$TELEGRAM_BOT_TOKEN" \
  --telegram-chat "$TELEGRAM_CHAT_ID"
```

Sends alert ONLY when a partition crosses the critical threshold.

### Workflow 3: Auto-Clean Safely

```bash
bash scripts/disk-monitor.sh --clean --targets apt,logs,tmp,docker
```

**What it cleans:**
- `apt` — `apt-get clean` / `yum clean all`
- `logs` — Rotated logs older than 7 days (`*.gz`, `*.1`, `*.old`)
- `tmp` — `/tmp` files older than 7 days
- `docker` — Unused Docker images, containers, volumes (`docker system prune`)
- `journal` — Systemd journal logs older than 7 days

### Workflow 4: Find Large Directories

```bash
bash scripts/disk-monitor.sh --find-large-dirs --path /home --top 10 --depth 3
```

**Output:**
```
=== Top 10 Largest Directories (max depth 3) ===
  12G   /home/user/.local/share/Steam
  8.4G  /home/user/projects/old-backups
  5.1G  /home/user/.cache
  ...
```

### Workflow 5: Scheduled Monitoring (Cron)

```bash
# Check every hour, alert on critical
echo "0 * * * * cd $(pwd) && bash scripts/disk-monitor.sh --check --critical-threshold 90 --alert telegram --telegram-token \$TELEGRAM_BOT_TOKEN --telegram-chat \$TELEGRAM_CHAT_ID >> /var/log/disk-monitor.log 2>&1" | crontab -

# Daily cleanup at 3 AM
echo "0 3 * * * cd $(pwd) && bash scripts/disk-monitor.sh --clean --targets logs,tmp,journal >> /var/log/disk-monitor.log 2>&1" | crontab -
```

### Workflow 6: Track Usage Over Time

```bash
bash scripts/disk-monitor.sh --check --log-history ~/.disk-history.csv
```

Appends usage data to CSV. Over time, you can spot trends:

```bash
bash scripts/disk-monitor.sh --trend --history-file ~/.disk-history.csv --partition /dev/sda1
```

**Output:**
```
=== Usage Trend for /dev/sda1 (last 30 days) ===
Feb 01: ████████████████░░░░ 78%
Feb 08: █████████████████░░░ 82%
Feb 15: █████████████████░░░ 85%  ← growing 1%/day
Feb 22: ██████████████████░░ 89%

⚠️  At current rate, partition will be FULL in ~11 days
```

## Configuration

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Email alerts (optional)
export SMTP_HOST="smtp.gmail.com"
export SMTP_USER="you@gmail.com"
export SMTP_PASS="app-password"
export ALERT_EMAIL="admin@example.com"

# Defaults
export DISK_WARN_THRESHOLD=80      # Percent
export DISK_CRITICAL_THRESHOLD=95  # Percent
```

### Config File (Optional)

```bash
cp scripts/config-template.yaml config.yaml
# Edit config.yaml, then:
bash scripts/disk-monitor.sh --config config.yaml
```

## Command Reference

| Flag | Description | Default |
|------|-------------|---------|
| `--check` | Show disk usage report | - |
| `--find-large` | Find largest files | - |
| `--find-large-dirs` | Find largest directories | - |
| `--clean` | Auto-clean temp/cache files | - |
| `--dry-run` | Show what would be cleaned | - |
| `--path <path>` | Target path for find operations | `/` |
| `--top <n>` | Number of results to show | `20` |
| `--depth <n>` | Max directory depth for scanning | `4` |
| `--warn-threshold <n>` | Warning percentage | `80` |
| `--critical-threshold <n>` | Critical percentage | `95` |
| `--alert <type>` | Alert method: telegram, email, webhook | - |
| `--targets <list>` | Clean targets (comma-separated) | `logs,tmp` |
| `--output <fmt>` | Output format: text, json, csv | `text` |
| `--log-history <file>` | Append usage to CSV history | - |
| `--trend` | Show usage trend from history | - |
| `--exclude <paths>` | Exclude paths (comma-separated) | `/proc,/sys,/dev` |

## Troubleshooting

### "Permission denied" on some directories

**Fix:** Run with `sudo` for full system scan:
```bash
sudo bash scripts/disk-monitor.sh --find-large --path /
```

### Docker cleanup not working

**Check:** Docker must be installed and user in `docker` group:
```bash
docker info >/dev/null 2>&1 && echo "Docker OK" || echo "Docker not available"
```

### Telegram alert not sending

**Test:**
```bash
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test" | jq .ok
```

## Dependencies

- `bash` (4.0+)
- `df`, `du`, `find` (coreutils — pre-installed on all Linux/Mac)
- `sort`, `awk`, `numfmt` (coreutils)
- Optional: `curl` (for Telegram/webhook alerts)
- Optional: `docker` (for Docker cleanup)
- Optional: `journalctl` (for journal cleanup)
