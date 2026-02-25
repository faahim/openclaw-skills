---
name: uptime-kuma
description: >-
  Install and manage Uptime Kuma — the most popular self-hosted monitoring dashboard.
  Add monitors, configure notifications, create status pages, all from the CLI.
categories: [automation, dev-tools]
dependencies: [docker, curl, jq]
---

# Uptime Kuma Manager

## What This Does

Install and manage [Uptime Kuma](https://github.com/louislam/uptime-kuma) (58k+ ⭐) — the most popular open-source, self-hosted monitoring tool. Unlike basic curl-based monitors, Uptime Kuma gives you a real-time web dashboard, 90+ notification integrations (Telegram, Slack, Discord, email, etc.), status pages, and certificate monitoring.

This skill handles the full lifecycle: install via Docker, manage monitors via API, configure alerts, and create public status pages — all without touching the web UI.

## Quick Start (5 minutes)

### 1. Install Uptime Kuma

```bash
# Install via Docker (recommended)
bash scripts/install.sh

# Or specify a custom port
bash scripts/install.sh --port 3001
```

This starts Uptime Kuma on `http://localhost:3001`.

### 2. Set Up Admin Account

```bash
# Create admin user (first run only)
bash scripts/setup.sh --username admin --password 'YourSecurePassword123!'

# Save credentials for API access
export KUMA_URL="http://localhost:3001"
export KUMA_USERNAME="admin"
export KUMA_PASSWORD="YourSecurePassword123!"
```

### 3. Add Your First Monitor

```bash
# Monitor a website
bash scripts/monitor.sh add \
  --name "My Website" \
  --url "https://example.com" \
  --interval 60

# Monitor an API endpoint
bash scripts/monitor.sh add \
  --name "API Health" \
  --url "https://api.example.com/health" \
  --type http \
  --expected-status 200 \
  --interval 30
```

## Core Workflows

### Workflow 1: Install & Configure

```bash
# Install with Docker
bash scripts/install.sh

# Check status
bash scripts/install.sh status

# View logs
docker logs uptime-kuma --tail 50

# Stop/Start
docker stop uptime-kuma
docker start uptime-kuma

# Upgrade to latest version
bash scripts/install.sh upgrade
```

### Workflow 2: Manage Monitors

```bash
# Add HTTP monitor
bash scripts/monitor.sh add \
  --name "Production Site" \
  --url "https://mysite.com" \
  --interval 60 \
  --retry 3

# Add TCP port monitor
bash scripts/monitor.sh add \
  --name "Database Port" \
  --type port \
  --hostname "db.internal" \
  --port 5432 \
  --interval 30

# Add ping monitor
bash scripts/monitor.sh add \
  --name "Gateway Ping" \
  --type ping \
  --hostname "192.168.1.1" \
  --interval 60

# Add keyword monitor (check page contains text)
bash scripts/monitor.sh add \
  --name "Checkout Page" \
  --url "https://shop.example.com" \
  --type keyword \
  --keyword "Add to Cart" \
  --interval 120

# Add DNS monitor
bash scripts/monitor.sh add \
  --name "DNS Check" \
  --type dns \
  --hostname "example.com" \
  --dns-resolver "8.8.8.8" \
  --interval 300

# List all monitors
bash scripts/monitor.sh list

# Pause a monitor
bash scripts/monitor.sh pause --id 1

# Resume a monitor
bash scripts/monitor.sh resume --id 1

# Delete a monitor
bash scripts/monitor.sh delete --id 1
```

### Workflow 3: Set Up Notifications

```bash
# Add Telegram notification
bash scripts/notify.sh add \
  --type telegram \
  --name "Telegram Alerts" \
  --token "BOT_TOKEN" \
  --chat-id "CHAT_ID"

# Add Slack webhook
bash scripts/notify.sh add \
  --type slack \
  --name "Slack Alerts" \
  --webhook "https://hooks.slack.com/services/xxx/yyy/zzz"

# Add Discord webhook
bash scripts/notify.sh add \
  --type discord \
  --name "Discord Alerts" \
  --webhook "https://discord.com/api/webhooks/xxx/yyy"

# Add email (SMTP)
bash scripts/notify.sh add \
  --type smtp \
  --name "Email Alerts" \
  --smtp-host "smtp.gmail.com" \
  --smtp-port 587 \
  --smtp-user "you@gmail.com" \
  --smtp-pass "app-password" \
  --smtp-to "alerts@example.com"

# List notifications
bash scripts/notify.sh list
```

### Workflow 4: Create Status Page

```bash
# Create a public status page
bash scripts/status-page.sh create \
  --slug "status" \
  --title "Service Status" \
  --description "Current status of our services" \
  --monitors 1,2,3

# Access at: http://localhost:3001/status/status
```

### Workflow 5: Monitor SSL Certificates

```bash
# Add SSL expiry monitor (alerts 30 days before expiry)
bash scripts/monitor.sh add \
  --name "SSL: mysite.com" \
  --url "https://mysite.com" \
  --type http \
  --interval 3600 \
  --ssl-expiry-days 30
```

### Workflow 6: Bulk Import Monitors

```bash
# Import from YAML config
bash scripts/monitor.sh import --config monitors.yaml
```

**monitors.yaml:**
```yaml
monitors:
  - name: "Production Web"
    url: "https://prod.example.com"
    interval: 60
    type: http
  - name: "Staging Web"
    url: "https://staging.example.com"
    interval: 120
    type: http
  - name: "Database"
    type: port
    hostname: "db.example.com"
    port: 5432
    interval: 30
  - name: "Redis"
    type: port
    hostname: "redis.example.com"
    port: 6379
    interval: 30
```

## Configuration

### Environment Variables

```bash
# Required for API access
export KUMA_URL="http://localhost:3001"
export KUMA_USERNAME="admin"
export KUMA_PASSWORD="your-password"

# Optional: custom Docker settings
export KUMA_PORT="3001"
export KUMA_DATA_DIR="/opt/uptime-kuma/data"
```

### Docker Compose (Advanced)

```yaml
# docker-compose.yml
version: '3'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
    environment:
      - NODE_ENV=production
```

## Advanced Usage

### Run Behind Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl;
    server_name status.example.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Backup & Restore

```bash
# Backup
bash scripts/install.sh backup
# Creates: uptime-kuma-backup-YYYY-MM-DD.tar.gz

# Restore
bash scripts/install.sh restore --file uptime-kuma-backup-2026-02-25.tar.gz
```

### API Direct Access

```bash
# Get auth token
TOKEN=$(curl -s "$KUMA_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$KUMA_USERNAME\",\"password\":\"$KUMA_PASSWORD\"}" | jq -r '.token')

# List monitors
curl -s "$KUMA_URL/api/monitors" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Get uptime summary
curl -s "$KUMA_URL/api/monitors/1/beats?hours=24" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

## Troubleshooting

### Issue: Docker not found

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: Port 3001 already in use

```bash
# Use a different port
bash scripts/install.sh --port 3002
```

### Issue: Cannot connect to Uptime Kuma API

**Check:**
1. Container is running: `docker ps | grep uptime-kuma`
2. Port is accessible: `curl -s http://localhost:3001/api/info`
3. Credentials are correct: verify KUMA_USERNAME/KUMA_PASSWORD

### Issue: WebSocket errors behind proxy

**Fix:** Ensure your reverse proxy forwards WebSocket connections (see Nginx config above).

### Issue: High memory usage

```bash
# Restart container (clears caches)
docker restart uptime-kuma

# Or limit memory
docker update --memory 512m uptime-kuma
```

## Monitor Types

| Type | Use Case | Required Fields |
|------|----------|----------------|
| `http` | Website/API monitoring | `url` |
| `port` | TCP port check | `hostname`, `port` |
| `ping` | ICMP ping | `hostname` |
| `keyword` | Page content check | `url`, `keyword` |
| `dns` | DNS resolution | `hostname` |
| `docker` | Docker container | `docker_container` |
| `push` | Dead man's switch | (generates push URL) |
| `steam` | Steam game server | `hostname`, `port` |
| `mqtt` | MQTT broker | `hostname`, `port` |
| `radius` | RADIUS server | `hostname` |
| `sqlserver` | SQL Server | connection string |
| `postgres` | PostgreSQL | connection string |
| `mysql` | MySQL | connection string |
| `mongodb` | MongoDB | connection string |
| `redis` | Redis | `hostname` |

## Key Principles

1. **Docker-first** — Runs in an isolated container, no system pollution
2. **API-driven** — Full control without touching the web UI
3. **90+ notification types** — Telegram, Slack, Discord, email, webhook, PagerDuty, etc.
4. **Status pages** — Public/private status pages for stakeholders
5. **Zero external dependencies** — Self-hosted, your data stays with you

## Dependencies

- `docker` (required for installation)
- `curl` (HTTP requests)
- `jq` (JSON parsing)
- Optional: `docker-compose` (for advanced setups)
