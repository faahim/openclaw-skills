---
name: docker-manager
description: >-
  Manage Docker containers, images, volumes, and networks from your OpenClaw agent. Start, stop, inspect, clean up, and monitor containers with simple commands.
categories: [dev-tools, automation]
dependencies: [docker, bash, jq, curl]
---

# Docker Manager

## What This Does

Manage your entire Docker environment through your OpenClaw agent. Start/stop containers, deploy compose stacks, monitor resource usage, clean up unused images and volumes, and get alerts when containers crash or use too much memory. No more SSH-ing into servers to run docker commands manually.

**Example:** "Deploy my compose stack, monitor all containers, alert me on Telegram if anything crashes or exceeds 80% memory."

## Quick Start (2 minutes)

### 1. Check Docker is Available

```bash
bash scripts/docker-manager.sh status
```

Output:
```
🐳 Docker Manager Status
Docker Version: 24.0.7
Containers: 5 running, 2 stopped
Images: 12 (3.2 GB)
Volumes: 8
Networks: 4
Disk Usage: 5.1 GB total
```

### 2. List All Containers

```bash
bash scripts/docker-manager.sh list
```

Output:
```
CONTAINER        IMAGE              STATUS          CPU    MEM     PORTS
nginx-proxy      nginx:alpine       Up 3 days       0.1%   12MB    80,443
postgres-db      postgres:16        Up 3 days       0.3%   85MB    5432
redis-cache      redis:7            Up 3 days       0.1%   8MB     6379
app-worker       myapp:latest       Up 1 hour       2.1%   256MB   -
```

### 3. Monitor Containers

```bash
bash scripts/docker-manager.sh monitor --interval 60 --alert telegram
```

## Core Workflows

### Workflow 1: Container Lifecycle

```bash
# Start a container
bash scripts/docker-manager.sh run --name my-redis --image redis:7-alpine --port 6379:6379 --restart always

# Stop a container
bash scripts/docker-manager.sh stop my-redis

# Restart a container
bash scripts/docker-manager.sh restart my-redis

# View logs (last 100 lines)
bash scripts/docker-manager.sh logs my-redis --tail 100

# View logs (follow)
bash scripts/docker-manager.sh logs my-redis --follow

# Execute command in container
bash scripts/docker-manager.sh exec my-redis "redis-cli ping"

# Remove container
bash scripts/docker-manager.sh rm my-redis --force
```

### Workflow 2: Docker Compose Management

```bash
# Deploy a compose stack
bash scripts/docker-manager.sh compose-up /path/to/docker-compose.yml

# Bring down a stack
bash scripts/docker-manager.sh compose-down /path/to/docker-compose.yml

# View compose stack status
bash scripts/docker-manager.sh compose-status /path/to/docker-compose.yml

# Pull latest images and redeploy
bash scripts/docker-manager.sh compose-update /path/to/docker-compose.yml
```

### Workflow 3: Cleanup & Disk Management

```bash
# Show disk usage breakdown
bash scripts/docker-manager.sh disk

# Remove unused images (dangling)
bash scripts/docker-manager.sh prune images

# Remove stopped containers
bash scripts/docker-manager.sh prune containers

# Remove unused volumes (CAREFUL — data loss)
bash scripts/docker-manager.sh prune volumes

# Full cleanup (images + containers + volumes + networks)
bash scripts/docker-manager.sh prune all

# Remove images older than 30 days
bash scripts/docker-manager.sh prune images --older-than 30d
```

### Workflow 4: Container Monitoring & Alerts

```bash
# One-shot health check
bash scripts/docker-manager.sh health

# Continuous monitoring (check every 60s)
bash scripts/docker-manager.sh monitor --interval 60

# Monitor with Telegram alerts
bash scripts/docker-manager.sh monitor --interval 60 --alert telegram

# Monitor with memory threshold (alert at 80%)
bash scripts/docker-manager.sh monitor --interval 60 --mem-threshold 80 --alert telegram

# Monitor specific containers only
bash scripts/docker-manager.sh monitor --containers "nginx,postgres,app" --interval 30
```

Output on crash detection:
```
🚨 ALERT: Container 'app-worker' exited unexpectedly (exit code 137 — OOMKilled)
   Image: myapp:latest
   Uptime before crash: 2h 15m
   Last 5 log lines:
     [ERROR] Out of memory allocating 1048576 bytes
     [FATAL] Process killed by kernel OOM killer
   Action: Consider increasing memory limit (currently 512MB)
```

### Workflow 5: Image Management

```bash
# List images with sizes
bash scripts/docker-manager.sh images

# Pull latest version of an image
bash scripts/docker-manager.sh pull nginx:alpine

# Check for image updates
bash scripts/docker-manager.sh check-updates

# Remove a specific image
bash scripts/docker-manager.sh rmi nginx:1.24

# Build image from Dockerfile
bash scripts/docker-manager.sh build --tag myapp:latest --path /path/to/project
```

### Workflow 6: Network & Volume Management

```bash
# List networks
bash scripts/docker-manager.sh networks

# Create a network
bash scripts/docker-manager.sh network-create my-network --driver bridge

# List volumes with sizes
bash scripts/docker-manager.sh volumes

# Inspect a volume
bash scripts/docker-manager.sh volume-inspect my-data

# Backup a volume to tar
bash scripts/docker-manager.sh volume-backup my-data /backups/my-data-$(date +%Y%m%d).tar.gz
```

## Configuration

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Docker host (optional — defaults to local socket)
export DOCKER_HOST="tcp://remote-server:2375"

# Memory alert threshold (default: 80%)
export DOCKER_MEM_THRESHOLD=80

# CPU alert threshold (default: 90%)
export DOCKER_CPU_THRESHOLD=90
```

### Monitoring Config File (Optional)

```yaml
# docker-monitor.yaml
interval: 60
alerts:
  - type: telegram
    chat_id: 123456
thresholds:
  memory: 80
  cpu: 90
containers:
  - name: nginx
    critical: true
  - name: postgres
    critical: true
  - name: worker
    critical: false
```

```bash
bash scripts/docker-manager.sh monitor --config docker-monitor.yaml
```

## Advanced Usage

### Run as Cron Job (Periodic Health Check)

```bash
# Health check every 5 minutes, alert on issues
*/5 * * * * cd /path/to/skill && bash scripts/docker-manager.sh health --alert telegram >> /var/log/docker-health.log 2>&1
```

### Auto-Restart Crashed Containers

```bash
bash scripts/docker-manager.sh monitor --interval 30 --auto-restart --alert telegram
```

### Generate Docker Report

```bash
bash scripts/docker-manager.sh report
```

Output: Markdown report with container status, resource usage, disk usage, recent events.

## Troubleshooting

### Issue: "permission denied" when running docker

**Fix:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in, or:
newgrp docker
```

### Issue: "Cannot connect to Docker daemon"

**Fix:**
```bash
# Check Docker is running
sudo systemctl status docker
# Start if stopped
sudo systemctl start docker
```

### Issue: Disk space full from Docker

**Fix:**
```bash
# See what's using space
bash scripts/docker-manager.sh disk
# Nuclear option — remove everything unused
bash scripts/docker-manager.sh prune all
```

## Key Principles

1. **Safe by default** — Destructive operations require `--force` flag
2. **Clear output** — Human-readable tables, not raw JSON
3. **Alert once** — Won't spam on repeated failures (tracks alert state)
4. **Composable** — Each command works standalone or in scripts
