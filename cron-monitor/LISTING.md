# Listing Copy: Cron Job Monitor

## Metadata
- **Type:** Skill
- **Name:** cron-monitor
- **Display Name:** Cron Job Monitor
- **Categories:** [automation, dev-tools]
- **Price:** $10
- **Dependencies:** [bash, crontab, journalctl, jq, curl]

## Tagline

Monitor your cron jobs — detect failures, missed runs, and alert instantly.

## Description

Cron jobs are the backbone of server automation, but when they fail silently, you don't know until something breaks. By the time you notice a missed backup or a failed cleanup script, the damage is done.

Cron Job Monitor watches your system's cron jobs and alerts you the moment something goes wrong. It parses your crontab, monitors system logs for execution results, detects missed schedules, and sends alerts via Telegram, Slack webhooks, or email. No external services needed — it runs entirely on your server.

**What it does:**
- 📋 Scan and catalog all cron jobs (user + system)
- ✅ Track execution success/failure from system logs
- ❌ Detect missed runs and non-zero exit codes
- 🔔 Alert via Telegram, webhooks, or email
- 📊 Generate uptime reports (daily/weekly/monthly)
- ⏱️ Monitor job duration and alert on slow runs
- 🛡️ Alert deduplication (no spam on repeated failures)

Perfect for sysadmins, developers, and anyone running scheduled tasks who needs to know when something breaks — before users do.

## Quick Start Preview

```bash
# Scan all cron jobs
bash scripts/scan-crontab.sh

# Check last 24h of execution history
bash scripts/check-history.sh --hours 24

# Install continuous monitoring (every 10 min)
bash scripts/install-monitor.sh --interval 10 --alert telegram
```

## Core Capabilities

1. Crontab scanning — Parse user, system, and cron.d jobs
2. Execution tracking — Monitor journalctl/syslog for cron output
3. Failure detection — Alert on non-zero exit codes
4. Missed run detection — Compare expected vs actual executions
5. Telegram alerts — Instant notifications with job details
6. Webhook alerts — Slack, Discord, or custom endpoints
7. Uptime reports — Markdown/JSON reports with per-job stats
8. Alert deduplication — 1-hour cooldown per issue (no spam)
9. Watchlist filtering — Monitor only critical jobs
10. Zero dependencies — Uses bash, curl, jq (standard tools)

## Installation Time
**5 minutes** — Run install script, configure alerts
