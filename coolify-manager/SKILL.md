---
name: coolify-manager
description: >-
  Install, configure, and manage Coolify — a self-hosted PaaS for deploying apps, databases, and services.
categories: [dev-tools, automation]
dependencies: [bash, curl, docker, ssh]
---

# Coolify Manager

## What This Does

Manage a **Coolify** self-hosted PaaS instance — install it, deploy apps from Git repos, manage databases (Postgres, MySQL, Redis, MongoDB), configure domains, check service health, and handle backups. Coolify is an open-source Heroku/Vercel/Netlify alternative you run on your own server.

**Example:** "Install Coolify on my VPS, deploy a Node.js app from GitHub, set up a Postgres database, and configure a custom domain with SSL."

## Quick Start (10 minutes)

### 1. Install Coolify

```bash
# Install on a fresh VPS (Ubuntu 22.04+ / Debian 12+)
# Requires: root/sudo access, 2GB+ RAM, Docker (auto-installed)
bash scripts/install.sh
```

This runs the official Coolify installer, sets up Docker if needed, and starts the Coolify dashboard.

### 2. Access Dashboard

After install, Coolify runs at `http://<your-server-ip>:8000`. Create your admin account on first visit.

### 3. Get API Token

```bash
# Generate an API token from Coolify dashboard:
# Settings → API Tokens → Create Token
export COOLIFY_URL="http://localhost:8000"
export COOLIFY_TOKEN="your-api-token-here"
```

### 4. Verify Connection

```bash
bash scripts/manage.sh status
# Output:
# ✅ Coolify v4.x running at http://localhost:8000
# 📦 3 applications deployed
# 🗄️ 2 databases running
# 💾 Disk: 45% used
```

## Core Workflows

### Workflow 1: Deploy an App from GitHub

```bash
# List available servers
bash scripts/manage.sh servers

# Deploy a new application
bash scripts/manage.sh deploy-app \
  --repo "https://github.com/user/myapp" \
  --branch main \
  --type nodejs \
  --domain myapp.example.com

# Check deployment status
bash scripts/manage.sh app-status --name myapp
```

**Output:**
```
🚀 Deploying user/myapp (branch: main)...
   Type: Node.js (auto-detected)
   Domain: myapp.example.com
   SSL: Auto (Let's Encrypt)
✅ Deployed successfully!
   URL: https://myapp.example.com
   Container: myapp-xxxxx
   Status: running
```

### Workflow 2: Create a Database

```bash
# Create a PostgreSQL database
bash scripts/manage.sh create-db \
  --type postgres \
  --name myapp-db \
  --version 16

# Get connection string
bash scripts/manage.sh db-info --name myapp-db
```

**Output:**
```
🗄️ Database created: myapp-db
   Type: PostgreSQL 16
   Host: localhost
   Port: 5432
   Connection: postgresql://coolify:generated-pass@localhost:5432/myapp-db
```

**Supported databases:** PostgreSQL, MySQL, MariaDB, MongoDB, Redis, KeyDB, DragonFly, Clickhouse

### Workflow 3: Manage Services

```bash
# List all running resources
bash scripts/manage.sh list

# Restart an application
bash scripts/manage.sh restart --name myapp

# View logs
bash scripts/manage.sh logs --name myapp --lines 100

# Stop a service
bash scripts/manage.sh stop --name myapp

# Start a service
bash scripts/manage.sh start --name myapp
```

### Workflow 4: Domain & SSL Management

```bash
# Add custom domain to app
bash scripts/manage.sh set-domain \
  --name myapp \
  --domain myapp.example.com

# SSL is auto-provisioned via Let's Encrypt
# Check SSL status
bash scripts/manage.sh ssl-status --name myapp
```

### Workflow 5: Backups

```bash
# Create a database backup
bash scripts/manage.sh backup --name myapp-db

# List backups
bash scripts/manage.sh backups --name myapp-db

# Schedule automatic backups (daily at 3 AM)
bash scripts/manage.sh backup-schedule \
  --name myapp-db \
  --cron "0 3 * * *"
```

### Workflow 6: Environment Variables

```bash
# Set env vars for an app
bash scripts/manage.sh env-set --name myapp \
  --key DATABASE_URL \
  --value "postgresql://user:pass@localhost:5432/db"

# List env vars
bash scripts/manage.sh env-list --name myapp

# Bulk set from .env file
bash scripts/manage.sh env-import --name myapp --file .env
```

### Workflow 7: Health Check & Monitoring

```bash
# Full system health check
bash scripts/manage.sh health

# Output:
# 🏥 Coolify Health Report
# ├── Coolify: v4.0.0-beta.361 ✅
# ├── Docker: 25.0.3 ✅
# ├── Disk: 45% (23GB / 50GB) ✅
# ├── Memory: 62% (1.2GB / 2GB) ⚠️
# ├── Apps: 3 running, 0 stopped ✅
# └── Databases: 2 running ✅

# Monitor resource usage per container
bash scripts/manage.sh resources
```

### Workflow 8: Update Coolify

```bash
# Check for updates
bash scripts/manage.sh check-update

# Update to latest version
bash scripts/manage.sh update
```

## Configuration

### Environment Variables

```bash
# Required
export COOLIFY_URL="http://localhost:8000"    # Coolify instance URL
export COOLIFY_TOKEN="your-api-token"         # API token from dashboard

# Optional
export COOLIFY_TEAM_ID="0"                    # Team ID (default: 0)
export COOLIFY_SERVER_ID=""                    # Default server UUID
```

Save these in `~/.coolify.env` and the scripts will auto-load them.

### Config File

```bash
# ~/.coolify.env
COOLIFY_URL=http://localhost:8000
COOLIFY_TOKEN=your-api-token-here
COOLIFY_TEAM_ID=0
```

## Advanced Usage

### Deploy Docker Compose Stack

```bash
bash scripts/manage.sh deploy-compose \
  --file docker-compose.yml \
  --name my-stack \
  --domain stack.example.com
```

### Deploy from Dockerfile

```bash
bash scripts/manage.sh deploy-app \
  --repo "https://github.com/user/myapp" \
  --type dockerfile \
  --dockerfile Dockerfile.prod \
  --domain myapp.example.com
```

### Add Remote Server

```bash
# Add a remote server for multi-server deployments
bash scripts/manage.sh add-server \
  --name production \
  --ip 203.0.113.10 \
  --user root \
  --key ~/.ssh/id_rsa
```

### Webhooks (Auto-Deploy on Push)

```bash
# Get webhook URL for auto-deployment
bash scripts/manage.sh webhook --name myapp

# Output:
# 🔗 Webhook URL: https://coolify.example.com/api/v1/deploy?uuid=xxx&token=yyy
# Add this to your GitHub repo → Settings → Webhooks
```

## Troubleshooting

### Issue: "Connection refused" on port 8000

**Fix:**
```bash
# Check if Coolify containers are running
docker ps | grep coolify

# Restart Coolify
cd /data/coolify/source
docker compose up -d --pull always

# Check logs
docker logs coolify -f --tail 100
```

### Issue: SSL certificate not provisioning

**Check:**
1. Domain DNS points to server IP: `dig +short myapp.example.com`
2. Port 80/443 is open: `sudo ufw status`
3. Coolify proxy (Traefik) is running: `docker ps | grep traefik`

### Issue: Deployment stuck

```bash
# Cancel stuck deployment
bash scripts/manage.sh cancel-deploy --name myapp

# Force rebuild
bash scripts/manage.sh deploy-app --name myapp --force
```

### Issue: Out of disk space

```bash
# Clean up Docker resources
docker system prune -af --volumes

# Check what's using space
bash scripts/manage.sh resources
```

## Key Principles

1. **Self-hosted** — Your data, your server, no vendor lock-in
2. **API-first** — Everything done via CLI uses Coolify's REST API
3. **Auto-SSL** — Let's Encrypt certificates provisioned automatically
4. **Git-based deploys** — Push to deploy from any Git repository
5. **Multi-server** — Deploy across multiple servers from one dashboard
