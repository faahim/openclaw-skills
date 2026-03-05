# Listing Copy: Lazydocker

## Metadata
- **Type:** Skill
- **Name:** lazydocker
- **Display Name:** Lazydocker — Terminal Docker Manager
- **Categories:** [dev-tools, automation]
- **Icon:** 🐳
- **Price:** $10
- **Dependencies:** [docker, curl, bash]

## Tagline

Manage Docker containers from your terminal — health checks, cleanup, logs, and live monitoring

## Description

Docker CLI commands are powerful but verbose. Between `docker ps`, `docker stats`, `docker logs`, and `docker system prune`, you're juggling a dozen commands just to keep things running. Add health checks and you're writing custom scripts every time.

**Lazydocker** installs the popular lazydocker terminal UI and adds automation scripts for the tasks you do every day: health dashboards, smart cleanup (with dry-run!), log tailing with grep, live resource monitoring, and container inspection. One install script handles OS/arch detection.

**What it does:**
- 🐳 One-command lazydocker installation (Linux/macOS, amd64/arm64)
- 📊 Container health dashboard — running, stopped, unhealthy at a glance
- 🧹 Smart cleanup — remove dangling images, volumes, build cache (dry-run supported)
- 📋 Log viewer with grep filtering and timestamp ranges
- 📈 Live CPU/memory/network stats per container
- 🔍 Container inspector — network, env, ports, mounts in one command
- 🔄 Auto-restart unhealthy containers
- ⏰ Cron-ready scripts for scheduled maintenance

Perfect for developers and sysadmins who run Docker in production or development and want fast, scriptable container management without memorizing format strings.

## Quick Start Preview

```bash
# Install lazydocker
bash scripts/install.sh

# Health dashboard
bash scripts/docker-health.sh

# Clean up unused resources
bash scripts/docker-cleanup.sh --dry-run

# Tail logs with error filtering
bash scripts/docker-logs.sh my-app --grep "error|500" --lines 200
```

## Dependencies
- `docker` (Docker Engine or Docker Desktop)
- `bash` (4.0+)
- `curl`
- `jq` (optional)

## Installation Time
**2 minutes** — run install script, start managing containers
