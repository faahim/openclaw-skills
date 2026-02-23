---
name: caddy-server
description: >-
  Install and manage Caddy web server with automatic HTTPS, reverse proxy, and virtual hosts.
categories: [dev-tools, automation]
dependencies: [bash, curl]
---

# Caddy Web Server Manager

## What This Does

Install, configure, and manage [Caddy](https://caddyserver.com) — a modern web server with **automatic HTTPS** (via Let's Encrypt), reverse proxy, static file serving, and load balancing. No manual SSL cert management needed.

**Why Caddy over Nginx?** Automatic HTTPS by default, simpler config syntax (Caddyfile), zero-downtime reloads, and built-in ACME client. Perfect for developers who want "it just works" HTTPS.

## Quick Start (5 minutes)

### 1. Install Caddy

```bash
bash scripts/install.sh
```

This installs Caddy via the official package repo (Debian/Ubuntu/RHEL/Fedora) or direct binary download.

### 2. Serve a Static Site

```bash
bash scripts/manage.sh serve --domain example.com --root /var/www/html
# Caddy automatically provisions HTTPS via Let's Encrypt
```

### 3. Reverse Proxy

```bash
bash scripts/manage.sh proxy --domain app.example.com --upstream localhost:3000
# HTTPS auto-configured, requests forwarded to your app
```

## Core Workflows

### Workflow 1: Static Site with Auto-HTTPS

```bash
# Serve files from a directory with automatic HTTPS
bash scripts/manage.sh serve \
  --domain mysite.com \
  --root /var/www/mysite

# Output:
# ✅ Added site: mysite.com → /var/www/mysite
# ✅ Caddy reloaded — HTTPS will auto-provision
```

### Workflow 2: Reverse Proxy (App Behind Caddy)

```bash
# Proxy requests to a backend app (Node, Python, Go, etc.)
bash scripts/manage.sh proxy \
  --domain api.mysite.com \
  --upstream localhost:8080

# With multiple upstreams (load balancing):
bash scripts/manage.sh proxy \
  --domain api.mysite.com \
  --upstream localhost:8080 \
  --upstream localhost:8081
```

### Workflow 3: Multiple Sites (Virtual Hosts)

```bash
# Add multiple sites
bash scripts/manage.sh proxy --domain app1.example.com --upstream localhost:3000
bash scripts/manage.sh proxy --domain app2.example.com --upstream localhost:4000
bash scripts/manage.sh serve --domain docs.example.com --root /var/www/docs

# List all configured sites
bash scripts/manage.sh list
```

### Workflow 4: SPA (Single Page App) Hosting

```bash
# Serve a React/Vue/Next.js static export with proper routing
bash scripts/manage.sh spa \
  --domain app.example.com \
  --root /var/www/app/dist
# All routes fall back to index.html
```

### Workflow 5: File Server with Directory Listing

```bash
bash scripts/manage.sh fileserver \
  --domain files.example.com \
  --root /home/user/shared \
  --browse
```

### Workflow 6: Redirect HTTP → HTTPS (or Domain → Domain)

```bash
bash scripts/manage.sh redirect \
  --from www.example.com \
  --to example.com
```

## Configuration

### Caddyfile Location

```
/etc/caddy/Caddyfile
```

### Manual Caddyfile Editing

```bash
# View current config
bash scripts/manage.sh show

# Edit Caddyfile directly
sudo nano /etc/caddy/Caddyfile

# Validate and reload
bash scripts/manage.sh validate
bash scripts/manage.sh reload
```

### Example Caddyfile

```
# Reverse proxy with headers
app.example.com {
    reverse_proxy localhost:3000 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
    }
}

# Static site with compression
docs.example.com {
    root * /var/www/docs
    encode gzip zstd
    file_server
}

# SPA with fallback
spa.example.com {
    root * /var/www/spa
    encode gzip zstd
    try_files {path} /index.html
    file_server
}
```

## Management Commands

```bash
# Service management
bash scripts/manage.sh status       # Check if Caddy is running
bash scripts/manage.sh start        # Start Caddy
bash scripts/manage.sh stop         # Stop Caddy
bash scripts/manage.sh restart      # Restart Caddy
bash scripts/manage.sh reload       # Zero-downtime config reload

# Site management
bash scripts/manage.sh list         # List configured sites
bash scripts/manage.sh remove --domain app.example.com  # Remove a site
bash scripts/manage.sh show         # Show current Caddyfile

# Diagnostics
bash scripts/manage.sh validate     # Validate Caddyfile syntax
bash scripts/manage.sh logs         # Show Caddy logs
bash scripts/manage.sh certs        # List managed SSL certificates
```

## Advanced Usage

### Basic Auth

```bash
bash scripts/manage.sh auth \
  --domain admin.example.com \
  --upstream localhost:8080 \
  --user admin \
  --password secret123
```

### Rate Limiting (via Caddy module)

```bash
# Add rate limiting to a site
bash scripts/manage.sh ratelimit \
  --domain api.example.com \
  --rate "100r/m"
```

### Custom Headers

Add to Caddyfile manually:
```
api.example.com {
    header {
        Access-Control-Allow-Origin *
        X-Frame-Options DENY
        Content-Security-Policy "default-src 'self'"
    }
    reverse_proxy localhost:3000
}
```

### Wildcard Certs (via DNS challenge)

```bash
bash scripts/manage.sh wildcard \
  --domain "*.example.com" \
  --dns-provider cloudflare \
  --dns-token "your-cf-api-token"
```

## Troubleshooting

### Issue: "permission denied" on install

```bash
# Run install with sudo
sudo bash scripts/install.sh
```

### Issue: Port 80/443 already in use

```bash
# Check what's using the ports
sudo ss -tlnp | grep -E ':80|:443'

# Stop conflicting service (e.g., Nginx, Apache)
sudo systemctl stop nginx
sudo systemctl stop apache2
```

### Issue: SSL certificate not provisioning

1. DNS must point to your server's IP
2. Ports 80 and 443 must be open
3. Check logs: `bash scripts/manage.sh logs`

### Issue: "Caddyfile syntax error"

```bash
bash scripts/manage.sh validate
# Shows exact line and error
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `systemctl` (for service management, Linux)
- Root/sudo access (for binding ports 80/443)

## Key Principles

1. **Auto-HTTPS** — Caddy handles SSL automatically via Let's Encrypt/ZeroSSL
2. **Zero-downtime reloads** — Config changes don't drop connections
3. **Simple syntax** — Caddyfile is human-readable, not XML/JSON
4. **Secure defaults** — HTTPS, HSTS, modern TLS out of the box
