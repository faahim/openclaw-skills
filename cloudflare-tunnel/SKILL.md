---
name: cloudflare-tunnel
description: >-
  Expose local services to the internet securely via Cloudflare Tunnels — no port forwarding, no public IP needed.
categories: [dev-tools, automation]
dependencies: [cloudflared, jq]
---

# Cloudflare Tunnel Manager

## What This Does

Securely expose local services (web apps, APIs, SSH, databases) to the internet through Cloudflare Tunnels without opening ports, configuring firewalls, or needing a public IP. Manages tunnel lifecycle: install, authenticate, create, route, monitor, and cleanup.

**Example:** "Expose my local Next.js dev server at localhost:3000 as myapp.example.com with automatic HTTPS."

## Quick Start (5 minutes)

### 1. Install cloudflared

```bash
bash scripts/install.sh
```

### 2. Authenticate with Cloudflare

```bash
bash scripts/run.sh auth
# Opens a browser URL — click to authorize, then the cert is saved locally
```

### 3. Create & Run a Tunnel

```bash
# Create a tunnel
bash scripts/run.sh create my-tunnel

# Route a hostname to your local service
bash scripts/run.sh route my-tunnel myapp.example.com

# Start the tunnel (forwards myapp.example.com → localhost:3000)
bash scripts/run.sh start my-tunnel --url localhost:3000
```

Your local service is now live at `https://myapp.example.com` with automatic HTTPS.

## Core Workflows

### Workflow 1: Expose a Web App

**Use case:** Make a local dev server publicly accessible

```bash
bash scripts/run.sh create webapp-tunnel
bash scripts/run.sh route webapp-tunnel app.yourdomain.com
bash scripts/run.sh start webapp-tunnel --url http://localhost:3000
```

**Output:**
```
✅ Tunnel webapp-tunnel created (id: a1b2c3d4-...)
✅ DNS route: app.yourdomain.com → webapp-tunnel
🚀 Tunnel running: app.yourdomain.com → http://localhost:3000
```

### Workflow 2: Expose SSH Access

**Use case:** SSH into a home server from anywhere

```bash
bash scripts/run.sh create ssh-tunnel
bash scripts/run.sh route ssh-tunnel ssh.yourdomain.com
bash scripts/run.sh start ssh-tunnel --url ssh://localhost:22
```

Then connect from anywhere:
```bash
# Client side (needs cloudflared installed)
ssh -o ProxyCommand="cloudflared access ssh --hostname ssh.yourdomain.com" user@ssh.yourdomain.com
```

### Workflow 3: Multi-Service Tunnel (Config File)

**Use case:** Expose multiple local services through one tunnel

```bash
# Copy and edit the config template
cp scripts/config-template.yaml tunnel-config.yaml
# Edit tunnel-config.yaml with your services

# Run with config
bash scripts/run.sh start my-tunnel --config tunnel-config.yaml
```

### Workflow 4: List & Monitor Tunnels

```bash
# List all tunnels
bash scripts/run.sh list

# Check tunnel status
bash scripts/run.sh status my-tunnel

# View tunnel metrics
bash scripts/run.sh metrics my-tunnel
```

### Workflow 5: Cleanup

```bash
# Stop a running tunnel
bash scripts/run.sh stop my-tunnel

# Delete tunnel and DNS routes
bash scripts/run.sh delete my-tunnel
```

## Configuration

### Multi-Service Config (YAML)

```yaml
# tunnel-config.yaml
tunnel: <TUNNEL_ID>
credentials-file: ~/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: app.example.com
    service: http://localhost:3000
  - hostname: api.example.com
    service: http://localhost:8080
  - hostname: grafana.example.com
    service: http://localhost:3001
  # Catch-all (required)
  - service: http_status:404
```

### Environment Variables

```bash
# Optional: Cloudflare API token (for programmatic management)
export CLOUDFLARE_API_TOKEN="<your-api-token>"

# Optional: custom config directory
export CLOUDFLARED_CONFIG_DIR="$HOME/.cloudflared"
```

## Advanced Usage

### Run as a System Service

```bash
# Install as systemd service (Linux)
bash scripts/run.sh service-install my-tunnel --config /path/to/config.yaml

# Manage the service
sudo systemctl status cloudflared-my-tunnel
sudo systemctl restart cloudflared-my-tunnel

# Uninstall service
bash scripts/run.sh service-uninstall my-tunnel
```

### Access Policies (Zero Trust)

```bash
# Require authentication for a hostname
bash scripts/run.sh protect app.example.com --policy email-domain:yourcompany.com
```

### Quick Temporary Tunnel (No DNS Setup)

```bash
# Get a random *.trycloudflare.com URL instantly
bash scripts/run.sh quick --url http://localhost:8080

# Output: https://random-words.trycloudflare.com → http://localhost:8080
```

## Troubleshooting

### Issue: "failed to connect to origin" 

**Check:** Is your local service actually running?
```bash
curl -s http://localhost:3000 > /dev/null && echo "Service is up" || echo "Service is DOWN"
```

### Issue: "Unable to establish connection" after DNS route

**Check:** DNS propagation can take up to 5 minutes. Verify:
```bash
dig +short app.example.com
```

### Issue: cloudflared auth fails

**Fix:** Delete stale cert and re-auth:
```bash
rm -f ~/.cloudflared/cert.pem
bash scripts/run.sh auth
```

### Issue: Permission denied on Linux

**Fix:** Run with sudo for service installation:
```bash
sudo bash scripts/run.sh service-install my-tunnel --config config.yaml
```

## Dependencies

- `cloudflared` (auto-installed by `scripts/install.sh`)
- `jq` (JSON parsing)
- `bash` (4.0+)
- A Cloudflare account with at least one domain (free tier works)

## Key Principles

1. **No port forwarding** — tunnels bypass NAT, firewalls, ISP blocks
2. **Automatic HTTPS** — Cloudflare handles SSL certificates
3. **Zero Trust ready** — add authentication policies to any exposed service
4. **One tunnel, many services** — route multiple hostnames through a single tunnel
5. **Persistent or temporary** — systemd service for production, quick tunnels for dev
