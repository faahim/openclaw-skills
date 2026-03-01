---
name: umami-analytics
description: >-
  Install and manage Umami — a privacy-focused, self-hosted web analytics alternative to Google Analytics. No cookies, GDPR-compliant, lightweight.
categories: [analytics, automation]
dependencies: [docker, docker-compose, curl, jq]
---

# Umami Analytics Manager

## What This Does

Deploy and manage [Umami](https://umami.is), a self-hosted web analytics platform that respects user privacy. No cookies, no tracking scripts that slow your site, fully GDPR/CCPA compliant — and you own all the data.

**Example:** "Deploy Umami on my server, add tracking to 3 websites, check daily stats, and get weekly traffic summaries via Telegram."

## Quick Start (10 minutes)

### 1. Install Dependencies

```bash
# Check Docker is installed
bash scripts/install.sh check

# Install Docker if missing (Ubuntu/Debian)
bash scripts/install.sh docker
```

### 2. Deploy Umami

```bash
# Deploy with default settings (PostgreSQL backend, port 3000)
bash scripts/run.sh deploy

# Deploy on custom port
bash scripts/run.sh deploy --port 8080

# Deploy with custom domain (for reverse proxy)
bash scripts/run.sh deploy --domain analytics.yoursite.com --port 3000
```

**Default credentials:** admin / umami (change immediately!)

### 3. Add Your First Website

```bash
# Add a website to track
bash scripts/run.sh add-site --name "My Blog" --domain "myblog.com"

# Output:
# ✅ Website added: My Blog (myblog.com)
# 📊 Tracking script:
# <script async src="https://your-umami:3000/script.js" data-website-id="abc123"></script>
```

## Core Workflows

### Workflow 1: Full Deployment

**Use case:** Fresh install on a VPS

```bash
# 1. Deploy Umami + PostgreSQL
bash scripts/run.sh deploy --port 3000

# 2. Change default password
bash scripts/run.sh change-password --user admin --new-password "YourSecurePass123!"

# 3. Add websites
bash scripts/run.sh add-site --name "Main Site" --domain "example.com"
bash scripts/run.sh add-site --name "Blog" --domain "blog.example.com"

# 4. Get tracking scripts
bash scripts/run.sh get-script --domain "example.com"
```

### Workflow 2: Check Stats

**Use case:** Quick traffic overview

```bash
# Today's stats for all sites
bash scripts/run.sh stats

# Output:
# 📊 Umami Stats — 2026-03-01
# ┌─────────────┬──────────┬───────┬──────────┬─────────┐
# │ Site        │ Visitors │ Views │ Bounced  │ Avg Time│
# ├─────────────┼──────────┼───────┼──────────┼─────────┤
# │ example.com │     342  │  891  │   42.1%  │  2m 15s │
# │ blog.ex.com │     128  │  367  │   38.5%  │  3m 42s │
# └─────────────┴──────────┴───────┴──────────┴─────────┘

# Stats for specific site and date range
bash scripts/run.sh stats --domain "example.com" --from "2026-02-01" --to "2026-02-28"

# Top pages
bash scripts/run.sh top-pages --domain "example.com" --limit 10

# Top referrers
bash scripts/run.sh top-referrers --domain "example.com"
```

### Workflow 3: Backup & Restore

**Use case:** Protect your analytics data

```bash
# Backup database
bash scripts/run.sh backup --output /backups/umami-$(date +%Y%m%d).sql.gz

# Restore from backup
bash scripts/run.sh restore --input /backups/umami-20260301.sql.gz

# Schedule daily backup (adds crontab entry)
bash scripts/run.sh backup --schedule "0 2 * * *" --output /backups/umami-daily.sql.gz
```

### Workflow 4: Update Umami

**Use case:** Keep Umami up to date

```bash
# Check for updates
bash scripts/run.sh check-update

# Update to latest version
bash scripts/run.sh update

# Update to specific version
bash scripts/run.sh update --version 2.15.0
```

### Workflow 5: Weekly Report via Telegram

**Use case:** Automated traffic digest

```bash
# Generate and send weekly report
bash scripts/run.sh report --period week --telegram

# Requires environment variables:
# TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID
```

## Configuration

### Environment Variables

```bash
# Umami server
export UMAMI_URL="http://localhost:3000"
export UMAMI_USER="admin"
export UMAMI_PASSWORD="your-password"

# Docker settings
export UMAMI_PORT=3000
export UMAMI_DB_PASSWORD="secure-db-password"

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="bot123:ABC..."
export TELEGRAM_CHAT_ID="123456"
```

### Docker Compose Override

Edit `~/.umami/docker-compose.override.yml` for custom settings:

```yaml
services:
  umami:
    environment:
      - TRACKER_SCRIPT_NAME=custom-script  # Rename script to avoid blockers
      - COLLECT_API_ENDPOINT=/api/custom    # Custom API endpoint
    deploy:
      resources:
        limits:
          memory: 512M
```

## Advanced Usage

### Custom Tracking Script Name

Ad blockers target `script.js`. Rename it:

```bash
bash scripts/run.sh config --tracker-name "stats.js"
# Now use: <script async src="https://analytics.site.com/stats.js" data-website-id="..."></script>
```

### Share Public Dashboard

```bash
# Create a shareable link for a site
bash scripts/run.sh share --domain "example.com"
# Output: https://your-umami:3000/share/abc123
```

### API Access

```bash
# Get auth token
bash scripts/run.sh token

# Use with Umami API directly
curl -H "Authorization: Bearer $TOKEN" \
  "$UMAMI_URL/api/websites/abc123/stats?startAt=1709251200000&endAt=1709337600000"
```

### Run Behind Nginx/Caddy

```bash
# Generate Nginx config
bash scripts/run.sh proxy-config --type nginx --domain analytics.yoursite.com

# Generate Caddy config
bash scripts/run.sh proxy-config --type caddy --domain analytics.yoursite.com
```

## Troubleshooting

### Issue: "Cannot connect to Umami"

**Fix:**
```bash
# Check if containers are running
bash scripts/run.sh status

# View logs
bash scripts/run.sh logs

# Restart
bash scripts/run.sh restart
```

### Issue: "Database connection failed"

**Fix:**
```bash
# Check PostgreSQL container
docker logs umami-db

# Reset database password
bash scripts/run.sh reset-db-password
```

### Issue: Tracking script blocked by ad blockers

**Fix:** Rename the script and proxy through your own domain:
```bash
bash scripts/run.sh config --tracker-name "my-analytics.js"
```

### Issue: High memory usage

**Fix:** Set resource limits in docker-compose override:
```yaml
deploy:
  resources:
    limits:
      memory: 256M
```

## Dependencies

- `docker` (20.10+) — Container runtime
- `docker-compose` (v2+) — Container orchestration
- `curl` — API calls
- `jq` — JSON parsing
- Optional: `gzip` — Backup compression
