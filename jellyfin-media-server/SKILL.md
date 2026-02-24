---
name: jellyfin-media-server
description: >-
  Install, configure, and manage Jellyfin — the free, self-hosted media streaming server.
categories: [media, home]
dependencies: [docker, bash, curl, jq]
---

# Jellyfin Media Server Manager

## What This Does

Install and manage Jellyfin, the open-source media streaming server. Stream your movies, TV shows, music, and photos from your own server to any device — no subscriptions, no tracking, full control.

**Example:** "Set up Jellyfin with Docker, configure media libraries, manage users, enable hardware transcoding, and monitor server health."

## Quick Start (5 minutes)

### 1. Install Jellyfin via Docker

```bash
bash scripts/install.sh
```

This will:
- Check Docker is installed (install if missing)
- Pull the latest Jellyfin image
- Create config/cache/media directories
- Start Jellyfin on port 8096

### 2. Verify Installation

```bash
bash scripts/manage.sh status
```

**Output:**
```
✅ Jellyfin is running
   URL: http://localhost:8096
   Version: 10.9.x
   Uptime: 2 minutes
   Libraries: 0 configured
```

### 3. Initial Setup

Open `http://<your-ip>:8096` in a browser to complete the setup wizard, or use the CLI:

```bash
# Create admin user
bash scripts/manage.sh create-user --name admin --password "YourSecurePassword"

# Add a media library
bash scripts/manage.sh add-library --name "Movies" --type movies --path /media/movies

# Add another library
bash scripts/manage.sh add-library --name "TV Shows" --type tvshows --path /media/tv
```

## Core Workflows

### Workflow 1: Full Server Setup

**Use case:** Set up a complete media server from scratch

```bash
# Install with custom ports and media path
bash scripts/install.sh \
  --port 8096 \
  --media-dir /mnt/storage/media \
  --config-dir /opt/jellyfin/config \
  --cache-dir /opt/jellyfin/cache

# Enable hardware transcoding (Intel QuickSync / NVIDIA / VAAPI)
bash scripts/manage.sh enable-hwaccel --type vaapi

# Set up HTTPS with reverse proxy
bash scripts/manage.sh setup-ssl --domain media.example.com
```

### Workflow 2: Library Management

**Use case:** Add, scan, and organize media libraries

```bash
# List all libraries
bash scripts/manage.sh list-libraries

# Add library
bash scripts/manage.sh add-library --name "Music" --type music --path /media/music

# Trigger library scan
bash scripts/manage.sh scan-library --name "Movies"

# Scan all libraries
bash scripts/manage.sh scan-all
```

**Output:**
```
📚 Libraries:
  1. Movies    — /media/movies   — 142 items — Last scan: 2 hours ago
  2. TV Shows  — /media/tv       — 38 series  — Last scan: 2 hours ago
  3. Music     — /media/music    — 1,204 tracks — Last scan: 1 hour ago
```

### Workflow 3: User Management

**Use case:** Create and manage user accounts

```bash
# List users
bash scripts/manage.sh list-users

# Create user with restricted access
bash scripts/manage.sh create-user \
  --name "guest" \
  --password "GuestPass123" \
  --libraries "Movies,Music" \
  --no-admin

# Delete user
bash scripts/manage.sh delete-user --name "guest"
```

### Workflow 4: Server Health & Monitoring

**Use case:** Monitor Jellyfin performance and resource usage

```bash
# Full health check
bash scripts/manage.sh health

# Output:
# 🖥️ Jellyfin Health Report
#    Status: ✅ Running
#    CPU: 12% | RAM: 480MB | Disk: 2.1TB used / 4TB
#    Active streams: 2 (1 transcoding, 1 direct play)
#    Transcoding: VAAPI hardware acceleration enabled
#    Scheduled tasks: 3 pending
#    Last backup: 2026-02-24 03:00 UTC
```

### Workflow 5: Backup & Restore

**Use case:** Back up Jellyfin configuration and metadata

```bash
# Backup config, metadata, and user data
bash scripts/manage.sh backup --output /backups/jellyfin-$(date +%Y%m%d).tar.gz

# Restore from backup
bash scripts/manage.sh restore --input /backups/jellyfin-20260224.tar.gz
```

### Workflow 6: Update Jellyfin

```bash
# Check for updates
bash scripts/manage.sh check-update

# Update to latest
bash scripts/manage.sh update

# Output:
# 🔄 Updating Jellyfin...
#    Current: 10.9.6 → Latest: 10.9.7
#    Pulling new image... done
#    Stopping container... done
#    Starting with new image... done
# ✅ Jellyfin updated to 10.9.7
```

## Configuration

### Docker Compose (config-template.yaml)

```yaml
# docker-compose.yml for Jellyfin
version: "3.8"
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"       # Web UI
      - "8920:8920"       # HTTPS (optional)
      - "7359:7359/udp"   # Service discovery
      - "1900:1900/udp"   # DLNA
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /media/movies:/media/movies:ro
      - /media/tv:/media/tv:ro
      - /media/music:/media/music:ro
    environment:
      - JELLYFIN_PublishedServerUrl=http://your-ip:8096
    # Hardware acceleration (uncomment as needed)
    # devices:
    #   - /dev/dri:/dev/dri          # Intel/VAAPI
    # runtime: nvidia                  # NVIDIA
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - capabilities: [gpu]    # NVIDIA
```

### Environment Variables

```bash
# Server config
export JELLYFIN_PORT=8096
export JELLYFIN_MEDIA_DIR=/media
export JELLYFIN_CONFIG_DIR=/opt/jellyfin/config
export JELLYFIN_CACHE_DIR=/opt/jellyfin/cache

# API access (get from Jellyfin Dashboard > API Keys)
export JELLYFIN_API_KEY="your-api-key"
export JELLYFIN_URL="http://localhost:8096"
```

## Advanced Usage

### Hardware Transcoding

```bash
# Check available hardware acceleration
bash scripts/manage.sh detect-hwaccel

# Output:
# 🎬 Hardware Acceleration:
#    Intel QuickSync: ✅ Available (/dev/dri/renderD128)
#    NVIDIA NVENC: ❌ Not detected
#    VAAPI: ✅ Available
#    Recommended: VAAPI (best compatibility)

# Enable VAAPI
bash scripts/manage.sh enable-hwaccel --type vaapi
```

### Scheduled Library Scans

```bash
# Add to crontab — scan libraries every 6 hours
bash scripts/manage.sh schedule-scan --interval 6h

# Or run as OpenClaw cron
# Schedule: every 6 hours
# Command: bash /path/to/scripts/manage.sh scan-all
```

### Network Tuning

```bash
# Enable DLNA for smart TVs
bash scripts/manage.sh enable-dlna

# Set up remote access (with Tailscale/reverse proxy)
bash scripts/manage.sh remote-access --method tailscale
```

## Troubleshooting

### Issue: "Permission denied" on media files

**Fix:**
```bash
# Set correct permissions (Jellyfin runs as UID 1000 by default)
sudo chown -R 1000:1000 /media/movies /media/tv
# Or add user to video group for hardware accel
sudo usermod -aG video $(whoami)
```

### Issue: Transcoding fails

**Check:**
```bash
bash scripts/manage.sh diagnose-transcode
# Checks: FFmpeg version, codec support, hardware accel, permissions
```

### Issue: Container won't start

**Fix:**
```bash
# Check logs
bash scripts/manage.sh logs --tail 50

# Reset container
bash scripts/manage.sh restart --force
```

### Issue: High CPU during playback

**Fix:** Enable hardware transcoding (see Advanced Usage). Software transcoding is CPU-intensive.

## Dependencies

- `docker` + `docker compose` (container runtime)
- `bash` (4.0+)
- `curl` (API calls)
- `jq` (JSON parsing)
- Optional: Intel/NVIDIA GPU drivers for hardware transcoding
