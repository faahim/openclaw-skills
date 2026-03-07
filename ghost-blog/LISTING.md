# Listing Copy: Ghost Blog Manager

## Metadata
- **Type:** Skill
- **Name:** ghost-blog
- **Display Name:** Ghost Blog Manager
- **Categories:** [writing, dev-tools]
- **Icon:** 👻
- **Price:** $15
- **Dependencies:** [docker, docker-compose, bash, curl]

## Tagline

Deploy and manage a self-hosted Ghost blog with Docker — themes, backups, SSL, and updates

## Description

Ghost(Pro) charges $9-199/month for hosting. But Ghost is open-source — you can run it yourself for the cost of a $5 VPS. The hard part is setting up Docker, MySQL, SSL certificates, backups, and updates. This skill handles all of it.

Ghost Blog Manager deploys a complete Ghost CMS stack in one command: Ghost app, MySQL database, and Caddy reverse proxy with automatic Let's Encrypt SSL. It also manages themes, backups, updates, and health monitoring — everything you need to run a professional blog without Ghost(Pro).

**What it does:**
- 🚀 One-command deployment — Ghost + MySQL + SSL in 10 minutes
- 🔒 Automatic HTTPS — Caddy with Let's Encrypt, zero config
- 💾 Full backups — database, content, images, themes in one archive
- 🔄 Safe updates — auto-backup before pulling latest Ghost image
- 🎨 Theme management — install from GitHub, activate, list
- 📊 Health monitoring — container status, SSL, API, disk usage
- 🗓️ Scheduled backups — daily/weekly with automatic pruning
- 🏗️ Multi-site — run multiple Ghost instances on one server

Perfect for bloggers, indie creators, and developers who want professional publishing without monthly hosting fees. Works on any Linux VPS or local machine with Docker.

## Core Capabilities

1. Docker-based deployment — Ghost + MySQL + Caddy in one compose stack
2. Automatic SSL — Let's Encrypt certificates via Caddy, auto-renewed
3. Full backup & restore — database dumps + content + themes in single archive
4. One-command updates — backup, pull latest, restart
5. Theme management — install from GitHub or zip, activate, list
6. Health dashboard — container status, API latency, SSL validity, disk usage
7. Scheduled backups — cron-based with configurable retention
8. Multi-site support — named deployments for multiple blogs
9. SMTP configuration — transactional email via Gmail, Mailgun, etc.
10. Clean destruction — full teardown with confirmation

## Dependencies
- `docker` (20.10+)
- `docker-compose` (v2+)
- `bash` (4.0+)
- `curl`, `openssl`

## Installation Time
**10 minutes** — install deps, deploy, create admin account
