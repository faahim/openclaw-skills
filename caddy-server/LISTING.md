# Listing Copy: Caddy Web Server Manager

## Metadata
- **Type:** Skill
- **Name:** caddy-server
- **Display Name:** Caddy Web Server Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl]
- **Icon:** 🌐

## Tagline

"Install and manage Caddy web server — automatic HTTPS, reverse proxy, zero config SSL"

## Description

Setting up web servers shouldn't require wrestling with Nginx configs and manually renewing SSL certificates. Caddy handles HTTPS automatically — no certbot, no cron jobs, no expired certs at 3am.

**Caddy Web Server Manager** installs and configures Caddy with simple commands. Reverse proxy your apps, serve static sites, host SPAs — all with automatic HTTPS via Let's Encrypt. Zero-downtime reloads mean your users never notice config changes.

**What it does:**
- 🔐 Automatic HTTPS — SSL certs provisioned and renewed automatically
- 🔄 Reverse proxy — Forward traffic to Node, Python, Go, or any backend
- 📁 Static file serving — Host sites with gzip/zstd compression
- ⚡ SPA hosting — React/Vue/Next.js with proper client-side routing
- 🔀 Load balancing — Round-robin across multiple upstreams
- 🔒 Basic auth — Password-protect admin panels
- 📋 Site management — Add, remove, list sites via CLI
- 🔄 Zero-downtime reloads — Config changes without dropping connections

**Perfect for developers and sysadmins** who want production-ready HTTPS without the Nginx/certbot dance.

## Quick Start Preview

```bash
# Install Caddy
bash scripts/install.sh

# Reverse proxy with auto-HTTPS
bash scripts/manage.sh proxy --domain app.example.com --upstream localhost:3000
# ✅ HTTPS auto-provisioned via Let's Encrypt
```

## Dependencies
- `bash` (4.0+)
- `curl`
- Root/sudo access

## Installation Time
**5 minutes** — Run install script, add your first site
