# Listing Copy: Immich Photo Server Manager

## Metadata
- **Type:** Skill
- **Name:** immich-server
- **Display Name:** Immich Photo Server Manager
- **Categories:** [media, home]
- **Price:** $15
- **Dependencies:** [docker, docker-compose, curl, jq]
- **Icon:** 📸

## Tagline

Deploy and manage Immich — self-hosted Google Photos with AI search and face recognition

## Description

Your photos shouldn't live on someone else's server. But setting up and maintaining a self-hosted photo solution is a pain — Docker configs, database backups, version upgrades, GPU acceleration, reverse proxy setup.

Immich Photo Server Manager handles the entire lifecycle of an Immich deployment. One command to install, automated database backups, safe upgrades with pre-upgrade snapshots, health monitoring, and GPU configuration for faster AI processing.

**What it does:**
- 🚀 One-command Immich deployment with secure defaults
- 💾 Automated PostgreSQL backups with retention policies
- ⬆️ Safe upgrades — always backs up before pulling new images
- 📊 Health monitoring — container status, storage usage, uptime
- 🎮 GPU acceleration setup (NVIDIA/Intel) for face detection & smart search
- 🔧 Configuration management — ports, storage, ML models
- 🔄 Database restore from any backup point
- 📱 Ready for mobile app connection (iOS/Android)

**Who it's for:** Developers, photographers, and privacy-conscious users who want Google Photos features without the cloud dependency. Perfect for home servers, NAS devices, and VPS deployments.

## Core Capabilities

1. Automated installation — Docker Compose deployment with generated credentials
2. Database backup — Scheduled PostgreSQL dumps with compression and rotation
3. Safe upgrades — Pre-upgrade backup, pull, restart, health verify
4. Health monitoring — Container status, storage usage, uptime tracking
5. GPU acceleration — NVIDIA CUDA and Intel OpenVINO setup
6. Configuration management — Port, storage path, ML model switching
7. Database restore — Point-in-time recovery from any backup
8. Reverse proxy config — Nginx config generation with SSL
9. Multi-user management — Create users with storage quotas via API
10. Cron-ready — Drop-in scheduled backups and monitoring
