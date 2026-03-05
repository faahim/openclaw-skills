# Listing Copy: Diun Notifier

## Metadata
- **Type:** Skill
- **Name:** diun-notifier
- **Display Name:** Diun — Docker Image Update Notifier
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [docker, curl, jq, bash]

## Tagline

Monitor Docker images for updates — Get notified when new versions are available

## Description

Running outdated container images is a security risk. But manually checking Docker Hub for updates across 10+ containers? Nobody has time for that.

**Diun Notifier** installs and configures Diun (Docker Image Update Notifier) to automatically watch your running containers or a custom image list for new versions. When an update is detected, you get an instant alert via Telegram, Slack, ntfy, email, or webhook.

**What it does:**
- 🐳 Auto-detect and watch all running Docker containers
- 📋 Or watch a custom list of images (no Docker required)
- ⏰ Configurable schedule (every hour, every 6 hours, daily)
- 🔔 Multi-channel alerts: Telegram, Slack, ntfy, email, webhook
- 🔐 Private registry support (GHCR, Quay, ECR, self-hosted)
- 🔍 Digest-based comparison — detects actual changes, not just tag updates
- ⚡ Lightweight Go binary — runs on Raspberry Pi
- 🛡️ Systemd service with security hardening

Perfect for developers and homelabbers running Docker stacks who want to stay on top of image updates without the manual overhead.

## Quick Start Preview

```bash
# Install & configure in one command
bash scripts/setup.sh --provider docker --schedule "0 */6 * * *" --notify telegram

# Test notifications
diun serve --config ~/.config/diun/diun.yml --test-notif
```

## Core Capabilities

1. Docker provider — Auto-watch all running containers
2. File provider — Watch specific images without Docker
3. Digest comparison — Detect real changes, not just tag pushes
4. Telegram alerts — Rich formatted update notifications
5. Slack/webhook alerts — POST to any endpoint on updates
6. Ntfy alerts — Push notifications to your phone
7. Email alerts — SMTP-based notifications
8. Private registries — Auth for GHCR, Quay, ECR, self-hosted
9. Tag filtering — Include/exclude patterns (semver, RC, alpha)
10. Systemd service — Runs as a daemon with auto-restart
11. Cron scheduling — Standard cron syntax for check intervals
12. Low resource — ~10MB binary, minimal CPU/RAM usage
