# Listing Copy: PocketBase Manager

## Metadata
- **Type:** Skill
- **Name:** pocketbase-manager
- **Display Name:** PocketBase Manager
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [bash, curl, jq, systemd]
- **Icon:** 🗄️

## Tagline

Deploy and manage PocketBase instances — Install, systemd, backups, and schema management in one skill

## Description

Setting up PocketBase manually means downloading binaries, writing systemd units, configuring reverse proxies, and scripting backups. PocketBase Manager handles all of it.

**One command to deploy:** Install PocketBase, create an instance, set up systemd with auto-restart, configure Caddy reverse proxy with auto-SSL, and schedule daily backups — all in under 5 minutes.

**What it does:**
- 🗄️ Install PocketBase (auto-detects OS/arch, any version)
- 🚀 Deploy instances with systemd services and auto-restart
- 📦 Automated backups to local storage or S3-compatible cloud
- 🔄 Safe upgrades with automatic pre-upgrade backups
- 📊 Collection schema export/import for version control
- 🏥 Health monitoring across multiple instances
- 🌐 Optional Caddy reverse proxy with auto-SSL

**Perfect for indie hackers, solo developers, and small teams** who use PocketBase as their backend and want production-grade deployment without the DevOps overhead.

## Core Capabilities

1. One-command install — Auto-detects OS and architecture, downloads correct binary
2. Instance management — Run multiple PocketBase instances on different ports
3. Systemd integration — Auto-restart on failure, boot startup, clean logs
4. Automated backups — Daily/hourly/weekly to local or S3 with retention policies
5. Safe upgrades — Pre-upgrade backup, binary swap, migration run, health verify
6. Schema version control — Export/import collection schemas as JSON
7. Health monitoring — Check all instances, response time, DB size
8. Full deployment — Install + init + systemd + Caddy + backups in one command
9. Restore from backup — Point-in-time recovery from local or S3
10. Multi-instance — Manage prod, staging, and dev on one server

## Dependencies
- `bash` (4.0+)
- `curl`, `jq`, `unzip`
- `systemd` (Linux)
- Optional: `aws` CLI (S3 backups), `caddy` (reverse proxy)

## Installation Time
**5 minutes** — Full production deployment
