---
name: flyio-manager
description: >-
  Deploy, scale, and manage applications on Fly.io — zero-downtime deployments from the terminal.
categories: [dev-tools, automation]
dependencies: [bash, curl]
---

# Fly.io App Manager

## What This Does

Manage your Fly.io applications without leaving the terminal. Install flyctl, deploy apps, scale machines, manage secrets, check logs, and set up custom domains — all automated through executable scripts.

**Example:** "Deploy a Node.js app to Fly.io, scale to 2 machines in IAD, set environment secrets, and configure a custom domain with SSL."

## Quick Start (5 minutes)

### 1. Install flyctl

```bash
bash scripts/install.sh
```

### 2. Authenticate

```bash
fly auth login
# Or use a token:
export FLY_API_TOKEN="your-token-here"
fly auth token
```

### 3. Deploy Your First App

```bash
cd /path/to/your/app
bash scripts/deploy.sh --init
```

## Core Workflows

### Workflow 1: Install flyctl CLI

**Use case:** First-time setup on a new machine

```bash
bash scripts/install.sh
```

This will:
- Detect your OS and architecture
- Download the latest flyctl binary
- Add it to your PATH
- Verify installation

### Workflow 2: Initialize & Deploy a New App

**Use case:** Deploy any app (Node.js, Python, Go, Docker, static site)

```bash
# Navigate to your project
cd /path/to/your/app

# Initialize (creates fly.toml)
bash scripts/deploy.sh --init

# Deploy
bash scripts/deploy.sh
```

**Output:**
```
[flyio-manager] Deploying app...
==> Building image
==> Pushing image
==> Creating release
==> Monitoring deployment
✅ App deployed: https://your-app.fly.dev
```

### Workflow 3: Scale Machines

**Use case:** Add more instances or change machine size

```bash
# Scale to 3 machines
bash scripts/scale.sh --count 3

# Change machine size
bash scripts/scale.sh --size shared-cpu-2x --memory 512

# Scale to specific regions
bash scripts/scale.sh --count 2 --region iad,cdg
```

### Workflow 4: Manage Secrets

**Use case:** Set environment variables securely

```bash
# Set secrets
bash scripts/secrets.sh --set DATABASE_URL="postgres://..." API_KEY="sk-..."

# List secrets (names only, values hidden)
bash scripts/secrets.sh --list

# Remove a secret
bash scripts/secrets.sh --unset OLD_SECRET
```

### Workflow 5: Custom Domain & SSL

**Use case:** Point your domain to a Fly.io app

```bash
# Add custom domain
bash scripts/domain.sh --add yourdomain.com

# Check certificate status
bash scripts/domain.sh --check yourdomain.com
```

**Output:**
```
[flyio-manager] Adding domain yourdomain.com...
Add these DNS records:
  CNAME: yourdomain.com → your-app.fly.dev
  (or A record if apex domain)
✅ Certificate will be auto-provisioned once DNS propagates
```

### Workflow 6: View Logs & Status

**Use case:** Debug issues, monitor health

```bash
# Stream live logs
bash scripts/status.sh --logs

# App status overview
bash scripts/status.sh

# Check machine health
bash scripts/status.sh --machines
```

### Workflow 7: Database Setup (Fly Postgres)

**Use case:** Provision a managed Postgres database

```bash
# Create Postgres cluster
bash scripts/database.sh --create --name myapp-db --region iad

# Attach to app (sets DATABASE_URL automatically)
bash scripts/database.sh --attach --db myapp-db --app myapp

# Connect via psql
bash scripts/database.sh --connect --db myapp-db
```

### Workflow 8: Zero-Downtime Deploy with Health Checks

**Use case:** Production deployments with rollback

```bash
# Deploy with canary strategy
bash scripts/deploy.sh --strategy canary

# Deploy with immediate rollback on failure
bash scripts/deploy.sh --strategy rolling --wait-timeout 120

# Rollback to previous version
bash scripts/deploy.sh --rollback
```

## Configuration

### fly.toml Reference

```toml
# fly.toml — auto-generated on init, customize as needed
app = "your-app-name"
primary_region = "iad"

[build]
  # Dockerfile (default) or buildpacks
  dockerfile = "Dockerfile"

[env]
  PORT = "8080"
  NODE_ENV = "production"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true

[[vm]]
  size = "shared-cpu-1x"
  memory = "256mb"

[checks]
  [checks.alive]
    type = "tcp"
    port = 8080
    interval = "15s"
    timeout = "2s"
```

### Environment Variables

```bash
# Authentication (one of these)
export FLY_API_TOKEN="your-token"  # For CI/CD
# Or: fly auth login (interactive)

# Optional: default app name
export FLY_APP="your-app-name"

# Optional: default region
export FLY_REGION="iad"
```

## Advanced Usage

### CI/CD Integration

```bash
# In your GitHub Actions / CI pipeline:
export FLY_API_TOKEN="${{ secrets.FLY_API_TOKEN }}"
bash scripts/install.sh
bash scripts/deploy.sh --app myapp
```

### Multi-Region Deployment

```bash
# Deploy to multiple regions
bash scripts/scale.sh --region iad,lhr,nrt --count 1

# Check region distribution
bash scripts/status.sh --machines
```

### Volume Management

```bash
# Create a persistent volume
fly volumes create mydata --region iad --size 10

# List volumes
fly volumes list
```

### Wireguard Tunnel (Private Networking)

```bash
# Set up private connection to your Fly network
fly wireguard create
```

## Troubleshooting

### Issue: "Error: app not found"

**Fix:** Make sure you're in the directory with `fly.toml`, or specify `--app`:
```bash
bash scripts/deploy.sh --app your-app-name
```

### Issue: Deployment fails with health check timeout

**Fix:** Increase timeout or check your app's startup time:
```bash
bash scripts/deploy.sh --wait-timeout 300
```

### Issue: Out of memory

**Fix:** Scale up machine size:
```bash
bash scripts/scale.sh --size shared-cpu-2x --memory 512
```

### Issue: "Error: Insufficient resources"

**Fix:** You may have hit free tier limits. Check usage:
```bash
fly orgs show
```

## Key Principles

1. **Deploy fast** — Push to production in under 2 minutes
2. **Scale anywhere** — 30+ regions worldwide
3. **Zero-downtime** — Rolling deployments by default
4. **Secure** — Secrets encrypted, SSL auto-provisioned
5. **Cost-effective** — Pay per machine-second, auto-stop idle machines

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `flyctl` (auto-installed by scripts/install.sh)
- Optional: `docker` (for custom Dockerfiles)
