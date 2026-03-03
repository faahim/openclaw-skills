# Listing Copy: PhotoPrism Manager

## Metadata
- **Type:** Skill
- **Name:** photoprism-manager
- **Display Name:** PhotoPrism Manager
- **Categories:** [media, home]
- **Price:** $15
- **Dependencies:** [docker, docker-compose]
- **Icon:** 📷

## Tagline

Deploy and manage PhotoPrism — your self-hosted AI-powered photo library

## Description

Manually organizing thousands of photos across devices is a nightmare. Cloud services like Google Photos mine your data, charge monthly fees, and can shut down anytime. You need a private, self-hosted alternative that's actually smart.

PhotoPrism Manager deploys and manages PhotoPrism on your server with a single command. PhotoPrism uses TensorFlow for automatic face recognition, object detection, and scene classification — all running locally on your hardware. No cloud, no subscriptions, no data mining.

**What it does:**
- 🚀 One-command deployment with Docker (SQLite or MariaDB)
- 🧠 AI-powered face recognition & object classification
- 📥 Bulk photo import with duplicate detection
- 💾 Automated backups & one-command restore
- 🔄 Easy updates to latest version
- 🌐 Nginx reverse proxy config generation
- ⏱️ Scheduled indexing via cron
- 🎮 GPU acceleration support (Intel QSV / NVIDIA)
- 📊 Status monitoring & health checks
- 🧹 Cleanup & database optimization

Perfect for photographers, families, and privacy-conscious users who want Google Photos features without giving up their data.

## Quick Start Preview

```bash
# Deploy PhotoPrism
bash scripts/install.sh deploy --password 'MySecurePass!' --database mariadb

# Import photos
bash scripts/manage.sh import ~/Pictures

# Check status
bash scripts/manage.sh status
```

## Core Capabilities

1. Docker deployment — SQLite (simple) or MariaDB (production) with one command
2. AI photo classification — Faces, objects, scenes, places auto-detected
3. Bulk import — Import thousands of photos with duplicate detection
4. Backup & restore — Full database + config backup to tar.gz
5. Version updates — Pull latest image and restart seamlessly
6. Nginx config — Auto-generate reverse proxy for custom domains
7. GPU acceleration — Intel QSV and NVIDIA GPU support for faster indexing
8. WebDAV sync — Built-in WebDAV for mobile/desktop photo sync
9. Scheduled indexing — Cron-based auto-indexing for new photos
10. User management — Password changes, config management
11. Maintenance — Cleanup orphans, optimize database, view logs
12. Clean uninstall — Remove containers/images, keep your photos

## Dependencies
- `docker` (20.10+)
- `docker compose` (v2)
- `curl`
- `tar`

## Installation Time
**10 minutes** — Run deploy, access web UI

## Pricing Justification
- Google Photos: $3/mo (100GB), $10/mo (2TB) — ongoing
- PhotoPrism Manager: $15 one-time — unlimited storage, full privacy
- Complexity: Medium-High (Docker orchestration + database + GPU + backup)
