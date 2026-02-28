# Listing Copy: Proxmox VE Manager

## Metadata
- **Type:** Skill
- **Name:** proxmox-manager
- **Display Name:** Proxmox VE Manager
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [curl, jq, bash]
- **Icon:** 🖥️

## Tagline
Manage Proxmox VMs & containers from the terminal — start, stop, snapshot, backup, monitor

## Description

Managing Proxmox VE through the web UI is fine — until you need to automate snapshots, check VM health at 3am, or batch-operate on a dozen containers. Context-switching between terminal and browser kills your flow.

Proxmox VE Manager gives your OpenClaw agent full control over your Proxmox cluster via the REST API. Start/stop VMs, create snapshots with automatic pruning, run backups, monitor resource usage, check health with Telegram alerts, and create new VMs/containers — all from a single bash script.

**What it does:**
- 🖥️ Full VM/CT lifecycle — start, stop, restart, suspend, resume
- 📸 Snapshot management — create, rollback, prune old snapshots automatically
- 💾 Backup with compression — vzdump to any storage, zstd/gzip/lzo
- 📊 Resource monitoring — CPU, RAM, disk, uptime for nodes and guests
- 🔔 Health checks with Telegram alerts — know when VMs go down
- 🚚 Live migration between cluster nodes
- 🏗️ Create VMs and LXC containers from templates
- 📋 JSON output for scripting and automation

**Perfect for** homelab enthusiasts, sysadmins, and DevOps engineers who want their OpenClaw agent to manage Proxmox infrastructure without touching the web UI.

## Core Capabilities

1. VM/CT lifecycle management — start, stop, restart, suspend, resume any guest
2. Snapshot automation — create, list, rollback, delete, auto-prune old snapshots
3. Backup management — vzdump with compression, list/restore backups
4. Cluster monitoring — CPU, RAM, disk, swap usage per node
5. Per-guest resource tracking — live CPU/RAM usage across all running guests
6. Health checks — verify critical VMs are running, alert via Telegram
7. Container creation — spin up LXC containers from templates
8. VM creation — create QEMU VMs with ISO, networking, storage
9. Live migration — move VMs between cluster nodes with zero downtime
10. API token auth — secure, no password storage needed
11. JSON output — pipe into jq for custom automation
12. Cron-ready — schedule snapshots, backups, health checks

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`

## Installation Time
**5 minutes** — copy config, set API token, run
