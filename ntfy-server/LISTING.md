# Listing Copy: Ntfy Push Notification Server

## Metadata
- **Type:** Skill
- **Name:** ntfy-server
- **Display Name:** Ntfy Push Notification Server
- **Categories:** [communication, automation]
- **Icon:** 🔔
- **Dependencies:** [bash, curl, systemctl]

## Tagline

"Self-hosted push notifications — alert your phone from any script, cron job, or service."

## Description

Manually checking if your backups ran, your deploys succeeded, or your servers are up is a waste of time. You need instant push notifications — but most services charge monthly fees and require complex integrations.

Ntfy Push Notification Server lets your OpenClaw agent install and manage a self-hosted ntfy instance. Send real-time alerts from shell scripts, cron jobs, monitoring tools, or any HTTP client to your phone, desktop, or browser. One `curl` command = instant notification. No API keys required for the public server, or self-host for full control.

**What it does:**
- 🔔 Install & configure self-hosted ntfy server (Debian, Ubuntu, RHEL, Arch, macOS)
- 📱 Send push notifications with one `curl` command
- ⏰ Wrap any cron job with success/failure alerts
- 🔍 Built-in uptime monitor with ntfy alerts
- 🔒 Authentication & access control for private servers
- 🌐 Nginx reverse proxy setup with SSL
- 🔗 UnifiedPush support for Matrix, Mastodon, etc.
- 📎 File attachments, action buttons, scheduled delivery

**Who it's for:** Developers, sysadmins, and homelabbers who want instant alerts without vendor lock-in.

## Core Capabilities

1. Server installation — Auto-detect OS, install ntfy binary or package
2. Service management — Start, stop, enable via systemd
3. Authentication setup — Users, tokens, topic-level access control
4. Cron wrapper — Notify on success/failure of any command
5. Uptime monitoring — Ping URLs, alert on downtime via ntfy
6. Nginx reverse proxy — Generate config with SSL/WebSocket support
7. Rich notifications — Titles, priorities, tags, attachments, action buttons
8. Scheduled messages — "At: tomorrow 9am" delivery
9. Multi-platform — Phone (iOS/Android), desktop, browser, CLI
10. UnifiedPush — Use as push provider for compatible apps
