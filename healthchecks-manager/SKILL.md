---
name: healthchecks-manager
description: >-
  Install and manage a self-hosted Healthchecks.io instance for monitoring cron jobs, 
  scheduled tasks, and background services. Get alerts when things stop running.
categories: [automation, dev-tools]
dependencies: [docker, docker-compose, curl, jq]
---

# Healthchecks Manager

## What This Does

Deploys and manages a self-hosted [Healthchecks.io](https://healthchecks.io) instance — a dead man's switch / cron job monitor. Your scheduled tasks ping a URL when they run successfully. If a ping doesn't arrive on time, you get alerted via email, Telegram, Slack, or webhook.

**Why an agent needs this:** Requires Docker installation, persistent service configuration, container lifecycle management, and API integration — none of which an agent can do with just text generation.

## Quick Start (10 minutes)

### 1. Install Dependencies

```bash
# Check Docker is installed
which docker docker-compose || {
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  echo "Log out and back in, then re-run."
  exit 1
}
```

### 2. Deploy Healthchecks

```bash
# Create project directory
mkdir -p ~/healthchecks && cd ~/healthchecks

# Generate secrets
HC_SECRET=$(openssl rand -hex 32)
HC_SUPERUSER_EMAIL="${HC_EMAIL:-admin@localhost}"
HC_SUPERUSER_PASSWORD="${HC_PASSWORD:-$(openssl rand -base64 16)}"

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSE'
version: "3"
services:
  healthchecks:
    image: healthchecks/healthchecks:latest
    restart: unless-stopped
    ports:
      - "${HC_PORT:-8000}:8000"
    environment:
      - DB=sqlite
      - DB_NAME=/data/hc.sqlite
      - SECRET_KEY=${HC_SECRET}
      - ALLOWED_HOSTS=*
      - SITE_ROOT=${HC_SITE_ROOT:-http://localhost:8000}
      - SITE_NAME=${HC_SITE_NAME:-Healthchecks}
      - DEFAULT_FROM_EMAIL=${HC_FROM_EMAIL:-healthchecks@localhost}
      - SUPERUSER_EMAIL=${HC_SUPERUSER_EMAIL}
      - SUPERUSER_PASSWORD=${HC_SUPERUSER_PASSWORD}
      - TELEGRAM_BOT_NAME=${HC_TELEGRAM_BOT:-}
      - TELEGRAM_TOKEN=${HC_TELEGRAM_TOKEN:-}
      - APPRISE_ENABLED=True
    volumes:
      - ./data:/data
COMPOSE

# Create .env file
cat > .env << EOF
HC_SECRET=${HC_SECRET}
HC_PORT=8000
HC_SITE_ROOT=http://$(hostname -I | awk '{print $1}'):8000
HC_SITE_NAME=Healthchecks
HC_SUPERUSER_EMAIL=${HC_SUPERUSER_EMAIL}
HC_SUPERUSER_PASSWORD=${HC_SUPERUSER_PASSWORD}
EOF

# Start the service
docker-compose up -d

echo "✅ Healthchecks running at http://$(hostname -I | awk '{print $1}'):8000"
echo "   Login: ${HC_SUPERUSER_EMAIL} / ${HC_SUPERUSER_PASSWORD}"
```

### 3. Create Your First Check

```bash
# Get API key from the web UI, then:
export HC_API_KEY="your-api-key-here"
export HC_URL="http://localhost:8000"

# Create a check for a daily backup job
curl -s "${HC_URL}/api/v3/checks/" \
  -H "X-Api-Key: ${HC_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Daily Backup",
    "tags": "backup production",
    "timeout": 90000,
    "grace": 3600,
    "channels": "*"
  }' | jq .
```

### 4. Ping from Your Cron Jobs

```bash
# Add to the END of any cron job:
# Success ping
curl -fsS --retry 3 "${HC_URL}/ping/<check-uuid>" > /dev/null

# Or with exit status reporting:
# At start:  curl -fsS "${HC_URL}/ping/<uuid>/start"
# On success: curl -fsS "${HC_URL}/ping/<uuid>"
# On failure: curl -fsS "${HC_URL}/ping/<uuid>/fail"
```

## Core Workflows

### Workflow 1: Monitor a Cron Job

**Use case:** Alert if your nightly backup doesn't run

```bash
# Create check with 24h timeout + 1h grace period
CHECK=$(curl -s "${HC_URL}/api/v3/checks/" \
  -H "X-Api-Key: ${HC_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Nightly Backup",
    "timeout": 86400,
    "grace": 3600,
    "tags": "backup"
  }')

UUID=$(echo "$CHECK" | jq -r '.ping_url' | grep -oP '[^/]+$')
echo "Ping URL: ${HC_URL}/ping/${UUID}"

# Add to your backup script:
# #!/bin/bash
# /path/to/backup.sh && curl -fsS "${HC_URL}/ping/${UUID}"
```

### Workflow 2: Monitor with Timing

**Use case:** Track job duration, alert on slowdowns

```bash
# In your script:
curl -fsS "${HC_URL}/ping/<uuid>/start"    # Job started
# ... your actual work ...
curl -fsS "${HC_URL}/ping/<uuid>"            # Job completed

# If job takes too long, Healthchecks alerts you
```

### Workflow 3: List All Checks & Status

```bash
# List all checks
curl -s "${HC_URL}/api/v3/checks/" \
  -H "X-Api-Key: ${HC_API_KEY}" | \
  jq -r '.checks[] | "\(.status)\t\(.name)\t\(.last_ping // "never")"' | \
  column -t -s $'\t'

# Output:
# up      Daily Backup     2026-02-25T10:00:00+00:00
# down    Log Rotation     2026-02-23T04:00:00+00:00
# new     SSL Renewal      never
```

### Workflow 4: Pause/Resume Checks

```bash
# Pause a check (e.g., during maintenance)
curl -s -X POST "${HC_URL}/api/v3/checks/<uuid>/pause" \
  -H "X-Api-Key: ${HC_API_KEY}" | jq .status

# Resume by sending a ping
curl -fsS "${HC_URL}/ping/<uuid>"
```

### Workflow 5: Set Up Telegram Alerts

```bash
# 1. Create a Telegram bot via @BotFather
# 2. Add to .env:
echo 'HC_TELEGRAM_BOT=YourBotName' >> ~/healthchecks/.env
echo 'HC_TELEGRAM_TOKEN=123456:ABC-DEF...' >> ~/healthchecks/.env

# 3. Restart
cd ~/healthchecks && docker-compose up -d

# 4. In the web UI: Integrations → Add Telegram
# Or via API: configure notification channels
```

## Management Commands

### Service Control

```bash
cd ~/healthchecks

# Status
docker-compose ps

# Logs
docker-compose logs --tail=50 -f

# Restart
docker-compose restart

# Update to latest version
docker-compose pull && docker-compose up -d

# Stop
docker-compose down

# Backup database
cp data/hc.sqlite "data/hc-backup-$(date +%Y%m%d).sqlite"
```

### API: Bulk Operations

```bash
# Delete all "new" (never-pinged) checks
curl -s "${HC_URL}/api/v3/checks/" \
  -H "X-Api-Key: ${HC_API_KEY}" | \
  jq -r '.checks[] | select(.status == "new") | .ping_url' | \
  grep -oP '[^/]+$' | \
  while read uuid; do
    curl -s -X DELETE "${HC_URL}/api/v3/checks/${uuid}" \
      -H "X-Api-Key: ${HC_API_KEY}"
    echo "Deleted ${uuid}"
  done

# Get all "down" checks (things that stopped running)
curl -s "${HC_URL}/api/v3/checks/" \
  -H "X-Api-Key: ${HC_API_KEY}" | \
  jq '[.checks[] | select(.status == "down") | {name, last_ping, status}]'
```

## Configuration

### Environment Variables

```bash
# Core
HC_SECRET=<random-hex-32>       # Django secret key
HC_PORT=8000                     # Web UI port
HC_SITE_ROOT=http://your-ip:8000 # Public URL
HC_SITE_NAME=Healthchecks        # Instance name

# Auth
HC_SUPERUSER_EMAIL=admin@you.com
HC_SUPERUSER_PASSWORD=<strong-password>

# Email (for alerts)
HC_FROM_EMAIL=healthchecks@you.com
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=you@gmail.com
EMAIL_HOST_PASSWORD=app-password
EMAIL_USE_TLS=True

# Telegram (for alerts)
HC_TELEGRAM_BOT=YourBotName
HC_TELEGRAM_TOKEN=123456:ABC-DEF...

# Optional
REGISTRATION_OPEN=False          # Disable public signup
PING_BODY_LIMIT=10000           # Max ping body size (bytes)
```

### Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl;
    server_name hc.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/hc.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hc.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Troubleshooting

### Issue: Container won't start

```bash
# Check logs
docker-compose logs healthchecks

# Common fix: permission issues
sudo chown -R 1000:1000 ~/healthchecks/data
docker-compose restart
```

### Issue: Pings not registering

```bash
# Test ping manually
curl -v "http://localhost:8000/ping/<uuid>"

# Check the check exists
curl -s "http://localhost:8000/api/v3/checks/" \
  -H "X-Api-Key: ${HC_API_KEY}" | jq '.checks[] | select(.name == "Your Check")'
```

### Issue: Email alerts not sending

```bash
# Test SMTP from inside container
docker-compose exec healthchecks python -c "
from django.core.mail import send_mail
send_mail('Test', 'Body', None, ['you@email.com'])
"
```

### Issue: High memory usage

```bash
# Prune old ping data (keep last 100 per check)
docker-compose exec healthchecks python manage.py prunepings --keep=100
```

## Integration with OpenClaw Cron

```bash
# Monitor your OpenClaw cron jobs automatically
# Add this wrapper function to your scripts:

hc_wrap() {
  local uuid="$1"; shift
  curl -fsS "${HC_URL}/ping/${uuid}/start" > /dev/null 2>&1
  if "$@"; then
    curl -fsS "${HC_URL}/ping/${uuid}" > /dev/null 2>&1
  else
    curl -fsS "${HC_URL}/ping/${uuid}/fail" > /dev/null 2>&1
    return 1
  fi
}

# Usage: hc_wrap <uuid> your-command --with-args
```

## Key Principles

1. **Dead man's switch** — Alerts on ABSENCE of pings, not presence of errors
2. **Grace periods** — Don't alert immediately; allow for normal timing variance
3. **Cron expression support** — Set expected schedules, not just timeouts
4. **Multiple alert channels** — Email, Telegram, Slack, webhook, PagerDuty, etc.
5. **Self-hosted** — Your data stays on your server, no SaaS dependency
