# Listing Copy: Systemd Timer Manager

- Type: Skill
- Name: systemd-timer-manager
- Display Name: Systemd Timer Manager
- Categories: [automation, dev-tools]
- Price: $12
- Dependencies: [systemd, bash, sudo]

## Tagline
Create reliable Linux scheduled jobs with systemd timers in minutes.

## Description
Cron is fast but brittle at scale. Systemd Timer Manager helps you create, inspect, and remove robust scheduled jobs using native `.service` and `.timer` units.

You can run jobs on interval calendars (`hourly`, `daily`, `*/15 * * * *`) or after boot delay (`OnBootSec=2min`), then inspect status and logs with one command. Great for backups, cache cleanups, sync jobs, and health checks.

### Core capabilities
- Create `.service` + `.timer` pairs automatically
- Enable and start timers immediately
- Use `OnCalendar` or `OnBootSec`
- View status + recent logs quickly
- Remove timers safely and reload daemon
