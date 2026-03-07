# Listing Copy: Miniflux RSS Server Manager

## Metadata
- **Type:** Skill
- **Name:** miniflux-server
- **Display Name:** Miniflux RSS Server Manager
- **Categories:** [communication, home]
- **Price:** $12
- **Dependencies:** [docker, curl, jq]

## Tagline

"Deploy a minimalist self-hosted RSS reader — own your feeds, no tracking, full API"

## Description

### The Problem

Commercial RSS readers track your reading habits, show ads, and can shut down at any time (RIP Google Reader). Self-hosting RSS sounds great, but setting up PostgreSQL, configuring Docker, and managing feeds from the command line is tedious.

### The Solution

Miniflux RSS Server Manager deploys a complete Miniflux instance in 5 minutes using Docker. One command gives you a fast, clean RSS reader with a full REST API. Import your OPML, add feeds, and read — all from your own server with zero tracking.

### Key Features

- 🚀 One-command deployment with Docker Compose + PostgreSQL
- 📡 Full REST API for feed management and automation
- 📥 OPML import/export for easy migration
- 🔍 Search across all your feeds
- 📊 Feed health monitoring (detect broken feeds)
- 💾 Database backup and restore scripts
- 🔄 Auto-update to latest version
- 🔒 Self-hosted — your reading data stays private
- ⚡ Lightweight — ~30MB RAM (written in Go)
- 🛠️ Management CLI for all common operations

### Who It's For

Developers, privacy-conscious users, and anyone who wants a fast, no-nonsense RSS reader they fully control.

## Quick Start Preview

```bash
# Deploy Miniflux
bash scripts/manage.sh   # Follow Quick Start in SKILL.md

# Add feeds
bash scripts/manage.sh add https://hnrss.org/frontpage

# Check status
bash scripts/manage.sh status
# Feeds: 12 total, 0 with errors
# Unread: 47 entries
```

## Core Capabilities

1. Docker deployment — PostgreSQL + Miniflux in one compose file
2. Feed management — Add, remove, refresh feeds via API
3. OPML support — Import/export for migration between readers
4. Unread tracking — Per-feed unread counts and bulk mark-as-read
5. Full-text search — Search across all feed entries
6. Feed health — Detect and report broken/erroring feeds
7. Database backup — One-command PostgreSQL dump with compression
8. Auto-update — Pull latest image and restart seamlessly
9. Reverse proxy ready — Nginx config included for HTTPS
10. Telegram integration — Optional notifications for new entries
11. API key auth — Secure API access without password exposure
12. Metrics — Prometheus-compatible metrics endpoint

## Dependencies
- Docker (with Docker Compose)
- curl
- jq
- openssl (for initial password generation)

## Installation Time
**5 minutes** — Run deploy script, log in
