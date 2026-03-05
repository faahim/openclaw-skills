---
name: gatus-health-dashboard
description: >-
  Install and manage Gatus — a self-hosted health dashboard that monitors endpoints, APIs, and services with a beautiful status page.
categories: [automation, dev-tools]
dependencies: [bash, curl, docker]
---

# Gatus Health Dashboard

## What This Does

Gatus is a developer-oriented health dashboard that monitors your endpoints, APIs, and services. It provides a beautiful status page, configurable alerting (Slack, Discord, Telegram, PagerDuty, email), and supports complex health checks including DNS, TCP, ICMP, HTTP, and more.

**Example:** "Monitor 20 endpoints with response time thresholds, get Telegram alerts on failures, serve a public status page at status.yoursite.com."

## Quick Start (5 minutes)

### Option A: Docker (Recommended)

```bash
# Create config directory
mkdir -p ~/.config/gatus

# Generate starter config
bash scripts/setup.sh --init

# Start Gatus
docker run -d \
  --name gatus \
  -p 8080:8080 \
  -v ~/.config/gatus/config.yaml:/config/config.yaml \
  twinproduction/gatus:latest

# Open http://localhost:8080 to see your status page
echo "✅ Gatus running at http://localhost:8080"
```

### Option B: Binary Install (No Docker)

```bash
# Install Gatus binary
bash scripts/install.sh

# Initialize config
bash scripts/setup.sh --init

# Start Gatus
gatus --config ~/.config/gatus/config.yaml
```

### Option C: Docker Compose

```bash
# Generate docker-compose.yaml + config
bash scripts/setup.sh --compose

# Start
cd ~/.config/gatus && docker compose up -d
```

## Core Workflows

### Workflow 1: Monitor HTTP Endpoints

```yaml
# ~/.config/gatus/config.yaml
endpoints:
  - name: Website
    group: core
    url: "https://yoursite.com"
    interval: 2m
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 500"

  - name: API Health
    group: core
    url: "https://api.yoursite.com/health"
    interval: 1m
    conditions:
      - "[STATUS] == 200"
      - "[BODY].status == UP"
      - "[RESPONSE_TIME] < 300"
```

### Workflow 2: Monitor with Telegram Alerts

```yaml
alerting:
  telegram:
    token: "${TELEGRAM_BOT_TOKEN}"
    id: "${TELEGRAM_CHAT_ID}"
    default-alert:
      enabled: true
      failure-threshold: 3
      success-threshold: 2
      send-on-resolved: true

endpoints:
  - name: Production API
    url: "https://api.yoursite.com/health"
    interval: 1m
    conditions:
      - "[STATUS] == 200"
    alerts:
      - type: telegram
        description: "Production API is down!"
```

### Workflow 3: Monitor DNS + TCP + ICMP

```yaml
endpoints:
  - name: DNS Resolution
    url: "8.8.8.8"
    dns:
      query-name: "yoursite.com"
      query-type: "A"
    conditions:
      - "[DNS_RCODE] == NOERROR"

  - name: Database Port
    url: "tcp://db.internal:5432"
    interval: 30s
    conditions:
      - "[CONNECTED] == true"

  - name: Server Ping
    url: "icmp://192.168.1.1"
    interval: 1m
    conditions:
      - "[CONNECTED] == true"
```

### Workflow 4: SSL Certificate Monitoring

```yaml
endpoints:
  - name: SSL Check - Main Site
    url: "https://yoursite.com"
    interval: 1h
    conditions:
      - "[STATUS] == 200"
      - "[CERTIFICATE_EXPIRATION] > 720h"  # Alert if <30 days
    alerts:
      - type: telegram
        description: "SSL cert expiring soon!"
```

### Workflow 5: Monitor with Slack/Discord Alerts

```yaml
alerting:
  slack:
    webhook-url: "https://hooks.slack.com/services/xxx/yyy/zzz"
    default-alert:
      enabled: true
      failure-threshold: 2
      send-on-resolved: true

  discord:
    webhook-url: "https://discord.com/api/webhooks/xxx/yyy"
    default-alert:
      enabled: true
      failure-threshold: 3
```

### Workflow 6: External Endpoints with Authentication

```yaml
endpoints:
  - name: Authenticated API
    url: "https://api.service.com/v1/status"
    method: GET
    headers:
      Authorization: "Bearer ${API_TOKEN}"
    interval: 5m
    conditions:
      - "[STATUS] == 200"

  - name: POST Health Check
    url: "https://api.service.com/health"
    method: POST
    body: '{"check": "deep"}'
    headers:
      Content-Type: "application/json"
    conditions:
      - "[STATUS] == 200"
      - "[BODY].healthy == true"
```

## Management Commands

### Add an endpoint

```bash
bash scripts/manage.sh add \
  --name "New Service" \
  --url "https://newservice.com" \
  --interval "2m" \
  --condition "[STATUS] == 200"
```

### List monitored endpoints

```bash
bash scripts/manage.sh list
```

### Check Gatus status

```bash
bash scripts/manage.sh status
```

### View recent results via API

```bash
# Gatus exposes a REST API
curl -s http://localhost:8080/api/v1/endpoints/statuses | jq '.[].name'
```

### Restart after config change

```bash
bash scripts/manage.sh reload
```

## Configuration

### Environment Variables

```bash
# Alert credentials (use .env file or export)
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."

# Optional: PagerDuty
export PAGERDUTY_INTEGRATION_KEY="your-key"

# Optional: Email (SMTP)
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_FROM="alerts@yoursite.com"
export SMTP_USERNAME="your-email"
export SMTP_PASSWORD="your-password"
```

### Storage (Persist History)

```yaml
storage:
  type: sqlite
  path: /data/gatus.db

# Or PostgreSQL for production:
storage:
  type: postgres
  path: "postgres://user:pass@localhost:5432/gatus?sslmode=disable"
```

### Custom Status Page

```yaml
ui:
  title: "Service Status"
  description: "Current status of our services"
  header: "Service Status Dashboard"
  logo: "https://yoursite.com/logo.png"
  link: "https://yoursite.com"
```

### Maintenance Windows

```yaml
maintenance:
  start: "23:00"
  duration: "1h"
  timezone: "America/New_York"
  # Alerts are suppressed during maintenance
```

## Advanced Usage

### Run as Systemd Service (non-Docker)

```bash
bash scripts/install.sh --systemd

# Manage with systemctl
sudo systemctl status gatus
sudo systemctl restart gatus
sudo journalctl -u gatus -f
```

### Run Behind Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl;
    server_name status.yoursite.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Kubernetes / Docker Compose with PostgreSQL

```bash
bash scripts/setup.sh --compose-postgres
# Generates docker-compose with PostgreSQL for persistent storage
```

### External Endpoint Configuration (Git-based)

```yaml
# Load configs from multiple files
endpoints: []
external-endpoints:
  - type: git
    url: "https://github.com/yourorg/gatus-configs"
    path: "endpoints/*.yaml"
    interval: 5m
```

## Troubleshooting

### Issue: Port 8080 already in use

```bash
# Change port
docker run -d --name gatus -p 9090:8080 \
  -v ~/.config/gatus/config.yaml:/config/config.yaml \
  twinproduction/gatus:latest
```

### Issue: DNS checks not working

DNS checks require the `url` to be a DNS server IP (e.g., `8.8.8.8`), not a hostname.

### Issue: Alerts not sending

1. Check env vars are set: `env | grep TELEGRAM`
2. Test bot manually: `curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=test"`
3. Check failure-threshold (alerts only fire after N consecutive failures)

### Issue: Config validation errors

```bash
# Validate config without starting
bash scripts/manage.sh validate
```

## Dependencies

- `bash` (4.0+)
- `curl` (for API queries)
- `docker` (recommended) OR ability to run Go binaries
- `jq` (for JSON parsing)
- Optional: `docker-compose` for multi-container setups
