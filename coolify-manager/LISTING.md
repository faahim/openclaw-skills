# Listing Copy: Coolify Manager

## Metadata
- **Type:** Skill
- **Name:** coolify-manager
- **Display Name:** Coolify Manager
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [bash, curl, docker, jq]

## Tagline

"Manage your self-hosted PaaS — deploy apps, databases, and services from the CLI"

## Description

Running your own platform shouldn't require a DevOps team. Coolify is the open-source Heroku alternative that lets you deploy anything on your own server — but managing it from the web UI gets tedious fast.

**Coolify Manager** gives your OpenClaw agent full control over your Coolify instance. Deploy apps from GitHub, spin up databases (Postgres, MySQL, Redis, MongoDB), manage domains with auto-SSL, view logs, set environment variables, and monitor resource usage — all from the command line.

**What it does:**
- 🚀 Deploy apps from any Git repo with auto-detection (Node.js, Python, PHP, Docker)
- 🗄️ Create and manage databases (PostgreSQL, MySQL, Redis, MongoDB, and more)
- 🔐 Auto-SSL via Let's Encrypt for all custom domains
- 📊 Monitor container resources, disk, and memory usage
- 🔄 Auto-deploy via webhooks on Git push
- 💾 Schedule automatic database backups
- 🌐 Multi-server support — deploy across multiple VPS from one agent
- 🩺 Health checks with actionable alerts

**Who it's for:** Developers and indie hackers who self-host with Coolify and want their AI agent to manage deployments, databases, and infrastructure without touching the dashboard.

## Quick Start Preview

```bash
# Install Coolify on a VPS
sudo bash scripts/install.sh

# Deploy an app
bash scripts/manage.sh deploy-app --repo https://github.com/user/app --domain app.example.com

# Create a database
bash scripts/manage.sh create-db --type postgres --name mydb

# Check health
bash scripts/manage.sh health
```

## Core Capabilities

1. One-command Coolify installation with pre-flight checks
2. Deploy apps from GitHub/GitLab with auto-detected build packs
3. Create PostgreSQL, MySQL, Redis, MongoDB databases instantly
4. Auto-SSL certificate provisioning via Let's Encrypt
5. Environment variable management (set, list, bulk import)
6. Container log viewing and resource monitoring
7. Webhook setup for push-to-deploy workflows
8. Scheduled database backups with cron expressions
9. Multi-server deployment management
10. Full health check with disk, memory, and service status

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- `docker` (auto-installed by Coolify)
- SSH access (for remote servers)

## Installation Time
**10 minutes** — Run installer, create API token, start deploying

## Pricing Justification

**Why $15:**
- Coolify replaces $20-50/month PaaS services (Heroku, Railway, Render)
- Full CLI automation vs manual dashboard clicking
- Database + app + SSL management in one tool
- One-time payment, unlimited use
