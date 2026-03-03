# Listing Copy: Audiobookshelf Manager

## Metadata
- **Type:** Skill
- **Name:** audiobookshelf
- **Display Name:** Audiobookshelf Manager
- **Categories:** [media, home]
- **Price:** $12
- **Dependencies:** [docker, curl, jq, bash]
- **Icon:** 🎧

## Tagline
Deploy & manage Audiobookshelf — self-hosted audiobook & podcast server

## Description

Managing audiobooks and podcasts across devices shouldn't require a cloud subscription. Audiobookshelf is the best self-hosted media server for spoken content — but setting it up, managing libraries, and keeping backups requires Docker knowledge and manual config.

**Audiobookshelf Manager** handles everything: one-command Docker deployment, library setup, user management, automated backups with retention, and Nginx reverse proxy generation. It wraps the Audiobookshelf API so your OpenClaw agent can manage your entire audiobook server.

**What it does:**
- 🚀 One-command Docker deployment with sensible defaults
- 📚 Library management — audiobooks and podcasts
- 👥 User creation and management via API
- 💾 Automated backup with cron scheduling and retention
- 🔄 One-command updates (latest or pinned version)
- 🌐 Nginx reverse proxy config generation
- 📊 Status monitoring, logs, and health checks
- 🔑 API token management for advanced automation

Perfect for audiobook enthusiasts, podcast hoarders, and self-hosting fans who want their media library accessible from any device — mobile apps included.

## Quick Start Preview

```bash
# Deploy in one command
bash scripts/run.sh deploy --port 13378 --audiobooks /media/audiobooks

# Check status
bash scripts/run.sh status
# ✅ Audiobookshelf is RUNNING
#    URL: http://localhost:13378
```

## Core Capabilities

1. Docker deployment — Pull, configure, and run with one command
2. Library management — Add audiobook and podcast libraries, trigger scans
3. Automated backups — Scheduled tar.gz backups with configurable retention
4. One-click updates — Pull latest image and recreate container seamlessly
5. User management — Create, list, and delete users via API
6. Nginx reverse proxy — Generate production-ready proxy configs
7. Health monitoring — Container status, logs, version checks
8. API access — Raw API calls for advanced automation
9. Restore from backup — Full restore with automatic restart
10. Docker Compose — Generates compose file for reproducible deploys

## Dependencies
- `docker` (20.10+)
- `curl`
- `jq`
- `bash` (4.0+)

## Installation Time
**5 minutes** — Run deploy, open browser, create admin account
