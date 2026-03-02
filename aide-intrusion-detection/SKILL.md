---
name: aide-intrusion-detection
description: >-
  File integrity monitoring with AIDE — detect unauthorized changes to system files, configs, and binaries.
categories: [security, automation]
dependencies: [aide, bash, cron]
---

# AIDE Intrusion Detection

## What This Does

Monitors your server's critical files for unauthorized changes using AIDE (Advanced Intrusion Detection Environment). Detects when binaries, configs, or system files are modified, added, or deleted — and alerts you immediately.

**Example:** "Check every 6 hours if any file in /etc, /usr/bin, or /var/www changed. Alert via Telegram if something was modified unexpectedly."

## Quick Start (5 minutes)

### 1. Install AIDE

```bash
bash scripts/install.sh
```

### 2. Initialize Baseline Database

```bash
# Scan system and create baseline snapshot
bash scripts/run.sh init

# Output:
# [2026-03-02 17:55:00] Initializing AIDE database...
# [2026-03-02 17:55:32] ✅ Baseline created: /var/lib/aide/aide.db
# [2026-03-02 17:55:32] Monitored: 45,230 files across 12 directories
```

### 3. Check for Changes

```bash
# Compare current state against baseline
bash scripts/run.sh check

# Output (no changes):
# [2026-03-02 18:00:00] ✅ No unauthorized changes detected (45,230 files checked)

# Output (changes found):
# [2026-03-02 18:00:00] ⚠️ 3 changes detected:
#   MODIFIED: /etc/passwd (size: 2048→2102, mtime changed)
#   ADDED:    /usr/local/bin/suspicious-script
#   REMOVED:  /etc/cron.d/backup-job
```

## Core Workflows

### Workflow 1: Initialize & Monitor

**Use case:** First-time setup on a new server

```bash
# Install and initialize
bash scripts/install.sh
bash scripts/run.sh init

# Set up automated checks every 6 hours
bash scripts/run.sh schedule --interval 6h

# Output:
# ✅ Cron job created: check every 6 hours
# Next check: 2026-03-02 23:55:00 UTC
```

### Workflow 2: Check & Report

**Use case:** Manual integrity check

```bash
bash scripts/run.sh check --report /tmp/aide-report.txt

# Generates detailed report:
# - Files added since baseline
# - Files modified (with what changed: size, permissions, hash, mtime)
# - Files removed
# - Summary statistics
```

### Workflow 3: Update Baseline After Approved Changes

**Use case:** You installed new software or updated configs intentionally

```bash
# Review what changed
bash scripts/run.sh check

# If changes are expected, update the baseline
bash scripts/run.sh update

# Output:
# [2026-03-02 18:10:00] ✅ Baseline updated with 3 approved changes
# Previous baseline backed up to /var/lib/aide/aide.db.bak.20260302
```

### Workflow 4: Monitor Specific Directories

**Use case:** Watch only your web app or config files

```bash
# Monitor only specific paths
bash scripts/run.sh init --paths "/var/www,/etc/nginx,/home/deploy/.ssh"

# Output:
# ✅ Baseline created for 3 custom paths (1,203 files)
```

### Workflow 5: Alert on Changes

**Use case:** Get Telegram/webhook alerts when files change

```bash
# Set alert destination
export AIDE_ALERT_TELEGRAM_TOKEN="your-bot-token"
export AIDE_ALERT_TELEGRAM_CHAT="your-chat-id"

# Or webhook
export AIDE_ALERT_WEBHOOK="https://hooks.slack.com/services/xxx"

# Run check with alerts
bash scripts/run.sh check --alert

# On change detection:
# 🚨 Telegram: "AIDE Alert: 3 file changes detected on server-01"
```

## Configuration

### Config File

```bash
# Copy and edit config
cp scripts/aide-config.conf /etc/aide/aide.conf

# Key settings:
# - Which directories to monitor
# - What attributes to check (hash, size, permissions, owner, mtime)
# - What to ignore (logs, temp files, caches)
```

### Default Monitored Paths

```
/etc           — System configuration
/usr/bin       — System binaries
/usr/sbin      — System admin binaries
/usr/lib       — System libraries
/boot          — Kernel and bootloader
/var/www       — Web files (if exists)
/home/*/.ssh   — SSH keys
/root/.ssh     — Root SSH keys
```

### Default Ignored Paths

```
/var/log       — Log files (change constantly)
/var/cache      — Package caches
/tmp           — Temporary files
/proc          — Virtual filesystem
/sys           — Virtual filesystem
/run           — Runtime data
```

### Environment Variables

```bash
# Alert via Telegram
export AIDE_ALERT_TELEGRAM_TOKEN="<bot-token>"
export AIDE_ALERT_TELEGRAM_CHAT="<chat-id>"

# Alert via webhook (POST JSON)
export AIDE_ALERT_WEBHOOK="<webhook-url>"

# Alert via email
export AIDE_ALERT_EMAIL="admin@example.com"

# Custom config path
export AIDE_CONFIG="/etc/aide/aide.conf"

# Custom database path
export AIDE_DB="/var/lib/aide/aide.db"
```

## Advanced Usage

### Custom Check Rules

```bash
# Check only file hashes (fast, catches content changes)
bash scripts/run.sh check --rules hash

# Check everything (hash + permissions + owner + timestamps + size + ACLs)
bash scripts/run.sh check --rules full

# Check permissions only (fast, catches chmod/chown changes)
bash scripts/run.sh check --rules perms
```

### Exclude Patterns

```bash
# Ignore specific files during check
bash scripts/run.sh check --exclude "*.log,*.tmp,*.cache"
```

### Cron Integration

```bash
# Check every 6 hours, alert on changes
bash scripts/run.sh schedule --interval 6h --alert

# Check daily at 3am
bash scripts/run.sh schedule --cron "0 3 * * *" --alert

# Remove scheduled checks
bash scripts/run.sh unschedule
```

### JSON Output (for automation)

```bash
bash scripts/run.sh check --format json

# Output:
# {
#   "timestamp": "2026-03-02T18:00:00Z",
#   "status": "changes_detected",
#   "summary": {"added": 1, "modified": 2, "removed": 0},
#   "changes": [
#     {"path": "/etc/passwd", "type": "modified", "details": {"size": "2048→2102", "mtime": "changed"}},
#     ...
#   ]
# }
```

## Troubleshooting

### Issue: "aide: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
sudo apt-get install -y aide aide-common   # Debian/Ubuntu
sudo yum install -y aide                     # RHEL/CentOS
sudo pacman -S aide                          # Arch
```

### Issue: "Database not found"

**Fix:** Initialize the database first:
```bash
bash scripts/run.sh init
```

### Issue: Too many false positives from log files

**Fix:** Edit config to exclude log directories:
```bash
# In /etc/aide/aide.conf, add:
!/var/log
!/var/cache
```
Then update baseline: `bash scripts/run.sh update`

### Issue: Check takes too long

**Fix:** Narrow monitored paths:
```bash
bash scripts/run.sh init --paths "/etc,/usr/bin,/home/*/.ssh"
```

### Issue: Permission denied

**Fix:** AIDE needs root to read system files:
```bash
sudo bash scripts/run.sh check
```

## Key Principles

1. **Baseline first** — Always initialize before checking
2. **Update after changes** — After approved updates, refresh the baseline
3. **Automate checks** — Use cron for regular integrity verification
4. **Alert fast** — Telegram/webhook alerts on any unauthorized change
5. **Backup baselines** — Old baselines are auto-preserved with timestamps
