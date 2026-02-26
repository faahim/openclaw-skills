---
name: apprise-notifications
description: >-
  Universal notification router — send alerts to 90+ services (Slack, Discord, Telegram, Email, Pushover, Gotify, ntfy, and more) from a single command.
categories: [communication, automation]
dependencies: [python3, pip]
---

# Apprise Notification Router

## What This Does

Send notifications to **90+ services** from a single unified interface. Slack, Discord, Telegram, Email (SMTP), Pushover, ntfy, Gotify, Microsoft Teams, Matrix, Rocket.Chat, IFTTT, webhooks, and dozens more — all with one command.

**Example:** "Send a deployment alert to Slack, email the team, and ping my phone via Pushover — all at once."

## Quick Start (3 minutes)

### 1. Install Apprise

```bash
pip3 install apprise
```

### 2. Send Your First Notification

```bash
# Send to a single service (Telegram example)
apprise -t "Hello" -b "Test notification from OpenClaw" \
  "tgram://BOT_TOKEN/CHAT_ID"

# Send to Slack
apprise -t "Deploy Complete" -b "v2.1.0 shipped to production" \
  "slack://TOKEN_A/TOKEN_B/TOKEN_C/#general"

# Send to multiple services at once
apprise -t "Alert" -b "Server CPU at 95%" \
  "tgram://BOT_TOKEN/CHAT_ID" \
  "slack://TOKEN_A/TOKEN_B/TOKEN_C/#ops" \
  "mailto://user:pass@gmail.com?to=admin@company.com"
```

### 3. Use a Config File for Persistent Targets

```bash
# Create config
cat > ~/.apprise.yml << 'EOF'
urls:
  - tgram://BOT_TOKEN/CHAT_ID:
      tag: personal
  - slack://TOKEN_A/TOKEN_B/TOKEN_C/#general:
      tag: team
  - mailto://user:pass@smtp.gmail.com?to=admin@company.com:
      tag: email
  - pover://USER_KEY@APP_TOKEN:
      tag: urgent
EOF

# Send to tagged groups
apprise -t "Deploy" -b "v2.1.0 live" --tag=team
apprise -t "URGENT" -b "DB connection pool exhausted" --tag=urgent,team
```

## Core Workflows

### Workflow 1: Multi-Channel Alert Pipeline

**Use case:** Send the same alert to multiple channels based on severity.

```bash
#!/bin/bash
# scripts/alert.sh — Severity-based multi-channel alerts

SEVERITY="${1:-info}"  # info, warning, critical
TITLE="$2"
BODY="$3"
CONFIG="${APPRISE_CONFIG:-$HOME/.apprise.yml}"

case "$SEVERITY" in
  info)
    apprise --config="$CONFIG" --tag=team -t "$TITLE" -b "$BODY"
    ;;
  warning)
    apprise --config="$CONFIG" --tag=team,email -t "⚠️ $TITLE" -b "$BODY"
    ;;
  critical)
    apprise --config="$CONFIG" --tag=team,email,urgent -t "🚨 $TITLE" -b "$BODY"
    ;;
esac
```

**Usage:**
```bash
bash scripts/alert.sh critical "DB Down" "Primary database unreachable since 14:32 UTC"
```

### Workflow 2: Pipe Command Output as Notification

**Use case:** Send output of any command as a notification.

```bash
# Disk usage alert
df -h / | apprise --config=~/.apprise.yml --tag=team -t "Disk Report" --input-format=text

# Send build log
make build 2>&1 | tail -20 | apprise --config=~/.apprise.yml --tag=team -t "Build Result"

# Cron job result
0 */6 * * * /usr/local/bin/backup.sh 2>&1 | apprise --config=~/.apprise.yml --tag=personal -t "Backup Report"
```

### Workflow 3: Watch a File and Alert on Changes

```bash
#!/bin/bash
# scripts/file-watcher.sh — Alert when a file changes

FILE="$1"
LAST_HASH=""

while true; do
  HASH=$(md5sum "$FILE" 2>/dev/null | awk '{print $1}')
  if [[ -n "$LAST_HASH" && "$HASH" != "$LAST_HASH" ]]; then
    apprise --config=~/.apprise.yml --tag=personal \
      -t "File Changed" -b "$FILE was modified at $(date)"
  fi
  LAST_HASH="$HASH"
  sleep 30
done
```

### Workflow 4: Health Check with Notifications

```bash
#!/bin/bash
# scripts/healthcheck.sh — Ping URLs, alert on failure

URLS=("https://myapp.com" "https://api.myapp.com/health")
TIMEOUT=10

for url in "${URLS[@]}"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url")
  if [[ $HTTP_CODE -lt 200 || $HTTP_CODE -ge 300 ]]; then
    apprise --config=~/.apprise.yml --tag=urgent \
      -t "🚨 Service Down" -b "$url returned $HTTP_CODE at $(date -u)"
  fi
done
```

## Configuration

### Config File Format (YAML)

```yaml
# ~/.apprise.yml
urls:
  # Telegram
  - tgram://BOT_TOKEN/CHAT_ID:
      tag: personal, alerts

  # Slack (webhook)
  - slack://TOKEN_A/TOKEN_B/TOKEN_C/#channel:
      tag: team

  # Discord (webhook)
  - discord://WEBHOOK_ID/WEBHOOK_TOKEN:
      tag: team

  # Email (Gmail)
  - mailto://yourname:app-password@smtp.gmail.com?to=recipient@example.com:
      tag: email

  # Pushover
  - pover://USER_KEY@APP_TOKEN:
      tag: urgent

  # ntfy (self-hosted or ntfy.sh)
  - ntfy://ntfy.sh/your-topic:
      tag: personal

  # Gotify
  - gotify://hostname/TOKEN:
      tag: alerts

  # Microsoft Teams
  - msteams://WEBHOOK_URL:
      tag: team

  # Matrix
  - matrix://USER:PASS@hostname/#room:
      tag: team

  # Generic webhook
  - json://your-webhook-url.com/endpoint:
      tag: custom
```

### Environment Variables

```bash
# Default config location
export APPRISE_CONFIG="$HOME/.apprise.yml"

# Or use URLs directly
export APPRISE_URLS="tgram://BOT/CHAT slack://A/B/C/#ch"
```

## Supported Services (Top 30)

| Service | URL Format |
|---------|-----------|
| Telegram | `tgram://BOT_TOKEN/CHAT_ID` |
| Slack | `slack://TOKEN_A/TOKEN_B/TOKEN_C/#channel` |
| Discord | `discord://WEBHOOK_ID/WEBHOOK_TOKEN` |
| Email (SMTP) | `mailto://user:pass@smtp.host?to=addr` |
| Pushover | `pover://USER_KEY@APP_TOKEN` |
| ntfy | `ntfy://ntfy.sh/topic` |
| Gotify | `gotify://hostname/TOKEN` |
| MS Teams | `msteams://WEBHOOK_URL` |
| Matrix | `matrix://user:pass@host/#room` |
| Rocket.Chat | `rocket://user:pass@hostname/#channel` |
| IFTTT | `ifttt://WEBHOOK_ID@EVENT` |
| Pushbullet | `pbul://ACCESS_TOKEN` |
| Join | `join://API_KEY/DEVICE` |
| Growl | `growl://hostname` |
| XMPP/Jabber | `xmpp://user:pass@host` |
| Twilio (SMS) | `twilio://SID:TOKEN@FROM/TO` |
| SNS (AWS) | `sns://ACCESS/SECRET/REGION/TOPIC` |
| Webhook (JSON) | `json://your-endpoint.com/path` |
| Webhook (XML) | `xml://your-endpoint.com/path` |
| Webhook (Form) | `form://your-endpoint.com/path` |

Full list: https://github.com/caronc/apprise/wiki

## Advanced Usage

### Send with Attachments

```bash
apprise --config=~/.apprise.yml --tag=team \
  -t "Screenshot" -b "Latest dashboard" \
  --attach=/path/to/screenshot.png
```

### Use from Python

```python
import apprise

ap = apprise.Apprise()
ap.add('tgram://BOT_TOKEN/CHAT_ID')
ap.add('slack://TOKEN_A/TOKEN_B/TOKEN_C/#general')

ap.notify(title="Deploy", body="v2.1.0 is live", notify_type=apprise.NotifyType.SUCCESS)
```

### Send HTML-Formatted Messages

```bash
apprise --config=~/.apprise.yml --tag=email \
  -t "Weekly Report" \
  -b "<h1>Metrics</h1><ul><li>Uptime: 99.9%</li><li>Errors: 3</li></ul>" \
  --input-format=html
```

### Dry Run (Test Without Sending)

```bash
# Validate your config
apprise --config=~/.apprise.yml --tag=team --dry-run \
  -t "Test" -b "This won't actually send"
```

## Troubleshooting

### Issue: "apprise: command not found"

```bash
pip3 install apprise
# Or if pip installs to user dir:
python3 -m pip install apprise
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: Gmail SMTP fails

Use an App Password (not your regular password):
1. Enable 2FA on Google account
2. Go to https://myaccount.google.com/apppasswords
3. Generate app password
4. Use that in the mailto:// URL

### Issue: Telegram bot not sending

1. Create bot via @BotFather
2. Get chat ID: `curl https://api.telegram.org/bot<TOKEN>/getUpdates`
3. Ensure bot is added to the chat/group

### Issue: Rate limiting

Add delays between bulk sends:
```bash
for target in team email urgent; do
  apprise --config=~/.apprise.yml --tag=$target -t "$TITLE" -b "$BODY"
  sleep 2
done
```

## Key Principles

1. **One config, many targets** — Define once, notify everywhere
2. **Tag-based routing** — Group services by purpose (team, urgent, personal)
3. **Pipe-friendly** — Works with stdin for scripting
4. **Fail gracefully** — Failed targets don't block others
5. **No vendor lock-in** — Switch services by editing one config line
