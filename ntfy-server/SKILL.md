---
name: ntfy-server
description: >-
  Install and manage a self-hosted ntfy push notification server for real-time alerts from scripts, cron jobs, and monitoring tools.
categories: [communication, automation]
dependencies: [bash, curl, systemctl]
---

# Ntfy Push Notification Server

## What This Does

Self-host your own push notification server using [ntfy](https://ntfy.sh). Send real-time alerts from shell scripts, cron jobs, monitoring tools, or any HTTP client to your phone, desktop, or browser — no third-party services, no API keys, no monthly fees.

**Example:** `curl -d "Backup complete ✅" ntfy.sh/your-topic` → instant notification on your phone.

## Quick Start (5 minutes)

### Option A: Use ntfy.sh Public Server (No Install)

```bash
# Send a notification right now (no setup needed)
curl -d "Hello from OpenClaw! 🤖" ntfy.sh/my-openclaw-alerts

# Subscribe on your phone: Install ntfy app → subscribe to "my-openclaw-alerts"
# Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy
# iOS: https://apps.apple.com/app/ntfy/id1625396347
```

### Option B: Self-Hosted Server

```bash
# Install ntfy server
bash scripts/install.sh

# Start the server
sudo systemctl start ntfy
sudo systemctl enable ntfy

# Send a test notification
curl -d "Self-hosted ntfy is running! 🎉" localhost:8080/test-topic
```

### 1. Install Dependencies

```bash
# Check if ntfy is installed
which ntfy && ntfy --version || bash scripts/install.sh
```

### 2. Configure Server

```bash
# Copy and edit config
sudo cp scripts/server.yml /etc/ntfy/server.yml

# Key settings to customize:
# - base-url: your domain (e.g., https://ntfy.yourdomain.com)
# - listen-http: port (default :8080)
# - behind-proxy: true if using nginx/caddy
# - auth-default-access: deny-all for private server
```

### 3. Set Up Authentication (Optional)

```bash
# Add a user
sudo ntfy user add --role=admin youradmin

# Create access tokens
sudo ntfy token add youradmin

# Restrict topic access
sudo ntfy access youradmin "alerts/*" rw
sudo ntfy access '*' "public-*" ro
```

## Core Workflows

### Workflow 1: Send Notifications from Scripts

**Use case:** Alert when a backup finishes, deployment completes, or error occurs.

```bash
# Simple message
curl -d "Deploy to production complete ✅" https://ntfy.yourdomain.com/deploys

# With title, priority, and tags
curl \
  -H "Title: Disk Space Warning" \
  -H "Priority: high" \
  -H "Tags: warning,computer" \
  -d "Server disk usage at 90% — /dev/sda1" \
  https://ntfy.yourdomain.com/server-alerts

# With click action (opens URL when tapped)
curl \
  -H "Title: New PR Ready" \
  -H "Click: https://github.com/you/repo/pull/42" \
  -H "Tags: git" \
  -d "PR #42: Fix auth bug — ready for review" \
  https://ntfy.yourdomain.com/github

# With file attachment
curl \
  -H "Filename: report.csv" \
  -T /tmp/daily-report.csv \
  https://ntfy.yourdomain.com/reports

# Delayed/scheduled notification
curl \
  -H "At: tomorrow, 9am" \
  -d "Stand-up meeting in 15 minutes" \
  https://ntfy.yourdomain.com/reminders
```

### Workflow 2: Integrate with Cron Jobs

**Use case:** Get notified when cron jobs succeed or fail.

```bash
# Add to any cron job — notify on success or failure
# In crontab:
0 2 * * * /usr/local/bin/backup.sh && curl -d "Backup OK ✅" ntfy.sh/my-cron || curl -H "Priority: urgent" -H "Tags: rotating_light" -d "Backup FAILED ❌" ntfy.sh/my-cron

# Or use the helper script:
bash scripts/notify.sh --topic my-alerts --title "Backup" --on-success "Backup complete" --on-fail "Backup failed" -- /usr/local/bin/backup.sh
```

### Workflow 3: Monitor Services

**Use case:** Ping ntfy when services go down.

```bash
# Simple uptime check + ntfy alert
bash scripts/monitor.sh --url https://yoursite.com --topic server-alerts --interval 300

# Output on failure:
# 🚨 Sent alert: "https://yoursite.com is DOWN (HTTP 503)"
```

### Workflow 4: Self-Hosted with Nginx Reverse Proxy

**Use case:** Run ntfy behind nginx with SSL.

```bash
# Generate nginx config
bash scripts/setup-nginx.sh --domain ntfy.yourdomain.com

# Output: /etc/nginx/sites-available/ntfy.conf
# Then:
sudo ln -s /etc/nginx/sites-available/ntfy.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Workflow 5: Send from Python/Node/Any Language

```python
# Python
import requests
requests.post("https://ntfy.yourdomain.com/alerts",
    data="Server restarted",
    headers={"Title": "Server Alert", "Priority": "high", "Tags": "server"})
```

```javascript
// Node.js
fetch("https://ntfy.yourdomain.com/alerts", {
    method: "POST",
    body: "Build #142 passed ✅",
    headers: { "Title": "CI/CD", "Tags": "white_check_mark" }
});
```

```bash
# Any language — it's just HTTP POST
wget --post-data="Message here" https://ntfy.yourdomain.com/topic
```

## Configuration

### Server Config (/etc/ntfy/server.yml)

```yaml
# Base URL (required for self-hosted)
base-url: "https://ntfy.yourdomain.com"

# Listen address
listen-http: ":8080"

# Behind reverse proxy (nginx/caddy)
behind-proxy: true

# Authentication
auth-file: "/var/lib/ntfy/user.db"
auth-default-access: "deny-all"

# Rate limiting
visitor-request-limit-burst: 60
visitor-request-limit-replenish: "5s"

# Message cache (SQLite)
cache-file: "/var/cache/ntfy/cache.db"
cache-duration: "24h"

# Attachment storage
attachment-cache-dir: "/var/cache/ntfy/attachments"
attachment-total-size-limit: "1G"
attachment-file-size-limit: "15M"

# Web UI
enable-web: true

# Upstream server (relay to ntfy.sh for UnifiedPush)
upstream-base-url: "https://ntfy.sh"
```

### Environment Variables

```bash
# For scripts using the public server
export NTFY_SERVER="https://ntfy.sh"        # or your self-hosted URL
export NTFY_TOPIC="my-alerts"               # default topic
export NTFY_TOKEN="tk_abc123"               # access token (if auth enabled)

# Priority levels: min, low, default, high, urgent
export NTFY_PRIORITY="default"
```

## Advanced Usage

### UnifiedPush Support

ntfy supports UnifiedPush — use it as a push provider for any UnifiedPush-compatible app (Matrix, Mastodon, etc.):

```bash
# Enable upstream relay in server.yml
upstream-base-url: "https://ntfy.sh"

# Apps auto-discover your ntfy instance as a push provider
```

### Webhooks from GitHub/Grafana/etc.

```bash
# GitHub webhook → ntfy (use scripts/webhook-relay.sh)
bash scripts/webhook-relay.sh --listen 9090 --topic github-events --secret YOUR_WEBHOOK_SECRET
```

### iOS/Android Rich Notifications

```bash
# With image
curl \
  -H "Title: Security Camera" \
  -H "Attach: https://cam.home/snapshot.jpg" \
  -d "Motion detected at front door" \
  https://ntfy.yourdomain.com/home-security

# With action buttons
curl \
  -H "Actions: view, Open Dashboard, https://grafana.local; http, Restart Service, https://api.local/restart, method=POST" \
  -d "Service health check failed" \
  https://ntfy.yourdomain.com/ops
```

## Troubleshooting

### Issue: "connection refused" on self-hosted

**Fix:**
```bash
# Check if ntfy is running
sudo systemctl status ntfy

# Check port
sudo ss -tlnp | grep 8080

# Check logs
sudo journalctl -u ntfy -f
```

### Issue: Notifications not arriving on phone

**Check:**
1. Topic name matches exactly (case-sensitive)
2. Phone app is subscribed to correct server URL
3. If self-hosted with auth: token is valid
4. Battery optimization not killing ntfy app (Android)

### Issue: Rate limited

**Fix:** Adjust in server.yml:
```yaml
visitor-request-limit-burst: 120
visitor-request-limit-replenish: "2s"
```

## Dependencies

- `bash` (4.0+)
- `curl` (sending notifications)
- `systemctl` (service management, Linux only)
- `ntfy` binary (auto-installed by install script)
- Optional: `nginx` or `caddy` (reverse proxy)
- Optional: `certbot` (SSL certificates)
