# Listing Copy: Dead Man's Switch

## Metadata
- **Type:** Skill
- **Name:** deadman-switch
- **Display Name:** Dead Man's Switch
- **Categories:** [automation, dev-tools]
- **Icon:** ⏰
- **Dependencies:** [bash, curl, jq]

## Tagline
Monitor cron jobs & scheduled tasks — Get alerted when they fail to run

## Description

Your nightly backup script should run at 2am. But did it? If it silently failed, you won't know until something breaks. Dead Man's Switch monitors that your cron jobs and scheduled tasks actually execute by requiring them to "check in" within expected intervals.

Dead Man's Switch is a self-hosted cron job monitor. Register jobs with expected intervals, add a simple ping command to your scripts, and get instant alerts via Telegram, email, or webhook when something misses its window. No external services, no monthly fees — runs entirely on your machine using bash, curl, and jq.

**What it does:**
- ⏰ Register jobs with custom intervals and grace periods
- 📡 Jobs check in via CLI ping or HTTP endpoint
- 🔔 Instant alerts via Telegram, email, or webhook
- ⏸ Pause/resume during maintenance windows
- 📊 Status dashboard with JSON output
- 🏷️ Tag-based filtering for organized monitoring
- 📝 Full event log with history
- 🌐 Optional HTTP listener for remote pings
- 🧹 Auto-prune stale jobs

Perfect for sysadmins, developers, and anyone running scheduled tasks who needs confidence they're actually executing.

## Quick Start Preview

```bash
# Register a job
bash ~/.deadman/deadman.sh register --name "db-backup" --interval 86400 --grace 1800

# Add ping to your cron job
0 2 * * * /usr/local/bin/backup.sh && bash ~/.deadman/deadman.sh ping db-backup

# Install the checker (runs every minute)
* * * * * bash ~/.deadman/deadman.sh check
```
