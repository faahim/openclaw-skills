# Listing Copy: Ngrok Tunnel Manager

## Metadata
- **Type:** Skill
- **Name:** ngrok-tunnel
- **Display Name:** Ngrok Tunnel Manager
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [bash, curl, jq, ngrok]

## Tagline

Expose local services to the internet — manage tunnels, inspect traffic, debug webhooks

## Description

Sharing a local dev server with a teammate or testing webhooks from external services means either deploying somewhere or punching holes in your firewall. Neither is fast.

Ngrok Tunnel Manager installs ngrok and wraps it in a clean CLI. Start HTTP, TCP, or TLS tunnels in one command. Protect them with basic auth or IP restrictions. Inspect every request and response that passes through. Replay failed webhooks for debugging without re-triggering them.

**What it does:**
- 🌐 Expose any local port with a public HTTPS URL
- 🔒 Basic auth and IP allowlists for security
- 📊 Inspect request/response traffic in real time
- 🔄 Replay captured requests for webhook debugging
- 🖥️ TCP tunnels for SSH, databases, game servers
- 🏠 Custom domains and named tunnel configs
- 🔧 Background mode with PID tracking and logs
- ⚡ Auto-installs ngrok for Linux (amd64/arm64) and Mac

Perfect for developers testing webhooks, sharing dev servers, demoing apps, or exposing home lab services.

## Quick Start Preview

```bash
# Expose local port 3000
bash scripts/tunnel.sh start --port 3000

# Output:
# ✅ Tunnel started
# 🌐 Public URL: https://abc123.ngrok-free.app
# 📊 Inspector: http://127.0.0.1:4040
```

## Core Capabilities

1. HTTP tunnels — Expose web servers with automatic HTTPS
2. TCP tunnels — Expose SSH, databases, any TCP service
3. Basic auth — Password-protect tunnels
4. Traffic inspection — View all request/response payloads
5. Request replay — Re-send captured requests for debugging
6. Background mode — Run tunnels as background processes
7. Named tunnels — Define and start tunnels from YAML config
8. IP restrictions — Allow only specific CIDRs
9. Custom domains — Use your own subdomain
10. Multi-platform — Linux (amd64/arm64) + macOS
