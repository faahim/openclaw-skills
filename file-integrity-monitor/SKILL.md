---
name: file-integrity-monitor
description: >-
  Monitor files and directories for unauthorized changes using SHA-256 hashing. Get instant alerts when files are modified, added, or deleted.
categories: [security, automation]
dependencies: [bash, sha256sum, find]
---

# File Integrity Monitor

## What This Does

Monitors critical files and directories for unauthorized modifications using SHA-256 checksums. Creates a baseline hash database, then scans periodically to detect changes — files modified, added, or deleted. Alerts via Telegram, email, or webhook when changes are detected.

Think of it as a lightweight AIDE/Tripwire that runs entirely in bash with zero dependencies beyond coreutils.

**Example:** "Monitor /etc, /usr/bin, and your web root — get a Telegram alert if any config file changes unexpectedly."

## Quick Start (3 minutes)

### 1. Initialize Baseline

```bash
# Monitor a single directory
bash scripts/fim.sh init --path /etc --db ~/.fim/etc.db

# Monitor multiple paths
bash scripts/fim.sh init --config config.yaml
```

### 2. Run a Check

```bash
# Check against baseline
bash scripts/fim.sh check --db ~/.fim/etc.db

# Output:
# [2026-03-07 16:00:00] 🔍 Scanning 1,247 files...
# [2026-03-07 16:00:03] ✅ No changes detected (1,247 files verified)
```

### 3. When Changes Are Detected

```
[2026-03-07 16:00:00] 🔍 Scanning 1,247 files...
[2026-03-07 16:00:03] ⚠️  3 changes detected:

  MODIFIED: /etc/passwd (hash mismatch)
    Old: a1b2c3d4e5f6...
    New: f6e5d4c3b2a1...

  ADDED:   /etc/cron.d/suspicious-job
    Hash: 9a8b7c6d5e4f...

  DELETED: /etc/security/access.conf

[2026-03-07 16:00:03] 🚨 Alert sent via Telegram
```

## Configuration

### Config File (YAML-style)

```bash
# Create config
cat > ~/.fim/config.yaml << 'EOF'
# File Integrity Monitor Configuration

# Directories to monitor
paths:
  - /etc
  - /usr/local/bin
  - /var/www/html
  - /home/user/.ssh

# File patterns to exclude
exclude:
  - "*.log"
  - "*.tmp"
  - "*.swp"
  - "*.cache"
  - "__pycache__"

# Alert configuration
alerts:
  telegram:
    enabled: true
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"
  webhook:
    enabled: false
    url: "https://hooks.slack.com/services/..."
  email:
    enabled: false
    to: "admin@example.com"

# Database location
db_dir: ~/.fim/databases

# Max file size to hash (skip large files)
max_file_size: 50M

# Include file permissions and ownership in checks
check_permissions: true
EOF
```

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

# Email alerts (SMTP)
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="your-email"
export SMTP_PASS="your-password"
```

## Core Workflows

### Workflow 1: Monitor System Config Files

```bash
# Initialize baseline for /etc
bash scripts/fim.sh init --path /etc --exclude "*.log,*.tmp" --db ~/.fim/etc.db

# Check for changes (run via cron)
bash scripts/fim.sh check --db ~/.fim/etc.db --alert telegram
```

### Workflow 2: Monitor Web Application Files

```bash
# Baseline your web root
bash scripts/fim.sh init --path /var/www/html --exclude "*.log,uploads/*" --db ~/.fim/webroot.db

# Detect defacement or backdoor injection
bash scripts/fim.sh check --db ~/.fim/webroot.db --alert webhook
```

### Workflow 3: Monitor SSH Keys & Auth Files

```bash
# Critical auth files
bash scripts/fim.sh init \
  --path /home/*/.ssh \
  --path /etc/ssh \
  --path /etc/sudoers.d \
  --db ~/.fim/auth.db

# Check with high priority alerting
bash scripts/fim.sh check --db ~/.fim/auth.db --alert telegram --severity critical
```

### Workflow 4: Full System Scan with Config

```bash
# Use config file for multi-path monitoring
bash scripts/fim.sh init --config ~/.fim/config.yaml
bash scripts/fim.sh check --config ~/.fim/config.yaml
```

### Workflow 5: Update Baseline After Legitimate Changes

```bash
# After you've made intentional changes, update the baseline
bash scripts/fim.sh update --db ~/.fim/etc.db

# Or update specific files only
bash scripts/fim.sh update --db ~/.fim/etc.db --path /etc/nginx/nginx.conf
```

### Workflow 6: Generate Report

```bash
# Generate a summary report
bash scripts/fim.sh report --db ~/.fim/etc.db

# Output:
# === File Integrity Report ===
# Database: /home/user/.fim/etc.db
# Baseline: 2026-03-07 12:00:00 UTC
# Files tracked: 1,247
# Last check: 2026-03-07 16:00:00 UTC
# Changes since baseline: 3 (2 modified, 1 added, 0 deleted)
# Database size: 156 KB
```

## Run on Schedule

### With Cron

```bash
# Check every 15 minutes
*/15 * * * * bash /path/to/scripts/fim.sh check --config ~/.fim/config.yaml >> ~/.fim/fim.log 2>&1

# Daily full re-baseline (optional)
0 3 * * * bash /path/to/scripts/fim.sh init --config ~/.fim/config.yaml
```

### With OpenClaw Cron

```bash
# Add to OpenClaw cron for agent-managed monitoring
# The agent can run: bash scripts/fim.sh check --config ~/.fim/config.yaml
# And interpret results, take action on alerts
```

### With Systemd Timer

```bash
# Create timer for periodic checks
bash scripts/fim.sh install-timer --interval 15min
```

## Advanced Usage

### Compare Two Baselines

```bash
# See what changed between two snapshots
bash scripts/fim.sh diff --old ~/.fim/etc.db.2026-03-06 --new ~/.fim/etc.db.2026-03-07
```

### Export to JSON

```bash
# Export current database as JSON for processing
bash scripts/fim.sh export --db ~/.fim/etc.db --format json > report.json
```

### Verify Specific File

```bash
# Quick check a single file against baseline
bash scripts/fim.sh verify --db ~/.fim/etc.db --file /etc/passwd
```

## Troubleshooting

### Issue: "Permission denied" on some files

**Fix:** Run with sudo for system directories:
```bash
sudo bash scripts/fim.sh init --path /etc --db ~/.fim/etc.db
```

### Issue: Scan takes too long

**Fix:** Exclude large/irrelevant directories and set max file size:
```bash
bash scripts/fim.sh init --path /etc --exclude "*.log,*.journal" --max-size 10M --db ~/.fim/etc.db
```

### Issue: Too many false positives from log rotation

**Fix:** Exclude dynamic files:
```bash
# In config.yaml, add to exclude:
exclude:
  - "*.log"
  - "*.pid"
  - "*.lock"
  - "/etc/mtab"
  - "/etc/resolv.conf"
```

## How It Works

1. **Init:** Walks target directories, computes SHA-256 hash of each file, stores hash + path + size + permissions + mtime in a flat database file
2. **Check:** Re-walks directories, computes fresh hashes, compares against stored baseline
3. **Alert:** On any mismatch (modified/added/deleted), sends notification via configured channel
4. **Update:** After reviewing changes, updates baseline to accept current state

## Dependencies

- `bash` (4.0+) — Script runtime
- `sha256sum` — Hash computation (part of coreutils)
- `find` — Directory traversal (part of findutils)
- `stat` — File metadata (part of coreutils)
- `curl` — Alert delivery (Telegram/webhook)
- Optional: `mail` — Email alerts

All dependencies are pre-installed on virtually every Linux system.

## Key Principles

1. **Zero external deps** — Uses only coreutils, works on any Linux/Mac
2. **Fast scans** — Parallel hashing for large directories
3. **Low false positives** — Configurable exclusions for dynamic files
4. **Tamper-resistant** — Database can be stored on read-only media
5. **Lightweight** — No daemon, no database server, just bash + flat files
