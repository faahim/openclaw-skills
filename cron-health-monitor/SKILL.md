---
name: cron-health-monitor
description: >-
  Wrap cron jobs to track success/failure, measure duration, detect missed runs, and alert on problems. Self-hosted monitoring with no external services.
categories: [automation, dev-tools]
dependencies: [bash, curl]
---

# Cron Health Monitor

## What This Does

Wraps your cron jobs with a lightweight monitor that tracks every execution — pass/fail, duration, stdout/stderr. Detects missed runs, alerts via Telegram or webhook when jobs fail, and generates health reports. Zero external services, fully self-hosted.

**Example:** "Monitor 15 cron jobs, get a Telegram alert if any fail or miss their schedule, review weekly health reports."

## Quick Start (5 minutes)

### 1. Install

```bash
# Create monitor directory
sudo mkdir -p /opt/cron-health-monitor/{logs,data}
sudo chmod 755 /opt/cron-health-monitor

# Copy scripts
sudo cp scripts/cronwrap.sh /opt/cron-health-monitor/cronwrap.sh
sudo cp scripts/cron-report.sh /opt/cron-health-monitor/cron-report.sh
sudo cp scripts/cron-watchdog.sh /opt/cron-health-monitor/cron-watchdog.sh
sudo chmod +x /opt/cron-health-monitor/*.sh

# Initialize config
sudo cp scripts/config.env /opt/cron-health-monitor/config.env
```

### 2. Configure Alerts (Optional)

```bash
# Edit /opt/cron-health-monitor/config.env
sudo nano /opt/cron-health-monitor/config.env
```

```bash
# Telegram alerts
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"

# Or webhook alerts
WEBHOOK_URL="https://hooks.slack.com/services/..."

# Or email alerts
ALERT_EMAIL="admin@example.com"
```

### 3. Wrap Your First Cron Job

**Before:**
```
*/5 * * * * /usr/local/bin/backup.sh
```

**After:**
```
*/5 * * * * /opt/cron-health-monitor/cronwrap.sh "backup" "*/5 * * * *" /usr/local/bin/backup.sh
```

That's it. The wrapper tracks everything automatically.

### 4. Add the Watchdog (Detects Missed Runs)

```bash
# Add to crontab — runs every 10 minutes
*/10 * * * * /opt/cron-health-monitor/cron-watchdog.sh
```

## Core Workflows

### Workflow 1: Wrap a Cron Job

```bash
# Syntax: cronwrap.sh <job-name> <schedule> <command> [args...]
/opt/cron-health-monitor/cronwrap.sh "db-backup" "0 2 * * *" pg_dump -U postgres mydb > /backups/mydb.sql
```

**What happens:**
- Records start time, end time, duration
- Captures exit code, stdout, stderr
- Logs to `/opt/cron-health-monitor/data/<job-name>.jsonl`
- On failure (exit != 0): sends alert

**Log entry (JSON Lines):**
```json
{"job":"db-backup","ts":"2026-03-06T20:00:00Z","duration_s":45,"exit":0,"status":"ok","stdout_lines":3,"stderr_lines":0}
```

### Workflow 2: Detect Missed Runs

The watchdog checks if jobs ran on schedule:

```bash
# Runs automatically via cron, or manually:
/opt/cron-health-monitor/cron-watchdog.sh
```

**How it works:**
- Reads each job's schedule (stored in `data/jobs.json`)
- Compares last run time against expected schedule
- If a job is overdue by >2x its interval, sends "MISSED RUN" alert

**Alert example:**
```
🚨 CRON MISSED: db-backup
Expected: every day at 02:00
Last run: 2026-03-05T02:00:12Z (25 hours ago)
Status: OVERDUE
```

### Workflow 3: Generate Health Report

```bash
# Daily/weekly report
/opt/cron-health-monitor/cron-report.sh

# Report for specific job
/opt/cron-health-monitor/cron-report.sh --job db-backup

# Report for last 7 days
/opt/cron-health-monitor/cron-report.sh --days 7
```

**Output:**
```
╔══════════════════════════════════════════════════════╗
║             CRON HEALTH REPORT — Last 7 Days        ║
╠══════════════════════════════════════════════════════╣
║ Job              │ Runs │ Pass │ Fail │ Avg Time     ║
╠──────────────────┼──────┼──────┼──────┼──────────────╣
║ db-backup        │  7   │  7   │  0   │ 45s          ║
║ log-rotate       │  7   │  6   │  1   │ 2s           ║
║ ssl-renew        │  1   │  1   │  0   │ 12s          ║
║ cache-clear      │ 168  │ 168  │  0   │ <1s          ║
╠──────────────────┼──────┼──────┼──────┼──────────────╣
║ TOTAL            │ 183  │ 182  │  1   │ 99.5% pass   ║
╚══════════════════════════════════════════════════════╝

⚠️  1 failure detected:
  log-rotate — 2026-03-04T03:00:15Z — exit 1
  stderr: "Permission denied: /var/log/app.log"
```

### Workflow 4: Wrap with Timeout

```bash
# Kill job if it runs longer than 300 seconds
/opt/cron-health-monitor/cronwrap.sh "slow-job" "*/30 * * * *" --timeout 300 /usr/local/bin/slow-task.sh
```

**On timeout:**
```
🚨 CRON TIMEOUT: slow-job
Duration: 300s (limit: 300s)
Process killed (SIGTERM → SIGKILL after 10s)
```

### Workflow 5: View Recent Failures

```bash
# Show last 10 failures across all jobs
/opt/cron-health-monitor/cron-report.sh --failures --limit 10
```

**Output:**
```
Recent Failures:
─────────────────────────────────────────────
2026-03-04 03:00:15 │ log-rotate  │ exit 1 │ Permission denied
2026-03-02 14:30:00 │ api-sync    │ exit 2 │ Connection refused
2026-03-01 08:00:00 │ report-gen  │ timeout│ Killed after 600s
```

## Configuration

### Environment Variables (`config.env`)

```bash
# === Alert Configuration ===

# Telegram (recommended)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Webhook (Slack, Discord, custom)
WEBHOOK_URL=""

# Email (requires sendmail/msmtp)
ALERT_EMAIL=""

# === Behavior ===

# Max log entries per job (older entries pruned)
MAX_LOG_ENTRIES=1000

# Watchdog: alert if job is overdue by this factor of its interval
OVERDUE_FACTOR=2

# Capture stdout/stderr (true/false — disable for large output)
CAPTURE_OUTPUT=true

# Max captured output lines per stream
MAX_OUTPUT_LINES=50

# Default timeout (0 = no timeout)
DEFAULT_TIMEOUT=0

# Quiet mode: suppress alerts for N minutes after first alert (anti-spam)
ALERT_COOLDOWN_MINUTES=30
```

### Job Registry (`data/jobs.json`)

Auto-populated when you first wrap a job:

```json
{
  "db-backup": {
    "schedule": "0 2 * * *",
    "registered": "2026-03-06T20:00:00Z",
    "timeout": 0,
    "alert_on_fail": true
  },
  "log-rotate": {
    "schedule": "0 3 * * *",
    "registered": "2026-03-06T20:00:00Z",
    "timeout": 60,
    "alert_on_fail": true
  }
}
```

## Advanced Usage

### Schedule Health Report via Cron

```bash
# Daily report at 8am
0 8 * * * /opt/cron-health-monitor/cron-report.sh --days 1 | /opt/cron-health-monitor/cronwrap.sh "health-report" "0 8 * * *" cat

# Weekly report on Monday
0 8 * * 1 /opt/cron-health-monitor/cron-report.sh --days 7 --send-telegram
```

### Disable Alerts for Specific Job

```bash
# Edit data/jobs.json, set alert_on_fail to false
jq '.["noisy-job"].alert_on_fail = false' /opt/cron-health-monitor/data/jobs.json > tmp.json && mv tmp.json /opt/cron-health-monitor/data/jobs.json
```

### Prune Old Logs

```bash
# Manually prune logs older than 30 days
find /opt/cron-health-monitor/data/ -name "*.jsonl" -exec sh -c '
  tmp=$(mktemp)
  cutoff=$(date -d "30 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-30d +%Y-%m-%dT%H:%M:%SZ)
  jq -c "select(.ts > \"$cutoff\")" "$1" > "$tmp" && mv "$tmp" "$1"
' _ {} \;
```

### Export Data as CSV

```bash
# Export job history
/opt/cron-health-monitor/cron-report.sh --export csv --job db-backup > db-backup-history.csv
```

## Troubleshooting

### Issue: "cronwrap.sh: Permission denied"

```bash
sudo chmod +x /opt/cron-health-monitor/cronwrap.sh
```

### Issue: Telegram alerts not arriving

```bash
# Test alert manually
source /opt/cron-health-monitor/config.env
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=Test alert from cron-health-monitor"
```

### Issue: Watchdog reports false positives

Increase `OVERDUE_FACTOR` in config.env:
```bash
OVERDUE_FACTOR=3  # Alert only if 3x overdue instead of 2x
```

### Issue: Log files growing too large

```bash
# Reduce max entries
sed -i 's/MAX_LOG_ENTRIES=1000/MAX_LOG_ENTRIES=200/' /opt/cron-health-monitor/config.env
# Prune now
/opt/cron-health-monitor/cron-report.sh --prune
```

## Dependencies

- `bash` (4.0+)
- `curl` (for alerts)
- `jq` (for JSON processing)
- `date` (GNU coreutils)
- Optional: `sendmail` or `msmtp` (for email alerts)
