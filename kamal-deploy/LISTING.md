# Listing Copy: Kamal Deploy Manager

## Metadata
- **Type:** Skill
- **Name:** kamal-deploy
- **Display Name:** Kamal Deploy Manager
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Icon:** 🚀
- **Dependencies:** [ruby, docker, ssh]

## Tagline

Deploy any Docker app to bare metal with zero downtime — no Kubernetes needed

## Description

Deploying web apps shouldn't require a PhD in Kubernetes. But SSH-ing into servers and running `docker pull && docker stop && docker run` is fragile, has downtime, and doesn't scale.

Kamal Deploy Manager sets up [Kamal](https://kamal-deploy.org/) (by 37signals, the team behind Basecamp & HEY) to handle zero-downtime deployments to any VPS or bare metal server. One YAML config, one command, and your app is live with SSL, health checks, and rolling deploys.

**What it does:**
- 🚀 Zero-downtime rolling deploys to any server via SSH
- 🔒 Automatic SSL via Traefik reverse proxy
- 🐳 Build & push Docker images to any registry
- 🔑 Encrypted secrets management (never in git)
- 📊 Multi-server, multi-role deployments (web + workers)
- ↩️ Instant rollbacks to any previous version
- 🗄️ Accessory services (Postgres, Redis, etc.) alongside your app
- 📋 Remote command execution (migrations, console, tasks)

Perfect for indie developers, startups, and anyone who wants production-grade deployments without the complexity of Kubernetes, Terraform, or managed PaaS pricing.

## Quick Start Preview

```bash
# Install Kamal
bash scripts/install.sh

# In your app directory
kamal init
# Edit config/deploy.yml with your server IP
kamal setup    # First deploy (installs Docker + Traefik)
kamal deploy   # Subsequent deploys (zero downtime)
```

## Core Capabilities

1. Zero-downtime deploys — Rolling container replacement with health checks
2. One-command setup — `kamal setup` provisions fresh servers
3. Multi-server support — Deploy to 1 or 100 servers
4. Role-based deployment — Web servers, background workers, cron jobs
5. Secrets management — Encrypted env vars, never committed to git
6. Instant rollbacks — Revert to any previous version in seconds
7. Accessory services — Run Postgres, Redis alongside your app
8. Remote execution — Run migrations, console, rake tasks remotely
9. SSL automation — Traefik handles Let's Encrypt certificates
10. Registry agnostic — Docker Hub, GitHub Container Registry, AWS ECR
11. SSH-based — No agents on servers, just SSH + Docker
12. Server health checks — Verify server readiness before deploying

## Dependencies
- Ruby (2.7+)
- Docker (for building images)
- SSH client + keys

## Installation Time
**10 minutes** — Install Kamal, configure deploy.yml, first deploy
