---
name: portainer-manager
description: >-
  Install, configure, and manage Portainer CE for Docker container management via CLI and API.
categories: [dev-tools, automation]
dependencies: [docker, curl, jq]
---

# Portainer Manager

## What This Does

Install and manage Portainer CE — the popular Docker management UI — entirely from the command line. Deploy Portainer, manage containers, stacks, images, volumes, and networks through Portainer's REST API without touching a browser.

**Example:** "Install Portainer, deploy a stack from a compose file, list running containers, check resource usage, manage users — all from the terminal."

## Quick Start (5 minutes)

### 1. Install Portainer CE

```bash
bash scripts/portainer.sh install
```

This creates a Portainer volume and starts the Portainer CE container on port 9443 (HTTPS) and 8000 (Edge agent).

### 2. Initialize Admin Account

```bash
bash scripts/portainer.sh init --password "YourSecurePassword123!"
```

Creates the admin user and stores the API token for subsequent commands.

### 3. Verify Installation

```bash
bash scripts/portainer.sh status
```

**Output:**
```
Portainer CE v2.21.x
Status: running
URL: https://localhost:9443
Endpoints: 1 (local)
Containers: 3 running, 0 stopped
Images: 5
Stacks: 0
```

## Core Workflows

### Workflow 1: List & Manage Containers

```bash
# List all containers
bash scripts/portainer.sh containers list

# Output:
# ID           NAME              IMAGE                STATUS     PORTS
# a1b2c3d4     portainer         portainer/portainer   running   9443/tcp, 8000/tcp
# e5f6g7h8     nginx-proxy       nginx:latest          running   80/tcp, 443/tcp
# i9j0k1l2     postgres-db       postgres:15           running   5432/tcp

# Start/stop/restart a container
bash scripts/portainer.sh containers stop nginx-proxy
bash scripts/portainer.sh containers start nginx-proxy
bash scripts/portainer.sh containers restart postgres-db

# View container logs
bash scripts/portainer.sh containers logs nginx-proxy --tail 50

# Inspect container details
bash scripts/portainer.sh containers inspect nginx-proxy
```

### Workflow 2: Deploy Stacks (Docker Compose)

```bash
# Deploy a stack from a compose file
bash scripts/portainer.sh stacks deploy --name my-app --file docker-compose.yml

# List stacks
bash scripts/portainer.sh stacks list

# Output:
# ID   NAME       STATUS    CONTAINERS
# 1    my-app     active    3
# 2    monitoring active    2

# Update a stack (re-deploy with new compose file)
bash scripts/portainer.sh stacks update --name my-app --file docker-compose.yml

# Remove a stack
bash scripts/portainer.sh stacks remove --name my-app
```

### Workflow 3: Manage Images

```bash
# List images
bash scripts/portainer.sh images list

# Pull an image
bash scripts/portainer.sh images pull nginx:latest

# Remove unused images
bash scripts/portainer.sh images prune

# Output:
# Removed 3 unused images
# Reclaimed 450MB disk space
```

### Workflow 4: Resource Monitoring

```bash
# Container resource usage
bash scripts/portainer.sh stats

# Output:
# NAME              CPU%     MEM USAGE / LIMIT    MEM%    NET I/O          BLOCK I/O
# nginx-proxy       0.15%    25MB / 2GB           1.25%   15MB / 8MB       2MB / 0B
# postgres-db       1.20%    180MB / 2GB          9.00%   50MB / 120MB     500MB / 200MB
# portainer         0.05%    30MB / 2GB           1.50%   5MB / 2MB        10MB / 5MB
```

### Workflow 5: Volume & Network Management

```bash
# List volumes
bash scripts/portainer.sh volumes list

# Create a volume
bash scripts/portainer.sh volumes create --name app-data

# List networks
bash scripts/portainer.sh networks list

# Create a network
bash scripts/portainer.sh networks create --name app-network --driver bridge
```

### Workflow 6: User Management

```bash
# List users
bash scripts/portainer.sh users list

# Create a user
bash scripts/portainer.sh users create --username developer --password "DevPass123!" --role standard

# Remove a user
bash scripts/portainer.sh users remove --username developer
```

## Configuration

### Environment Variables

```bash
# Portainer API connection (auto-set after `init`)
export PORTAINER_URL="https://localhost:9443"
export PORTAINER_API_KEY="ptr_xxxxxxxxxxxxxxxxxxxxxxxx"

# Custom port (set before install)
export PORTAINER_HTTPS_PORT=9443
export PORTAINER_EDGE_PORT=8000
```

### Config File

After `init`, credentials are stored in `~/.config/portainer/config.json`:

```json
{
  "url": "https://localhost:9443",
  "api_key": "ptr_xxxxxxxxxxxxxxxxxxxxxxxx",
  "username": "admin",
  "endpoint_id": 1
}
```

## Advanced Usage

### Deploy Stack from Git Repository

```bash
bash scripts/portainer.sh stacks deploy \
  --name my-app \
  --git-url https://github.com/user/repo \
  --git-ref main \
  --compose-path docker-compose.yml
```

### Add Remote Docker Endpoint

```bash
bash scripts/portainer.sh endpoints add \
  --name production-server \
  --url tcp://192.168.1.100:2375
```

### Backup Portainer Data

```bash
bash scripts/portainer.sh backup --output /backups/portainer-$(date +%Y%m%d).tar.gz
```

### Restore from Backup

```bash
bash scripts/portainer.sh restore --file /backups/portainer-20260301.tar.gz
```

### Webhook for Auto-Deploy

```bash
# Create a webhook for a stack (auto-redeploy on trigger)
bash scripts/portainer.sh stacks webhook --name my-app

# Output:
# Webhook URL: https://localhost:9443/api/stacks/webhooks/xxxx-xxxx-xxxx
# Trigger: curl -X POST <webhook-url>
```

## Troubleshooting

### Issue: "Cannot connect to Portainer API"

**Fix:**
```bash
# Check if Portainer container is running
docker ps | grep portainer

# If not running, restart
docker start portainer

# If port conflict, reinstall on different port
PORTAINER_HTTPS_PORT=9444 bash scripts/portainer.sh install
```

### Issue: "Unauthorized" errors

**Fix:**
```bash
# Re-authenticate
bash scripts/portainer.sh init --password "YourPassword"

# Or generate new API key
bash scripts/portainer.sh token --refresh
```

### Issue: Stack deploy fails

**Fix:**
```bash
# Validate compose file first
docker compose -f docker-compose.yml config

# Check Portainer logs
bash scripts/portainer.sh containers logs portainer --tail 100
```

### Issue: "Docker not found"

**Fix:**
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in
```

## Uninstall

```bash
bash scripts/portainer.sh uninstall
# Removes container, image, and optionally the data volume
```

## Dependencies

- `docker` (20.10+)
- `curl` (HTTP API calls)
- `jq` (JSON parsing)
- `openssl` (for self-signed cert handling)
