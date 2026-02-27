---
name: webhook-relay
description: >-
  Receive webhooks on a local port and route them to multiple destinations — Telegram, Discord, Slack, email, or any URL.
categories: [communication, automation]
dependencies: [python3, curl]
---

# Webhook Relay

## What This Does

Runs a lightweight HTTP server that receives incoming webhooks and forwards them to multiple configured destinations. Route GitHub push events to Telegram, Stripe payment webhooks to Discord, or any webhook to any combination of targets.

**Example:** GitHub pushes → Telegram + Discord. Stripe payments → email + Slack. One endpoint, unlimited routes.

## Quick Start (3 minutes)

### 1. Install

```bash
# Create config directory
mkdir -p ~/.config/webhook-relay

# Copy the relay script
cp scripts/relay.py ~/.config/webhook-relay/relay.py
chmod +x ~/.config/webhook-relay/relay.py

# Copy default config
cp scripts/config.yaml ~/.config/webhook-relay/config.yaml
```

### 2. Configure Routes

Edit `~/.config/webhook-relay/config.yaml`:

```yaml
server:
  host: 0.0.0.0
  port: 9876
  secret: ""  # Optional: validate X-Hub-Signature-256 (GitHub, etc.)

routes:
  - name: github-to-telegram
    match:
      path: /github
      # Optional: filter by JSON field
      # field: "$.action"
      # value: "opened"
    targets:
      - type: telegram
        bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: "${TELEGRAM_CHAT_ID}"
        template: "🔔 GitHub: ${summary}"
      - type: url
        url: https://hooks.slack.com/services/XXX/YYY/ZZZ
        method: POST

  - name: catch-all
    match:
      path: /hook
    targets:
      - type: log
        file: /var/log/webhook-relay.log
```

### 3. Run

```bash
# Start the relay
python3 ~/.config/webhook-relay/relay.py

# Or run in background
nohup python3 ~/.config/webhook-relay/relay.py >> /tmp/webhook-relay.log 2>&1 &

# Test it
curl -X POST http://localhost:9876/github \
  -H "Content-Type: application/json" \
  -d '{"action":"push","repository":{"full_name":"user/repo"},"sender":{"login":"alice"}}'
```

## Core Workflows

### Workflow 1: GitHub → Telegram

**Use case:** Get Telegram notifications for repo events

```yaml
# In config.yaml
routes:
  - name: github-events
    match:
      path: /github
    targets:
      - type: telegram
        bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: "${TELEGRAM_CHAT_ID}"
        template: |
          📦 *${headers.X-GitHub-Event}* on ${body.repository.full_name}
          By: ${body.sender.login}
          ${body.head_commit.message|body.action|'event received'}
```

Set your GitHub webhook URL to `http://your-server:9876/github`.

### Workflow 2: Stripe → Discord

**Use case:** Payment notifications in Discord

```yaml
routes:
  - name: stripe-payments
    match:
      path: /stripe
      field: "$.type"
      value: "payment_intent.succeeded"
    targets:
      - type: discord
        webhook_url: "https://discord.com/api/webhooks/XXX/YYY"
        template: "💰 Payment received: $${body.data.object.amount_received / 100}"
```

### Workflow 3: Multi-Target Fan-Out

**Use case:** Same webhook → multiple destinations

```yaml
routes:
  - name: alerts
    match:
      path: /alert
    targets:
      - type: telegram
        bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: "${TELEGRAM_CHAT_ID}"
        template: "🚨 ${body.message}"
      - type: discord
        webhook_url: "${DISCORD_WEBHOOK_URL}"
        template: "🚨 ${body.message}"
      - type: url
        url: https://hooks.slack.com/services/XXX
        method: POST
        headers:
          Content-Type: application/json
        body: '{"text": "🚨 Alert: ${body.message}"}'
      - type: log
        file: /var/log/alerts.log
```

### Workflow 4: Filtered Routes

**Use case:** Only forward specific events

```yaml
routes:
  - name: pr-opened
    match:
      path: /github
      header: "X-GitHub-Event"
      header_value: "pull_request"
      field: "$.action"
      value: "opened"
    targets:
      - type: telegram
        bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: "${TELEGRAM_CHAT_ID}"
        template: "🔀 New PR: ${body.pull_request.title} by ${body.pull_request.user.login}"
```

## Run as Systemd Service

```bash
# Create service file
sudo bash scripts/install-service.sh

# Manage
sudo systemctl start webhook-relay
sudo systemctl enable webhook-relay    # Auto-start on boot
sudo systemctl status webhook-relay
journalctl -u webhook-relay -f         # View logs
```

## Target Types

### Telegram
```yaml
- type: telegram
  bot_token: "123456:ABC..."   # Or ${TELEGRAM_BOT_TOKEN}
  chat_id: "986606208"         # Or ${TELEGRAM_CHAT_ID}
  template: "Message text"     # Supports ${body.field} interpolation
  parse_mode: Markdown         # Optional: Markdown or HTML
```

### Discord
```yaml
- type: discord
  webhook_url: "https://discord.com/api/webhooks/..."
  template: "Message text"
```

### Slack
```yaml
- type: url
  url: "https://hooks.slack.com/services/..."
  method: POST
  headers:
    Content-Type: application/json
  body: '{"text": "${body.message}"}'
```

### Email (via SMTP)
```yaml
- type: email
  smtp_host: smtp.gmail.com
  smtp_port: 587
  smtp_user: "${SMTP_USER}"
  smtp_pass: "${SMTP_PASS}"
  from: "relay@example.com"
  to: "admin@example.com"
  subject: "Webhook Alert"
  template: "${body.message}"
```

### Custom URL
```yaml
- type: url
  url: "https://any-endpoint.com/webhook"
  method: POST
  headers:
    Authorization: "Bearer ${API_TOKEN}"
    Content-Type: application/json
  body: '${raw}'  # Forward raw payload
```

### Log File
```yaml
- type: log
  file: /var/log/webhook-relay.log  # Append JSON lines
```

## Environment Variables

```bash
# Telegram
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

# Discord
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."

# Email
export SMTP_USER="your-email@gmail.com"
export SMTP_PASS="your-app-password"
export SMTP_HOST="smtp.gmail.com"

# Custom
export API_TOKEN="your-api-key"
```

## Signature Verification

Verify webhook authenticity (GitHub, Stripe, etc.):

```yaml
server:
  secret: "your-webhook-secret"
  signature_header: "X-Hub-Signature-256"  # GitHub
  # signature_header: "Stripe-Signature"   # Stripe
```

## Troubleshooting

### Port already in use
```bash
# Find what's using the port
lsof -i :9876
# Kill it or change port in config.yaml
```

### Telegram bot not sending
1. Verify token: `curl https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe`
2. Verify chat_id: Send a message to bot, check `getUpdates`
3. Check logs: `journalctl -u webhook-relay -f`

### Webhooks not arriving
1. Check firewall: `sudo ufw allow 9876/tcp`
2. Test locally: `curl -X POST http://localhost:9876/hook -d '{"test":true}'`
3. Check route matching: Path must match exactly

## Dependencies

- `python3` (3.8+) — ships with most Linux distros
- `curl` — for testing
- No pip packages required (uses stdlib only)
