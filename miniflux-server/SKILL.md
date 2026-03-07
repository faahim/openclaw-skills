---
name: miniflux-server
description: >-
  Install and manage Miniflux, a minimalist self-hosted RSS reader with a clean UI and powerful API.
categories: [communication, home]
dependencies: [docker, curl, jq]
---

# Miniflux RSS Server Manager

## What This Does

Miniflux is a minimalist, opinionated RSS reader that's fast, lightweight, and self-hosted. This skill installs and manages a Miniflux instance using Docker, with PostgreSQL as the backend. No tracking, no ads, no bloat — just your feeds.

**Example:** "Deploy Miniflux on your server, import 50 RSS feeds from OPML, and access a clean reading experience at https://rss.yourdomain.com"

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ensure Docker and Docker Compose are installed
which docker docker-compose || which docker compose
# If not installed, use the docker-manager skill or:
curl -fsSL https://get.docker.com | sh
```

### 2. Deploy Miniflux

```bash
# Create project directory
mkdir -p ~/miniflux && cd ~/miniflux

# Generate secure passwords
DB_PASS=$(openssl rand -hex 16)
ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=')

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSE'
services:
  miniflux:
    image: miniflux/miniflux:latest
    container_name: miniflux
    restart: unless-stopped
    ports:
      - "8070:8080"
    environment:
      - DATABASE_URL=postgres://miniflux:${DB_PASSWORD}@db/miniflux?sslmode=disable
      - RUN_MIGRATIONS=1
      - CREATE_ADMIN=1
      - ADMIN_USERNAME=${ADMIN_USER}
      - ADMIN_PASSWORD=${ADMIN_PASS}
      - BASE_URL=${BASE_URL:-http://localhost:8070}
      - POLLING_FREQUENCY=15
      - BATCH_SIZE=50
      - POLLING_PARSING_ERROR_LIMIT=0
      - CLEANUP_ARCHIVE_UNREAD_DAYS=-1
      - CLEANUP_ARCHIVE_READ_DAYS=60
      - METRICS_COLLECTOR=1
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthcheck"]
      interval: 30s
      timeout: 5s
      retries: 3

  db:
    image: postgres:16-alpine
    container_name: miniflux-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=miniflux
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=miniflux
    volumes:
      - miniflux-db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "miniflux"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  miniflux-db:
COMPOSE

# Create .env file
cat > .env << EOF
DB_PASSWORD=${DB_PASS}
ADMIN_USER=admin
ADMIN_PASS=${ADMIN_PASS}
BASE_URL=http://localhost:8070
EOF

echo "Admin credentials saved to ~/miniflux/.env"
echo "Username: admin"
echo "Password: ${ADMIN_PASS}"

# Start Miniflux
docker compose up -d

echo ""
echo "✅ Miniflux is running at http://localhost:8070"
echo "📝 Login with credentials from .env file"
```

### 3. Verify Installation

```bash
# Check health
curl -s http://localhost:8070/healthcheck
# Expected: OK

# Check containers
docker compose -f ~/miniflux/docker-compose.yml ps
```

## Core Workflows

### Workflow 1: Add RSS Feeds via API

```bash
# Set API credentials
MINIFLUX_URL="http://localhost:8070"
source ~/miniflux/.env
API_AUTH="-u admin:${ADMIN_PASS}"

# Add a single feed
curl -s ${API_AUTH} -X POST "${MINIFLUX_URL}/v1/feeds" \
  -H "Content-Type: application/json" \
  -d '{"feed_url": "https://hnrss.org/frontpage", "category_id": 1}' | jq .

# List all feeds
curl -s ${API_AUTH} "${MINIFLUX_URL}/v1/feeds" | jq '.[].title'
```

### Workflow 2: Import OPML

```bash
# Import feeds from OPML file
source ~/miniflux/.env
curl -s -u "admin:${ADMIN_PASS}" -X POST \
  "http://localhost:8070/v1/import" \
  -H "Content-Type: application/xml" \
  --data-binary @subscriptions.opml | jq .
```

### Workflow 3: Export OPML Backup

```bash
# Export all feeds as OPML
source ~/miniflux/.env
curl -s -u "admin:${ADMIN_PASS}" \
  "http://localhost:8070/v1/export" > miniflux-backup-$(date +%Y%m%d).opml

echo "✅ Exported to miniflux-backup-$(date +%Y%m%d).opml"
```

### Workflow 4: Get Unread Entries

```bash
# Fetch unread articles
source ~/miniflux/.env
curl -s -u "admin:${ADMIN_PASS}" \
  "http://localhost:8070/v1/entries?status=unread&limit=10&direction=desc" | \
  jq '.entries[] | {title: .title, feed: .feed.title, url: .url, published: .published_at}'
```

### Workflow 5: Mark All as Read

```bash
# Mark all entries in a feed as read
source ~/miniflux/.env
FEED_ID=1
curl -s -u "admin:${ADMIN_PASS}" -X PUT \
  "http://localhost:8070/v1/feeds/${FEED_ID}/mark-all-as-read" | jq .
```

### Workflow 6: Search Entries

```bash
# Search across all feeds
source ~/miniflux/.env
curl -s -u "admin:${ADMIN_PASS}" \
  "http://localhost:8070/v1/entries?search=kubernetes&limit=5" | \
  jq '.entries[] | {title: .title, url: .url}'
```

## Management Scripts

### scripts/manage.sh — Full Management CLI

```bash
bash scripts/manage.sh status       # Check service health
bash scripts/manage.sh feeds        # List all feeds with stats
bash scripts/manage.sh add <url>    # Add a new feed
bash scripts/manage.sh import <opml> # Import OPML file
bash scripts/manage.sh export       # Export OPML backup
bash scripts/manage.sh unread       # Show unread count per feed
bash scripts/manage.sh refresh      # Force refresh all feeds
bash scripts/manage.sh backup       # Full database backup
bash scripts/manage.sh update       # Update to latest version
bash scripts/manage.sh logs         # View recent logs
```

## Configuration

### Environment Variables

Key settings in `~/miniflux/.env`:

```bash
# Core
BASE_URL=https://rss.yourdomain.com  # Public URL (for links in notifications)
ADMIN_USER=admin                      # Admin username
ADMIN_PASS=your-secure-password       # Admin password

# Polling
POLLING_FREQUENCY=15    # Minutes between feed checks (default: 60)
BATCH_SIZE=50           # Feeds to check per polling cycle
POLLING_SCHEDULER=entry_frequency  # Adaptive polling based on feed activity

# Cleanup
CLEANUP_ARCHIVE_READ_DAYS=60    # Keep read articles for 60 days
CLEANUP_ARCHIVE_UNREAD_DAYS=-1  # Never delete unread articles
CLEANUP_REMOVE_SESSIONS_DAYS=30 # Remove old sessions after 30 days

# Integrations (optional)
POCKET_CONSUMER_KEY=                # Pocket integration
WALLABAG_ENABLED=false              # Wallabag save
TELEGRAM_BOT_TOKEN=                 # Telegram notifications
TELEGRAM_BOT_CHAT_ID=               # Telegram chat ID
```

### Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name rss.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/rss.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rss.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8070;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Advanced Usage

### Database Backup & Restore

```bash
# Backup PostgreSQL database
docker exec miniflux-db pg_dump -U miniflux miniflux | gzip > miniflux-db-$(date +%Y%m%d).sql.gz

# Restore from backup
gunzip -c miniflux-db-20260307.sql.gz | docker exec -i miniflux-db psql -U miniflux miniflux
```

### Update Miniflux

```bash
cd ~/miniflux
docker compose pull
docker compose up -d
echo "✅ Miniflux updated to latest version"
```

### Monitor Feed Health

```bash
# Check for feeds with errors
source ~/miniflux/.env
curl -s -u "admin:${ADMIN_PASS}" \
  "http://localhost:8070/v1/feeds" | \
  jq '.[] | select(.parsing_error_count > 0) | {title: .title, errors: .parsing_error_count, last_error: .parsing_error_message}'
```

### API Key Authentication

```bash
# Create an API key (more secure than username/password)
source ~/miniflux/.env
API_KEY=$(curl -s -u "admin:${ADMIN_PASS}" -X POST \
  "http://localhost:8070/v1/me/api-keys" \
  -H "Content-Type: application/json" \
  -d '{"description": "OpenClaw automation"}' | jq -r '.api_key')

echo "API Key: ${API_KEY}"
echo "Use with: curl -H 'X-Auth-Token: ${API_KEY}' http://localhost:8070/v1/feeds"
```

## Troubleshooting

### Issue: Container won't start

**Check logs:**
```bash
docker compose -f ~/miniflux/docker-compose.yml logs miniflux --tail 50
```

**Common fix — database not ready:**
```bash
docker compose -f ~/miniflux/docker-compose.yml restart miniflux
```

### Issue: "relation does not exist" error

**Fix — run migrations manually:**
```bash
docker exec miniflux /usr/bin/miniflux -migrate
```

### Issue: Feeds not updating

**Check:**
1. Polling frequency: `POLLING_FREQUENCY` in .env (minutes)
2. Feed errors: Check feed health via API (see above)
3. Force refresh: `curl -s ${API_AUTH} -X PUT "${MINIFLUX_URL}/v1/feeds/<id>/refresh"`

### Issue: Port conflict

**Fix — change port in docker-compose.yml:**
```yaml
ports:
  - "9090:8080"  # Change 8070 to any available port
```

## Key Principles

1. **Minimalist** — Miniflux does one thing well: RSS reading
2. **Self-hosted** — Your data stays on your server
3. **API-first** — Full REST API for automation
4. **Fast** — Written in Go, minimal resource usage (~30MB RAM)
5. **No tracking** — No analytics, no ads, no third-party requests

## Dependencies

- `docker` (with Docker Compose)
- `curl` (API interactions)
- `jq` (JSON parsing)
- `openssl` (password generation)
