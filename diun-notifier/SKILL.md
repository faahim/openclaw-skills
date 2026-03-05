---
name: diun-notifier
description: >-
  Monitor Docker images for new versions and get notified when updates are available.
categories: [automation, dev-tools]
dependencies: [docker, curl, jq, bash]
---

# Diun — Docker Image Update Notifier

## What This Does

Monitors your running Docker containers and watched images for new versions on registries (Docker Hub, GHCR, etc.). When a newer tag or digest is found, it sends alerts via Telegram, Slack webhook, email, or ntfy. Never miss a critical security update again.

**Example:** "Watch 15 container images, get a Telegram alert when nginx, postgres, or redis publish new versions."

## Quick Start (5 minutes)

### 1. Install Diun

```bash
# Download latest Diun binary
DIUN_VERSION=$(curl -s https://api.github.com/repos/crazy-max/diun/releases/latest | jq -r .tag_name)
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -sSL "https://github.com/crazy-max/diun/releases/download/${DIUN_VERSION}/diun_${DIUN_VERSION#v}_linux_${ARCH}.tar.gz" | tar xz -C /usr/local/bin diun
chmod +x /usr/local/bin diun

# Verify
diun --version
```

### 2. Create Config

```bash
mkdir -p ~/.config/diun

cat > ~/.config/diun/diun.yml << 'EOF'
watch:
  schedule: "0 */6 * * *"  # Check every 6 hours
  firstCheckNotif: false

providers:
  docker:
    watchByDefault: true    # Watch all running containers
    watchStopped: false

notif:
  telegram:
    token: "${TELEGRAM_BOT_TOKEN}"
    chatIDs:
      - ${TELEGRAM_CHAT_ID}
    templateBody: |
      🐳 Docker Image Update
      Image: {{ .Entry.Image }}
      Current: {{ .Entry.Manifest.Digest | substr 0 12 }}
      {{ if .Entry.Manifest.Platform }}Platform: {{ .Entry.Manifest.Platform }}{{ end }}
      Status: {{ .Entry.Status }}
EOF
```

### 3. Run First Check

```bash
# Set credentials
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Run once (test)
diun serve --config ~/.config/diun/diun.yml --test-notif

# Run check now
diun serve --config ~/.config/diun/diun.yml
```

## Core Workflows

### Workflow 1: Watch All Running Docker Containers

**Use case:** Auto-detect all running containers, check for updates every 6 hours.

```bash
bash scripts/setup.sh --provider docker --schedule "0 */6 * * *" --notify telegram
```

Config generated at `~/.config/diun/diun.yml`:
```yaml
watch:
  schedule: "0 */6 * * *"

providers:
  docker:
    watchByDefault: true

notif:
  telegram:
    token: "${TELEGRAM_BOT_TOKEN}"
    chatIDs:
      - ${TELEGRAM_CHAT_ID}
```

### Workflow 2: Watch Specific Images (No Docker Required)

**Use case:** Monitor specific images even without running containers.

```bash
bash scripts/setup.sh --provider file --images "nginx:latest,postgres:16,redis:7-alpine" --notify telegram
```

Config:
```yaml
providers:
  file:
    filename: ~/.config/diun/images.yml

# images.yml:
# - name: docker.io/library/nginx:latest
# - name: docker.io/library/postgres:16
# - name: docker.io/library/redis:7-alpine
```

### Workflow 3: Watch Docker Compose Stack

**Use case:** Monitor images from a docker-compose.yml.

```bash
bash scripts/setup.sh --provider docker --labels --schedule "0 8 * * *"
```

Then add labels to your docker-compose services:
```yaml
services:
  web:
    image: nginx:latest
    labels:
      - "diun.enable=true"
      - "diun.watch_repo=true"
      - "diun.max_tags=5"
```

### Workflow 4: Slack/Webhook Notifications

```bash
bash scripts/setup.sh --provider docker --notify webhook --webhook-url "https://hooks.slack.com/services/xxx"
```

### Workflow 5: Ntfy Notifications

```bash
bash scripts/setup.sh --provider docker --notify ntfy --ntfy-topic "docker-updates"
```

## Configuration

### Full Config Reference

```yaml
# ~/.config/diun/diun.yml
watch:
  schedule: "0 */6 * * *"    # Cron schedule
  firstCheckNotif: false       # Don't alert on first scan
  compareDigest: true          # Compare by digest (not just tag)

defaults:
  watchRepo: false
  maxTags: 10
  includeTags:
    - "latest"
    - "^\\d+\\.\\d+$"         # Semver major.minor
  excludeTags:
    - "^sha-"
    - ".*-rc.*"

providers:
  docker:
    watchByDefault: true
    watchStopped: false
    # tlsVerify: true

  # OR: file-based provider (no Docker needed)
  # file:
  #   filename: ~/.config/diun/images.yml

regopts:
  # Private registry auth
  - name: "myregistry"
    selector: "registry.example.com"
    username: "${REGISTRY_USER}"
    password: "${REGISTRY_PASS}"

notif:
  telegram:
    token: "${TELEGRAM_BOT_TOKEN}"
    chatIDs:
      - ${TELEGRAM_CHAT_ID}

  # webhook:
  #   endpoint: "https://hooks.slack.com/services/xxx"
  #   method: POST
  #   headers:
  #     Content-Type: application/json

  # ntfy:
  #   endpoint: "https://ntfy.sh"
  #   topic: "docker-updates"
  #   priority: 3
  #   timeout: 10s

  # mail:
  #   host: "smtp.gmail.com"
  #   port: 587
  #   ssl: false
  #   startTLS: true
  #   username: "${SMTP_USER}"
  #   password: "${SMTP_PASS}"
  #   from: "diun@example.com"
  #   to: "admin@example.com"
```

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Private registry (optional)
export REGISTRY_USER="<username>"
export REGISTRY_PASS="<password>"

# SMTP (optional)
export SMTP_USER="<email>"
export SMTP_PASS="<password>"
```

## Run as a Service

### Systemd Service

```bash
bash scripts/install-service.sh
```

Creates `/etc/systemd/system/diun.service`:
```ini
[Unit]
Description=Diun - Docker Image Update Notifier
After=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/diun serve --config /etc/diun/diun.yml
Restart=on-failure
RestartSec=30
EnvironmentFile=-/etc/diun/env

[Install]
WantedBy=multi-user.target
```

### Docker (Run Diun in Docker)

```bash
docker run -d \
  --name diun \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v diun-data:/data \
  -v ~/.config/diun/diun.yml:/diun.yml:ro \
  -e TZ=UTC \
  -e TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}" \
  -e TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}" \
  crazymax/diun:latest
```

### OpenClaw Cron (Agent-Native)

```bash
# Run check every 6 hours via OpenClaw cron
# Agent reads this SKILL.md and runs: diun serve --config ~/.config/diun/diun.yml
```

## Checking Current Status

```bash
# List watched images
diun image list --config ~/.config/diun/diun.yml

# Inspect a specific image
diun image inspect --config ~/.config/diun/diun.yml "docker.io/library/nginx:latest"

# Check Diun database
ls -la ~/.local/share/diun/diun.db
```

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Fix:**
```bash
# Add current user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo
sudo diun serve --config ~/.config/diun/diun.yml
```

### Issue: "Rate limit exceeded" on Docker Hub

**Fix:** Add Docker Hub credentials:
```yaml
regopts:
  - name: "dockerhub"
    selector: "docker.io"
    username: "${DOCKERHUB_USER}"
    password: "${DOCKERHUB_TOKEN}"
```

### Issue: No notifications received

**Check:**
1. Test notifications: `diun serve --config ~/.config/diun/diun.yml --test-notif`
2. Verify env vars: `echo $TELEGRAM_BOT_TOKEN`
3. Check logs: `journalctl -u diun -f`

### Issue: "unknown image" for private registry

**Fix:** Add registry auth in `regopts` section of config.

## Uninstall

```bash
# Stop and remove service
sudo systemctl stop diun
sudo systemctl disable diun
sudo rm /etc/systemd/system/diun.service

# Remove binary
sudo rm /usr/local/bin/diun

# Remove data
rm -rf ~/.config/diun ~/.local/share/diun
```

## Key Principles

1. **Digest-based comparison** — Detects actual image changes, not just tag updates
2. **Registry-agnostic** — Docker Hub, GHCR, Quay, private registries
3. **Multi-notification** — Telegram, Slack, email, ntfy, webhook, Gotify, and more
4. **Low resource** — Lightweight Go binary, runs on Raspberry Pi
5. **Schedule-based** — Cron syntax, checks only when you want

## Dependencies

- `bash` (4.0+)
- `curl` (for downloading Diun)
- `jq` (for parsing GitHub API)
- `docker` (optional — only for Docker provider)
- `systemd` (optional — for service install)
