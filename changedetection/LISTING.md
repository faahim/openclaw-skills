# Listing Copy: Changedetection

## Metadata
- **Type:** Skill
- **Name:** changedetection
- **Display Name:** Website Change Monitor
- **Categories:** [automation, analytics]
- **Price:** $12
- **Icon:** 🔍
- **Dependencies:** [docker, curl, jq]

## Tagline
Monitor websites for content changes — Get alerts when pages update

## Description

Manually checking websites for updates is tedious and unreliable. Whether it's competitor pricing, job listings, government notices, or product availability — you need to know the moment something changes.

Website Change Monitor deploys and manages changedetection.io — a powerful self-hosted tool that watches web pages and alerts you when content changes. It monitors any URL, shows you the exact diff, and sends notifications via Telegram, Slack, Discord, email, or 90+ other channels.

**What it does:**
- 🔍 Watch unlimited URLs for content changes
- 🎯 CSS/XPath selectors to monitor specific page sections
- 📱 Instant alerts via Telegram, Slack, email, webhooks (90+ channels)
- 🌐 JavaScript rendering support for SPAs via headless browser
- 📊 Visual diffs showing exactly what changed
- 🏷️ Tag-based organization for managing many watches
- ⏸️ Pause/resume individual watches or groups
- 📦 Bulk import URLs from file
- 🔄 On-demand rechecks via CLI or API
- 🏠 Self-hosted — your data, your server, no monthly fees

## Quick Start Preview

```bash
# Install (Docker)
bash scripts/install.sh

# Watch a URL
bash scripts/watch.sh add --url "https://competitor.com/pricing" --interval 3600

# Set up Telegram alerts
bash scripts/notify.sh setup-telegram --bot-token "$TOKEN" --chat-id "$CHAT_ID"
```

## Installation Time
**5 minutes** — Docker pull + start
