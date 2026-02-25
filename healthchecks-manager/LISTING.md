# Listing Copy: Healthchecks Manager

## Metadata
- **Type:** Skill
- **Name:** healthchecks-manager
- **Display Name:** Healthchecks Manager
- **Categories:** [automation, dev-tools]
- **Icon:** 🏥
- **Dependencies:** [docker, docker-compose, curl, jq]

## Tagline

Monitor your cron jobs and scheduled tasks — Get alerted when things stop running

## Description

Cron jobs fail silently. Your nightly backup, your SSL renewal, your database cleanup — when they stop working, you don't know until something breaks. By then it's too late.

Healthchecks Manager deploys a self-hosted Healthchecks.io instance that works as a dead man's switch. Your scheduled tasks ping a URL when they complete. If a ping doesn't arrive on time, you get alerted via Telegram, email, Slack, or webhook. No SaaS dependency, no monthly fees — runs entirely on your server.

**What it does:**
- 🚀 One-command Docker deployment of Healthchecks.io
- ⏱️ Monitor unlimited cron jobs and background tasks
- 🔔 Multi-channel alerts: Telegram, email, Slack, webhook, PagerDuty
- 📊 Track job duration and detect slowdowns
- 🔐 Self-hosted — your monitoring data stays on your server
- 🛠️ Full CLI management: create, list, pause, delete checks
- 💾 SQLite backend — zero external database dependency
- 🔄 Auto-restart, easy updates, database backup built in

Perfect for developers, sysadmins, and homelabbers who run cron jobs and need to know when they fail.

## Quick Start Preview

```bash
# Deploy Healthchecks in one command
bash scripts/install.sh

# Create a check for your nightly backup
bash scripts/manage.sh create "Nightly Backup" 86400 3600

# Add to your backup script
curl -fsS "http://localhost:8000/ping/<uuid>" > /dev/null
```

## Core Capabilities

1. Docker deployment — Single-command install with auto-configuration
2. Dead man's switch — Alerts on MISSING pings, not errors
3. Grace periods — Configurable tolerance for timing variance
4. Duration tracking — Detect jobs running slower than expected
5. Telegram integration — Native bot alerts with setup guide
6. API management — Create, list, pause, delete checks via CLI
7. Bulk operations — Manage all checks programmatically
8. Database backup — One-command SQLite backup
9. Ping pruning — Keep storage lean with configurable retention
10. Reverse proxy ready — Nginx config template included
