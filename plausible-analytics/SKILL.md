---
name: plausible-analytics
description: >-
  Deploy and manage self-hosted Plausible Analytics — privacy-friendly, cookie-free web analytics with no Google dependency.
categories: [analytics, automation]
dependencies: [docker, docker-compose, curl, openssl]
---

# Plausible Analytics Manager

## What This Does

Deploy self-hosted Plausible Analytics in minutes. Get privacy-friendly, GDPR-compliant web analytics without Google Analytics, cookies, or tracking consent banners. Lightweight (<1KB script), real-time dashboard, and you own all your data.

**Example:** "Deploy Plausible on my VPS, add tracking to 3 sites, get weekly traffic reports via Telegram."

## Quick Start (10 minutes)

### 1. Check Prerequisites

```bash
# Verify Docker and Docker Compose are installed
bash scripts/install.sh --check

# If missing, install them:
bash scripts/install.sh --install-deps
```

### 2. Deploy Plausible

```bash
# Interactive setup — prompts for domain, email, etc.
bash scripts/run.sh setup

# Or non-interactive:
bash scripts/run.sh setup \
  --domain analytics.yourdomain.com \
  --admin-email admin@yourdomain.com \
  --admin-name "Your Name" \
  --admin-password "SecurePass123!"
```

**Output:**
```
✅ Plausible Analytics deployed!
   Dashboard: https://analytics.yourdomain.com
   Admin: admin@yourdomain.com
   Tracking script: <script defer data-domain="yourdomain.com" src="https://analytics.yourdomain.com/js/script.js"></script>
```

### 3. Add Tracking to Your Site

```html
<!-- Add this before </head> on every page -->
<script defer data-domain="yourdomain.com" src="https://analytics.yourdomain.com/js/script.js"></script>
```

## Core Workflows

### Workflow 1: Deploy Fresh Instance

**Use case:** Set up Plausible on a new server

```bash
bash scripts/run.sh setup \
  --domain analytics.example.com \
  --admin-email you@example.com \
  --admin-name "Admin" \
  --admin-password "$(openssl rand -base64 16)"
```

This will:
1. Generate `docker-compose.yml` and `plausible-conf.env`
2. Generate a secret key base
3. Pull Docker images
4. Start containers (Plausible + PostgreSQL + ClickHouse)
5. Create admin account
6. Print dashboard URL and tracking snippet

### Workflow 2: Add a New Site

**Use case:** Start tracking a new domain

```bash
bash scripts/run.sh add-site --domain newsite.com
```

**Output:**
```
✅ Site added: newsite.com
   Tracking snippet:
   <script defer data-domain="newsite.com" src="https://analytics.example.com/js/script.js"></script>

   Enhanced tracking (outbound links + file downloads):
   <script defer data-domain="newsite.com" src="https://analytics.example.com/js/script.tagged-events.outbound-links.file-downloads.js"></script>
```

### Workflow 3: Get Traffic Stats

**Use case:** Quick stats from the command line

```bash
# Today's stats
bash scripts/run.sh stats --domain yourdomain.com

# Last 7 days
bash scripts/run.sh stats --domain yourdomain.com --period 7d

# Last 30 days with breakdown
bash scripts/run.sh stats --domain yourdomain.com --period 30d --breakdown
```

**Output:**
```
📊 yourdomain.com — Last 7 days

  Visitors:    1,247
  Pageviews:   3,891
  Bounce Rate: 42%
  Avg. Time:   2m 34s

  Top Pages:
    /                    → 892 views
    /blog/new-post       → 445 views
    /pricing             → 234 views

  Top Sources:
    Google               → 456 visitors
    Twitter              → 234 visitors
    Direct               → 189 visitors
```

### Workflow 4: Weekly Traffic Report

**Use case:** Automated weekly summary via Telegram/email

```bash
# Set up weekly report (runs every Monday 9am)
bash scripts/run.sh schedule-report \
  --domain yourdomain.com \
  --frequency weekly \
  --notify telegram \
  --chat-id "$TELEGRAM_CHAT_ID"
```

### Workflow 5: Backup Analytics Data

**Use case:** Backup ClickHouse + Postgres data

```bash
# Create backup
bash scripts/run.sh backup --output /backups/plausible-$(date +%Y%m%d).tar.gz

# Restore from backup
bash scripts/run.sh restore --input /backups/plausible-20260227.tar.gz
```

### Workflow 6: Update Plausible

**Use case:** Upgrade to latest version

```bash
bash scripts/run.sh update

# Output:
# 📦 Current: v2.1.4
# 📦 Latest:  v2.2.0
# ⏳ Pulling new images...
# ⏳ Recreating containers...
# ✅ Updated to v2.2.0 — Dashboard: https://analytics.example.com
```

## Configuration

### Environment Variables

```bash
# Required for Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Plausible API (auto-generated during setup)
export PLAUSIBLE_URL="https://analytics.yourdomain.com"
export PLAUSIBLE_API_KEY="<your-api-key>"
```

### Config File

```bash
# Generated at ~/.plausible/config.env during setup
cat ~/.plausible/config.env
```

```env
PLAUSIBLE_URL=https://analytics.yourdomain.com
PLAUSIBLE_API_KEY=your-api-key
PLAUSIBLE_INSTALL_DIR=/opt/plausible
ADMIN_EMAIL=admin@yourdomain.com
```

### Docker Compose Override

```bash
# Custom settings (memory limits, ports, etc.)
cat ~/.plausible/docker-compose.override.yml
```

```yaml
services:
  plausible:
    deploy:
      resources:
        limits:
          memory: 512M
  clickhouse:
    deploy:
      resources:
        limits:
          memory: 1G
```

## Advanced Usage

### Custom Events Tracking

```html
<!-- Track button clicks -->
<button onclick="plausible('Signup')">Sign Up</button>

<!-- Track with custom properties -->
<script>
plausible('Purchase', {props: {plan: 'Pro', price: '49'}});
</script>
```

### API Access

```bash
# Get realtime visitors
curl -s "$PLAUSIBLE_URL/api/v1/stats/realtime/visitors?site_id=yourdomain.com" \
  -H "Authorization: Bearer $PLAUSIBLE_API_KEY"

# Get aggregate stats
curl -s "$PLAUSIBLE_URL/api/v1/stats/aggregate?site_id=yourdomain.com&period=30d&metrics=visitors,pageviews,bounce_rate" \
  -H "Authorization: Bearer $PLAUSIBLE_API_KEY"
```

### Reverse Proxy with Nginx

```bash
# Generate Nginx config for Plausible
bash scripts/run.sh nginx-config --domain analytics.yourdomain.com

# Output saved to /etc/nginx/sites-available/plausible
```

### Import from Google Analytics

```bash
bash scripts/run.sh import-ga \
  --domain yourdomain.com \
  --ga-property UA-12345678-1
```

## Troubleshooting

### Issue: "Connection refused" on dashboard

**Fix:**
```bash
# Check if containers are running
bash scripts/run.sh status

# Restart if needed
bash scripts/run.sh restart

# Check logs
bash scripts/run.sh logs --tail 50
```

### Issue: No data showing up

**Check:**
1. Tracking script is on the page: View source, search for `plausible`
2. Domain matches exactly: `yourdomain.com` not `www.yourdomain.com`
3. Ad blockers aren't blocking: Test in incognito
4. Proxy the script for ad-blocker bypass:
```bash
bash scripts/run.sh proxy-script --domain yourdomain.com
```

### Issue: High memory usage

**Fix:**
```bash
# ClickHouse can be hungry — limit it
bash scripts/run.sh tune --clickhouse-memory 512M --plausible-memory 256M
```

### Issue: SSL certificate errors

**Fix:**
```bash
# Use Let's Encrypt (requires port 80/443 open)
bash scripts/run.sh ssl --domain analytics.yourdomain.com

# Or use Cloudflare proxy (set DNS to orange cloud)
```

## System Requirements

- **OS:** Linux (Ubuntu 20.04+, Debian 11+, or similar)
- **RAM:** 2GB minimum (4GB recommended)
- **Disk:** 10GB minimum (scales with traffic)
- **Docker:** 20.10+ with Docker Compose v2
- **Ports:** 80, 443 (or behind reverse proxy)

## Why Plausible Over Google Analytics?

| Feature | Plausible | Google Analytics |
|---------|-----------|-----------------|
| Privacy | ✅ No cookies, GDPR-compliant | ❌ Requires consent banner |
| Script size | 1KB | 45KB |
| Data ownership | ✅ Self-hosted, you own it | ❌ Google owns it |
| Setup time | 10 min | 30+ min |
| Pricing | Free (self-hosted) | Free (you're the product) |
| Dashboard | Simple, one page | Complex, 50+ reports |

## Dependencies

- `docker` (20.10+)
- `docker-compose` (v2+)
- `curl` (HTTP requests)
- `openssl` (key generation)
- `jq` (JSON parsing for stats)
- Optional: `nginx` (reverse proxy)
