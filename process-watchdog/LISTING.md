# Listing Copy: Process Watchdog

## Metadata
- **Type:** Skill
- **Name:** process-watchdog
- **Display Name:** Process Watchdog
- **Categories:** [automation, dev-tools]
- **Price:** $10
- **Icon:** 👁️
- **Dependencies:** [bash, ps, systemctl]

## Tagline

Monitor processes and auto-restart on crash — with instant Telegram/webhook alerts

## Description

Crashed services cost you users, revenue, and sleep. By the time you notice your app is down, the damage is done.

Process Watchdog monitors your processes every 10 seconds and auto-restarts them if they die. Get instant alerts via Telegram, webhook, or email. Smart flap detection prevents restart loops. Install as a systemd service for 24/7 protection.

**What it does:**
- 👁️ Monitor processes by name, PID file, or systemd service
- 🔄 Auto-restart crashed processes with configurable commands
- 🔔 Instant alerts via Telegram, Slack webhook, or email
- 🛡️ Flap detection — backs off if process keeps crashing
- 📊 Track restart history and uptime statistics
- ⚡ Install as systemd service — runs on boot, survives reboots
- 📋 YAML config for monitoring multiple processes at once

Perfect for developers, sysadmins, and indie hackers running self-hosted services who need reliable process monitoring without heavyweight solutions like Monit or Supervisor.

## Quick Start Preview

```bash
# Monitor nginx, restart if it crashes, alert on Telegram
bash scripts/watchdog.sh --service nginx --alert telegram --interval 10

# [2026-03-02 07:00:00] 👁️ Watching: nginx (interval: 10s)
# [2026-03-02 07:00:10] ✅ nginx — running (PID: 1234)
```

## Core Capabilities

1. Process monitoring — Check by name (pgrep), PID file, or systemd service
2. Auto-restart — Custom restart commands or systemctl restart
3. Health checks — HTTP endpoint checks beyond just "is it running?"
4. Telegram alerts — Instant notification when processes crash or restart
5. Webhook alerts — Send to Slack, Discord, or any webhook endpoint
6. Flap detection — Stop restart loops, alert for manual intervention
7. Multi-process config — YAML config for monitoring multiple services
8. Systemd integration — Install as persistent service, runs on boot
9. Restart statistics — Track uptime percentage and restart history
10. Cooldown system — Configurable delay between restart attempts
