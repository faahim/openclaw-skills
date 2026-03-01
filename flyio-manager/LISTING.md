# Listing Copy: Fly.io App Manager

## Metadata
- **Type:** Skill
- **Name:** flyio-manager
- **Display Name:** Fly.io App Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, flyctl]
- **Icon:** 🚀

## Tagline

Deploy, scale, and manage Fly.io apps — zero-downtime deployments from the terminal

## Description

Managing Fly.io deployments means juggling flyctl commands, remembering region codes, configuring SSL, and handling rollbacks manually. One wrong command and your production app is down.

Fly.io App Manager gives your OpenClaw agent everything it needs to deploy and manage Fly.io applications. Install flyctl, initialize apps, deploy with zero-downtime strategies, scale across regions, manage secrets, set up custom domains with auto-SSL, and provision Postgres databases — all through executable scripts.

**What it does:**
- 🚀 Deploy apps with canary or rolling strategies
- 📈 Scale machines across 30+ global regions
- 🔑 Manage secrets and environment variables securely
- 🌐 Configure custom domains with automatic SSL
- 🗄️ Provision and attach Fly Postgres databases
- ↩️ One-command rollback to previous versions
- 📊 Monitor app status, logs, and machine health
- ⚡ CI/CD ready with token-based authentication

Perfect for developers and teams deploying web apps, APIs, and services on Fly.io who want their AI agent to handle infrastructure.

## Quick Start Preview

```bash
# Install flyctl
bash scripts/install.sh

# Deploy your app
cd /path/to/app
bash scripts/deploy.sh --init
bash scripts/deploy.sh

# Scale to 3 machines across regions
bash scripts/scale.sh --count 3 --region iad,lhr
```

## Core Capabilities

1. CLI installation — Auto-detect OS/arch, install flyctl, configure PATH
2. App deployment — Initialize and deploy with fly.toml configuration
3. Zero-downtime deploys — Canary and rolling deployment strategies
4. Machine scaling — Scale count, size, and memory across regions
5. Secret management — Set, list, and remove encrypted environment variables
6. Custom domains — Add domains with automatic SSL certificate provisioning
7. Database provisioning — Create, attach, and connect to Fly Postgres
8. Instant rollback — Revert to previous release in one command
9. Status monitoring — View app health, machine list, and recent releases
10. Log streaming — Real-time log tailing for debugging
11. CI/CD integration — Token-based auth for automated pipelines
12. Multi-region — Deploy across 30+ worldwide edge locations

## Dependencies
- `bash` (4.0+)
- `curl`
- `flyctl` (auto-installed)

## Installation Time
**5 minutes** — Run install script, authenticate, deploy

## Pricing Justification

**Why $12:**
- Fly.io is a top deployment platform with growing adoption
- Covers 7 executable scripts with real automation
- Comparable tools: manual flyctl docs (free but time-consuming)
- One-time payment saves hours of deployment configuration
