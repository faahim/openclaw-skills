# Listing Copy: Docker Manager

## Metadata
- **Type:** Skill
- **Name:** docker-manager
- **Display Name:** Docker Manager
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [docker, bash, jq, curl]
- **Icon:** 🐳

## Tagline
Manage Docker containers, images, and stacks — monitor resources, auto-restart crashes, clean up disk

## Description

Manually SSH-ing into servers to check containers, restart crashed services, or clean up disk space is tedious and error-prone. When a container silently OOMs at 3am, you find out from angry users — not from your tooling.

Docker Manager gives your OpenClaw agent full control over your Docker environment. List containers with live CPU/memory stats, deploy and update Compose stacks, monitor for crashes with auto-restart, and prune unused images before your disk fills up. Get Telegram alerts when containers crash or exceed memory thresholds.

**What it does:**
- 🐳 Full container lifecycle — run, stop, restart, remove, logs, exec
- 📦 Compose stack management — deploy, update, tear down
- 📊 Live resource monitoring with CPU/memory stats
- 🚨 Crash detection with Telegram alerts and auto-restart
- 🧹 Disk cleanup — prune images, volumes, containers by age
- 💾 Volume backup to tar.gz archives
- 🔄 Image update checking across all running containers
- 📋 Full environment reports in markdown

**Who it's for:** Developers, sysadmins, and indie hackers running Docker on VPS, homelab, or local dev — anyone who wants their agent to manage containers instead of doing it manually.

## Core Capabilities

1. Container lifecycle — Start, stop, restart, remove containers with simple commands
2. Live stats dashboard — CPU, memory, ports, uptime for all running containers
3. Compose management — Deploy, update, and tear down multi-container stacks
4. Crash monitoring — Detect exited containers, OOMKills, and unexpected restarts
5. Telegram alerts — Get notified instantly when containers crash or exceed thresholds
6. Auto-restart — Automatically restart crashed containers (optional)
7. Disk management — See what's using space, prune by type or age
8. Volume backup — Backup Docker volumes to compressed tar archives
9. Image updates — Check all images for newer versions upstream
10. Environment reports — Generate full markdown reports of your Docker setup
11. Resource thresholds — Configure CPU/memory alert thresholds per container
12. Safe defaults — Destructive operations require explicit --force flag

## Quick Start Preview

```bash
# Check Docker status
bash scripts/docker-manager.sh status

# List containers with live stats
bash scripts/docker-manager.sh list

# Monitor with alerts
bash scripts/docker-manager.sh monitor --interval 60 --alert telegram

# Cleanup unused images
bash scripts/docker-manager.sh prune images --older-than 30d
```

## Dependencies
- `docker` (Docker Engine 20+)
- `bash` (4.0+)
- `jq` (JSON processing)
- `curl` (for Telegram alerts)
- `bc` (math — usually preinstalled)

## Installation Time
**2 minutes** — Just needs Docker installed
