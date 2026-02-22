# Listing Copy: Crontab Manager

## Metadata
- **Type:** Skill
- **Name:** crontab-manager
- **Display Name:** Crontab Manager
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, crontab]

## Tagline
Manage cron jobs with human-readable schedules — no more memorizing `* * * * *`

## Description

Cron syntax is cryptic. Is `0 */6 * * 1-5` every 6 hours on weekdays, or every Monday through Friday at 6am? One wrong field and your backup script runs every minute instead of every month.

Crontab Manager lets your OpenClaw agent manage cron jobs using human-readable schedules like "daily at 2am" or "weekdays at 9am". It validates expressions before applying them, auto-backs up your crontab before changes, and monitors job execution with logging and failure detection.

**What it does:**
- ✅ Add jobs with plain English schedules ("every 5 minutes", "daily at 2am")
- 🔍 Validate and explain cron expressions before applying
- 💾 Auto-backup crontab before every change, with restore/diff
- ⏸️ Disable/enable jobs without deleting them
- 📊 Monitor execution history and detect failures
- 📝 Optional log wrapper tracks stdout, stderr, exit codes, duration
- 🧹 Auto-prune old backups and logs

Perfect for developers and sysadmins who use cron daily but don't want to debug scheduling mistakes or lose jobs to a bad `crontab -e`.

## Core Capabilities

1. Human-readable scheduling — "daily at 2am" → `0 2 * * *`
2. Expression validation — Catches out-of-range values before they break
3. Plain English explain — Describe what any cron expression does
4. Auto-backup — Every modification backs up first
5. Backup restore & diff — Roll back or compare changes
6. Job disable/enable — Pause without deleting
7. Execution logging — Wrap commands to capture output + exit codes
8. Failure detection — Scan logs for non-zero exits
9. Cron service status — Verify the daemon is running
10. Backup pruning — Auto-clean old backups (configurable retention)

## Dependencies
- `bash` (4.0+)
- `crontab` (standard)
- `grep`, `sed`, `awk`, `date`

## Installation Time
**2 minutes** — chmod scripts, run first command
