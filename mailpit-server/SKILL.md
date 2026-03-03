---
name: mailpit-server
description: >-
  Install and run Mailpit — a local SMTP server that captures all outgoing emails for development and testing.
categories: [dev-tools, communication]
dependencies: [curl, bash]
---

# Mailpit Email Testing Server

## What This Does

Mailpit is a lightweight, self-contained email testing tool for developers. It runs a local SMTP server that captures ALL outgoing emails instead of sending them to real recipients. View captured emails in a clean web UI with HTML rendering, attachments, and spam score checking.

**Example:** "Set up a local mail server on port 1025, view all captured emails at http://localhost:8025, test your app's email flows without sending real emails."

## Quick Start (2 minutes)

### 1. Install Mailpit

```bash
# Auto-detect OS and architecture, install latest release
bash scripts/install.sh
```

### 2. Start Mailpit

```bash
# Start with defaults (SMTP: 1025, Web UI: 8025)
bash scripts/run.sh start

# Open the web UI
echo "📧 Mailpit UI: http://localhost:8025"
```

### 3. Test It

```bash
# Send a test email via the local SMTP server
bash scripts/run.sh test

# Check http://localhost:8025 — your test email should appear!
```

## Core Workflows

### Workflow 1: Development Email Testing

**Use case:** Capture emails from your app during development

Configure your app to use SMTP `localhost:1025`:

```bash
# Environment variables for most frameworks
export SMTP_HOST=localhost
export SMTP_PORT=1025

# Node.js (nodemailer)
# { host: 'localhost', port: 1025, secure: false }

# Python (Django)
# EMAIL_HOST = 'localhost'
# EMAIL_PORT = 1025

# PHP (Laravel)
# MAIL_HOST=localhost
# MAIL_PORT=1025
```

### Workflow 2: Run as Background Service

**Use case:** Keep Mailpit running across terminal sessions

```bash
# Start in background (creates systemd service or nohup)
bash scripts/run.sh daemon

# Check status
bash scripts/run.sh status

# Stop background service
bash scripts/run.sh stop
```

### Workflow 3: Custom Ports

**Use case:** Avoid port conflicts

```bash
# Custom SMTP and web UI ports
bash scripts/run.sh start --smtp 2525 --ui 9025

# Access at http://localhost:9025
```

### Workflow 4: SMTP Relay (Forward Real Emails)

**Use case:** View emails AND forward them to real SMTP server

```bash
# Capture + relay to a real SMTP server
bash scripts/run.sh start \
  --relay-host smtp.gmail.com \
  --relay-port 587 \
  --relay-user your@gmail.com \
  --relay-pass "your-app-password"
```

### Workflow 5: API Access

**Use case:** Programmatically check captured emails in tests

```bash
# List all messages (JSON)
curl -s http://localhost:8025/api/v1/messages | jq '.messages | length'

# Get latest message
curl -s http://localhost:8025/api/v1/messages | jq '.messages[0]'

# Search messages
curl -s 'http://localhost:8025/api/v1/search?query=welcome' | jq '.messages'

# Delete all messages
curl -X DELETE http://localhost:8025/api/v1/messages
```

### Workflow 6: Docker Integration

**Use case:** Add Mailpit to your docker-compose stack

```yaml
# Add to docker-compose.yml
services:
  mailpit:
    image: axllent/mailpit:latest
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
```

## Configuration

### Environment Variables

```bash
# SMTP settings
MP_SMTP_BIND_ADDR=0.0.0.0:1025    # SMTP listen address
MP_UI_BIND_ADDR=0.0.0.0:8025      # Web UI listen address
MP_MAX_MESSAGES=5000                # Max stored messages (0=unlimited)
MP_DATABASE=/tmp/mailpit.db         # SQLite database path

# Authentication (optional)
MP_UI_AUTH_FILE=/path/to/htpasswd   # Protect web UI with basic auth
MP_SMTP_AUTH_ACCEPT_ANY=true        # Accept any SMTP auth credentials

# SMTP relay (optional)
MP_SMTP_RELAY_HOST=smtp.gmail.com
MP_SMTP_RELAY_PORT=587
MP_SMTP_RELAY_USERNAME=user@gmail.com
MP_SMTP_RELAY_PASSWORD=app-password

# TLS (optional)
MP_SMTP_TLS_CERT=/path/to/cert.pem
MP_SMTP_TLS_KEY=/path/to/key.pem
```

## Troubleshooting

### Issue: "Port 1025 already in use"

**Fix:**
```bash
# Find what's using the port
lsof -i :1025
# Kill it or use a different port
bash scripts/run.sh start --smtp 2525
```

### Issue: Emails not appearing in web UI

**Check:**
1. Mailpit is running: `bash scripts/run.sh status`
2. Your app connects to correct port: `telnet localhost 1025`
3. Check Mailpit logs: `bash scripts/run.sh logs`

### Issue: "Permission denied" on install

**Fix:**
```bash
# Install to user directory instead
bash scripts/install.sh --user
```

## Uninstall

```bash
bash scripts/run.sh stop
bash scripts/install.sh --uninstall
```

## Dependencies

- `bash` (4.0+)
- `curl` (for downloading binary + API access)
- No runtime dependencies — Mailpit is a single static binary
