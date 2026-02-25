# Listing Copy: Gotify Push Notifications

## Metadata
- **Type:** Skill
- **Name:** gotify-notifications
- **Display Name:** Gotify Push Notification Server
- **Categories:** [communication, automation]
- **Icon:** 🔔
- **Dependencies:** [bash, curl, jq, docker]

## Tagline

"Self-hosted push notifications — real-time alerts to your phone with zero third-party limits"

## Description

Sending alerts from your agent shouldn't depend on Telegram rate limits or third-party API quotas. Gotify is a self-hosted push notification server — you own it, you control it, no limits.

This skill installs and configures a Gotify server (via Docker or binary), creates notification channels, and gives your agent a dead-simple way to push messages to your phone or desktop in real-time via WebSocket. No polling, no delays.

**What it does:**
- 🔔 Install Gotify server in one command (Docker or binary)
- 📱 Push real-time alerts to Android app or web UI
- 🏷️ Separate apps per service (monitoring, deploys, backups, etc.)
- ⚡ Priority routing — critical alerts bypass Do Not Disturb
- 📜 Full message history with search and bulk delete
- 🔒 Self-hosted — your data stays on your server
- 🔧 Nginx reverse proxy + SSL setup included
- 📊 Health checks and server management built-in

## Who It's For

Developers, sysadmins, and self-hosters who want reliable push notifications without depending on external services. Perfect for pairing with monitoring, backup, and CI/CD skills.

## Quick Start Preview

```bash
# Install server
bash scripts/install.sh --method docker --port 8080

# Create app & get token
bash scripts/manage.sh create-app --name "My Agent"

# Send alert
bash scripts/send.sh --token "YOUR_TOKEN" --title "🚀 Deploy Done" --message "v2.1.0 shipped to prod" --priority 5
```

## Core Capabilities

1. One-command server install — Docker or native binary
2. App management — Create, list, delete notification channels
3. Priority routing — 0 (silent) to 10 (alarm) priority levels
4. Markdown support — Rich notification formatting
5. WebSocket push — Real-time delivery, not polling
6. Stdin piping — Pipe any command output as a notification
7. Nginx integration — Reverse proxy with SSL-ready config
8. Systemd service — Auto-start on boot (binary install)
9. Client management — Multiple devices per user
10. Message history — View, filter, bulk delete

## Dependencies
- `bash` (4.0+), `curl`, `jq`
- `docker` (recommended) or direct binary
- Optional: `nginx`, `certbot`

## Installation Time
**5 minutes** — One script, choose Docker or binary
