# Listing Copy: Process Manager

## Metadata
- **Type:** Skill
- **Name:** process-manager
- **Display Name:** Process Manager
- **Categories:** [dev-tools, automation]
- **Icon:** ⚙️
- **Dependencies:** [node, npm]

## Tagline

Manage long-running processes — auto-restart, log rotation, and boot persistence with PM2

## Description

Running background processes shouldn't require babysitting. Whether it's a web server, API, worker queue, or cron script — if it crashes at 3am, you need it back up automatically without manual intervention.

Process Manager wraps PM2 — the battle-tested process manager used on millions of production servers — into an agent-executable skill. Start any process (Node.js, Python, Bash, Go), configure auto-restart on crash or memory limits, rotate logs automatically, and persist everything across system reboots. One ecosystem config file manages your entire stack.

**What it does:**
- ⚙️ Start and manage any long-running process (Node, Python, Bash, binaries)
- 🔄 Auto-restart on crash with configurable retry limits and delays
- 📊 Real-time CPU/memory monitoring dashboard
- 📋 Automatic log rotation (daily, max 10MB, 30-day retention)
- 🔁 Cluster mode for zero-downtime reloads and load balancing
- 💾 Persist process list across reboots (startup scripts)
- ⏰ Cron-based scheduled restarts
- 👀 Watch mode for development (auto-restart on file change)
- 📁 Ecosystem config file for managing multiple services

Perfect for developers, sysadmins, and anyone running background services who needs reliable process management without systemd complexity.

## Quick Start Preview

```bash
# Install PM2
bash scripts/install.sh

# Start a process with auto-restart
bash scripts/run.sh start --name "api" --cmd "node server.js" --cwd /app

# Check status
bash scripts/run.sh status
# ┌────┬──────┬─────┬────────┬─────────┐
# │ id │ name │ pid │ status │ cpu/mem  │
# │ 0  │ api  │ 1234│ online │ 0.1/25M │
# └────┴──────┴─────┴────────┴─────────┘
```

## Core Capabilities

1. Process lifecycle — Start, stop, restart, reload, delete managed processes
2. Auto-restart — Automatically recover crashed processes with configurable limits
3. Memory limits — Restart processes that exceed memory thresholds
4. Cluster mode — Run multiple instances with zero-downtime reload
5. Log management — View, stream, flush, and auto-rotate process logs
6. Startup persistence — Survive reboots with generated startup scripts
7. Ecosystem configs — Define entire stack in one config file
8. Resource monitoring — Real-time CPU and memory dashboard
9. Watch mode — Auto-restart on file changes (development)
10. Cron restarts — Schedule periodic process restarts
11. Environment injection — Pass env vars per process
12. Multi-runtime — Node.js, Python, Bash, Go, any executable

## Dependencies
- `node` (14+) and `npm`
- `pm2` (auto-installed by install.sh)

## Installation Time
**3 minutes** — Run install.sh, start managing processes
