---
name: linkding-bookmarks
description: >-
  Install and manage Linkding — a self-hosted bookmark manager with tagging, search, full-text archiving, and REST API.
categories: [productivity, home]
dependencies: [docker, curl, jq]
---

# Linkding Bookmark Manager

## What This Does

Installs and manages [Linkding](https://github.com/sissbruecker/linkding), a lightweight self-hosted bookmark manager. Save bookmarks with tags, search across your collection, archive pages for offline reading, and access everything via REST API. No cloud dependency — your bookmarks stay on your server.

**Example:** "Save 500 bookmarks with tags, search instantly, archive pages before they disappear, import/export browser bookmarks."

## Quick Start (5 minutes)

### 1. Install Linkding

```bash
bash scripts/install.sh
```

This pulls the Docker image and starts Linkding on port 9090.

### 2. Create Admin User

```bash
bash scripts/manage.sh create-user --username admin --password your-secure-password
```

### 3. Get API Token

```bash
bash scripts/manage.sh get-token --username admin --password your-secure-password
```

Save the token:
```bash
echo 'export LINKDING_URL="http://localhost:9090"' >> ~/.bashrc
echo 'export LINKDING_TOKEN="your-api-token"' >> ~/.bashrc
source ~/.bashrc
```

### 4. Add Your First Bookmark

```bash
bash scripts/bookmarks.sh add \
  --url "https://github.com/sissbruecker/linkding" \
  --title "Linkding - Self-hosted bookmark manager" \
  --tags "selfhosted,bookmarks,tools"
```

## Core Workflows

### Workflow 1: Add Bookmarks

```bash
# Add with tags and description
bash scripts/bookmarks.sh add \
  --url "https://example.com/article" \
  --title "Great Article" \
  --description "Notes about this article" \
  --tags "reading,tech,reference"

# Add and archive the page
bash scripts/bookmarks.sh add \
  --url "https://example.com/article" \
  --tags "archive" \
  --archive
```

### Workflow 2: Search Bookmarks

```bash
# Search by keyword
bash scripts/bookmarks.sh search "docker setup"

# Search by tag
bash scripts/bookmarks.sh search --tag "selfhosted"

# List all bookmarks
bash scripts/bookmarks.sh list --limit 20
```

**Output:**
```
ID    | URL                              | Title                    | Tags
------|----------------------------------|--------------------------|------------------
42    | https://docs.docker.com          | Docker Documentation     | docker,reference
38    | https://example.com/deploy       | Deployment Guide         | docker,devops
```

### Workflow 3: Import Browser Bookmarks

```bash
# Export bookmarks from your browser as HTML (Netscape format)
# Then import:
bash scripts/bookmarks.sh import --file bookmarks.html

# Output:
# ✅ Imported 347 bookmarks
# ⚠️  12 duplicates skipped
```

### Workflow 4: Export Bookmarks

```bash
# Export as HTML (browser-compatible)
bash scripts/bookmarks.sh export --format html > my-bookmarks.html

# Export as JSON (for backup/migration)
bash scripts/bookmarks.sh export --format json > my-bookmarks.json
```

### Workflow 5: Bulk Tag Management

```bash
# Add tag to multiple bookmarks
bash scripts/bookmarks.sh bulk-tag --ids "42,38,55" --add "important"

# Remove tag
bash scripts/bookmarks.sh bulk-tag --ids "42,38" --remove "temp"

# List all tags with counts
bash scripts/bookmarks.sh tags
```

**Output:**
```
Tag            | Count
---------------|------
selfhosted     | 45
docker         | 32
reference      | 28
reading        | 22
```

## Server Management

### Start/Stop/Restart

```bash
bash scripts/manage.sh start
bash scripts/manage.sh stop
bash scripts/manage.sh restart
bash scripts/manage.sh status
```

### Backup Database

```bash
# Create backup
bash scripts/manage.sh backup

# Output: ✅ Backup saved to backups/linkding-2026-03-07.sql.gz

# Restore from backup
bash scripts/manage.sh restore --file backups/linkding-2026-03-07.sql.gz
```

### Update Linkding

```bash
bash scripts/manage.sh update
# Pulls latest image, restarts container, preserves data
```

### Configure Reverse Proxy

```bash
# Generate Nginx config for domain access
bash scripts/manage.sh nginx-config --domain bookmarks.example.com

# Output: Nginx config written to /etc/nginx/sites-available/linkding
# Run: sudo ln -s /etc/nginx/sites-available/linkding /etc/nginx/sites-enabled/
# Run: sudo nginx -t && sudo systemctl reload nginx
```

## Configuration

### Environment Variables

```bash
# Required
export LINKDING_URL="http://localhost:9090"
export LINKDING_TOKEN="your-api-token"

# Optional
export LINKDING_PORT=9090              # Change default port
export LINKDING_DATA_DIR="$HOME/.linkding"  # Data directory
```

### Docker Compose (Advanced)

The installer creates `~/.linkding/docker-compose.yml`:

```yaml
services:
  linkding:
    image: sissbruecker/linkding:latest
    container_name: linkding
    ports:
      - "${LINKDING_PORT:-9090}:9090"
    volumes:
      - ./data:/etc/linkding/data
    environment:
      - LD_SUPERUSER_NAME=${LINKDING_ADMIN:-admin}
      - LD_SUPERUSER_PASSWORD=${LINKDING_PASSWORD:-}
      - LD_ENABLE_AUTH_PROXY=False
    restart: unless-stopped
```

## API Usage (for automation)

```bash
# Direct API calls
curl -s "$LINKDING_URL/api/bookmarks/" \
  -H "Authorization: Token $LINKDING_TOKEN" | jq .

# Create bookmark via API
curl -s -X POST "$LINKDING_URL/api/bookmarks/" \
  -H "Authorization: Token $LINKDING_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","tag_names":["test"]}'

# Search via API
curl -s "$LINKDING_URL/api/bookmarks/?q=docker" \
  -H "Authorization: Token $LINKDING_TOKEN" | jq '.results[] | {title, url}'
```

## Troubleshooting

### Issue: "Docker not found"

**Fix:**
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: Port 9090 already in use

**Fix:**
```bash
export LINKDING_PORT=9091
bash scripts/install.sh
```

### Issue: "401 Unauthorized" on API calls

**Check:**
1. Token is set: `echo $LINKDING_TOKEN`
2. Token is valid: Try logging into web UI at `http://localhost:9090`
3. Regenerate: `bash scripts/manage.sh get-token --username admin --password yourpass`

### Issue: Container won't start

**Fix:**
```bash
# Check logs
docker logs linkding

# Check disk space
df -h

# Recreate container (data is preserved in volume)
bash scripts/manage.sh stop
bash scripts/manage.sh start
```

## Key Principles

1. **Your data** — Bookmarks stored locally in SQLite, no cloud sync
2. **Fast search** — Full-text search across titles, URLs, descriptions, and archived content
3. **Archive pages** — Save page content before it disappears (linkrot protection)
4. **Browser-compatible** — Import/export standard Netscape bookmark HTML
5. **REST API** — Automate everything via the built-in API
6. **Lightweight** — ~50MB Docker image, minimal resource usage
