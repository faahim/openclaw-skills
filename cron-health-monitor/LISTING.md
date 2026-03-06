# Listing Copy: Cron Health Monitor

## Metadata
- **Type:** Skill
- **Name:** cron-health-monitor
- **Display Name:** Cron Health Monitor
- **Categories:** [automation, dev-tools]
- **Icon:** ⏰
- **Dependencies:** [bash, curl, jq]

## Tagline

Monitor cron jobs — Track execution, detect failures, alert on missed runs

## Description

Your cron jobs run silently in the background — until they don't. A failed backup, a missed sync, a hung script — you won't know until the damage is done.

Cron Health Monitor wraps your cron jobs with lightweight tracking. Every execution is logged: pass/fail, duration, exit code, stderr output. A watchdog detects missed runs by comparing actual execution against expected schedules. When something breaks, you get an instant alert via Telegram, Slack webhook, or email.

**What it does:**
- ⏱️ Track every cron job execution (duration, exit code, output)
- 🚨 Instant alerts on failures via Telegram, webhook, or email
- 👁️ Detect missed/overdue runs automatically
- ⏳ Kill hung jobs with configurable timeouts
- 📊 Generate health reports (pass rate, avg duration, failure details)
- 🔇 Smart alert cooldown — no spam on repeated failures
- 📦 Export history as CSV for analysis
- 🪶 Pure bash — no heavy dependencies, no external services

Perfect for sysadmins, developers, and anyone running scheduled tasks who needs visibility without enterprise monitoring complexity.

## Quick Start Preview

```bash
# Before: silent cron job
*/5 * * * * /usr/local/bin/backup.sh

# After: monitored cron job
*/5 * * * * /opt/cron-health-monitor/cronwrap.sh "backup" "*/5 * * * *" /usr/local/bin/backup.sh
```

## Core Capabilities

1. Job wrapping — One-line change to monitor any cron job
2. Execution logging — JSON Lines format with duration, exit code, output
3. Failure alerts — Telegram, Slack webhook, email, custom webhook
4. Missed run detection — Watchdog compares actual vs expected schedule
5. Timeout enforcement — Kill hung jobs after configurable duration
6. Health reports — ASCII table with pass rate, avg duration, failures
7. Alert cooldown — Suppress repeat alerts to prevent notification spam
8. CSV export — Export job history for external analysis
9. Log pruning — Auto-rotate logs to prevent disk fill
10. Zero dependencies — Pure bash + curl + jq, no external services

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- `date` (GNU coreutils)

## Installation Time
5 minutes
