# Listing Copy: Fly.io Manager

## Metadata
- **Type:** Skill
- **Name:** flyio-manager
- **Display Name:** Fly.io Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [curl, bash]

## Tagline

Deploy and manage apps on Fly.io — global edge deployment from your terminal

## Description

Deploying apps shouldn't require clicking through dashboards. With Fly.io Manager, your OpenClaw agent handles the entire deployment lifecycle — from installing the CLI to scaling across regions.

Fly.io Manager wraps the flyctl CLI into agent-friendly workflows. Launch new apps, deploy updates, manage secrets and volumes, configure custom domains, and monitor deployments — all through natural conversation with your agent.

**What it does:**
- 🚀 Install flyctl and authenticate in one step
- 📦 Deploy apps with Docker or buildpacks
- 🌍 Scale across 30+ global regions
- 🔐 Manage secrets securely (set, import from .env, unset)
- 💾 Create and manage persistent volumes
- 🔒 Custom domains with automatic SSL
- 📊 Monitor status, logs, and machine health
- 🐘 Spin up managed Postgres databases
- 🔧 SSH into running machines for debugging
- ⚡ Blue-green and rolling deployment strategies

Perfect for developers and teams who want fast, repeatable deployments without leaving their terminal. Works great for Node.js, Python, Go, Ruby, Rust, Elixir, and any Docker-based app.

## Quick Start Preview

```bash
# Install flyctl
bash scripts/install.sh

# Deploy your app
cd my-app && fly launch

# Scale globally
fly scale count 3 --region sjc,iad,lhr
```

## Core Capabilities

1. CLI installation — One-command install with PATH setup
2. App deployment — Docker builds, buildpacks, multi-stage
3. Global scaling — 30+ regions, multi-region with one command
4. Secret management — Set, import, list, unset environment secrets
5. Volume management — Create, extend, snapshot persistent storage
6. Custom domains — Add domains with automatic Let's Encrypt SSL
7. Database management — Managed Postgres with attach/connect
8. Machine control — Start, stop, restart, scale VM size and memory
9. Deployment strategies — Blue-green, rolling, canary deployments
10. Monitoring — Real-time logs, status checks, SSH debugging

## Dependencies
- `curl`
- `bash` (4.0+)
- Docker (optional, for custom builds)

## Installation Time
**5 minutes** — Install CLI, authenticate, deploy
