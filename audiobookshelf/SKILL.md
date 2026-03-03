---
name: audiobookshelf
description: >-
  Deploy and manage Audiobookshelf — a self-hosted audiobook and podcast server with Docker, library management, user setup, and backup.
categories: [media, home]
dependencies: [docker, curl, jq, bash]
---

# Audiobookshelf Manager

## What This Does

Deploy, configure, and manage [Audiobookshelf](https://www.audiobookshelf.org/) — a self-hosted audiobook and podcast server. Handles Docker deployment, library setup, user management, backup/restore, and monitoring. Access your audiobooks and podcasts from any device with the mobile app.

**Example:** "Deploy Audiobookshelf on port 13378, create libraries for audiobooks and podcasts, add a user, and set up daily backups."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Docker required
which docker || curl -fsSL https://get.docker.com | sh

# Verify
docker --version
```

### 2. Deploy Audiobookshelf

```bash
bash scripts/run.sh deploy --port 13378 --data-dir /opt/audiobookshelf
```

**Output:**
```
✅ Audiobookshelf deployed successfully
   URL: http://localhost:13378
   Data: /opt/audiobookshelf
   Config: /opt/audiobookshelf/config
   Metadata: /opt/audiobookshelf/metadata
   Status: running
```

### 3. Add a Library

```bash
# Create audiobook library (point to your audiobooks folder)
bash scripts/run.sh library-add --name "Audiobooks" --path /media/audiobooks --type book

# Create podcast library
bash scripts/run.sh library-add --name "Podcasts" --path /media/podcasts --type podcast
```

## Core Workflows

### Workflow 1: Deploy with Custom Settings

```bash
bash scripts/run.sh deploy \
  --port 13378 \
  --data-dir /opt/audiobookshelf \
  --audiobooks /media/audiobooks \
  --podcasts /media/podcasts \
  --timezone "America/New_York"
```

### Workflow 2: User Management

```bash
# Create a user
bash scripts/run.sh user-add --username "alice" --password "securepass123" --type user

# List users
bash scripts/run.sh users

# Delete user
bash scripts/run.sh user-del --username "alice"
```

### Workflow 3: Backup & Restore

```bash
# Create backup
bash scripts/run.sh backup --output /backups/audiobookshelf-$(date +%Y%m%d).tar.gz

# Restore from backup
bash scripts/run.sh restore --input /backups/audiobookshelf-20260301.tar.gz

# Auto-backup via cron (daily at 3am)
bash scripts/run.sh backup-cron --schedule "0 3 * * *" --output-dir /backups --keep 7
```

### Workflow 4: Update Audiobookshelf

```bash
# Check current version
bash scripts/run.sh version

# Update to latest
bash scripts/run.sh update

# Update to specific version
bash scripts/run.sh update --version 2.17.0
```

### Workflow 5: Monitor Health

```bash
# Check status
bash scripts/run.sh status

# View logs
bash scripts/run.sh logs --lines 50

# Check library scan status
bash scripts/run.sh scan-status
```

### Workflow 6: Library Scan

```bash
# Trigger a library scan (after adding new files)
bash scripts/run.sh scan --library "Audiobooks"

# Scan all libraries
bash scripts/run.sh scan --all
```

## Configuration

### Environment Variables

```bash
# Server config
export ABS_PORT=13378
export ABS_DATA_DIR=/opt/audiobookshelf
export ABS_HOST=0.0.0.0

# Paths
export ABS_AUDIOBOOKS=/media/audiobooks
export ABS_PODCASTS=/media/podcasts

# Timezone
export TZ=America/New_York
```

### Docker Compose Override

The deploy command creates a `docker-compose.yml`. Customize it:

```yaml
# /opt/audiobookshelf/docker-compose.yml
services:
  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    ports:
      - "13378:80"
    volumes:
      - ./config:/config
      - ./metadata:/metadata
      - /media/audiobooks:/audiobooks
      - /media/podcasts:/podcasts
    environment:
      - TZ=America/New_York
    restart: unless-stopped
```

## Advanced Usage

### Reverse Proxy (Nginx)

```bash
# Generate nginx config for Audiobookshelf
bash scripts/run.sh nginx-config --domain audiobooks.example.com --port 13378
```

**Output (nginx config):**
```nginx
server {
    listen 80;
    server_name audiobooks.example.com;

    location / {
        proxy_pass http://127.0.0.1:13378;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### API Access

```bash
# Get API token (after initial setup via web UI)
bash scripts/run.sh api-token --username admin --password yourpass

# List all library items via API
bash scripts/run.sh api --endpoint "/api/libraries" --method GET
```

### Multi-Library Setup

```bash
# Fiction audiobooks
bash scripts/run.sh library-add --name "Fiction" --path /media/audiobooks/fiction --type book

# Non-fiction
bash scripts/run.sh library-add --name "Non-Fiction" --path /media/audiobooks/nonfiction --type book

# Podcasts
bash scripts/run.sh library-add --name "Podcasts" --path /media/podcasts --type podcast
```

## Troubleshooting

### Issue: Container won't start

**Check:**
```bash
bash scripts/run.sh logs --lines 20
docker ps -a | grep audiobookshelf
```

**Common fixes:**
- Port conflict: Change `--port` to unused port
- Permission issue: `sudo chown -R 1000:1000 /opt/audiobookshelf`

### Issue: Books not appearing after scan

**Check:**
1. Folder structure: Audiobookshelf expects `Author/Book Title/audiofile.mp3`
2. File permissions: `ls -la /media/audiobooks/`
3. Force rescan: `bash scripts/run.sh scan --library "Audiobooks" --force`

### Issue: Can't access from other devices

**Fix:**
- Firewall: `sudo ufw allow 13378/tcp`
- Docker binding: Ensure `--host 0.0.0.0` (default)

### Issue: High memory usage

**Fix:** Set memory limit in docker-compose:
```yaml
deploy:
  resources:
    limits:
      memory: 512M
```

## Dependencies

- `docker` (20.10+) or `docker compose` (v2)
- `curl` (HTTP requests)
- `jq` (JSON parsing)
- `bash` (4.0+)
- Optional: `nginx` (reverse proxy)
