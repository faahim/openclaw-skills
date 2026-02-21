---
name: nginx-reverse-proxy
description: >-
  Install and configure Nginx as a reverse proxy with SSL termination, load balancing, and auto-renewal.
categories: [dev-tools, automation]
dependencies: [nginx, certbot, openssl]
---

# Nginx Reverse Proxy

## What This Does

Set up Nginx as a reverse proxy for your web apps in minutes. Handles SSL certificates (Let's Encrypt), load balancing across multiple backends, WebSocket proxying, and automatic config generation. No manual nginx.conf editing — just tell the agent what you need.

**Example:** "Proxy api.example.com to localhost:3000 with SSL, and app.example.com to localhost:8080 with WebSocket support."

## Quick Start (5 minutes)

### 1. Install Nginx + Certbot

```bash
bash scripts/install.sh
```

This installs nginx, certbot, and the nginx certbot plugin. Works on Ubuntu/Debian and RHEL/CentOS/Fedora.

### 2. Add Your First Proxy

```bash
bash scripts/proxy.sh add \
  --domain api.example.com \
  --upstream 127.0.0.1:3000 \
  --ssl
```

This will:
- Create an nginx server block for `api.example.com`
- Obtain a Let's Encrypt SSL certificate
- Configure HTTPS redirect
- Reload nginx

### 3. Verify

```bash
bash scripts/proxy.sh status
```

Output:
```
DOMAIN                  UPSTREAM           SSL    STATUS
api.example.com         127.0.0.1:3000     ✅     active
```

## Core Workflows

### Workflow 1: Simple Reverse Proxy (No SSL)

```bash
bash scripts/proxy.sh add \
  --domain myapp.local \
  --upstream 127.0.0.1:8080
```

### Workflow 2: HTTPS with Let's Encrypt

```bash
bash scripts/proxy.sh add \
  --domain myapp.example.com \
  --upstream 127.0.0.1:3000 \
  --ssl \
  --email admin@example.com
```

### Workflow 3: Load Balancing

```bash
bash scripts/proxy.sh add \
  --domain api.example.com \
  --upstream 127.0.0.1:3001,127.0.0.1:3002,127.0.0.1:3003 \
  --ssl \
  --lb-method least_conn
```

Load balancing methods: `round_robin` (default), `least_conn`, `ip_hash`.

### Workflow 4: WebSocket Support

```bash
bash scripts/proxy.sh add \
  --domain ws.example.com \
  --upstream 127.0.0.1:4000 \
  --websocket \
  --ssl
```

### Workflow 5: Custom Headers & Rate Limiting

```bash
bash scripts/proxy.sh add \
  --domain api.example.com \
  --upstream 127.0.0.1:3000 \
  --ssl \
  --rate-limit 10r/s \
  --add-header "X-Frame-Options: DENY" \
  --add-header "X-Content-Type-Options: nosniff"
```

### Workflow 6: Remove a Proxy

```bash
bash scripts/proxy.sh remove --domain api.example.com
```

### Workflow 7: Renew All SSL Certificates

```bash
bash scripts/proxy.sh renew
```

Set up auto-renewal:
```bash
bash scripts/proxy.sh setup-renewal
# Adds crontab: 0 3 * * * certbot renew --quiet --post-hook "systemctl reload nginx"
```

## Configuration

### Config Directory Structure

```
/etc/nginx/
├── nginx.conf                    # Main config (managed by install.sh)
├── sites-available/              # All proxy configs
│   ├── api.example.com.conf
│   └── app.example.com.conf
├── sites-enabled/                # Symlinks to active configs
│   ├── api.example.com.conf -> ../sites-available/api.example.com.conf
│   └── app.example.com.conf -> ../sites-available/app.example.com.conf
└── snippets/
    ├── ssl-params.conf           # Shared SSL settings
    └── proxy-params.conf         # Shared proxy headers
```

### Environment Variables

```bash
# Default email for Let's Encrypt (optional)
export CERTBOT_EMAIL="admin@example.com"

# Custom nginx config path (default: /etc/nginx)
export NGINX_CONF_DIR="/etc/nginx"

# Dry run mode (test without making changes)
export DRY_RUN=true
```

## Advanced Usage

### Custom Nginx Config

For complex setups, generate a template and edit:

```bash
bash scripts/proxy.sh template --domain api.example.com --upstream 127.0.0.1:3000 > custom.conf
# Edit custom.conf as needed
sudo cp custom.conf /etc/nginx/sites-available/api.example.com.conf
sudo ln -sf /etc/nginx/sites-available/api.example.com.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Multiple Upstreams with Weights

```bash
bash scripts/proxy.sh add \
  --domain api.example.com \
  --upstream "127.0.0.1:3001 weight=3,127.0.0.1:3002 weight=1" \
  --ssl
```

### Health Checks

```bash
bash scripts/proxy.sh health --domain api.example.com
```

Output:
```
Domain: api.example.com
  Nginx: ✅ running
  SSL: ✅ valid (expires 2026-08-21, 181 days)
  Upstream 127.0.0.1:3000: ✅ responding (HTTP 200, 45ms)
```

### Backup & Restore

```bash
# Backup all configs
bash scripts/proxy.sh backup
# Creates /etc/nginx/backups/nginx-backup-2026-02-21.tar.gz

# Restore from backup
bash scripts/proxy.sh restore --file /etc/nginx/backups/nginx-backup-2026-02-21.tar.gz
```

## Troubleshooting

### Issue: "nginx: [emerg] bind() to 0.0.0.0:80 failed"

**Fix:** Another process is using port 80.
```bash
sudo lsof -i :80
# Kill the process or change its port
```

### Issue: Certbot fails with "Could not bind TCP port 80"

**Fix:** Nginx must be running for the webroot challenge:
```bash
sudo systemctl start nginx
bash scripts/proxy.sh add --domain example.com --upstream 127.0.0.1:3000 --ssl
```

### Issue: 502 Bad Gateway

**Fix:** Your upstream app isn't running or is on the wrong port:
```bash
curl -s http://127.0.0.1:3000  # Test upstream directly
```

### Issue: SSL certificate not renewing

**Fix:** Check certbot timer:
```bash
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

## Security Defaults

All generated configs include:
- TLS 1.2+ only (no SSLv3, TLS 1.0/1.1)
- Strong cipher suite (ECDHE + AES-GCM preferred)
- HSTS header (max-age=31536000)
- X-Frame-Options, X-Content-Type-Options headers
- Rate limiting (configurable)
- Proxy header forwarding (X-Real-IP, X-Forwarded-For, X-Forwarded-Proto)

## Dependencies

- `nginx` (1.18+)
- `certbot` + `python3-certbot-nginx`
- `openssl` (for SSL checks)
- `curl` (for health checks)
- Root/sudo access required
