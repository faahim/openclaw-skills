---
name: mailpit-server
description: >-
  Install and manage Mailpit — a local SMTP email testing server that catches all outgoing emails for inspection.
categories: [dev-tools, communication]
dependencies: [curl, bash]
---

# Mailpit Email Testing Server

## What This Does

Installs and manages [Mailpit](https://github.com/axllent/mailpit) — a lightweight, self-hosted SMTP server that catches ALL outgoing emails. Instead of sending real emails during development, route them to Mailpit and inspect them via its web UI.

**Example:** "Set up local email testing — all emails from my app go to Mailpit instead of real inboxes. View them at http://localhost:8025."

## Quick Start (3 minutes)

### 1. Install Mailpit

```bash
bash scripts/install.sh
```

This downloads the latest Mailpit binary for your platform and installs it to `~/.local/bin/mailpit`.

### 2. Start Mailpit

```bash
bash scripts/run.sh start
```

- **SMTP server:** `localhost:1025` (point your app here)
- **Web UI:** `http://localhost:8025` (view caught emails)

### 3. Test It

```bash
# Send a test email via SMTP
bash scripts/run.sh test

# Or manually:
echo -e "Subject: Test\nFrom: dev@test.com\nTo: user@example.com\n\nHello from Mailpit!" | \
  curl -s smtp://localhost:1025 --mail-from dev@test.com --mail-rcpt user@example.com -T -
```

Then open `http://localhost:8025` to see the caught email.

## Core Workflows

### Workflow 1: Start/Stop Server

```bash
# Start in background
bash scripts/run.sh start

# Check status
bash scripts/run.sh status

# Stop
bash scripts/run.sh stop

# Restart
bash scripts/run.sh restart
```

### Workflow 2: Configure Your App

Point your application's SMTP settings to Mailpit:

```bash
# Environment variables (common pattern)
export SMTP_HOST=localhost
export SMTP_PORT=1025
export SMTP_USER=""     # No auth needed
export SMTP_PASS=""
```

**Node.js (nodemailer):**
```javascript
const transporter = nodemailer.createTransport({
  host: 'localhost',
  port: 1025,
  secure: false
});
```

**Python (smtplib):**
```python
import smtplib
server = smtplib.SMTP('localhost', 1025)
server.sendmail('from@test.com', 'to@test.com', message)
```

**Django:**
```python
EMAIL_HOST = 'localhost'
EMAIL_PORT = 1025
```

**Laravel (.env):**
```
MAIL_MAILER=smtp
MAIL_HOST=localhost
MAIL_PORT=1025
```

**Rails:**
```ruby
config.action_mailer.smtp_settings = { address: 'localhost', port: 1025 }
```

### Workflow 3: Search & Filter Emails

Use Mailpit's API to search caught emails:

```bash
# List all messages
curl -s http://localhost:8025/api/v1/messages | jq '.messages[] | {from: .From.Address, to: .To[0].Address, subject: .Subject}'

# Search by subject
curl -s 'http://localhost:8025/api/v1/search?query=subject:welcome' | jq '.messages[].Subject'

# Delete all messages
curl -s -X DELETE http://localhost:8025/api/v1/messages
```

### Workflow 4: Run as Systemd Service

```bash
# Install as systemd user service (auto-start on login)
bash scripts/run.sh install-service

# Manage via systemctl
systemctl --user status mailpit
systemctl --user stop mailpit
systemctl --user start mailpit
```

### Workflow 5: Custom Port & Settings

```bash
# Custom SMTP and HTTP ports
bash scripts/run.sh start --smtp-port 2525 --http-port 9025

# With max message storage limit
bash scripts/run.sh start --max 500

# With SMTP auth required
bash scripts/run.sh start --smtp-auth-accept-any
```

## Configuration

### Environment Variables

```bash
# Custom ports (defaults shown)
export MAILPIT_SMTP_PORT=1025
export MAILPIT_HTTP_PORT=8025

# Max stored messages (0 = unlimited)
export MAILPIT_MAX_MESSAGES=500

# Database path for persistence (default: in-memory)
export MAILPIT_DB_PATH=~/.local/share/mailpit/mailpit.db
```

### Common Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--smtp` | SMTP bind address | `0.0.0.0:1025` |
| `--listen` | HTTP bind address | `0.0.0.0:8025` |
| `--max` | Max stored messages | `500` |
| `--db-file` | SQLite database path | (in-memory) |
| `--smtp-auth-accept-any` | Accept any SMTP credentials | off |

## Troubleshooting

### Issue: "port already in use"

```bash
# Check what's using the port
lsof -i :1025 2>/dev/null || ss -tlnp | grep 1025

# Use a different port
bash scripts/run.sh start --smtp-port 2525 --http-port 9025
```

### Issue: Mailpit not receiving emails

1. Check Mailpit is running: `bash scripts/run.sh status`
2. Verify your app points to `localhost:1025`
3. Test manually: `bash scripts/run.sh test`
4. Check firewall isn't blocking local ports

### Issue: Can't access web UI

1. Verify Mailpit is running
2. Try `http://127.0.0.1:8025` instead of `localhost`
3. If remote: Mailpit binds to `0.0.0.0` by default, check firewall

## Dependencies

- `bash` (4.0+)
- `curl` (for download and API)
- Internet connection (for initial download only)
