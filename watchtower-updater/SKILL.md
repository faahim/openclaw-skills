---
name: watchtower-updater
description: >-
  Automatically update running Docker containers when new images are available.
  Monitor, schedule, and get notified about container updates.
categories: [automation, dev-tools]
dependencies: [docker, bash, curl]
---

# Watchtower Container Updater

## What This Does

Automatically monitors your running Docker containers and updates them when new images are published. Uses [Watchtower](https://containrrr.dev/watchtower/) — the standard tool for automated Docker container updates. Get Telegram/Slack/email notifications when containers are updated, schedule update windows, and exclude specific containers.

**Example:** "Auto-update all my containers nightly at 3am, notify me on Telegram when anything changes."

## Quick Start (5 minutes)

### 1. Prerequisites

```bash
# Docker must be installed and running
docker --version || echo "Install Docker first: https://docs.docker.com/get-docker/"
```

### 2. Run Watchtower (One Command)

```bash
# Update all running containers, check every 24 hours
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  --schedule "0 0 3 * * *"
```

That's it. Watchtower will check for updates every day at 3am and auto-update containers.

### 3. Setup Script (Recommended)

```bash
# Use our setup script for full configuration
bash scripts/setup.sh
```

The script walks you through:
- Update schedule (cron expression)
- Notification setup (Telegram, Slack, email, Gotify)
- Container include/exclude lists
- Rolling restart options

## Core Workflows

### Workflow 1: Update All Containers on Schedule

```bash
# Every day at 3am UTC
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  --schedule "0 0 3 * * *"
```

### Workflow 2: Update Specific Containers Only

```bash
# Only update nginx and postgres
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  nginx postgres
```

### Workflow 3: Exclude Containers from Updates

```bash
# Label containers you DON'T want updated
docker label add com.centurylinklabs.watchtower.enable=false my-production-db

# Watchtower respects labels automatically
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_LABEL_ENABLE=true \
  containrrr/watchtower \
  --cleanup
```

### Workflow 4: One-Shot Update (Run Once)

```bash
# Check and update everything right now, then exit
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once \
  --cleanup
```

### Workflow 5: With Telegram Notifications

```bash
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_NOTIFICATIONS=shoutrrr \
  -e WATCHTOWER_NOTIFICATION_URL="telegram://${TELEGRAM_BOT_TOKEN}@telegram?channels=${TELEGRAM_CHAT_ID}" \
  containrrr/watchtower \
  --cleanup \
  --schedule "0 0 3 * * *"
```

### Workflow 6: With Slack Notifications

```bash
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_NOTIFICATIONS=shoutrrr \
  -e WATCHTOWER_NOTIFICATION_URL="slack://hook:${SLACK_TOKEN}@${SLACK_CHANNEL}" \
  containrrr/watchtower \
  --cleanup \
  --schedule "0 0 3 * * *"
```

### Workflow 7: Monitor Update Status

```bash
# Check Watchtower logs
docker logs watchtower --tail 50

# Check when containers were last updated
bash scripts/status.sh
```

### Workflow 8: Rolling Restarts (Zero Downtime)

```bash
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_ROLLING_RESTART=true \
  containrrr/watchtower \
  --cleanup \
  --schedule "0 0 3 * * *"
```

## Configuration

### Environment Variables

```bash
# Schedule (6-field cron: sec min hour day month weekday)
WATCHTOWER_SCHEDULE="0 0 3 * * *"        # 3am daily
WATCHTOWER_POLL_INTERVAL=86400            # Alternative: seconds between checks

# Notifications (via Shoutrrr)
WATCHTOWER_NOTIFICATIONS=shoutrrr
WATCHTOWER_NOTIFICATION_URL="telegram://TOKEN@telegram?channels=CHAT_ID"

# Behavior
WATCHTOWER_CLEANUP=true                   # Remove old images after update
WATCHTOWER_INCLUDE_STOPPED=false          # Don't update stopped containers
WATCHTOWER_INCLUDE_RESTARTING=false       # Don't update restarting containers
WATCHTOWER_ROLLING_RESTART=false          # Rolling restarts for zero downtime
WATCHTOWER_NO_PULL=false                  # Set true to only restart, not pull
WATCHTOWER_LABEL_ENABLE=false             # Only update labeled containers
WATCHTOWER_REVIVE_STOPPED=false           # Don't start stopped containers
WATCHTOWER_TIMEOUT=30                     # Timeout for stopping containers (sec)
WATCHTOWER_LIFECYCLE_HOOKS=true           # Run pre/post-update scripts

# Private registries
WATCHTOWER_HTTP_API_TOKEN="mytoken"       # API token for HTTP mode
REPO_USER="username"                      # Registry username
REPO_PASS="password"                      # Registry password
```

### Docker Compose

```yaml
# docker-compose.yml
version: "3"
services:
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
      - WATCHTOWER_NOTIFICATIONS=shoutrrr
      - WATCHTOWER_NOTIFICATION_URL=telegram://TOKEN@telegram?channels=CHATID
    # Optional: only update specific containers
    # command: nginx postgres redis
```

### Container Labels

```bash
# Enable/disable per container
docker run -d --label com.centurylinklabs.watchtower.enable=true myapp
docker run -d --label com.centurylinklabs.watchtower.enable=false my-db

# Pre/post update hooks
docker run -d \
  --label com.centurylinklabs.watchtower.lifecycle.pre-update="/backup.sh" \
  --label com.centurylinklabs.watchtower.lifecycle.post-update="/migrate.sh" \
  myapp
```

## Advanced Usage

### Private Registry Authentication

```bash
# Create config.json for private registries
mkdir -p ~/.docker
cat > ~/.docker/config.json << 'EOF'
{
  "auths": {
    "ghcr.io": { "auth": "BASE64_ENCODED_USER:TOKEN" },
    "registry.example.com": { "auth": "BASE64_ENCODED_USER:TOKEN" }
  }
}
EOF

# Mount it into Watchtower
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.docker/config.json:/config.json \
  containrrr/watchtower \
  --cleanup
```

### HTTP API Mode (Trigger Updates Externally)

```bash
# Run Watchtower with HTTP API
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_HTTP_API_UPDATE=true \
  -e WATCHTOWER_HTTP_API_TOKEN="mytoken" \
  -p 8080:8080 \
  containrrr/watchtower

# Trigger update from CI/CD or webhook
curl -H "Authorization: Bearer mytoken" http://localhost:8080/v1/update
```

### Multiple Watchtower Instances

```bash
# Instance 1: Critical apps (check every hour)
docker run -d --name watchtower-critical \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_LABEL_ENABLE=true \
  containrrr/watchtower --schedule "0 0 * * * *" --cleanup

# Instance 2: Non-critical (check daily at 3am)
docker run -d --name watchtower-daily \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower --schedule "0 0 3 * * *" --cleanup

# Label critical containers
docker run -d --label com.centurylinklabs.watchtower.enable=true my-critical-app
```

## Troubleshooting

### Issue: Watchtower not updating containers

**Check:**
```bash
# 1. Is Watchtower running?
docker ps | grep watchtower

# 2. Check logs for errors
docker logs watchtower --tail 100

# 3. Is Docker socket mounted?
docker inspect watchtower | grep -A5 Mounts
```

### Issue: Private registry auth failing

**Fix:**
```bash
# Regenerate auth token
echo -n "username:password" | base64
# Put in ~/.docker/config.json, remount
docker restart watchtower
```

### Issue: Container keeps restarting after update

**Fix:**
```bash
# Exclude the problematic container
docker label add com.centurylinklabs.watchtower.enable=false problem-container

# Or pin to specific image tag (Watchtower only updates :latest by default)
docker run -d --name myapp myimage:1.2.3  # Won't be updated
```

### Issue: Notifications not sending

**Check:**
```bash
# Test notification URL directly
docker run --rm containrrr/shoutrrr send \
  --url "telegram://TOKEN@telegram?channels=CHATID" \
  --message "Test notification"
```

### Issue: Too many old images consuming disk

**Fix:** Watchtower's `--cleanup` flag removes old images. If already accumulated:
```bash
docker image prune -a --filter "until=168h"  # Remove images older than 7 days
```

## Dependencies

- `docker` (required — Watchtower runs as a container)
- `bash` (for setup/status scripts)
- `curl` (optional — for HTTP API trigger)

## Key Principles

1. **Safe defaults** — Only updates running containers, cleans up old images
2. **Opt-out model** — Updates everything unless you label containers to exclude
3. **Notification-first** — Always know what changed and when
4. **Non-destructive** — Watchtower pulls new image, stops container, starts with same config
5. **Schedule-aware** — Update during maintenance windows, not during peak traffic
