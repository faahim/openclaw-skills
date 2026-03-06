# Listing Copy: Beszel Server Monitor

## Metadata
- **Type:** Skill
- **Name:** beszel-monitor
- **Display Name:** Beszel Server Monitor
- **Categories:** [automation, analytics]
- **Icon:** 📊
- **Dependencies:** [docker, curl]

## Tagline
Monitor servers with historical data, Docker stats, and alerts — lightweight and self-hosted

## Description

Keeping tabs on your servers shouldn't require a heavyweight stack. Prometheus + Grafana works, but it eats 500MB+ of RAM and takes 30 minutes to configure. Most of us just want to know: is my server healthy, and alert me if it's not.

Beszel Server Monitor gives your OpenClaw agent the ability to deploy and manage Beszel — a modern, lightweight monitoring platform that uses ~50MB RAM. It tracks CPU, memory, disk, network, GPU, temperature, and per-container Docker/Podman stats with full historical data and a beautiful web dashboard.

**What you get:**
- 📊 Real-time dashboard with historical charts (30+ days)
- 🐳 Per-container Docker/Podman CPU, memory, and network stats
- 🔔 Configurable alerts via Telegram, Slack, email, webhooks, ntfy
- 👥 Multi-user support with OAuth/OIDC (Google, GitHub, etc.)
- 💾 Automatic S3-compatible backups
- 🖥️ GPU monitoring (Nvidia, AMD, Intel)
- 🌡️ Temperature sensors and SMART disk health
- ⚡ 5-minute setup via Docker or binary install

Perfect for developers, sysadmins, and homelabbers who want reliable server monitoring without the complexity of enterprise stacks.

## Quick Start Preview

```bash
# Deploy hub
bash scripts/install.sh --hub

# Deploy agent on monitored server
bash scripts/install.sh --agent --key "ssh-ed25519 AAAA..."

# Check status
bash scripts/install.sh --status
```

## Core Capabilities

1. Server resource monitoring — CPU, memory, swap, load average, disk usage & I/O
2. Docker/Podman stats — Per-container CPU, memory, and network tracking
3. Network monitoring — Bandwidth per interface with historical graphs
4. GPU monitoring — Nvidia, AMD, Intel usage and power draw
5. Temperature sensors — System thermal monitoring with alerts
6. SMART disk health — Drive health status including eMMC wear
7. Configurable alerts — Telegram, Slack, email, webhook, ntfy, Gotify
8. Historical data — 30+ days of metrics with interactive charts
9. Multi-user & OAuth — User isolation with Google/GitHub/OIDC auth
10. Automatic backups — S3-compatible backup with scheduled retention
11. Docker & binary install — Flexible deployment options
12. Reverse proxy ready — Nginx/Caddy configs included

## Installation Time
**5 minutes** — Run install script, create admin account, add agents
