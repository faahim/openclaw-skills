---
name: api-monitor
description: >-
  Monitor API endpoints with response validation, latency tracking, and multi-channel alerts.
categories: [automation, dev-tools]
dependencies: [bash, curl, jq]
---

# API Monitor

## What This Does

Continuously monitors your API endpoints — checks HTTP status codes, validates JSON responses against expected patterns, tracks response times, and sends instant alerts via Telegram, Slack webhook, or email when something breaks. Runs as a lightweight bash process or cron job with zero external dependencies beyond curl and jq.

**Example:** "Monitor 15 API endpoints every 2 minutes. Alert me on Telegram if any return non-200, take longer than 3 seconds, or stop matching the expected JSON schema."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# These are pre-installed on most systems
which curl jq bash || echo "Install: sudo apt-get install curl jq"

# For Telegram alerts (optional)
export API_MONITOR_TELEGRAM_TOKEN="your-bot-token"
export API_MONITOR_TELEGRAM_CHAT_ID="your-chat-id"
```

### 2. Create Your First Monitor

```bash
# Copy the config template
cp scripts/config-template.json monitors.json

# Edit monitors.json with your endpoints (see Configuration below)
```

### 3. Run It

```bash
# Single check (great for cron)
bash scripts/monitor.sh --config monitors.json

# Continuous mode (runs in background)
bash scripts/monitor.sh --config monitors.json --loop --interval 120

# Quick single-endpoint test
bash scripts/monitor.sh --url https://api.example.com/health --expect-status 200
```

## Core Workflows

### Workflow 1: Monitor REST API Health

**Use case:** Ensure your production API is responding correctly.

```bash
bash scripts/monitor.sh \
  --url https://api.yourapp.com/health \
  --expect-status 200 \
  --expect-json '{"status":"ok"}' \
  --timeout 5 \
  --alert telegram
```

**Output:**
```
[2026-02-22 01:00:00] ✅ api.yourapp.com/health — 200 OK (142ms) — JSON ✓
[2026-02-22 01:02:00] ✅ api.yourapp.com/health — 200 OK (138ms) — JSON ✓
[2026-02-22 01:04:00] ❌ api.yourapp.com/health — 500 ERROR (2341ms)
  🚨 ALERT → Telegram: "api.yourapp.com/health returned 500 (expected 200)"
```

### Workflow 2: Multi-Endpoint Monitoring with Config

**Use case:** Monitor all your services from one config file.

```bash
# monitors.json defines all endpoints (see Configuration)
bash scripts/monitor.sh --config monitors.json --loop --interval 60
```

### Workflow 3: Response Body Validation

**Use case:** Ensure API returns expected data structure.

```bash
bash scripts/monitor.sh \
  --url https://api.stripe.com/v1/balance \
  --header "Authorization: Bearer sk_live_xxx" \
  --expect-json-path '.available[0].amount' \
  --timeout 10
```

### Workflow 4: Latency Threshold Alerts

**Use case:** Get alerted when response times exceed acceptable limits.

```bash
bash scripts/monitor.sh \
  --url https://api.yourapp.com/search \
  --method POST \
  --body '{"q":"test"}' \
  --content-type "application/json" \
  --max-latency 2000 \
  --alert slack
```

### Workflow 5: Run via Cron

**Use case:** Schedule checks every 5 minutes without a long-running process.

```bash
# Add to crontab
*/5 * * * * cd /path/to/api-monitor && bash scripts/monitor.sh --config monitors.json >> logs/monitor.log 2>&1

# Or use OpenClaw cron for agent-integrated monitoring
```

### Workflow 6: SSL Certificate Check

**Use case:** Monitor certificate expiry alongside API health.

```bash
bash scripts/monitor.sh \
  --url https://api.yourapp.com \
  --check-ssl \
  --ssl-warn-days 30 \
  --alert telegram
```

## Configuration

### Config File Format (JSON)

```json
{
  "defaults": {
    "timeout": 5,
    "interval": 120,
    "max_latency": 3000,
    "retries": 2,
    "retry_delay": 5,
    "alert_cooldown": 300
  },
  "alerts": {
    "telegram": {
      "token": "${API_MONITOR_TELEGRAM_TOKEN}",
      "chat_id": "${API_MONITOR_TELEGRAM_CHAT_ID}"
    },
    "slack": {
      "webhook_url": "${API_MONITOR_SLACK_WEBHOOK}"
    },
    "email": {
      "smtp_host": "smtp.gmail.com",
      "smtp_port": 587,
      "from": "monitor@yourapp.com",
      "to": "alerts@yourapp.com",
      "user": "${SMTP_USER}",
      "pass": "${SMTP_PASS}"
    }
  },
  "monitors": [
    {
      "name": "Production API",
      "url": "https://api.yourapp.com/health",
      "method": "GET",
      "expect_status": 200,
      "expect_json": {"status": "ok"},
      "interval": 60,
      "alerts": ["telegram", "slack"]
    },
    {
      "name": "Payment Service",
      "url": "https://payments.yourapp.com/ping",
      "method": "GET",
      "expect_status": 200,
      "timeout": 3,
      "max_latency": 1000,
      "alerts": ["telegram"]
    },
    {
      "name": "Auth Endpoint",
      "url": "https://auth.yourapp.com/token",
      "method": "POST",
      "headers": {
        "Content-Type": "application/json"
      },
      "body": "{\"grant_type\":\"client_credentials\"}",
      "expect_status": [200, 201],
      "expect_json_path": ".access_token",
      "alerts": ["slack"]
    }
  ]
}
```

### Environment Variables

```bash
# Telegram
export API_MONITOR_TELEGRAM_TOKEN="123456:ABC-DEF..."
export API_MONITOR_TELEGRAM_CHAT_ID="987654321"

# Slack
export API_MONITOR_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"

# Email (SMTP)
export SMTP_USER="monitor@yourapp.com"
export SMTP_PASS="app-password-here"

# State directory (default: ./state)
export API_MONITOR_STATE_DIR="/var/lib/api-monitor"

# Log directory (default: ./logs)
export API_MONITOR_LOG_DIR="/var/log/api-monitor"
```

## Advanced Usage

### Custom Headers & Auth

```json
{
  "name": "Authenticated API",
  "url": "https://api.example.com/data",
  "headers": {
    "Authorization": "Bearer ${API_TOKEN}",
    "X-Custom-Header": "value"
  }
}
```

### Response Time History

```bash
# View latency stats for last 24 hours
bash scripts/monitor.sh --stats --hours 24

# Output:
# Production API    — avg: 145ms  p95: 320ms  p99: 890ms  checks: 720
# Payment Service   — avg: 82ms   p95: 150ms  p99: 250ms  checks: 720
# Auth Endpoint     — avg: 210ms  p95: 450ms  p99: 1200ms checks: 720
```

### Alert Cooldown

Prevents alert spam when an endpoint is persistently down:

```json
{
  "alert_cooldown": 300,
  "escalation": [60, 300, 900, 3600]
}
```

First alert immediately, then 5 min, 15 min, 1 hour between repeats.

### Recovery Notifications

```json
{
  "notify_recovery": true
}
```

Sends "✅ Production API is back UP (was down for 12 min)" when service recovers.

## Troubleshooting

### Issue: "jq: command not found"

```bash
sudo apt-get install jq    # Debian/Ubuntu
brew install jq             # macOS
```

### Issue: Telegram alerts not sending

1. Verify token: `curl "https://api.telegram.org/bot$API_MONITOR_TELEGRAM_TOKEN/getMe"`
2. Verify chat ID: `curl "https://api.telegram.org/bot$API_MONITOR_TELEGRAM_TOKEN/sendMessage?chat_id=$API_MONITOR_TELEGRAM_CHAT_ID&text=test"`
3. Ensure bot is added to the chat/group

### Issue: False alerts from timeouts

Increase timeout and retries in config:
```json
{"timeout": 10, "retries": 3, "retry_delay": 5}
```

### Issue: High memory usage with many monitors

Use cron mode (single check per run) instead of loop mode for 50+ endpoints.

## Key Principles

1. **Retry before alerting** — Default 2 retries to avoid false positives
2. **Alert cooldown** — No spam on persistent failures
3. **Recovery notifications** — Know when things come back
4. **Stateless checks** — Each run reads config, checks, exits (cron-friendly)
5. **Environment-based secrets** — Never hardcode tokens in config files
