---
name: uptime-monitor
description: >-
  Monitor URLs and APIs with automated alerts on downtime. Supports Telegram, webhooks, email, SSL expiry checks, and multi-target config.
categories: [automation, dev-tools]
dependencies: [curl, jq, openssl, bash]
---

# Uptime Monitor

## What This Does

Monitors your websites, APIs, and services — alerts you instantly when something goes down. Checks HTTP status codes, response times, body content, and SSL certificate expiry. Runs entirely on your machine with no external monitoring service needed.

**Example:** "Monitor 10 URLs every 5 minutes, get a Telegram alert within 2 checks if any go down, plus weekly SSL expiry warnings."

## Quick Start (2 minutes)

### 1. Check dependencies

```bash
which curl jq openssl || echo "Install missing: apt install curl jq openssl"
```

### 2. One-shot check

```bash
bash scripts/check-once.sh https://google.com
# ✅ https://google.com — 200 OK (85ms)
# {"url":"https://google.com","status":"up","http_code":200,"latency_ms":85,"ssl_days_left":62,"checked_at":"2026-02-21 12:00:00 UTC"}
```

### 3. Continuous monitoring

```bash
bash scripts/monitor.sh --url https://yoursite.com --interval 300
```

## Alerting

### Telegram (recommended)

```bash
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF"
export TELEGRAM_CHAT_ID="987654321"
bash scripts/monitor.sh --url https://yoursite.com --alert telegram
```

### Webhook (Slack, Discord, custom)

```bash
export WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxxx"
bash scripts/monitor.sh --url https://yoursite.com --alert webhook
```

### Email (SMTP)

```bash
export SMTP_HOST="smtp.gmail.com" SMTP_PORT="587"
export SMTP_USER="you@gmail.com" SMTP_PASS="app-password"
export ALERT_EMAIL="ops@company.com"
bash scripts/monitor.sh --url https://yoursite.com --alert email
```

### Custom script

```bash
export ALERT_SCRIPT="/path/to/your/alert.sh"
bash scripts/monitor.sh --url https://yoursite.com --alert script
```

## Core Workflows

### Monitor single URL

```bash
bash scripts/monitor.sh --url https://example.com --interval 60 --timeout 10
```

### Monitor API with body validation

```bash
bash scripts/monitor.sh \
  --url https://api.service.com/health \
  --expect-body '"status":"ok"' \
  --interval 30
```

### SSL certificate expiry check

```bash
bash scripts/monitor.sh \
  --url https://example.com \
  --check-ssl \
  --ssl-warn 30 \
  --alert telegram
```

### Monitor multiple URLs (config file)

```bash
# Create config (see examples/monitors.json)
cat > monitors.json <<'EOF'
{
  "monitors": [
    {"url": "https://example.com", "interval": 300, "check_ssl": true, "alert": "telegram"},
    {"url": "https://api.example.com/health", "interval": 60, "expect_body": "\"status\":\"ok\"", "alert": "webhook"}
  ]
}
EOF

bash scripts/monitor.sh --config monitors.json
```

### Run as daemon

```bash
bash scripts/monitor.sh --url https://example.com --interval 300 --daemon
# Monitor daemon started (PID: 12345)
```

### Run via cron (one-shot checks)

```bash
# Add to crontab — check every 5 minutes
*/5 * * * * bash /path/to/scripts/check-once.sh https://example.com >> /var/log/uptime.log 2>&1
```

### OpenClaw cron integration

```
Use OpenClaw's cron tool to schedule check-once.sh runs.
The JSON output is machine-readable — your agent can parse it and take action (restart services, notify teams, create incidents).
```

## Advanced Options

| Flag | Default | Description |
|------|---------|-------------|
| `--url` | — | URL to monitor |
| `--config` | — | JSON config for multiple monitors |
| `--interval` | 300 | Seconds between checks |
| `--timeout` | 10 | Request timeout in seconds |
| `--expect-status` | 2 | Expected HTTP status prefix (2=2xx, 3=3xx) |
| `--expect-body` | — | String that must appear in response body |
| `--check-ssl` | false | Enable SSL expiry checking |
| `--ssl-warn` | 30 | Alert if SSL expires within N days |
| `--alert` | — | Alert type: telegram, webhook, email, script |
| `--threshold` | 2 | Consecutive failures before alerting |
| `--log` | — | Log file path (auto-rotates at 10k lines) |
| `--daemon` | false | Run in background |

## Smart Alert Features

- **Deduplication:** Only alerts once per incident (not every failed check)
- **Recovery alerts:** Notifies when service comes back up
- **Configurable threshold:** Wait for N consecutive failures before alerting (avoids false positives)
- **State persistence:** Tracks failure counts across checks in `~/.uptime-monitor/`

## Troubleshooting

### "command not found: jq"
```bash
sudo apt-get install jq  # Debian/Ubuntu
brew install jq           # macOS
```

### Telegram alerts not working
```bash
# Test bot token + chat ID
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=Test" | jq .ok
```

### False positives on slow networks
Increase timeout: `--timeout 20`
Increase threshold: `--threshold 3`

### SSL check fails
Ensure openssl is installed and the target uses HTTPS. Self-signed certs may produce warnings.
