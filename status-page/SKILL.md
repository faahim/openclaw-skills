---
name: status-page
description: >-
  Deploy a self-hosted status page with automated endpoint monitoring using Gatus.
categories: [automation, dev-tools]
dependencies: [docker, curl]
---

# Status Page — Self-Hosted Service Monitoring Dashboard

## What This Does

Deploy a public-facing status page that monitors your websites, APIs, and services. Uses [Gatus](https://github.com/TwiN/gatus) — a lightweight, developer-friendly health dashboard with alerting. No signup, no SaaS fees, runs anywhere Docker runs.

**Example:** Monitor 20 endpoints, show uptime badges on your site, get Telegram/Slack/Discord alerts on failure — all from a single YAML config.

## Quick Start (5 minutes)

### 1. Prerequisites

```bash
# Docker must be installed
which docker || echo "Install Docker first: https://docs.docker.com/engine/install/"

# Create working directory
mkdir -p ~/status-page && cd ~/status-page
```

### 2. Generate Config

```bash
# Run the config generator
bash scripts/setup.sh init

# This creates:
# ~/status-page/config/config.yaml  — endpoint definitions
# ~/status-page/docker-compose.yml  — container config
```

### 3. Add Your Endpoints

Edit `~/status-page/config/config.yaml`:

```yaml
endpoints:
  - name: My Website
    group: Production
    url: "https://yoursite.com"
    interval: 2m
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 2000"

  - name: API Health
    group: Production
    url: "https://api.yoursite.com/health"
    interval: 1m
    conditions:
      - "[STATUS] == 200"
      - "[BODY].status == UP"

  - name: Database
    group: Infrastructure
    url: "tcp://db.internal:5432"
    interval: 30s
    conditions:
      - "[CONNECTED] == true"
```

### 4. Launch

```bash
bash scripts/setup.sh start

# Status page available at http://localhost:8080
# Or your server's IP/domain on port 8080
```

## Core Workflows

### Workflow 1: Basic Website Monitoring

```yaml
# config/config.yaml
endpoints:
  - name: Homepage
    group: Web
    url: "https://example.com"
    interval: 5m
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 3000"
    alerts:
      - type: telegram
        send-on-resolved: true
        description: "Homepage is DOWN"
```

### Workflow 2: API Monitoring with JSON Validation

```yaml
endpoints:
  - name: User API
    group: APIs
    url: "https://api.example.com/v1/users"
    method: GET
    headers:
      Authorization: "Bearer ${API_TOKEN}"
    interval: 1m
    conditions:
      - "[STATUS] == 200"
      - "[BODY].data != null"
      - "[RESPONSE_TIME] < 1000"
```

### Workflow 3: Multi-Service Dashboard with Groups

```yaml
endpoints:
  # Production
  - name: Web App
    group: Production
    url: "https://app.example.com"
    interval: 2m
    conditions:
      - "[STATUS] == 200"

  - name: API Gateway
    group: Production
    url: "https://api.example.com/health"
    interval: 1m
    conditions:
      - "[STATUS] == 200"

  # Infrastructure
  - name: PostgreSQL
    group: Infrastructure
    url: "tcp://db.internal:5432"
    interval: 30s
    conditions:
      - "[CONNECTED] == true"

  - name: Redis
    group: Infrastructure
    url: "tcp://redis.internal:6379"
    interval: 30s
    conditions:
      - "[CONNECTED] == true"

  # External Dependencies
  - name: Stripe API
    group: External
    url: "https://api.stripe.com/v1"
    interval: 5m
    conditions:
      - "[STATUS] == 401"  # Expected without auth
```

### Workflow 4: Alerting (Telegram + Slack + Discord)

```yaml
alerting:
  telegram:
    token: "${TELEGRAM_BOT_TOKEN}"
    id: "${TELEGRAM_CHAT_ID}"

  slack:
    webhook-url: "${SLACK_WEBHOOK_URL}"

  discord:
    webhook-url: "${DISCORD_WEBHOOK_URL}"

endpoints:
  - name: Critical Service
    url: "https://critical.example.com"
    interval: 30s
    conditions:
      - "[STATUS] == 200"
    alerts:
      - type: telegram
        send-on-resolved: true
        failure-threshold: 3
        success-threshold: 2
      - type: slack
        send-on-resolved: true
        failure-threshold: 5
```

### Workflow 5: SSL Certificate Monitoring

```yaml
endpoints:
  - name: SSL Check - Main Site
    group: SSL Certificates
    url: "https://example.com"
    interval: 1h
    conditions:
      - "[STATUS] == 200"
      - "[CERTIFICATE_EXPIRATION] > 720h"  # Alert if < 30 days
```

## Management Commands

```bash
# Start the status page
bash scripts/setup.sh start

# Stop
bash scripts/setup.sh stop

# Restart (after config changes)
bash scripts/setup.sh restart

# View logs
bash scripts/setup.sh logs

# Check status
bash scripts/setup.sh status

# Add a new endpoint interactively
bash scripts/setup.sh add-endpoint

# Validate config
bash scripts/setup.sh validate

# Backup config + data
bash scripts/setup.sh backup

# Update Gatus to latest version
bash scripts/setup.sh update
```

## Configuration Reference

### Endpoint Options

```yaml
endpoints:
  - name: "Service Name"          # Display name
    group: "Group Name"           # Group on dashboard
    url: "https://..."            # URL to monitor (http/https/tcp/icmp/dns)
    method: GET                   # HTTP method (GET, POST, PUT, etc.)
    interval: 2m                  # Check frequency (30s, 1m, 5m, 1h)
    headers:                      # Custom HTTP headers
      Authorization: "Bearer ..."
    body: '{"key":"value"}'       # Request body (POST/PUT)
    conditions:                   # Pass/fail conditions
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 2000"
      - "[BODY].status == ok"
      - "[CONNECTED] == true"           # TCP checks
      - "[CERTIFICATE_EXPIRATION] > 720h"  # SSL expiry
    alerts:                       # Alert channels
      - type: telegram
        send-on-resolved: true    # Notify when recovered
        failure-threshold: 3      # Failures before alerting
        success-threshold: 2      # Successes before resolving
```

### Alert Providers

```yaml
alerting:
  # Telegram
  telegram:
    token: "${TELEGRAM_BOT_TOKEN}"
    id: "${TELEGRAM_CHAT_ID}"

  # Slack
  slack:
    webhook-url: "https://hooks.slack.com/services/..."

  # Discord
  discord:
    webhook-url: "https://discord.com/api/webhooks/..."

  # PagerDuty
  pagerduty:
    integration-key: "${PAGERDUTY_KEY}"

  # Email (SMTP)
  email:
    from: "status@example.com"
    host: "smtp.gmail.com"
    port: 587
    username: "${SMTP_USER}"
    password: "${SMTP_PASS}"
    to: "admin@example.com"

  # Custom webhook
  custom:
    url: "https://your-webhook.example.com/alert"
    method: POST
    body: |
      {
        "service": "[ALERT_TRIGGERED_OR_RESOLVED]",
        "description": "[ALERT_DESCRIPTION]",
        "endpoint": "[ENDPOINT_NAME]"
      }
```

### Storage (Persist History)

```yaml
storage:
  type: sqlite
  path: /data/gatus.db
```

### UI Customization

```yaml
ui:
  title: "My Status Page"
  header: "Service Status"
  logo: "https://example.com/logo.png"
  link: "https://example.com"
  buttons:
    - name: "Homepage"
      link: "https://example.com"
```

## Environment Variables

```bash
# Required for alerts (set in .env file)
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_CHAT_ID=your-chat-id
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# Optional
GATUS_PORT=8080                  # Dashboard port
GATUS_CONFIG_PATH=./config       # Config directory
```

## Reverse Proxy Setup

### Nginx

```nginx
server {
    listen 80;
    server_name status.example.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Caddy

```
status.example.com {
    reverse_proxy localhost:8080
}
```

## Troubleshooting

### Issue: "port 8080 already in use"

```bash
# Change port in docker-compose.yml or:
bash scripts/setup.sh start --port 9090
```

### Issue: Alerts not firing

1. Check alert config: `bash scripts/setup.sh validate`
2. Test Telegram: `curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test"`
3. Check failure-threshold (alerts only fire after N consecutive failures)

### Issue: "connection refused" for internal services

- Use Docker network names if monitoring containers on same host
- For TCP checks, ensure ports are exposed

### Issue: Dashboard shows no data

- Wait for first check interval to pass
- Check logs: `bash scripts/setup.sh logs`
- Ensure config.yaml is valid: `bash scripts/setup.sh validate`

## Uptime Badges

Embed badges in your README or website:

```markdown
![Status](https://status.example.com/api/v1/endpoints/production_web-app/uptimes/7d/badge.svg)
```

Available badge endpoints:
- `/api/v1/endpoints/{key}/uptimes/7d/badge.svg` — 7-day uptime
- `/api/v1/endpoints/{key}/uptimes/24h/badge.svg` — 24-hour uptime
- `/api/v1/endpoints/{key}/response-times/7d/badge.svg` — Response time

## Dependencies

- `docker` + `docker compose` (container runtime)
- `curl` (for health checks)
- `yq` (optional, for config validation)
