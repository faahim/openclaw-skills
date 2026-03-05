---
name: lazydocker
description: >-
  Install and manage Docker containers through lazydocker's terminal UI, plus CLI shortcuts for container health, log tailing, cleanup, and resource monitoring.
categories: [dev-tools, automation]
dependencies: [docker, curl, bash]
---

# Lazydocker — Terminal Docker Management

## What This Does

Installs **lazydocker** (a powerful terminal UI for Docker) and provides automation scripts for common Docker operations: container health checks, log monitoring, resource usage, bulk cleanup, and scheduled maintenance. Stop memorizing `docker ps -a --format` incantations.

**Example:** "Install lazydocker, show me all running containers with CPU/memory usage, clean up dangling images, tail logs from my web server container."

## Quick Start (2 minutes)

### 1. Install Lazydocker

```bash
bash scripts/install.sh
```

This auto-detects your OS/arch and installs the latest lazydocker binary.

### 2. Launch Terminal UI

```bash
lazydocker
```

Navigate with arrow keys. Press `enter` on containers to see logs, stats, config.

### 3. Use CLI Shortcuts

```bash
# Quick container health overview
bash scripts/docker-health.sh

# Cleanup unused resources (images, volumes, networks)
bash scripts/docker-cleanup.sh

# Tail logs from a container
bash scripts/docker-logs.sh <container-name> --lines 100

# Monitor resource usage (live)
bash scripts/docker-stats.sh

# Export container inspection as JSON
bash scripts/docker-inspect.sh <container-name>
```

## Core Workflows

### Workflow 1: Install Lazydocker

```bash
bash scripts/install.sh
```

**What it does:**
- Detects OS (Linux/macOS) and architecture (amd64/arm64)
- Downloads latest release from GitHub
- Installs to `/usr/local/bin/lazydocker` (or `~/.local/bin/` if no sudo)
- Verifies installation

**Output:**
```
Detecting system... Linux arm64
Downloading lazydocker v0.24.1...
Installing to /usr/local/bin/lazydocker...
✅ lazydocker v0.24.1 installed successfully
```

### Workflow 2: Container Health Dashboard

```bash
bash scripts/docker-health.sh
```

**Output:**
```
=== Docker Health Dashboard ===
Containers: 5 running, 2 stopped, 1 unhealthy
Images: 12 (3.2 GB total)
Volumes: 8 (1.1 GB total)
Networks: 4

CONTAINER         STATUS      CPU    MEM       HEALTH
nginx-proxy       Up 3d       0.1%   32MB      healthy
postgres-db       Up 3d       2.3%   256MB     healthy
redis-cache       Up 3d       0.5%   18MB      healthy
app-server        Up 1h       12.1%  512MB     healthy
worker-1          Up 1h       5.2%   128MB     —
old-test          Exited      —      —         —
broken-app        Exited(1)   —      —         unhealthy
```

### Workflow 3: Smart Cleanup

```bash
# Dry run (shows what would be removed)
bash scripts/docker-cleanup.sh --dry-run

# Actually clean up
bash scripts/docker-cleanup.sh

# Aggressive cleanup (includes stopped containers)
bash scripts/docker-cleanup.sh --aggressive
```

**Output:**
```
=== Docker Cleanup Report ===
Dangling images:     4 (892 MB) — REMOVED
Unused volumes:      2 (340 MB) — REMOVED
Stopped containers:  0 (skipped, use --aggressive)
Build cache:         156 MB — REMOVED
Total freed:         1.39 GB ✅
```

### Workflow 4: Live Resource Monitor

```bash
bash scripts/docker-stats.sh
```

**Output (updates every 2 seconds):**
```
CONTAINER         CPU %    MEM USAGE / LIMIT   MEM %   NET I/O         BLOCK I/O
nginx-proxy       0.12%    31.2MB / 2GB        1.56%   45.2MB / 12MB   8.1MB / 0B
postgres-db       2.31%    254MB / 4GB         6.35%   120MB / 85MB    2.3GB / 1.1GB
app-server        11.8%    510MB / 2GB         25.5%   890MB / 234MB   45MB / 12MB
```

### Workflow 5: Container Log Tailing

```bash
# Last 50 lines
bash scripts/docker-logs.sh nginx-proxy --lines 50

# Follow (like tail -f)
bash scripts/docker-logs.sh nginx-proxy --follow

# Filter for errors
bash scripts/docker-logs.sh nginx-proxy --grep "error\|ERROR\|500"

# Since timestamp
bash scripts/docker-logs.sh nginx-proxy --since "2026-03-01"
```

### Workflow 6: Container Inspection

```bash
# Full inspection as formatted JSON
bash scripts/docker-inspect.sh app-server

# Just the networking info
bash scripts/docker-inspect.sh app-server --network

# Just environment variables
bash scripts/docker-inspect.sh app-server --env

# Just port mappings
bash scripts/docker-inspect.sh app-server --ports
```

## Configuration

### Lazydocker Config

Lazydocker config lives at `~/.config/lazydocker/config.yml`:

```yaml
# Custom key bindings, update intervals, etc.
gui:
  scrollHeight: 2
  theme:
    activeBorderColor:
      - green
      - bold
  returnImmediately: false
update:
  dockerRefreshInterval: 100ms  # How often to refresh stats
reporting: "off"
```

### Environment Variables

```bash
# Docker socket (default: /var/run/docker.sock)
export DOCKER_HOST="unix:///var/run/docker.sock"

# For remote Docker hosts
export DOCKER_HOST="tcp://192.168.1.100:2376"
export DOCKER_TLS_VERIFY=1
```

## Advanced Usage

### Schedule Automated Cleanup

```bash
# Add to crontab — clean up every Sunday at 3am
(crontab -l 2>/dev/null; echo "0 3 * * 0 /path/to/scripts/docker-cleanup.sh >> /var/log/docker-cleanup.log 2>&1") | crontab -
```

### Monitor Container Health via OpenClaw Cron

Use with OpenClaw's cron system to get alerts:

```bash
# Run health check, alert if any container is unhealthy
bash scripts/docker-health.sh --json | jq '.unhealthy[]' 
```

### Restart Unhealthy Containers

```bash
# Auto-restart any container marked unhealthy
bash scripts/docker-health.sh --restart-unhealthy
```

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Fix:**
```bash
# Check Docker is running
sudo systemctl status docker

# Add user to docker group (avoids sudo)
sudo usermod -aG docker $USER
# Then log out and back in
```

### Issue: "lazydocker: command not found"

**Fix:**
```bash
# Check installation path
which lazydocker || echo "Not in PATH"

# Re-run install
bash scripts/install.sh

# Or add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: Permission denied on cleanup

**Fix:**
```bash
# Run with sudo if needed
sudo bash scripts/docker-cleanup.sh
```

## Dependencies

- `docker` (Docker Engine or Docker Desktop)
- `bash` (4.0+)
- `curl` (for installation)
- `jq` (optional, for JSON output)
