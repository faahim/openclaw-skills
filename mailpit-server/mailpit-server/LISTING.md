# Listing Copy: Mailpit Email Testing Server

## Metadata
- **Type:** Skill
- **Name:** mailpit-server
- **Display Name:** Mailpit Email Testing Server
- **Categories:** [dev-tools, communication]
- **Price:** $8
- **Dependencies:** [curl, bash]
- **Icon:** 📧

## Tagline

Catch all outgoing emails locally — test email flows without hitting real inboxes

## Description

Tired of accidentally sending test emails to real users? Or setting up complex email mocking? Mailpit is a lightweight local SMTP server that catches every email your app sends, letting you inspect them in a clean web UI.

This skill installs and manages Mailpit with one command. Point your app's SMTP settings to `localhost:1025`, and every email lands in the Mailpit web UI at `http://localhost:8025` — HTML rendering, attachments, headers, everything visible instantly.

**What it does:**
- 📥 Catches ALL outgoing SMTP emails from any app/framework
- 🌐 Clean web UI to inspect HTML emails, attachments, and headers
- 🔍 Search and filter caught emails via web UI or REST API
- 🗑️ One-command cleanup of all test messages
- 🔧 Works with any language: Node.js, Python, PHP, Ruby, Go, Java
- ⚡ Auto-installs the correct binary for your platform (Linux/macOS, x64/ARM)
- 🔄 Run as systemd service for auto-start on boot
- 📊 REST API for programmatic email inspection in CI/CD

Perfect for developers building apps that send emails — signup flows, password resets, notifications, newsletters. Test everything locally, send nothing to the real world.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Start server
bash scripts/run.sh start
# SMTP: localhost:1025 | Web: http://localhost:8025

# Send test email
bash scripts/run.sh test
# ✅ Check http://localhost:8025 to see it
```

## Core Capabilities

1. One-command install — auto-detects OS and architecture
2. Background server management — start/stop/restart/status
3. Test email sender — verify setup instantly
4. Web UI for email inspection — HTML rendering, source view, attachments
5. REST API access — search, list, delete messages programmatically
6. Systemd service — auto-start on boot, managed via systemctl
7. Configurable ports — avoid conflicts with existing services
8. Message limits — control storage with max message cap
9. Multi-framework support — config examples for Node, Python, Django, Laravel, Rails
10. Zero auth required — just point SMTP and go

## Installation Time
**3 minutes** — download binary, start server, send test email
