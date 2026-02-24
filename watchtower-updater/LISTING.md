# Listing Copy: Watchtower Container Updater

## Metadata
- **Type:** Skill
- **Name:** watchtower-updater
- **Display Name:** Watchtower Container Updater
- **Categories:** [automation, dev-tools]
- **Icon:** 🐋
- **Dependencies:** [docker, bash]

## Tagline

Auto-update Docker containers — get notified when images change, schedule maintenance windows

## Description

Running Docker containers in production means constantly checking for image updates, pulling new versions, restarting services, and cleaning up old images. Miss an update and you're running vulnerable software. Do it manually and you waste hours every week.

Watchtower Container Updater sets up [Watchtower](https://containrrr.dev/watchtower/) — the industry-standard tool for automated Docker container updates. It monitors your running containers, detects when new images are available, gracefully stops and restarts containers with the new image, and cleans up old images automatically.

**What it does:**
- 🔄 Auto-update all running Docker containers on a schedule
- ⏰ Configurable update windows (cron-based scheduling)
- 🔔 Notifications via Telegram, Slack, Discord, email, or Gotify
- 🏷️ Include/exclude specific containers with labels
- 🔄 Rolling restarts for zero-downtime updates
- 🧹 Automatic cleanup of old images (saves disk space)
- 🔐 Private registry support (GHCR, ECR, custom registries)
- 🔌 HTTP API for triggering updates from CI/CD pipelines
- ⚡ One-shot mode for manual update runs
- 📊 Status monitoring and log inspection

**Who it's for:** Developers, sysadmins, and homelabbers running Docker who want their containers always up-to-date without manual intervention.

## Quick Start Preview

```bash
# Interactive setup with notifications
bash scripts/setup.sh

# Or one command to start auto-updating
docker run -d --name watchtower --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower --cleanup --schedule "0 0 3 * * *"
```

## Dependencies
- `docker` (required)
- `bash` (for setup/status scripts)

## Installation Time
**5 minutes** — Run setup script, configure notifications, done.
