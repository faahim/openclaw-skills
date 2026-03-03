---
name: systemd-timer-manager
description: Install, configure, and automate recurring jobs with systemd timers. Use when you need reliable scheduled tasks with logs, retries, and service-level control on Linux hosts.
---

# Systemd Timer Manager

Automate recurring jobs using native `systemd` timers instead of fragile crontab entries. This skill creates, validates, and manages `.service` + `.timer` units with safe defaults.

## Quick Start

```bash
cd /home/clawd/clawmart-factory/output/systemd-timer-manager
bash scripts/install.sh

# Create a timer that runs every 15 minutes
bash scripts/create_timer.sh \
  --name cleanup-cache \
  --command '/usr/bin/find /tmp -type f -mtime +3 -delete' \
  --on-calendar '*/15 * * * *'

# Verify status + next run
bash scripts/list_timers.sh cleanup-cache
```

## Workflows

### 1) Create recurring job
```bash
bash scripts/create_timer.sh \
  --name check-disk \
  --command '/usr/bin/df -h > /var/log/check-disk.log' \
  --on-calendar 'hourly'
```

### 2) Create boot-delayed job
```bash
bash scripts/create_timer.sh \
  --name boot-sync \
  --command '/usr/local/bin/sync-job.sh' \
  --on-boot-sec '2min'
```

### 3) Remove timer cleanly
```bash
bash scripts/remove_timer.sh check-disk
```

## Notes
- Requires Linux with `systemd` PID 1.
- Writes units to `/etc/systemd/system` (uses sudo).
- Logs are visible with `journalctl -u <name>.service -f`.
