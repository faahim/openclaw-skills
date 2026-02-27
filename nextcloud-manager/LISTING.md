# Listing Copy: Nextcloud Manager

## Metadata
- **Type:** Skill
- **Name:** nextcloud-manager
- **Display Name:** Nextcloud Manager
- **Categories:** [data, home]
- **Price:** $15
- **Dependencies:** [docker, bash, curl, jq]
- **Icon:** ☁️

## Tagline

Deploy and manage self-hosted Nextcloud — your private cloud for files, calendar, and 300+ apps

## Description

### The Problem

Cloud storage means trusting someone else with your data. Google Drive, Dropbox, iCloud — they're convenient but they mine your files, cap your storage, and charge monthly. Self-hosting Nextcloud fixes this, but setup is a maze of Docker configs, database tuning, SSL certs, and PHP settings.

### The Solution

Nextcloud Manager handles the entire lifecycle of a Nextcloud instance — from one-command Docker installation with PostgreSQL + Redis, to user management, app installation, automated backups, and health monitoring. No YAML wrestling, no PHP debugging. Your agent runs it all.

### Key Features

- ☁️ **One-command install** — Docker-based Nextcloud with PostgreSQL + Redis in minutes
- 👥 **User management** — Create, disable, reset passwords, set quotas and groups
- 📦 **App lifecycle** — Install, update, and manage 300+ Nextcloud apps
- 💾 **Automated backups** — Files + database + config, local or S3, with retention policies
- 🏥 **Health monitoring** — Check web server, database, cache, cron, SSL, disk space
- ⚡ **Performance tuning** — OPcache, Redis caching, upload limits, background jobs
- 🔧 **Maintenance tools** — Database repair, file scanning, maintenance mode
- ⬆️ **Safe upgrades** — Auto-backup before upgrade, one-command update

### Who It's For

Developers, sysadmins, and privacy-conscious users who want their own cloud without the ops headache. Perfect for home labs, small teams, and anyone tired of paying monthly for cloud storage.

## Quick Start Preview

```bash
# Install Nextcloud with PostgreSQL + Redis
bash scripts/nextcloud-manager.sh install --domain cloud.example.com --db postgres --cache redis

# Create a user
bash scripts/nextcloud-manager.sh user create --username alice --email alice@example.com --quota 10G

# Run health check
bash scripts/nextcloud-manager.sh health --fix
```

## Core Capabilities

1. Docker installation — PostgreSQL, Redis, auto-generated passwords, ready in 2 minutes
2. User management — Create, list, disable, enable, reset passwords, set quotas
3. Group management — Create groups, assign users, manage permissions
4. App management — Browse, install, update, disable Nextcloud apps
5. Full backups — Files + database + config in one command
6. S3 backups — Upload directly to AWS S3, Backblaze B2, or any S3-compatible storage
7. Scheduled backups — Cron-based with configurable retention
8. Health checks — Web server, database, cache, cron, SSL, disk space
9. Auto-fix — Common issues fixed automatically (cron mode, phone region, etc.)
10. Performance tuning — OPcache, Redis file locking, upload limits
11. Safe upgrades — Backup-then-upgrade workflow
12. Maintenance mode — Database repair, file scanning, index rebuilding

## Dependencies
- Docker (20.10+) and Docker Compose v2
- bash (4.0+), curl, jq, openssl
- Optional: aws CLI (S3 backups), certbot (SSL)

## Installation Time
**10 minutes** — Run install, access Nextcloud

## Pricing Justification
- Comparable: Managed Nextcloud hosting $5-20/month (Hetzner, Webo)
- One-time $15 vs recurring monthly fees
- Full control, no vendor lock-in
- Complexity: High (Docker + database + cache + SSL + backups)
