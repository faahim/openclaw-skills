# Listing Copy: Nginx Reverse Proxy

## Metadata
- **Type:** Skill
- **Name:** nginx-reverse-proxy
- **Display Name:** Nginx Reverse Proxy
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [nginx, certbot, openssl]
- **Icon:** 🔀

## Tagline

Set up Nginx reverse proxies with SSL, load balancing, and WebSocket support in one command.

## Description

Configuring Nginx as a reverse proxy means editing config files, managing SSL certificates, setting up security headers, and remembering the right syntax every time. One typo and your site goes down.

**Nginx Reverse Proxy** automates the entire setup. Add a proxy in one command — it generates the nginx config, obtains Let's Encrypt SSL certificates, configures security headers (HSTS, X-Frame-Options), and sets up automatic certificate renewal. Supports load balancing across multiple backends, WebSocket proxying, rate limiting, and custom headers.

**What it does:**
- 🔀 One-command proxy setup with auto-generated nginx configs
- 🔐 Automatic Let's Encrypt SSL with HTTPS redirect
- ⚖️ Load balancing (round robin, least connections, IP hash)
- 🔌 WebSocket proxy support for real-time apps
- 🛡️ Security defaults: TLS 1.2+, strong ciphers, security headers
- 📊 Health checks for upstream servers and SSL expiry
- 🔄 Auto-renewal cron for SSL certificates
- 💾 Backup and restore all proxy configurations
- 🧪 Dry-run mode to preview configs before applying

Perfect for developers and sysadmins who deploy web apps and need reliable reverse proxy setup without manual config editing.

## Quick Start Preview

```bash
# Install nginx + certbot
bash scripts/install.sh

# Add a proxy with SSL
bash scripts/proxy.sh add --domain api.example.com --upstream 127.0.0.1:3000 --ssl

# Check status
bash scripts/proxy.sh status
# DOMAIN                  UPSTREAM           SSL    STATUS
# api.example.com         127.0.0.1:3000     ✅     active
```

## Core Capabilities

1. Reverse proxy setup — One command creates full nginx server block
2. Let's Encrypt SSL — Auto-obtains and configures HTTPS certificates
3. Load balancing — Distribute traffic across multiple backend servers
4. WebSocket support — Proxy WebSocket connections for real-time apps
5. Rate limiting — Protect backends from request floods
6. Security headers — HSTS, X-Frame-Options, X-Content-Type-Options by default
7. Health monitoring — Check nginx, SSL expiry, and upstream health
8. Auto-renewal — Cron job for automatic SSL certificate renewal
9. Backup/restore — Full config backup and one-command restore
10. Multi-OS support — Ubuntu, Debian, CentOS, Fedora, RHEL
