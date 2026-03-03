# Listing Copy: Dozzle Log Viewer

## Metadata
- **Type:** Skill
- **Name:** dozzle-log-viewer
- **Display Name:** Dozzle Log Viewer
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [docker, bash, curl]
- **Icon:** 📋

## Tagline

"Deploy Dozzle — real-time Docker container log viewer with a beautiful web UI"

## Description

Debugging Docker containers shouldn't mean juggling `docker logs` across dozens of terminals. Dozzle gives you a single, beautiful web dashboard that streams logs from all your containers in real-time — with zero storage overhead.

This skill deploys and manages Dozzle with one command. It handles Docker socket mounting, authentication setup, custom ports, container filtering, remote host monitoring, and reverse proxy configuration. Update, check status, or remove with dedicated scripts.

**What it does:**
- 🚀 One-command deploy with sensible defaults
- 🔐 Optional username/password authentication
- 🌐 Multi-host monitoring (remote Docker hosts, Swarm)
- 🔍 Filter logs by container name or label
- ⚡ Real-time WebSocket streaming — no polling
- 📊 Status checks with health monitoring and resource usage
- 🔄 Zero-downtime updates preserving your configuration
- 🧹 Clean removal with optional image cleanup

**Zero overhead:** Dozzle is ~10MB, uses minimal CPU/RAM, and stores nothing on disk. It reads directly from the Docker socket.

Perfect for developers, sysadmins, and homelab enthusiasts who run Docker containers and need fast, frictionless log access.

## Quick Start Preview

```bash
bash scripts/deploy.sh
# ✅ Dozzle is running!
#    🌐 URL: http://192.168.1.100:8080

# With auth:
bash scripts/deploy.sh --auth --user admin --password secret

# Custom port:
bash scripts/deploy.sh --port 9090
```

## Core Capabilities

1. One-command deployment — Running in under 60 seconds
2. Real-time log streaming — WebSocket-based, no page refresh needed
3. Authentication support — Protect with username/password
4. Multi-host monitoring — View logs from remote Docker hosts
5. Container filtering — Show only containers you care about
6. Reverse proxy ready — Works behind Nginx/Caddy/Traefik
7. Auto-restart — Survives server reboots
8. Zero-downtime updates — Pull latest, recreate with same config
9. Resource monitoring — CPU and memory usage in status checks
10. Clean removal — One command to tear down everything

## Installation Time
**Under 2 minutes** — Pull image, run container, open browser
