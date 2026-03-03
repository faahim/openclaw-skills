---
name: photoprism-manager
description: >-
  Install, configure, and manage PhotoPrism — the self-hosted AI-powered photo management platform.
categories: [media, home]
dependencies: [docker, docker-compose]
---

# PhotoPrism Manager

## What This Does

Deploys and manages [PhotoPrism](https://github.com/photoprism/photoprism), a self-hosted Google Photos alternative with AI-powered face recognition, object detection, and automatic categorization. Handles installation via Docker, configuration, importing photos, user management, and maintenance tasks.

**Example:** "Deploy PhotoPrism on my server, import 50GB of photos, and set up automatic indexing."

## Quick Start (10 minutes)

### 1. Check Prerequisites

```bash
# Verify Docker and Docker Compose are installed
bash scripts/install.sh check
```

### 2. Deploy PhotoPrism

```bash
# Deploy with default settings (port 2342, SQLite)
bash scripts/install.sh deploy

# Deploy with custom settings
bash scripts/install.sh deploy --port 8080 --password 'MySecurePass123!' --storage /mnt/photos
```

### 3. Access PhotoPrism

```
Open http://<your-server-ip>:2342 in your browser
Default login: admin / <password-you-set>
```

## Core Workflows

### Workflow 1: Full Deployment with MariaDB

**Use case:** Production setup with proper database for large photo libraries (10k+ photos)

```bash
bash scripts/install.sh deploy \
  --port 2342 \
  --password 'YourSecurePassword!' \
  --storage /mnt/photos \
  --database mariadb \
  --data-dir /opt/photoprism
```

**What this does:**
- Creates Docker Compose config with PhotoPrism + MariaDB
- Sets up persistent volumes for photos, database, and sidecar files
- Configures automatic restart on boot
- Starts both containers

### Workflow 2: Import Photos

**Use case:** Bulk import photos from a directory

```bash
# Import from a local directory
bash scripts/manage.sh import /path/to/photos

# Import and move originals (instead of copy)
bash scripts/manage.sh import /path/to/photos --move
```

**Output:**
```
📸 Importing photos from /path/to/photos...
   Found 1,247 files (8.3 GB)
   Importing... done (2m 34s)
   ✅ 1,230 photos imported, 17 duplicates skipped
   🔍 Indexing started in background
```

### Workflow 3: Index & Classify Photos

**Use case:** Trigger AI classification on all photos

```bash
# Full index (re-analyze all photos)
bash scripts/manage.sh index --full

# Quick index (new photos only)
bash scripts/manage.sh index

# Check indexing status
bash scripts/manage.sh status
```

**Output:**
```
📊 PhotoPrism Status:
   Photos: 12,450
   Videos: 342
   Albums: 28
   Faces: 156 recognized
   Places: 89 locations
   Storage: 45.2 GB used
   Status: Running (uptime: 14d 3h)
```

### Workflow 4: Backup & Restore

**Use case:** Back up PhotoPrism database and config

```bash
# Create backup
bash scripts/manage.sh backup /path/to/backups

# Restore from backup
bash scripts/manage.sh restore /path/to/backups/photoprism-backup-2026-03-03.tar.gz
```

**Output:**
```
💾 Backup created: /path/to/backups/photoprism-backup-2026-03-03.tar.gz
   Database: 12.4 MB
   Config: 2.1 KB
   Sidecar files: 156 MB
   Total: 168.5 MB
```

### Workflow 5: User Management

**Use case:** Manage PhotoPrism users and roles

```bash
# Change admin password
bash scripts/manage.sh password 'NewSecurePassword!'

# Show current configuration
bash scripts/manage.sh config
```

### Workflow 6: Update PhotoPrism

**Use case:** Update to latest version

```bash
bash scripts/manage.sh update

# Output:
# 🔄 Pulling latest PhotoPrism image...
#    Current: 2026.02.1
#    Latest: 2026.03.0
#    Updating... done
#    ✅ PhotoPrism updated and restarted
```

### Workflow 7: Maintenance

**Use case:** Clean up and optimize

```bash
# Remove orphaned sidecar files
bash scripts/manage.sh cleanup

# Optimize database
bash scripts/manage.sh optimize

# View logs
bash scripts/manage.sh logs

# View logs (last 100 lines, follow)
bash scripts/manage.sh logs -f --tail 100
```

## Configuration

### Environment Variables

```bash
# PhotoPrism data directory (default: /opt/photoprism)
export PHOTOPRISM_DATA_DIR="/opt/photoprism"

# Photos storage directory (default: ~/Photos)
export PHOTOPRISM_PHOTOS_DIR="$HOME/Photos"

# Port (default: 2342)
export PHOTOPRISM_PORT=2342
```

### Docker Compose Override

After deployment, edit `$PHOTOPRISM_DATA_DIR/docker-compose.yml` to customize:

```yaml
services:
  photoprism:
    environment:
      PHOTOPRISM_SITE_TITLE: "My Photos"
      PHOTOPRISM_SITE_URL: "https://photos.example.com"
      PHOTOPRISM_WORKERS: 4               # CPU cores for indexing
      PHOTOPRISM_JPEG_QUALITY: 85         # JPEG quality (1-100)
      PHOTOPRISM_DETECT_NSFW: "true"      # NSFW content detection
      PHOTOPRISM_UPLOAD_NSFW: "false"     # Block NSFW uploads
      PHOTOPRISM_RAW_PRESETS: "true"      # Enable RAW file presets
      PHOTOPRISM_DISABLE_WEBDAV: "false"  # Enable WebDAV for sync
```

Then apply: `bash scripts/manage.sh restart`

## Advanced Usage

### Reverse Proxy with Nginx

```bash
# Generate Nginx config for PhotoPrism
bash scripts/manage.sh nginx-config photos.example.com

# Output: Nginx config written to /etc/nginx/sites-available/photoprism
# Run: sudo ln -s /etc/nginx/sites-available/photoprism /etc/nginx/sites-enabled/
# Run: sudo nginx -t && sudo systemctl reload nginx
```

### WebDAV Sync (Mobile/Desktop)

PhotoPrism includes WebDAV. Connect with any WebDAV client:

```
URL: http://<server>:2342/originals/
Username: admin
Password: <your-password>
```

### Scheduled Indexing via Cron

```bash
# Add to crontab: re-index every 6 hours
bash scripts/manage.sh cron-setup --interval 6h
```

### Hardware Acceleration (GPU)

```bash
# Deploy with Intel Quick Sync Video (QSV) support
bash scripts/install.sh deploy --gpu intel

# Deploy with NVIDIA GPU support
bash scripts/install.sh deploy --gpu nvidia
```

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Fix:**
```bash
# Start Docker
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: "PhotoPrism container keeps restarting"

**Check logs:**
```bash
bash scripts/manage.sh logs --tail 50
```

**Common causes:**
1. Insufficient memory (need 2GB+ RAM)
2. Port conflict (change with --port)
3. Database connection failed (check MariaDB container)

### Issue: "Photos not appearing after import"

**Fix:**
```bash
# Trigger manual index
bash scripts/manage.sh index --full

# Check file permissions
ls -la $PHOTOPRISM_PHOTOS_DIR
```

### Issue: "Slow indexing performance"

**Fix:**
```bash
# Increase worker count
# Edit docker-compose.yml: PHOTOPRISM_WORKERS: 4
bash scripts/manage.sh restart
```

## System Requirements

- **CPU:** 2+ cores (4+ recommended for AI features)
- **RAM:** 2 GB minimum, 4 GB+ recommended
- **Disk:** 20 GB + your photo library size
- **OS:** Linux (amd64 or arm64)
- **Docker:** 20.10+ with Docker Compose v2

## Dependencies

- `docker` (20.10+)
- `docker compose` (v2)
- `curl` (for health checks)
- `tar` (for backups)
