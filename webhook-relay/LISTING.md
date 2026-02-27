# Listing Copy: Webhook Relay

## Metadata
- **Type:** Skill
- **Name:** webhook-relay
- **Display Name:** Webhook Relay
- **Categories:** [communication, automation]
- **Price:** $10
- **Dependencies:** [python3]

## Tagline
Receive webhooks and route them to Telegram, Discord, Slack, email, or any URL

## Description

Webhooks are everywhere — GitHub, Stripe, monitoring tools, CI/CD — but routing them to where you actually need them is a pain. You end up writing custom scripts or paying for services like Zapier just to get a Telegram ping when someone pushes to your repo.

Webhook Relay runs a lightweight Python HTTP server (zero pip dependencies) that receives incoming webhooks and fans them out to multiple destinations. One endpoint, unlimited routes. Configure it with a simple YAML file: match by path, headers, or JSON fields, then send to Telegram, Discord, Slack, email, custom URLs, or log files.

**What it does:**
- 🔀 Route one webhook to multiple destinations simultaneously
- 🎯 Filter by path, headers, or JSON field values
- 📱 Built-in Telegram, Discord, and email senders
- 🔒 HMAC signature verification (GitHub, Stripe compatible)
- 📝 Template engine with `${body.field}` interpolation
- ⚡ Zero external dependencies — Python 3.8+ stdlib only
- 🔧 Runs as systemd service with auto-restart

Perfect for developers and sysadmins who want webhook routing without external services or monthly fees.

## Quick Start Preview

```bash
# Start the relay
python3 relay.py

# Send a test webhook
curl -X POST http://localhost:9876/hook -d '{"message":"Hello!"}'
# → Forwarded to Telegram, Discord, log file, etc.
```

## Core Capabilities

1. Multi-target fan-out — One webhook → Telegram + Discord + Slack + email
2. Path-based routing — /github, /stripe, /alerts → different handlers
3. JSON field filtering — Only forward PRs, not all GitHub events
4. Header matching — Route by X-GitHub-Event, Content-Type, etc.
5. Template engine — ${body.repository.full_name} interpolation with fallbacks
6. Signature verification — HMAC-SHA256 for GitHub, Stripe webhook security
7. Systemd service — Install as daemon with auto-restart on failure
8. Health endpoint — GET /health for monitoring the relay itself
9. Environment variables — ${TELEGRAM_BOT_TOKEN} in config, no hardcoded secrets
10. Zero dependencies — Python stdlib only, runs anywhere Python 3.8+ exists
