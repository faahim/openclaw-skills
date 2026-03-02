# Listing Copy: Ctop Container Monitor

## Metadata
- **Type:** Skill
- **Name:** ctop-monitor
- **Display Name:** Ctop Container Monitor
- **Categories:** [dev-tools, automation]
- **Icon:** 🐳
- **Dependencies:** [docker, ctop, curl, jq]

## Tagline
Real-time Docker container monitoring — CPU, memory, network alerts at a glance

## Description

Running Docker containers without monitoring is flying blind. By the time you notice a memory leak or CPU spike, your app is already struggling. You need visibility into container health — without paying $50/mo for enterprise monitoring.

Ctop Container Monitor gives your OpenClaw agent eyes on every running container. It installs `ctop` for a beautiful terminal dashboard, plus includes automated monitoring scripts that check CPU, memory, and network usage against your thresholds. Exceed a limit? Get an instant Telegram alert. Container going haywire? Auto-restart it with configurable cooldowns.

**What it does:**
- 📊 Interactive terminal dashboard for all containers (like htop for Docker)
- ⚠️ Configurable CPU and memory warning/critical thresholds
- 🔔 Instant alerts via Telegram, Slack webhook, or stdout
- 🔄 Auto-restart containers that exceed resource limits
- 📈 CSV logging for historical resource tracking and capacity planning
- 🔍 Filter monitoring by Docker Compose project or container labels
- ⏱️ Cron-ready one-shot mode for scheduled health checks

Perfect for developers and sysadmins running Docker in production, staging, or homelab environments who want reliable container monitoring without enterprise complexity.

## Quick Start Preview

```bash
# Install ctop
bash scripts/install.sh

# Interactive dashboard
ctop

# Automated monitoring with Telegram alerts
bash scripts/monitor.sh --cpu-warn 80 --mem-warn 85 --alert telegram
```

## Core Capabilities

1. Interactive terminal UI — Sort by CPU, memory, network; drill into container details
2. Threshold monitoring — Configurable warning and critical levels for CPU and memory
3. Multi-channel alerts — Telegram, Slack webhook, or custom webhook endpoints
4. Auto-restart — Restart containers exceeding critical thresholds with cooldown protection
5. Resource logging — CSV output for historical analysis and capacity planning
6. One-shot mode — Run as cron job for periodic health checks
7. Label filtering — Monitor specific Docker Compose projects or labeled containers
8. Cross-platform — Linux (amd64, arm64) with Docker socket access
9. Zero external services — Everything runs locally, no SaaS dependency
10. Status reports — One-command snapshot of all container resource usage

## Dependencies
- Docker Engine (running)
- `ctop` (installed by included script)
- `curl`, `jq`, `bc` (for monitoring scripts)

## Installation Time
**3 minutes** — Run installer, start monitoring
