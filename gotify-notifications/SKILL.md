---
name: gotify-notifications
description: >-
  Install, configure, and manage a self-hosted Gotify push notification server for real-time alerts from your agent.
categories: [communication, automation]
dependencies: [bash, curl, jq, docker]
---

# Gotify Push Notification Server

## What This Does

Deploy a self-hosted Gotify server for push notifications — no third-party services, no rate limits, full control. Your OpenClaw agent can send real-time alerts to your phone or desktop for monitoring, cron results, build notifications, or anything else.

**Example:** "Send a push notification to my phone whenever a deploy finishes, a backup fails, or disk usage exceeds 90%."

## Quick Start (5 minutes)

### 1. Install Gotify Server

```bash
# Using Docker (recommended)
bash scripts/install.sh --method docker --port 8080

# Or download binary directly (no Docker needed)
bash scripts/install.sh --method binary --port 8080
```

### 2. Create an Application & Get Token

```bash
# Create your first app (returns app token for sending messages)
bash scripts/manage.sh create-app --name "OpenClaw Agent" --description "Alerts from my agent"

# Output:
# ✅ App created: "OpenClaw Agent"
# 📌 App Token: A1b2C3d4E5f6G7
# Save this token — you'll use it to send messages.
```

### 3. Send Your First Notification

```bash
# Send a test message
bash scripts/send.sh --token "A1b2C3d4E5f6G7" --title "Hello from OpenClaw" --message "Gotify is working! 🎉" --priority 5

# Output:
# ✅ Message sent (id: 42) — priority 5
```

### 4. Install Gotify Client (Phone/Desktop)

- **Android:** [Gotify Android App](https://github.com/gotify/android) (F-Droid / GitHub releases)
- **iOS:** Use any WebSocket client or the web UI at `http://your-server:8080`
- **Desktop:** Web UI works in any browser

## Core Workflows

### Workflow 1: Send Alert from Agent

**Use case:** Trigger push notification from any script or cron job

```bash
# Simple alert
bash scripts/send.sh \
  --token "$GOTIFY_TOKEN" \
  --title "Backup Complete" \
  --message "Daily backup finished. 2.3GB compressed to S3." \
  --priority 5

# High-priority alert (shows as urgent on phone)
bash scripts/send.sh \
  --token "$GOTIFY_TOKEN" \
  --title "🚨 Server Down" \
  --message "api.example.com returned 502 at $(date)" \
  --priority 8
```

### Workflow 2: Manage Applications

**Use case:** Create separate apps for different alert sources

```bash
# List all apps
bash scripts/manage.sh list-apps

# Create app for monitoring
bash scripts/manage.sh create-app --name "Uptime Monitor" --description "Site health alerts"

# Create app for deploys
bash scripts/manage.sh create-app --name "Deploy Bot" --description "CI/CD notifications"

# Delete an app
bash scripts/manage.sh delete-app --id 3
```

### Workflow 3: Manage Clients

**Use case:** Create client tokens for receiving messages

```bash
# List connected clients
bash scripts/manage.sh list-clients

# Create a client
bash scripts/manage.sh create-client --name "Phone"

# Output:
# ✅ Client created: "Phone"
# 📌 Client Token: X9y8Z7w6V5u4
```

### Workflow 4: View Message History

**Use case:** Check recent notifications

```bash
# List recent messages
bash scripts/manage.sh list-messages --limit 20

# List messages for specific app
bash scripts/manage.sh list-messages --app-id 1 --limit 10

# Delete all messages
bash scripts/manage.sh delete-messages
```

### Workflow 5: Health Check

**Use case:** Verify Gotify server is running

```bash
bash scripts/manage.sh health

# Output:
# ✅ Gotify server is healthy
# Version: 2.4.0
# Uptime: 14d 3h 22m
# Apps: 4 | Clients: 2 | Messages: 847
```

## Configuration

### Environment Variables

```bash
# Required
export GOTIFY_URL="http://localhost:8080"    # Your Gotify server URL
export GOTIFY_TOKEN="A1b2C3d4E5f6G7"        # App token for sending
export GOTIFY_ADMIN_USER="admin"              # Admin username
export GOTIFY_ADMIN_PASS="your-secure-password"  # Admin password

# Optional
export GOTIFY_PORT=8080                       # Server port (install only)
export GOTIFY_DATA_DIR="/var/lib/gotify"      # Data directory
```

### Docker Compose (Production)

```yaml
# docker-compose.yml
version: "3"
services:
  gotify:
    image: gotify/server
    ports:
      - "8080:80"
    environment:
      - GOTIFY_DEFAULTUSER_NAME=admin
      - GOTIFY_DEFAULTUSER_PASS=changeme
    volumes:
      - gotify-data:/app/data
    restart: unless-stopped

volumes:
  gotify-data:
```

### Priority Levels

| Priority | Meaning | Android Behavior |
|----------|---------|-----------------|
| 0 | Minimum | No notification |
| 1-3 | Low | Silent notification |
| 4-7 | Normal | Standard notification |
| 8-10 | High | Urgent / alarm |

## Advanced Usage

### Send with Markdown

```bash
bash scripts/send.sh \
  --token "$GOTIFY_TOKEN" \
  --title "Deploy Report" \
  --message "## Build #142\n- ✅ Tests passed\n- ✅ Docker image built\n- 🚀 Deployed to production" \
  --priority 5 \
  --content-type "text/markdown"
```

### Send with Extra Data (for custom clients)

```bash
bash scripts/send.sh \
  --token "$GOTIFY_TOKEN" \
  --title "Disk Alert" \
  --message "Disk usage at 92%" \
  --priority 8 \
  --extras '{"client::notification":{"click":{"url":"https://your-dashboard.com"}}}'
```

### Use as Cron Alert Sink

```bash
# In crontab: pipe any command's output as a notification
0 */6 * * * df -h / | bash /path/to/scripts/send.sh --token "$GOTIFY_TOKEN" --title "Disk Report" --stdin --priority 3
```

### Reverse Proxy with Nginx

```bash
# Auto-configure Nginx reverse proxy with SSL
bash scripts/install.sh --method docker --port 8080 --domain gotify.example.com --nginx
```

## Troubleshooting

### Issue: "connection refused"

**Fix:**
```bash
# Check if Gotify is running
docker ps | grep gotify
# Or for binary install:
systemctl status gotify

# Restart if needed
docker restart gotify
# Or: systemctl restart gotify
```

### Issue: Android app not receiving notifications

**Check:**
1. App token matches: `bash scripts/manage.sh list-apps`
2. Server URL is accessible from phone (not just localhost)
3. Battery optimization is disabled for Gotify app
4. WebSocket connection is active (check app settings)

### Issue: "401 Unauthorized"

**Fix:**
```bash
# Verify your token
curl -s "$GOTIFY_URL/current/user" -H "X-Gotify-Key: $GOTIFY_TOKEN"

# If invalid, create a new app token
bash scripts/manage.sh create-app --name "My App"
```

## Why Use This Instead of Native Tools?

- **Self-hosted** — No Telegram bot API limits, no third-party dependencies
- **WebSocket** — Real-time push, not polling
- **Multi-app** — Separate notification streams per service
- **Priority routing** — Critical alerts cut through Do Not Disturb
- **History** — Full message log, searchable, deletable
- **Android app** — Dedicated client with persistent connection

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests)
- `jq` (JSON parsing)
- `docker` (recommended) OR ability to run binary
- Optional: `nginx` (for reverse proxy)
