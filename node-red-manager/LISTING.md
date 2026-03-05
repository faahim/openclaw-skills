# Listing Copy: Node-RED Manager

## Metadata
- **Type:** Skill
- **Name:** node-red-manager
- **Display Name:** Node-RED Manager
- **Categories:** [home, automation]
- **Icon:** 🔴
- **Price:** $12
- **Dependencies:** [bash, node, npm]

## Tagline

Install and manage Node-RED — visual automation for IoT, APIs, and smart home

## Description

Setting up Node-RED shouldn't mean wrestling with npm permissions, systemd configs, and security settings. You just want to wire up automations and get on with your life.

Node-RED Manager handles the entire lifecycle: one-command install (native or Docker), password authentication, systemd service management, palette node installation, flow backup/restore with scheduled cron jobs, and reverse proxy generation for Nginx or Caddy. It even checks for updates and monitors health.

**What it does:**
- 🔧 One-command install (native npm or Docker)
- 🔐 Password authentication setup with bcrypt hashing
- 🚀 Systemd service management (start/stop/restart/enable)
- 📦 Palette management — install/remove/search/update nodes
- 💾 Flow backup & restore with scheduled cron backups
- ⬆️ Version checking and safe updates
- 🌐 Reverse proxy config generation (Nginx + Caddy)
- ❤️ Health checks for monitoring integration
- 📊 Status dashboard (memory, flows, uptime)
- 🐳 Docker mode support

Perfect for home lab enthusiasts, IoT builders, and anyone who wants visual automation without the setup headache.

## Quick Start Preview

```bash
# Install Node-RED
bash scripts/install.sh

# Secure with password
bash scripts/secure.sh --user admin --pass 'MyPassword'

# Start as service
bash scripts/manage.sh start

# Install Telegram + Dashboard nodes
bash scripts/palette.sh install node-red-contrib-telegrambot node-red-dashboard

# Schedule daily backups
bash scripts/backup.sh --schedule "0 2 * * *" --output ~/node-red-backups --keep 7
```

## Dependencies
- `bash` (4.0+)
- `node` (18+)
- `npm`
- Optional: `docker`, `nginx`/`caddy`

## Installation Time
**5 minutes** — install, secure, start
