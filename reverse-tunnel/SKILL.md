---
name: reverse-tunnel
description: >-
  Expose local services to the internet via secure tunnels using cloudflared, bore, or localtunnel.
categories: [dev-tools, automation]
dependencies: [bash, curl]
---

# Reverse Tunnel Manager

## What This Does

Expose local ports (dev servers, APIs, databases) to the internet through secure tunnels — no port forwarding, no firewall changes, no static IP needed. Supports three tunnel backends: **Cloudflare Tunnel** (production-grade), **bore** (simple, self-hostable), and **localtunnel** (zero-config).

**Example:** "Expose my local dev server on port 3000 to a public HTTPS URL for testing webhooks, sharing demos, or remote access."

## Quick Start (2 minutes)

### 1. Install a Tunnel Backend

```bash
# Option A: Cloudflare Tunnel (recommended for production)
bash scripts/install.sh cloudflared

# Option B: bore (lightweight, Rust-based)
bash scripts/install.sh bore

# Option C: localtunnel (Node.js, zero-config)
bash scripts/install.sh localtunnel
```

### 2. Expose a Local Port

```bash
# Expose port 3000 via cloudflared (auto-generates URL)
bash scripts/tunnel.sh start --backend cloudflared --port 3000

# Output:
# 🚇 Tunnel active: https://random-slug.trycloudflare.com → localhost:3000
# Press Ctrl+C to stop

# Expose with bore
bash scripts/tunnel.sh start --backend bore --port 3000

# Expose with localtunnel (custom subdomain)
bash scripts/tunnel.sh start --backend localtunnel --port 3000 --subdomain myapp
```

### 3. List Active Tunnels

```bash
bash scripts/tunnel.sh list
# ID      Backend      Local           Public URL                              Status
# t-001   cloudflared  localhost:3000  https://random-slug.trycloudflare.com   active
# t-002   bore         localhost:8080  bore.pub:54321                          active
```

## Core Workflows

### Workflow 1: Quick Dev Share

**Use case:** Share your local dev server with a teammate for 30 minutes

```bash
bash scripts/tunnel.sh start --backend cloudflared --port 3000
# Share the generated URL
# Tunnel auto-cleans up on Ctrl+C
```

### Workflow 2: Webhook Testing

**Use case:** Receive webhooks from Stripe/GitHub/Slack on your local machine

```bash
# Start tunnel with request logging
bash scripts/tunnel.sh start --backend cloudflared --port 8080 --log-requests

# Output:
# 🚇 Tunnel active: https://abc123.trycloudflare.com → localhost:8080
# [21:45:01] POST /webhook → 200 (12ms)
# [21:45:05] POST /webhook → 200 (8ms)
```

### Workflow 3: Named Cloudflare Tunnel (Persistent)

**Use case:** Production-grade tunnel with custom domain

```bash
# Login to Cloudflare (one-time)
cloudflared tunnel login

# Create named tunnel
bash scripts/tunnel.sh create --name my-api --port 8080

# Configure DNS (points myapi.yourdomain.com → tunnel)
bash scripts/tunnel.sh dns --name my-api --hostname myapi.yourdomain.com

# Run as systemd service
bash scripts/tunnel.sh service --name my-api --enable
```

### Workflow 4: Expose Multiple Ports

**Use case:** Frontend + API + database admin

```bash
# Start multiple tunnels
bash scripts/tunnel.sh start --backend cloudflared --port 3000 --name frontend &
bash scripts/tunnel.sh start --backend cloudflared --port 8080 --name api &
bash scripts/tunnel.sh start --backend cloudflared --port 5432 --name pgadmin &

# List all
bash scripts/tunnel.sh list
```

### Workflow 5: Self-Hosted bore Server

**Use case:** Run your own tunnel relay for privacy

```bash
# On your VPS (one-time setup)
bash scripts/install.sh bore
bore server --min-port 1024 --max-port 65535

# On your local machine
bash scripts/tunnel.sh start --backend bore --port 3000 --server your-vps.com
```

## Configuration

### Environment Variables

```bash
# Cloudflare (for named tunnels)
export CLOUDFLARE_TUNNEL_TOKEN="<token>"  # Optional: for pre-authenticated tunnels

# bore (self-hosted)
export BORE_SERVER="bore.pub"  # Default public server
export BORE_SECRET=""           # Optional: server secret

# Alerts (optional)
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"
```

### Config File (for persistent tunnels)

```yaml
# ~/.reverse-tunnel/config.yaml
tunnels:
  - name: dev-server
    backend: cloudflared
    local_port: 3000
    auto_start: true

  - name: api
    backend: bore
    local_port: 8080
    server: bore.pub

  - name: webhook-receiver
    backend: localtunnel
    local_port: 9000
    subdomain: my-webhooks
```

```bash
# Start all configured tunnels
bash scripts/tunnel.sh start-all --config ~/.reverse-tunnel/config.yaml
```

## Advanced Usage

### Run as Background Service

```bash
# Create systemd service for a tunnel
bash scripts/tunnel.sh service --backend cloudflared --port 3000 --name myapp --enable

# Manage service
systemctl status tunnel-myapp
systemctl stop tunnel-myapp
systemctl start tunnel-myapp
```

### Auto-Restart on Failure

```bash
# Built into the tunnel script
bash scripts/tunnel.sh start --backend cloudflared --port 3000 --restart-on-fail --max-retries 5
```

### Notify on Tunnel URL Change

```bash
# Get Telegram alert when tunnel URL changes (cloudflared quick tunnels)
bash scripts/tunnel.sh start --backend cloudflared --port 3000 --notify telegram
```

## Troubleshooting

### Issue: "cloudflared: command not found"

**Fix:**
```bash
bash scripts/install.sh cloudflared
# Or manually:
# Linux: curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$(dpkg --print-architecture) -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared
# Mac: brew install cloudflared
```

### Issue: "bore: command not found"

**Fix:**
```bash
bash scripts/install.sh bore
# Or: cargo install bore-cli
```

### Issue: Tunnel disconnects frequently

**Fix:** Use `--restart-on-fail` flag or run as systemd service for auto-recovery.

### Issue: Port already in use

**Check:**
```bash
lsof -i :<port>
# Kill the process or use a different port
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- One of: `cloudflared`, `bore`, or `localtunnel` (installed via scripts/install.sh)
- Optional: `jq` (for JSON output), `systemd` (for service management)
