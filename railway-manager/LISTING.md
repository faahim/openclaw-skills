# Listing Copy: Railway Manager

## Metadata
- **Type:** Skill
- **Name:** railway-manager
- **Display Name:** Railway Manager
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [curl, jq]

## Tagline

Deploy and manage Railway services — projects, environments, domains, and logs from your terminal

## Description

Deploying apps shouldn't require clicking through dashboards. Railway is one of the fastest cloud platforms for deploying web apps, APIs, and databases — but managing everything through the web UI gets tedious.

Railway Manager gives your OpenClaw agent full control of Railway deployments. Install the CLI, create projects, deploy from any directory, manage environment variables, add custom domains, tail logs, and spin up managed databases — all from the terminal.

**What it does:**
- 🚀 One-command deploys with `railway up`
- 🔐 Manage environment variables across environments
- 🌐 Add and configure custom domains
- 📋 View and tail production logs in real-time
- 🗄️ Add managed databases (PostgreSQL, Redis, MySQL)
- 🔄 Manage staging/production environments
- 🔗 CI/CD integration with GitHub Actions
- 📊 Monitor deployments and service status

**Who it's for:** Developers and indie hackers who deploy web apps, APIs, and services on Railway and want terminal-first control without touching the dashboard.

## Quick Start Preview

```bash
# Install Railway CLI
bash scripts/install.sh

# Authenticate
railway login

# Deploy your app
railway init && railway up

# Output:
# 🚀 Deploying...
# ✅ https://your-app.up.railway.app
```

## Core Capabilities

1. CLI installation — Auto-detect OS/arch, install Railway CLI
2. Project management — Create, link, and list Railway projects
3. One-command deploy — Build and deploy from current directory
4. Environment variables — Set, list, delete secrets and config
5. Custom domains — Add and configure domains with CNAME instructions
6. Log streaming — Tail real-time production and build logs
7. Database plugins — Add PostgreSQL, Redis, MySQL with one command
8. Multi-environment — Manage staging/production separately
9. Monorepo support — Deploy specific directories from monorepos
10. CI/CD ready — GitHub Actions integration with token-based auth

## Dependencies
- `curl`
- `jq` (optional, for API queries)
- Railway account (free tier available)

## Installation Time
**5 minutes** — Install CLI, authenticate, deploy
