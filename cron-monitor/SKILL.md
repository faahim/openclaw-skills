---
name: cron-monitor
description: >-
  Monitor system cron jobs — detect missed runs, track failures, alert on problems, and generate uptime reports.
categories: [automation, dev-tools]
dependencies: [bash, crontab, journalctl]
---

# Cron Job Monitor

## What This Does

Monitors your system's cron jobs for failures, missed runs, and performance issues. Parses your crontab, watches system logs for execution results, and alerts you when something goes wrong.

**Example:** "Monitor all cron jobs, alert via Telegram if any fail or miss their schedule, generate a daily uptime report."

## Quick Start (5 minutes)

### 1. Install

```bash
# Copy scripts to a persistent location
INSTALL_DIR="$HOME/.cron-monitor"
mkdir -p "$INSTALL_DIR"/{scripts,data,logs}
cp scripts/*.sh "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR/scripts/"*.sh

# Verify dependencies
which crontab journalctl jq || echo "Install missing: sudo apt-get install jq"
```

### 2. Run First Scan

```bash
# Scan current crontab and show all scheduled jobs
bash scripts/scan-crontab.sh

# Output:
# Found 5 cron jobs:
# [1] */5 * * * *  /home/user/backup.sh         (every 5 min)
# [2] 0 2 * * *    /home/user/cleanup.sh         (daily at 2am)
# [3] 0 * * * *    /usr/local/bin/healthcheck.sh  (hourly)
```

### 3. Check Recent Execution History

```bash
# Check journal for cron execution in last 24h
bash scripts/check-history.sh --hours 24

# Output:
# === Cron Execution Report (last 24h) ===
# ✅ backup.sh        — 288/288 runs  (100% success)
# ❌ cleanup.sh       — 0/1 runs      (MISSED at 02:00)
# ✅ healthcheck.sh   — 24/24 runs    (100% success)
```

### 4. Set Up Continuous Monitoring

```bash
# Add monitor as a cron job itself (checks every 10 min)
bash scripts/install-monitor.sh --interval 10 --alert telegram

# This adds to your crontab:
# */10 * * * * $HOME/.cron-monitor/scripts/monitor.sh >> $HOME/.cron-monitor/logs/monitor.log 2>&1
```

## Core Workflows

### Workflow 1: One-Time Health Check

**Use case:** Quick check if all cron jobs are running as expected.

```bash
bash scripts/check-history.sh --hours 24 --format summary
```

**Output:**
```
╔══════════════════════════════════════════╗
║         CRON HEALTH REPORT              ║
║         Last 24 hours                   ║
╠══════════════════════════════════════════╣
║ Total jobs:      5                      ║
║ Healthy:         4  ✅                  ║
║ Failed:          1  ❌                  ║
║ Missed:          0  ⚠️                  ║
║ Overall health:  80%                    ║
╠══════════════════════════════════════════╣
║ FAILURES:                               ║
║ • cleanup.sh — exit code 1 at 02:00    ║
║   stderr: "Permission denied"           ║
╚══════════════════════════════════════════╝
```

### Workflow 2: Continuous Monitoring with Alerts

**Use case:** Get notified when a cron job fails or misses its schedule.

```bash
# Configure alerts
cat > "$HOME/.cron-monitor/config.yaml" << 'EOF'
alerts:
  telegram:
    enabled: true
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"
  webhook:
    enabled: false
    url: "https://hooks.slack.com/..."

monitoring:
  check_interval: 600  # seconds (10 min)
  history_window: 3600 # look back 1 hour
  alert_on:
    - failure      # non-zero exit code
    - missed       # job didn't run on schedule
    - slow         # took longer than threshold

thresholds:
  slow_seconds: 300  # alert if job takes >5 min
  miss_tolerance: 2  # alert after 2 consecutive misses
EOF

# Start monitoring
bash scripts/monitor.sh --config "$HOME/.cron-monitor/config.yaml"
```

**Alert example (Telegram):**
```
🚨 CRON ALERT — myserver

❌ FAILED: /home/user/cleanup.sh
   Schedule: 0 2 * * * (daily at 2am)
   Exit code: 1
   Duration: 0.3s
   stderr: Permission denied: /var/log/app.log

   Last success: 2026-02-28 02:00:00 (48h ago)
```

### Workflow 3: Generate Uptime Report

**Use case:** Weekly cron job reliability report.

```bash
bash scripts/report.sh --days 7 --format markdown > /tmp/cron-report.md
```

**Output:**
```markdown
# Cron Job Report — Feb 22-Mar 1, 2026

## Summary
- **Jobs monitored:** 5
- **Total executions:** 2,304
- **Success rate:** 99.7%
- **Failures:** 7

## Per-Job Breakdown

| Job | Schedule | Runs | Success | Avg Time | Failures |
|-----|----------|------|---------|----------|----------|
| backup.sh | */5 * * * * | 2,016 | 100% | 2.3s | 0 |
| cleanup.sh | 0 2 * * * | 7 | 85.7% | 45s | 1 |
| healthcheck.sh | 0 * * * * | 168 | 100% | 0.5s | 0 |
| deploy-check.sh | */30 * * * * | 336 | 98.2% | 12s | 6 |
| log-rotate.sh | 0 0 * * * | 7 | 100% | 3.1s | 0 |

## Failure Details

### cleanup.sh (1 failure)
- **Feb 26 02:00** — Exit 1: "Permission denied: /var/log/app.log"

### deploy-check.sh (6 failures)
- **Feb 23 14:30** — Exit 2: "Connection timeout"
- **Feb 24 09:00** — Exit 2: "Connection timeout"
- ...
```

### Workflow 4: Monitor Specific Jobs Only

**Use case:** Only monitor critical jobs, ignore others.

```bash
# Create a watchlist
cat > "$HOME/.cron-monitor/watchlist.txt" << 'EOF'
backup.sh
deploy-check.sh
healthcheck.sh
EOF

bash scripts/monitor.sh --watchlist "$HOME/.cron-monitor/watchlist.txt"
```

## Configuration

### Config File (YAML)

```yaml
# $HOME/.cron-monitor/config.yaml

# Which crontabs to monitor
sources:
  - user        # current user's crontab
  - /etc/crontab
  - /etc/cron.d/*

# Alert channels
alerts:
  telegram:
    enabled: true
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"
  webhook:
    enabled: false
    url: ""
    headers:
      Content-Type: "application/json"
  email:
    enabled: false
    to: "admin@example.com"
    smtp_host: "smtp.gmail.com"

# What to monitor
monitoring:
  check_interval: 600
  history_window: 3600
  alert_on: [failure, missed, slow]

# Thresholds
thresholds:
  slow_seconds: 300
  miss_tolerance: 2
  max_retries: 3
```

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Data directory (default: ~/.cron-monitor/data)
export CRON_MONITOR_DATA="$HOME/.cron-monitor/data"
```

## Advanced Usage

### Run as Systemd Timer (instead of cron)

```bash
bash scripts/install-systemd.sh --interval 10min
# Creates systemd timer + service for monitoring
```

### Export History to JSON

```bash
bash scripts/check-history.sh --hours 168 --format json > cron-history.json
```

### Integration with OpenClaw Cron

```bash
# Monitor OpenClaw's own cron jobs
bash scripts/check-history.sh --grep "openclaw" --hours 24
```

## Troubleshooting

### Issue: "No cron entries found"

**Check:**
1. User has a crontab: `crontab -l`
2. System crontab exists: `cat /etc/crontab`
3. Run with sudo for system-wide: `sudo bash scripts/scan-crontab.sh`

### Issue: "Journal access denied"

**Fix:**
```bash
# Add user to systemd-journal group
sudo usermod -aG systemd-journal $USER
# Re-login required
```

### Issue: Missed job not detected

**Check:** The monitor's check interval must be shorter than the job's schedule interval. If a job runs hourly, check at least every 30 minutes.

## Dependencies

- `bash` (4.0+)
- `crontab` (read cron schedules)
- `journalctl` (read execution logs) OR `/var/log/syslog`
- `jq` (JSON processing)
- `curl` (for Telegram/webhook alerts)
- Optional: `systemd` (for timer-based monitoring)
