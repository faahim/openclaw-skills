---
name: service-dashboard
description: >-
  Generate a self-hosted HTML status page by monitoring HTTP, TCP, DNS, and Docker services. Auto-refreshes, alerts on downtime.
categories: [automation, dev-tools]
dependencies: [bash, curl, jq, nc]
---

# Service Health Dashboard

## What This Does

Monitors your services (websites, APIs, databases, Docker containers, DNS records) and generates a **live HTML status page** you can self-host or share. Think "your own StatusPage.io" — zero dependencies beyond bash and curl.

**Example:** Monitor 20 services, generate `status.html` every 5 minutes, get Telegram alerts when something goes down.

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# These are pre-installed on most Linux systems
which curl jq nc || sudo apt-get install -y curl jq netcat-openbsd

# Optional: Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
```

### 2. Create Config

```bash
cat > ~/.service-dashboard.yaml << 'EOF'
title: "My Services"
checks:
  - name: "Website"
    type: http
    url: "https://example.com"
    expect_status: 200

  - name: "API"
    type: http
    url: "https://api.example.com/health"
    expect_body: '"status":"ok"'

  - name: "Database"
    type: tcp
    host: "localhost"
    port: 5432

  - name: "DNS"
    type: dns
    domain: "example.com"
    record: A

alerts:
  telegram:
    enabled: true
EOF
```

### 3. Run First Check

```bash
bash scripts/dashboard.sh --config ~/.service-dashboard.yaml --output /tmp/status.html

# Open the generated dashboard
echo "Dashboard: file:///tmp/status.html"
```

## Core Workflows

### Workflow 1: Generate Status Page

```bash
bash scripts/dashboard.sh \
  --config ~/.service-dashboard.yaml \
  --output /var/www/html/status.html
```

Produces a self-contained HTML file with:
- ✅/❌ status per service
- Response time (ms)
- Last checked timestamp
- 24-hour uptime percentage (from history log)
- Auto-refresh every 60 seconds

### Workflow 2: Continuous Monitoring via Cron

```bash
# Check every 5 minutes, update dashboard
*/5 * * * * bash /path/to/scripts/dashboard.sh --config ~/.service-dashboard.yaml --output /var/www/html/status.html >> /var/log/service-dashboard.log 2>&1
```

### Workflow 3: Monitor Docker Containers

```bash
# Add Docker checks to config
cat >> ~/.service-dashboard.yaml << 'EOF'
  - name: "Nginx Container"
    type: docker
    container: "nginx"

  - name: "Postgres Container"
    type: docker
    container: "postgres-db"
EOF
```

### Workflow 4: JSON Output for API Consumption

```bash
bash scripts/dashboard.sh --config ~/.service-dashboard.yaml --format json --output /var/www/html/status.json
```

Returns:
```json
{
  "generated_at": "2026-02-24T10:00:00Z",
  "overall": "degraded",
  "services": [
    {"name": "Website", "status": "up", "response_ms": 145, "uptime_24h": "99.8%"},
    {"name": "Database", "status": "down", "error": "Connection refused", "uptime_24h": "95.2%"}
  ]
}
```

## Configuration

### Check Types

**HTTP** — Check URL returns expected status code / body content:
```yaml
- name: "My API"
  type: http
  url: "https://api.example.com/health"
  expect_status: 200        # Expected HTTP status (default: 200)
  expect_body: "ok"         # Optional: string that must appear in response
  timeout: 10               # Seconds (default: 10)
  method: GET               # HTTP method (default: GET)
  headers:                  # Optional headers
    Authorization: "Bearer token123"
```

**TCP** — Check port is open:
```yaml
- name: "Postgres"
  type: tcp
  host: "db.example.com"
  port: 5432
  timeout: 5
```

**DNS** — Check DNS record resolves:
```yaml
- name: "DNS Check"
  type: dns
  domain: "example.com"
  record: A                 # A, AAAA, MX, CNAME, TXT
  expect: "93.184.216.34"   # Optional: expected value
  nameserver: "8.8.8.8"    # Optional: specific nameserver
```

**Docker** — Check container is running and healthy:
```yaml
- name: "App Container"
  type: docker
  container: "my-app"      # Container name or ID
```

**Command** — Run arbitrary command, check exit code:
```yaml
- name: "Disk Space"
  type: command
  cmd: "test $(df / --output=pcent | tail -1 | tr -d '% ') -lt 90"
  label: "Disk < 90%"
```

### Alert Configuration

```yaml
alerts:
  telegram:
    enabled: true
    # Uses TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID env vars
    on_down: true           # Alert when service goes down (default: true)
    on_recovery: true       # Alert when service recovers (default: true)
    cooldown: 300           # Seconds between repeat alerts (default: 300)

  webhook:
    enabled: false
    url: "https://hooks.slack.com/services/..."
    on_down: true
    on_recovery: true

  command:
    enabled: false
    on_down: "echo '{name} is DOWN' | mail -s 'Alert' admin@example.com"
    on_recovery: "echo '{name} recovered' | mail -s 'Recovery' admin@example.com"
```

### Dashboard Appearance

```yaml
title: "Acme Corp Status"
logo: "🏢"
theme: dark               # dark or light (default: dark)
refresh: 60               # Auto-refresh interval in seconds (default: 60)
show_response_time: true   # Show response time column (default: true)
show_uptime: true          # Show 24h uptime % (default: true)
```

## Advanced Usage

### History & Uptime Tracking

The dashboard maintains a rolling history file at `~/.service-dashboard-history.jsonl`:

```bash
# View recent history
tail -20 ~/.service-dashboard-history.jsonl | jq .

# Calculate uptime for last 7 days
bash scripts/dashboard.sh --report 7d
```

### Multiple Environments

```bash
# Production
bash scripts/dashboard.sh --config prod.yaml --output /var/www/status/prod.html

# Staging
bash scripts/dashboard.sh --config staging.yaml --output /var/www/status/staging.html
```

### Serve via Python (quick local server)

```bash
# Generate + serve
bash scripts/dashboard.sh --config ~/.service-dashboard.yaml --output /tmp/status/index.html
cd /tmp/status && python3 -m http.server 8080
# Visit http://localhost:8080
```

## Troubleshooting

### Issue: "nc: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install netcat-openbsd
# Alpine
apk add netcat-openbsd
# Mac (pre-installed)
```

### Issue: Docker checks fail with "permission denied"

```bash
# Add your user to docker group
sudo usermod -aG docker $USER
# Or run dashboard with sudo
```

### Issue: DNS checks fail

```bash
# Install dig
sudo apt-get install dnsutils
# Or use nslookup fallback (auto-detected)
```

### Issue: Telegram alerts not sending

1. Verify: `echo $TELEGRAM_BOT_TOKEN` (should not be empty)
2. Test: `curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test"`
3. Ensure bot was started (`/start` in Telegram)

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP checks + alerts)
- `jq` (JSON parsing)
- `nc` / netcat (TCP checks)
- `dig` or `nslookup` (DNS checks, optional)
- `docker` CLI (Docker checks, optional)
