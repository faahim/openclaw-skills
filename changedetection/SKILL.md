---
name: changedetection
description: >-
  Monitor websites for content changes and get instant alerts when pages update.
categories: [automation, analytics]
dependencies: [docker, curl, jq]
---

# Changedetection — Website Change Monitor

## What This Does

Deploys and manages [changedetection.io](https://github.com/dgtlmoon/changedetection.io) — a self-hosted tool that watches web pages for content changes and sends notifications when something updates. Track pricing pages, job boards, government notices, competitor sites, or any URL where content matters.

**Example:** "Watch 50 URLs, get a Telegram alert with a diff whenever any page changes."

## Quick Start (5 minutes)

### 1. Install & Start Server

```bash
# Using Docker (recommended)
bash scripts/install.sh

# This starts changedetection.io on port 5000
# Access UI at http://localhost:5000
```

### 2. Add Your First Watch

```bash
# Watch a URL for changes (check every 30 minutes)
bash scripts/watch.sh add \
  --url "https://example.com/pricing" \
  --interval 1800 \
  --tag "pricing"

# Output:
# ✅ Added watch: https://example.com/pricing (every 30m, tag: pricing)
# 🔑 Watch UUID: a1b2c3d4-...
```

### 3. Configure Alerts

```bash
# Set up Telegram notifications
bash scripts/notify.sh setup-telegram \
  --bot-token "$TELEGRAM_BOT_TOKEN" \
  --chat-id "$TELEGRAM_CHAT_ID"

# Or use any apprise-compatible URL
bash scripts/notify.sh add \
  --url "slack://TokenA/TokenB/TokenC"
```

## Core Workflows

### Workflow 1: Monitor a Pricing Page

```bash
bash scripts/watch.sh add \
  --url "https://competitor.com/pricing" \
  --interval 3600 \
  --tag "competitor" \
  --css-filter ".pricing-table"
```

When the pricing section changes, you get an alert with the exact diff.

### Workflow 2: Track Job Listings

```bash
bash scripts/watch.sh add \
  --url "https://company.com/careers" \
  --interval 1800 \
  --tag "jobs" \
  --css-filter ".job-listings" \
  --title "Company X Jobs"
```

### Workflow 3: Monitor Government/Legal Notices

```bash
bash scripts/watch.sh add \
  --url "https://gov.site/notices" \
  --interval 7200 \
  --tag "legal" \
  --ignore-text "Last updated:"
```

### Workflow 4: Watch Multiple URLs from File

```bash
# Create a URLs file
cat > urls.txt << 'EOF'
https://example.com/pricing|3600|pricing
https://news.site.com/feed|1800|news
https://competitor.com/features|7200|competitor
EOF

# Bulk import
bash scripts/watch.sh bulk-add --file urls.txt
```

### Workflow 5: Get Change History

```bash
# List all watches
bash scripts/watch.sh list

# Get recent changes for a specific watch
bash scripts/watch.sh history --uuid "a1b2c3d4-..."

# Export all change snapshots
bash scripts/watch.sh export --tag "pricing" --format json
```

### Workflow 6: Pause/Resume Monitoring

```bash
# Pause a watch
bash scripts/watch.sh pause --uuid "a1b2c3d4-..."

# Resume
bash scripts/watch.sh resume --uuid "a1b2c3d4-..."

# Pause all watches with a tag
bash scripts/watch.sh pause --tag "competitor"
```

## Configuration

### Environment Variables

```bash
# Changedetection.io server
export CHANGEDETECTION_URL="http://localhost:5000"
export CHANGEDETECTION_API_KEY=""  # Set in UI: Settings → API

# Telegram notifications
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Data directory (persistent storage)
export CHANGEDETECTION_DATA="/opt/changedetection/data"
```

### Docker Compose (Advanced)

```yaml
# docker-compose.yml
version: '3'
services:
  changedetection:
    image: ghcr.io/dgtlmoon/changedetection.io
    container_name: changedetection
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - ${CHANGEDETECTION_DATA:-./data}:/datastore
    environment:
      - PLAYWRIGHT_DRIVER_URL=ws://playwright-chrome:3000
      - BASE_URL=http://localhost:5000

  # Optional: browser for JavaScript-rendered pages
  playwright-chrome:
    image: browserless/chrome
    restart: unless-stopped
    environment:
      - SCREEN_WIDTH=1920
      - SCREEN_HEIGHT=1080
```

## Advanced Usage

### CSS/XPath Selectors

Only watch specific parts of a page:

```bash
# CSS selector — watch only the price element
bash scripts/watch.sh add \
  --url "https://shop.com/product" \
  --css-filter ".product-price"

# XPath — watch a specific table
bash scripts/watch.sh add \
  --url "https://data.gov/stats" \
  --xpath "//table[@id='main-stats']"
```

### Ignore Noise

Filter out dynamic content that changes every load:

```bash
bash scripts/watch.sh add \
  --url "https://news.site.com" \
  --ignore-text "Advertisement" \
  --ignore-text "Last refreshed:" \
  --ignore-regex "Session ID: [a-f0-9]+"
```

### JavaScript-Rendered Pages

For SPAs and JS-heavy sites, use the Playwright browser:

```bash
# Ensure playwright-chrome is running (see docker-compose above)
bash scripts/watch.sh add \
  --url "https://spa-app.com/dashboard" \
  --browser \
  --wait 5  # Wait 5 seconds for JS to render
```

### API Direct Access

```bash
# List all watches
curl -s "$CHANGEDETECTION_URL/api/v1/watch" \
  -H "x-api-key: $CHANGEDETECTION_API_KEY" | jq .

# Add a watch via API
curl -s -X POST "$CHANGEDETECTION_URL/api/v1/watch" \
  -H "x-api-key: $CHANGEDETECTION_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "time_between_check": {"minutes": 30}}'

# Trigger immediate recheck
curl -s -X POST "$CHANGEDETECTION_URL/api/v1/watch/<uuid>/recheck" \
  -H "x-api-key: $CHANGEDETECTION_API_KEY"
```

### Run as OpenClaw Cron

```bash
# Check for changes every hour and report
*/60 * * * * bash /path/to/scripts/report.sh --format summary
```

## Troubleshooting

### Issue: Docker not installed

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### Issue: No changes detected on JS-heavy site

Add the Playwright browser container (see Docker Compose above) and use `--browser` flag.

### Issue: Too many false positives

Use CSS/XPath selectors to narrow what you're watching, and `--ignore-text` / `--ignore-regex` to filter noise.

### Issue: Notifications not arriving

```bash
# Test notification setup
bash scripts/notify.sh test

# Check logs
docker logs changedetection 2>&1 | tail -20
```

## Key Principles

1. **Self-hosted** — Your data stays on your server, no SaaS dependency
2. **Visual diffs** — See exactly what changed, highlighted
3. **Smart filtering** — CSS/XPath selectors + ignore patterns reduce noise
4. **Multi-channel alerts** — Telegram, Slack, Discord, email, webhooks (90+ via Apprise)
5. **JS support** — Playwright browser handles SPAs and dynamic content

## Dependencies

- `docker` + `docker-compose` (for server)
- `curl` (for API calls)
- `jq` (for JSON parsing)
- Optional: `playwright-chrome` container (for JS-rendered pages)
