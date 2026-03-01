---
name: flyio-manager
description: >-
  Deploy and manage applications on Fly.io — install flyctl, launch apps, manage machines, scale, secrets, and volumes from your terminal.
categories: [dev-tools, automation]
dependencies: [curl, bash]
---

# Fly.io Manager

## What This Does

Deploy and manage applications on Fly.io's global edge network directly from your OpenClaw agent. Install the flyctl CLI, launch new apps, manage machines, handle secrets, configure volumes, scale resources, and monitor deployments — all without leaving the terminal.

**Example:** "Deploy my Node.js app to Fly.io in 3 regions with 512MB RAM, set environment secrets, and check deployment status."

## Quick Start (5 minutes)

### 1. Install flyctl

```bash
# Install Fly.io CLI
curl -L https://fly.io/install.sh | sh

# Add to PATH (if not already)
export FLYCTL_INSTALL="/home/$USER/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# Verify installation
fly version
```

### 2. Authenticate

```bash
# Interactive login (opens browser)
fly auth login

# Or use API token (headless/CI)
export FLY_API_TOKEN="your-token-here"
fly auth whoami
```

### 3. Launch Your First App

```bash
# From your project directory
cd /path/to/your/app
fly launch

# Or non-interactive
fly launch --name my-app --region sjc --no-deploy
```

## Core Workflows

### Workflow 1: Deploy an App

**Use case:** Deploy a web application to Fly.io

```bash
# Initialize (first time)
cd /path/to/app
fly launch --name my-app --region sjc

# Deploy (subsequent)
fly deploy

# Deploy with specific Dockerfile
fly deploy --dockerfile Dockerfile.prod

# Deploy and wait for health checks
fly deploy --wait-timeout 300
```

**Output:**
```
==> Verifying app config
--> Verified app config
==> Building image
...
==> Pushing image
--> Pushing image done
==> Creating release
--> Release v2 created
==> Monitoring deployment
  1 desired, 1 placed, 1 healthy, 0 unhealthy
--> v2 deployed successfully
```

### Workflow 2: Manage Machines

**Use case:** Scale, start, stop, or restart machines

```bash
# List machines
fly machine list -a my-app

# Scale to 3 machines
fly scale count 3 -a my-app

# Scale machine size
fly scale vm shared-cpu-2x -a my-app

# Scale memory
fly scale memory 512 -a my-app

# Stop a machine
fly machine stop <machine-id> -a my-app

# Start a machine
fly machine start <machine-id> -a my-app

# Restart all machines
fly apps restart my-app
```

### Workflow 3: Manage Secrets

**Use case:** Set environment variables securely

```bash
# Set a secret
fly secrets set DATABASE_URL="postgres://..." -a my-app

# Set multiple secrets
fly secrets set \
  DATABASE_URL="postgres://..." \
  REDIS_URL="redis://..." \
  API_KEY="sk-..." \
  -a my-app

# Set from .env file
cat .env | fly secrets import -a my-app

# List secrets (names only, values hidden)
fly secrets list -a my-app

# Unset a secret
fly secrets unset API_KEY -a my-app
```

### Workflow 4: Manage Volumes

**Use case:** Persistent storage for databases or file uploads

```bash
# Create a volume
fly volumes create data --size 10 --region sjc -a my-app

# List volumes
fly volumes list -a my-app

# Extend a volume
fly volumes extend <vol-id> --size 20 -a my-app

# Delete a volume
fly volumes destroy <vol-id> -a my-app

# Snapshot a volume
fly volumes snapshots list <vol-id> -a my-app
```

### Workflow 5: Multi-Region Deployment

**Use case:** Deploy globally for low latency

```bash
# Set primary region
fly regions set sjc -a my-app

# Add backup regions
fly regions add iad lhr nrt -a my-app

# List regions
fly regions list -a my-app

# Scale across regions
fly scale count 2 --region sjc -a my-app
fly scale count 1 --region iad -a my-app
```

### Workflow 6: Database Management

**Use case:** Create and manage Fly Postgres

```bash
# Create Postgres cluster
fly postgres create --name my-db --region sjc

# Attach to app
fly postgres attach my-db -a my-app

# Connect to Postgres
fly postgres connect -a my-db

# List databases
fly postgres db list -a my-db

# Create a database
fly postgres db create my_new_db -a my-db
```

### Workflow 7: Monitor & Debug

**Use case:** Check app status, logs, and health

```bash
# Check app status
fly status -a my-app

# View logs (real-time)
fly logs -a my-app

# View recent logs
fly logs -a my-app --no-tail

# SSH into a running machine
fly ssh console -a my-app

# Run a one-off command
fly ssh console -a my-app -C "node scripts/migrate.js"

# Check VM metrics
fly machine status <machine-id> -a my-app
```

### Workflow 8: Custom Domains & SSL

**Use case:** Point your domain to your Fly app

```bash
# Add a custom domain
fly certs add mydomain.com -a my-app

# Check certificate status
fly certs show mydomain.com -a my-app

# List all certificates
fly certs list -a my-app

# Remove a certificate
fly certs remove mydomain.com -a my-app
```

**DNS Setup:**
```
# Add these DNS records:
# A    @ → <app-ipv4>   (from `fly ips list`)
# AAAA @ → <app-ipv6>
# CNAME www → my-app.fly.dev
```

### Workflow 9: Manage IPs

```bash
# List IPs
fly ips list -a my-app

# Allocate dedicated IPv4
fly ips allocate-v4 -a my-app

# Allocate IPv6
fly ips allocate-v6 -a my-app

# Release an IP
fly ips release <ip-address> -a my-app
```

## Configuration

### fly.toml Reference

```toml
# fly.toml — Fly.io app configuration
app = "my-app"
primary_region = "sjc"

[build]
  dockerfile = "Dockerfile"

[env]
  NODE_ENV = "production"
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

  [http_service.concurrency]
    type = "requests"
    hard_limit = 250
    soft_limit = 200

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 512

[[mounts]]
  source = "data"
  destination = "/data"

[checks]
  [checks.health]
    type = "http"
    port = 8080
    path = "/health"
    interval = "10s"
    timeout = "2s"
    grace_period = "5s"
```

### Environment Variables

```bash
# Authentication
export FLY_API_TOKEN="fo1_..."

# Default app (skip -a flag)
export FLY_APP="my-app"

# Default region
export FLY_REGION="sjc"
```

## Advanced Usage

### Blue-Green Deployments

```bash
# Deploy without promoting
fly deploy --strategy bluegreen -a my-app

# Check new machines
fly machine list -a my-app

# Promote manually if healthy
fly deploy --strategy immediate -a my-app
```

### Autoscaling

```bash
# Enable autoscaling
fly autoscale set min=1 max=10 -a my-app

# Check autoscale config
fly autoscale show -a my-app
```

### WireGuard Tunnel (Private Network)

```bash
# Create WireGuard peer
fly wireguard create

# List peers
fly wireguard list

# Access internal services
# Apps communicate via <app>.internal on port 6pn
```

### Proxy to Local Machine

```bash
# Forward remote port to local
fly proxy 5432:5432 -a my-db

# Access Postgres locally
psql postgres://localhost:5432/my_db
```

## Troubleshooting

### Issue: "Error: could not find app"

**Fix:**
```bash
# Check app name
fly apps list

# Set default app
export FLY_APP="correct-app-name"
```

### Issue: Deploy fails with health check timeout

**Fix:**
```bash
# Increase timeout
fly deploy --wait-timeout 600

# Or adjust fly.toml
# [checks.health]
#   timeout = "10s"
#   grace_period = "30s"
```

### Issue: Machine keeps restarting

**Fix:**
```bash
# Check logs for crash reason
fly logs -a my-app

# SSH in to debug
fly ssh console -a my-app

# Check if port matches fly.toml internal_port
```

### Issue: Volume not mounting

**Fix:**
```bash
# Verify volume exists in same region as machine
fly volumes list -a my-app

# Ensure fly.toml has correct mount config
# [[mounts]]
#   source = "data"
#   destination = "/data"
```

### Issue: "Out of memory" crashes

**Fix:**
```bash
# Scale memory
fly scale memory 1024 -a my-app

# Check current allocation
fly scale show -a my-app
```

## Fly.io Regions Reference

| Code | Location |
|------|----------|
| sjc | San Jose, CA |
| iad | Ashburn, VA |
| lhr | London, UK |
| nrt | Tokyo, Japan |
| sin | Singapore |
| syd | Sydney, Australia |
| cdg | Paris, France |
| fra | Frankfurt, Germany |
| gru | São Paulo, Brazil |
| bom | Mumbai, India |

Full list: `fly platform regions`

## Key Principles

1. **Deploy fast** — `fly launch` → `fly deploy` in minutes
2. **Scale globally** — Multi-region with one command
3. **Secrets are secrets** — Never put sensitive values in fly.toml
4. **Volumes are regional** — Create in same region as machines
5. **Auto-stop saves money** — Enable `auto_stop_machines` for dev apps
6. **Health checks matter** — Always configure them for zero-downtime deploys

## Dependencies

- `curl` (for installation)
- `flyctl` (installed by this skill)
- Docker (for building images, optional if using buildpacks)
