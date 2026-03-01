# Listing Copy: Portainer Manager

## Metadata
- **Type:** Skill
- **Name:** portainer-manager
- **Display Name:** Portainer Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [docker, curl, jq]

## Tagline

Manage Docker containers, stacks, and images through Portainer's API — no browser needed

## Description

Managing Docker containers shouldn't require keeping a browser tab open. Portainer is the most popular Docker management UI, but switching between terminal and browser breaks your flow.

Portainer Manager lets your OpenClaw agent install, configure, and fully manage Portainer CE from the command line. Deploy stacks from compose files or git repos, monitor container resources, manage images and volumes, handle user permissions — all through Portainer's REST API.

**What it does:**
- 🐳 Install Portainer CE with one command
- 📦 Deploy stacks from Docker Compose files or Git repos
- 📊 Monitor container CPU, memory, and network usage
- 🔄 Start, stop, restart containers by name
- 🗂️ Manage images, volumes, and networks
- 👥 Create and manage users with role-based access
- 💾 Backup and restore Portainer data
- 🔗 Auto-deploy webhooks for CI/CD integration
- 🌐 Add remote Docker endpoints for multi-host management

Perfect for developers and sysadmins who want Docker management without leaving the terminal. Setup takes 5 minutes, works on any Linux/Mac system with Docker installed.

## Quick Start Preview

```bash
# Install Portainer
bash scripts/portainer.sh install

# Initialize admin
bash scripts/portainer.sh init --password "YourSecurePassword123!"

# Deploy a stack
bash scripts/portainer.sh stacks deploy --name my-app --file docker-compose.yml

# Check status
bash scripts/portainer.sh status
```

## Core Capabilities

1. One-command installation — Portainer CE running in under 60 seconds
2. Stack deployment — Deploy from local compose files or Git repositories
3. Container management — Start, stop, restart, inspect, and tail logs
4. Resource monitoring — Real-time CPU, memory, network stats per container
5. Image management — Pull, list, and prune unused images
6. Volume & network control — Create, list, and manage Docker resources
7. User management — Create users with admin or standard roles
8. Backup & restore — Full data backup to tar.gz, one-command restore
9. Multi-host support — Add remote Docker endpoints
10. Webhook auto-deploy — Create webhooks for CI/CD stack redeployment
11. API key auth — Secure, persistent authentication via stored config
12. Uninstall cleanly — Remove everything or keep data volume

## Dependencies
- `docker` (20.10+)
- `curl`
- `jq`

## Installation Time
**5 minutes**
