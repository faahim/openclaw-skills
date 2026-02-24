# Listing Copy: Jellyfin Media Server Manager

## Metadata
- **Type:** Skill
- **Name:** jellyfin-media-server
- **Display Name:** Jellyfin Media Server Manager
- **Categories:** [media, home]
- **Icon:** 🎬
- **Dependencies:** [docker, bash, curl, jq]

## Tagline

Install and manage Jellyfin — stream your media library from your own server

## Description

Tired of paying for streaming subscriptions that keep raising prices and removing content? Host your own media server with Jellyfin — the free, open-source alternative to Plex and Emby.

Jellyfin Media Server Manager handles the entire lifecycle: install Jellyfin via Docker with one command, auto-detect hardware transcoding (Intel/NVIDIA), manage media libraries, create user accounts, monitor server health, backup configurations, and update to the latest version. No subscriptions, no tracking, full control.

**What it does:**
- 🚀 One-command Docker installation with auto-GPU detection
- 📚 Add, scan, and organize media libraries (movies, TV, music, photos)
- 👥 Create and manage user accounts with access control
- 🎮 Auto-detect and enable hardware transcoding (VAAPI/NVENC)
- 📊 Health monitoring — CPU, RAM, active streams, log errors
- 📦 Backup and restore configuration and metadata
- 🔄 Update Jellyfin with zero-downtime container replacement
- 🔧 Diagnose transcoding issues and storage problems

Perfect for self-hosters, media enthusiasts, and anyone who wants Netflix-like streaming from their own hardware.

## Quick Start Preview

```bash
# Install Jellyfin
bash scripts/install.sh --media-dir /mnt/media

# Check status
bash scripts/manage.sh status
# ✅ Jellyfin is running
#    URL: http://localhost:8096
#    Active streams: 0
#    Libraries: 3 configured

# Add a library
bash scripts/manage.sh add-library --name "Movies" --type movies --path /media/movies
```

## Core Capabilities

1. Docker installation — Auto-install Docker if missing, pull and configure Jellyfin
2. Hardware transcoding — Detect Intel QuickSync, NVIDIA NVENC, VAAPI and enable automatically
3. Library management — Add, scan, list media libraries via CLI or API
4. User management — Create accounts with admin/user roles and library access control
5. Health monitoring — CPU, RAM, active streams, log errors, disk usage
6. Backup & restore — Tar config/metadata, stop-start for consistency
7. Zero-downtime updates — Pull new image, swap container, verify health
8. DLNA support — Auto-discovery for smart TVs and devices
9. Remote access — Works with Tailscale, reverse proxies, custom domains
10. Comprehensive logging — View and filter container logs
