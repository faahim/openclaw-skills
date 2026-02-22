---
name: crontab-manager
description: >-
  Manage system cron jobs with backup, validation, human-readable scheduling, execution monitoring, and log analysis.
categories: [automation, dev-tools]
dependencies: [bash, crontab, mail]
---

# Crontab Manager

## What This Does

Manage Linux/macOS cron jobs without memorizing cron syntax. Create jobs with human-readable schedules ("every 5 minutes", "daily at 3am"), validate expressions before applying, backup/restore crontabs, monitor job execution, and analyze cron logs for failures.

**Example:** "Add a job that runs `backup.sh` every night at 2am, back up my current crontab first, then show me which jobs failed this week."

## Quick Start (2 minutes)

### 1. Install

```bash
# Copy scripts to your preferred location
chmod +x scripts/*.sh

# Verify cron is running
bash scripts/crontab-manager.sh status
```

### 2. List Current Jobs

```bash
bash scripts/crontab-manager.sh list
# Output:
# ID  Schedule              Command                    Next Run
# 1   */5 * * * *           /home/user/check.sh       in 3 minutes
# 2   0 2 * * *             /home/user/backup.sh      tomorrow 02:00
# 3   0 9 * * 1-5           /home/user/report.sh      Monday 09:00
```

### 3. Add a Job (Human-Readable)

```bash
# Using natural language
bash scripts/crontab-manager.sh add --schedule "every 5 minutes" --command "/home/user/check.sh"
bash scripts/crontab-manager.sh add --schedule "daily at 2am" --command "/home/user/backup.sh"
bash scripts/crontab-manager.sh add --schedule "weekdays at 9am" --command "/home/user/report.sh"
bash scripts/crontab-manager.sh add --schedule "every sunday at 6pm" --command "/home/user/weekly.sh"

# Using cron expression (validated before applying)
bash scripts/crontab-manager.sh add --cron "0 */6 * * *" --command "/home/user/sync.sh"
```

## Core Workflows

### Workflow 1: Backup & Restore

```bash
# Backup current crontab
bash scripts/crontab-manager.sh backup
# ✅ Backed up to ~/.crontab-manager/backups/2026-02-22T10:53:00Z.crontab

# List backups
bash scripts/crontab-manager.sh backups
# 1. 2026-02-22T10:53:00Z.crontab (5 jobs)
# 2. 2026-02-21T14:00:00Z.crontab (4 jobs)

# Restore from backup
bash scripts/crontab-manager.sh restore --id 1

# Diff current vs backup
bash scripts/crontab-manager.sh diff --id 2
```

### Workflow 2: Validate Cron Expressions

```bash
# Check if an expression is valid
bash scripts/crontab-manager.sh validate "*/5 * * * *"
# ✅ Valid: Every 5 minutes

bash scripts/crontab-manager.sh validate "0 25 * * *"
# ❌ Invalid: Hour must be 0-23 (got 25)

# Explain what an expression means
bash scripts/crontab-manager.sh explain "15 3 1,15 * *"
# At 03:15 on the 1st and 15th of every month
```

### Workflow 3: Monitor Execution

```bash
# Check which jobs ran recently
bash scripts/crontab-manager.sh history
# Last 24 hours:
# ✅ 02:00 /home/user/backup.sh (exit 0, 12s)
# ❌ 09:00 /home/user/report.sh (exit 1, 0.3s)
# ✅ 10:00 /home/user/check.sh (exit 0, 2s)

# Check for failed jobs
bash scripts/crontab-manager.sh failures --days 7
# 3 failures in last 7 days:
# ❌ Feb 22 09:00 /home/user/report.sh — exit 1
# ❌ Feb 21 09:00 /home/user/report.sh — exit 1
# ❌ Feb 20 02:00 /home/user/backup.sh — exit 2 (disk full)
```

### Workflow 4: Enable/Disable Jobs

```bash
# Disable a job (comments it out, doesn't delete)
bash scripts/crontab-manager.sh disable --id 2
# ✅ Disabled: 0 2 * * * /home/user/backup.sh

# Enable it back
bash scripts/crontab-manager.sh enable --id 2

# Remove a job entirely
bash scripts/crontab-manager.sh remove --id 3
```

### Workflow 5: Wrap Commands with Logging

```bash
# Add a job with automatic logging + exit code tracking
bash scripts/crontab-manager.sh add \
  --schedule "daily at 2am" \
  --command "/home/user/backup.sh" \
  --log  # Wraps command to log stdout/stderr and exit code

# Logs stored in ~/.crontab-manager/logs/<job-hash>/
# Each run: YYYY-MM-DD_HH-MM.log
```

## Human-Readable Schedule Reference

| Input | Cron Expression |
|-------|----------------|
| `every minute` | `* * * * *` |
| `every 5 minutes` | `*/5 * * * *` |
| `every hour` | `0 * * * *` |
| `every 6 hours` | `0 */6 * * *` |
| `daily at 2am` | `0 2 * * *` |
| `daily at 11:30pm` | `30 23 * * *` |
| `weekdays at 9am` | `0 9 * * 1-5` |
| `weekends at 10am` | `0 10 * * 0,6` |
| `every monday at 8am` | `0 8 * * 1` |
| `every sunday at 6pm` | `0 18 * * 0` |
| `monthly on 1st at midnight` | `0 0 1 * *` |
| `every 15th at noon` | `0 12 15 * *` |
| `yearly on jan 1` | `0 0 1 1 *` |

## Configuration

```bash
# Set default log directory
export CRONTAB_MANAGER_DIR="$HOME/.crontab-manager"

# Set max backup retention (default: 30)
export CRONTAB_MANAGER_MAX_BACKUPS=30

# Set log retention days (default: 90)
export CRONTAB_MANAGER_LOG_DAYS=90
```

## Troubleshooting

### Issue: "no crontab for user"
**Fix:** This is normal for first-time use. `crontab-manager add` will create one.

### Issue: Jobs not running
**Check:**
1. Cron daemon running: `systemctl status cron` or `service cron status`
2. Script is executable: `chmod +x /path/to/script.sh`
3. Full paths used (cron has minimal PATH)
4. Check mail: `mail` (cron sends output to user mail)

### Issue: Permission denied
**Fix:** Run with user's crontab (default) or `sudo` for system-wide `/etc/crontab`.

## Dependencies

- `bash` (4.0+)
- `crontab` (standard on Linux/macOS)
- `date` (GNU coreutils)
- `grep`, `sed`, `awk` (standard)
- Optional: `mail` (for checking cron error mail)
