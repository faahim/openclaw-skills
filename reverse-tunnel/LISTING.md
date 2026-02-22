# Listing Copy: Reverse Tunnel Manager

## Metadata
- **Type:** Skill
- **Name:** reverse-tunnel
- **Display Name:** Reverse Tunnel Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, cloudflared/bore/localtunnel]

## Tagline
Expose local ports to the internet — secure tunnels with zero config

## Description

Sharing a local dev server shouldn't require port forwarding, static IPs, or firewall changes. But every time you need to test webhooks, demo to a client, or access your home lab remotely, you're stuck fighting network config.

Reverse Tunnel Manager lets your OpenClaw agent spin up secure tunnels in seconds. Expose any local port to a public HTTPS URL using Cloudflare Tunnel (production-grade), bore (self-hostable), or localtunnel (zero-config). Manage multiple tunnels, run them as system services, and get notified when URLs change.

**What it does:**
- 🚇 Expose any local port to a public HTTPS URL
- 🔄 Three backends: Cloudflare Tunnel, bore, localtunnel
- 📋 Multi-tunnel management (start, stop, list)
- 🔧 Systemd service creation for persistent tunnels
- 🔔 Telegram notifications on tunnel events
- ⚡ Auto-restart on failure with configurable retries
- 🏠 Self-hosted option (run your own bore relay)
- 📝 YAML config for managing multiple tunnels

Perfect for developers testing webhooks, sharing demos, accessing home labs, or anyone who needs temporary or persistent public URLs for local services.

## Core Capabilities

1. Quick tunnel creation — One command to expose any port
2. Three backend options — Cloudflare, bore, localtunnel
3. Named tunnels — Persistent Cloudflare tunnels with custom domains
4. Multi-tunnel management — Run and track multiple tunnels
5. Systemd integration — Run tunnels as background services
6. Auto-restart — Recover from failures automatically
7. Request logging — See incoming traffic in real-time
8. Config-based — YAML config for reproducible tunnel setups
9. Self-hosted relay — Run your own bore server for privacy
10. Telegram alerts — Get notified on tunnel URL changes

## Dependencies
- `bash` (4.0+)
- `curl`
- One of: `cloudflared`, `bore`, `localtunnel` (auto-installed)

## Installation Time
**2 minutes** — Run install script, start tunneling
