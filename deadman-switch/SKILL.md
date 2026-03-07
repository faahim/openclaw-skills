---
name: deadman-switch
description: >-
  Self-hosted dead man's switch that monitors cron jobs and scheduled tasks.
  Alerts when jobs fail to check in within expected intervals.
categories: [automation, dev-tools]
dependencies: [bash, curl, jq]
---

# Dead Man's Switch

## What This Does

Monitors that your cron jobs and scheduled tasks actually run. Each job "checks in" by hitting a local endpoint or running a ping command. If a job misses its expected check-in window, you get alerted via Telegram, email, or webhook.

Think healthchecks.io — but self-hosted, zero dependencies, runs entirely on your machine.

**Example:** Your nightly database backup should run at 2am. If it doesn't check in by 2:30am, you get a Telegram alert: "⚠️ db-backup missed check-in (30m overdue)".

## Quick Start (3 minutes)

### 1. Install

```bash
# Create the deadman directory
DEADMAN_DIR="${DEADMAN_DIR:-$HOME/.deadman}"
mkdir -p "$DEADMAN_DIR"/{jobs,logs}

# Copy scripts
cp scripts/deadman.sh "$DEADMAN_DIR/deadman.sh"
chmod +x "$DEADMAN_DIR/deadman.sh"
```

### 2. Register Your First Job

```bash
# Register a job that should check in every 5 minutes
bash "$DEADMAN_DIR/deadman.sh" register \
  --name "my-backup" \
  --interval 300 \
  --grace 60

# Output:
# ✅ Registered job: my-backup
# Interval: 300s | Grace: 60s
# Ping with: bash ~/.deadman/deadman.sh ping my-backup
```

### 3. Add Ping to Your Cron Job

```bash
# In your existing crontab, append the ping:
# Before:
# 0 2 * * * /usr/local/bin/backup.sh
#
# After:
# 0 2 * * * /usr/local/bin/backup.sh && bash ~/.deadman/deadman.sh ping my-backup
```

### 4. Set Up Monitoring

```bash
# Add the checker to crontab (runs every minute)
(crontab -l 2>/dev/null; echo "* * * * * bash $HOME/.deadman/deadman.sh check") | crontab -

# Output: Deadman checker installed (runs every 60s)
```

### 5. Configure Alerts

```bash
# Telegram alerts
bash "$DEADMAN_DIR/deadman.sh" config \
  --telegram-token "YOUR_BOT_TOKEN" \
  --telegram-chat "YOUR_CHAT_ID"

# Or webhook alerts
bash "$DEADMAN_DIR/deadman.sh" config \
  --webhook "https://hooks.slack.com/services/..."

# Or email alerts (requires mailx/sendmail)
bash "$DEADMAN_DIR/deadman.sh" config \
  --email "admin@example.com"
```

## Core Workflows

### Workflow 1: Monitor Cron Jobs

**Use case:** Ensure nightly backups, log rotations, and cleanup scripts actually run.

```bash
# Register multiple jobs
bash ~/.deadman/deadman.sh register --name "db-backup" --interval 86400 --grace 1800
bash ~/.deadman/deadman.sh register --name "log-rotate" --interval 86400 --grace 3600
bash ~/.deadman/deadman.sh register --name "cert-renew" --interval 604800 --grace 86400

# List all monitored jobs
bash ~/.deadman/deadman.sh list

# Output:
# NAME          INTERVAL   GRACE    LAST PING            STATUS
# db-backup     24h        30m      2026-03-07 02:01:15  ✅ OK
# log-rotate    24h        1h       2026-03-07 03:00:02  ✅ OK
# cert-renew    7d         24h      2026-03-05 12:00:00  ✅ OK
```

### Workflow 2: Monitor Heartbeat Services

**Use case:** Ensure long-running daemons are alive.

```bash
# Register a service that should ping every 60 seconds
bash ~/.deadman/deadman.sh register --name "api-server" --interval 60 --grace 30

# In your service's health check loop:
while true; do
  if curl -sf http://localhost:3000/health > /dev/null; then
    bash ~/.deadman/deadman.sh ping api-server
  fi
  sleep 60
done
```

### Workflow 3: Monitor Remote Jobs via HTTP

**Use case:** Remote servers ping your deadman switch over HTTP.

```bash
# Start the HTTP listener (lightweight, uses socat or python)
bash ~/.deadman/deadman.sh serve --port 8090 &

# Remote machines ping via HTTP:
# curl -sf http://your-server:8090/ping/remote-backup
```

### Workflow 4: Pause/Resume Monitoring

```bash
# Pause during maintenance
bash ~/.deadman/deadman.sh pause db-backup --duration 2h

# Resume early
bash ~/.deadman/deadman.sh resume db-backup
```

## Configuration

### Config File

```bash
# ~/.deadman/config.json
{
  "alert_channels": {
    "telegram": {
      "bot_token": "YOUR_BOT_TOKEN",
      "chat_id": "YOUR_CHAT_ID"
    },
    "webhook": {
      "url": "https://hooks.slack.com/services/...",
      "method": "POST"
    },
    "email": {
      "to": "admin@example.com",
      "from": "deadman@$(hostname)",
      "smtp": "localhost"
    }
  },
  "defaults": {
    "grace_seconds": 300,
    "alert_repeat_seconds": 3600,
    "alert_channels": ["telegram"]
  }
}
```

### Job File Format

```bash
# ~/.deadman/jobs/db-backup.json
{
  "name": "db-backup",
  "interval_seconds": 86400,
  "grace_seconds": 1800,
  "last_ping": "2026-03-07T02:01:15Z",
  "status": "ok",
  "last_alert": null,
  "paused_until": null,
  "created_at": "2026-03-01T00:00:00Z",
  "alert_channels": ["telegram"],
  "tags": ["backup", "database"]
}
```

### Environment Variables

```bash
export DEADMAN_DIR="$HOME/.deadman"          # Base directory
export DEADMAN_TELEGRAM_TOKEN="bot_token"    # Telegram bot token
export DEADMAN_TELEGRAM_CHAT="chat_id"       # Telegram chat ID
export DEADMAN_WEBHOOK_URL="https://..."     # Webhook URL
export DEADMAN_EMAIL="admin@example.com"     # Alert email
```

## Advanced Usage

### Custom Alert Messages

```bash
bash ~/.deadman/deadman.sh register \
  --name "payment-processor" \
  --interval 300 \
  --grace 60 \
  --alert-message "🚨 CRITICAL: Payment processor hasn't checked in!"
```

### Tags & Filtering

```bash
# Add tags when registering
bash ~/.deadman/deadman.sh register --name "db-backup" --interval 86400 --tags "backup,critical"

# List only critical jobs
bash ~/.deadman/deadman.sh list --tag critical

# Check only jobs with specific tags
bash ~/.deadman/deadman.sh check --tag backup
```

### Status Summary (for dashboards)

```bash
# JSON output for integration
bash ~/.deadman/deadman.sh status --json

# Output:
# {
#   "total": 5,
#   "ok": 4,
#   "late": 1,
#   "paused": 0,
#   "jobs": [...]
# }
```

### Log History

```bash
# View alert history
bash ~/.deadman/deadman.sh log --last 20

# Output:
# 2026-03-07 02:35:00 ⚠️ db-backup LATE (5m overdue)
# 2026-03-07 02:36:12 ✅ db-backup recovered (pinged)
# 2026-03-06 14:00:00 ⚠️ cert-renew LATE (2h overdue)
```

### Cleanup Old Jobs

```bash
# Remove a job
bash ~/.deadman/deadman.sh remove db-backup

# Remove jobs with no ping in 30 days
bash ~/.deadman/deadman.sh prune --days 30
```

## Troubleshooting

### Issue: Alerts not sending

**Check config:**
```bash
bash ~/.deadman/deadman.sh config --test
# Sends a test alert to all configured channels
```

### Issue: Job shows LATE but it ran

**Check:** The ping command may not be running after the job.
```bash
# Ensure ping runs AFTER the job succeeds:
/path/to/job.sh && bash ~/.deadman/deadman.sh ping job-name

# Not:
/path/to/job.sh; bash ~/.deadman/deadman.sh ping job-name  # Pings even on failure!
```

### Issue: Too many alerts

**Fix:** Increase grace period or alert repeat interval:
```bash
bash ~/.deadman/deadman.sh update db-backup --grace 3600 --alert-repeat 7200
```

## Key Principles

1. **Zero dependencies** — Pure bash + curl + jq (standard on any server)
2. **File-based state** — No database, just JSON files in ~/.deadman/jobs/
3. **Idempotent pings** — Multiple pings in the same interval are fine
4. **Alert deduplication** — Won't spam you; configurable repeat interval
5. **Fail-open** — If deadman itself fails, it won't block your jobs
