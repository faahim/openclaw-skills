---
name: dokku-manager
description: >-
  Deploy apps to your own server with git push — install, configure, and manage Dokku PaaS.
categories: [dev-tools, automation]
dependencies: [bash, curl, docker]
---

# Dokku Manager

## What This Does

Install and manage [Dokku](https://dokku.com) — a self-hosted Platform as a Service (PaaS) that gives you Heroku-like `git push` deploys on your own server. Create apps, manage domains, add databases (Postgres, Redis, MySQL), configure SSL with Let's Encrypt, and scale services — all from the command line.

**Example:** "Create a new app called `myapi`, attach a Postgres database, set environment variables, configure SSL, and deploy with `git push dokku main`."

## Quick Start (10 minutes)

### 1. Install Dokku

```bash
# Install Dokku on Ubuntu/Debian (requires root)
bash scripts/install.sh

# Verify installation
dokku version
```

### 2. Create Your First App

```bash
# Create an app
bash scripts/manage.sh app:create myapp

# Set a domain
bash scripts/manage.sh domains:set myapp myapp.example.com

# Add environment variables
bash scripts/manage.sh config:set myapp DATABASE_URL=postgres://... SECRET_KEY=mysecret
```

### 3. Deploy

```bash
# From your local machine, add the Dokku remote
git remote add dokku dokku@your-server:myapp

# Deploy!
git push dokku main
```

## Core Workflows

### Workflow 1: Create App with Database

**Use case:** Deploy a web app with a Postgres database

```bash
# Create app
bash scripts/manage.sh app:create myapi

# Install Postgres plugin (first time only)
bash scripts/manage.sh plugin:install postgres

# Create and link a database
bash scripts/manage.sh postgres:create myapi-db
bash scripts/manage.sh postgres:link myapi-db myapi

# The DATABASE_URL is automatically set in the app's environment
bash scripts/manage.sh config myapi
# => DATABASE_URL: postgres://postgres:xxxx@dokku-postgres-myapi-db:5432/myapi_db
```

### Workflow 2: Enable SSL with Let's Encrypt

**Use case:** Auto-provision and renew SSL certificates

```bash
# Install Let's Encrypt plugin (first time only)
bash scripts/manage.sh plugin:install letsencrypt

# Set email for Let's Encrypt
bash scripts/manage.sh config:set --global DOKKU_LETSENCRYPT_EMAIL=admin@example.com

# Enable SSL for an app
bash scripts/manage.sh letsencrypt:enable myapp

# Auto-renew all certificates via cron
bash scripts/manage.sh letsencrypt:cron-job --add
```

### Workflow 3: Scale and Monitor

**Use case:** Scale processes and check app health

```bash
# Scale web workers
bash scripts/manage.sh ps:scale myapp web=3 worker=2

# Check running processes
bash scripts/manage.sh ps:report myapp

# View logs
bash scripts/manage.sh logs myapp --tail

# Restart app
bash scripts/manage.sh ps:restart myapp
```

### Workflow 4: Add Redis Cache

```bash
# Install Redis plugin
bash scripts/manage.sh plugin:install redis

# Create and link
bash scripts/manage.sh redis:create myapp-cache
bash scripts/manage.sh redis:link myapp-cache myapp

# REDIS_URL is auto-set
```

### Workflow 5: Backup & Restore Database

```bash
# Export database
bash scripts/manage.sh postgres:export myapi-db > backup-$(date +%Y%m%d).sql

# Import database
bash scripts/manage.sh postgres:import myapi-db < backup.sql

# Clone a database
bash scripts/manage.sh postgres:clone myapi-db myapi-db-staging
```

### Workflow 6: Zero-Downtime Deploys

```bash
# Enable zero-downtime checks
bash scripts/manage.sh checks:enable myapp

# Set custom health check
bash scripts/manage.sh checks:set myapp /health

# Deploy rolls back automatically if health check fails
```

### Workflow 7: List All Apps & Status

```bash
# List all apps
bash scripts/manage.sh apps:list

# Full status report
bash scripts/manage.sh report

# Storage and resource usage
bash scripts/manage.sh ps:report --all
```

## Configuration

### Environment Variables

```bash
# Set variables (triggers app restart)
bash scripts/manage.sh config:set myapp \
  NODE_ENV=production \
  API_KEY=secret123 \
  PORT=5000

# View all config
bash scripts/manage.sh config myapp

# Remove a variable
bash scripts/manage.sh config:unset myapp OLD_VAR
```

### Custom Domains

```bash
# Add domain
bash scripts/manage.sh domains:add myapp api.example.com

# Remove domain
bash scripts/manage.sh domains:remove myapp old.example.com

# List domains
bash scripts/manage.sh domains:report myapp
```

### Buildpacks

```bash
# Set a buildpack (auto-detected by default)
bash scripts/manage.sh buildpacks:set myapp https://github.com/heroku/heroku-buildpack-nodejs

# Use Dockerfile instead
# Just include a Dockerfile in your repo — Dokku detects it automatically

# Use Cloud Native Buildpacks (CNB)
bash scripts/manage.sh builder:set myapp pack
```

### Docker Options

```bash
# Mount volumes
bash scripts/manage.sh storage:mount myapp /var/lib/dokku/data/storage/myapp:/app/uploads

# Set Docker options
bash scripts/manage.sh docker-options:add myapp deploy "--memory 512m"
bash scripts/manage.sh docker-options:add myapp deploy "--cpus 1.5"
```

## Available Plugins

The manage script can install these popular Dokku plugins:

| Plugin | Command | What It Does |
|--------|---------|-------------|
| **postgres** | `plugin:install postgres` | PostgreSQL databases |
| **redis** | `plugin:install redis` | Redis key-value store |
| **mysql** | `plugin:install mysql` | MySQL databases |
| **mongo** | `plugin:install mongo` | MongoDB databases |
| **letsencrypt** | `plugin:install letsencrypt` | Auto SSL certificates |
| **rabbitmq** | `plugin:install rabbitmq` | Message queue |
| **elasticsearch** | `plugin:install elasticsearch` | Search engine |
| **memcached** | `plugin:install memcached` | In-memory caching |

## Troubleshooting

### Issue: "Permission denied" during install

**Fix:** Run install script with sudo:
```bash
sudo bash scripts/install.sh
```

### Issue: App not accessible after deploy

**Check:**
1. App is running: `dokku ps:report myapp`
2. Port mapping: `dokku proxy:ports myapp`
3. Domain set: `dokku domains:report myapp`
4. Logs: `dokku logs myapp --tail`

### Issue: Deploy fails with "no matching app"

**Fix:** Make sure app exists:
```bash
dokku apps:list
dokku apps:create myapp  # if missing
```

### Issue: Database connection refused

**Check:**
1. Database running: `dokku postgres:info myapi-db`
2. Linked to app: `dokku postgres:linked myapi-db myapp`
3. Check DATABASE_URL: `dokku config myapp | grep DATABASE`

### Issue: SSL certificate not renewing

**Fix:**
```bash
# Check cron job exists
dokku letsencrypt:cron-job --list

# Force renewal
dokku letsencrypt:enable myapp
```

## Key Principles

1. **One command per action** — Each Dokku operation is a single command
2. **Convention over config** — Sensible defaults, customize when needed
3. **Plugin ecosystem** — Databases, caching, SSL via plugins
4. **Git-based deploys** — Push code, Dokku handles the rest
5. **Docker under the hood** — Each app runs in isolated containers
6. **Zero-downtime** — Rolling deploys with health checks

## Dependencies

- `bash` (4.0+)
- `docker` (20.10+)
- `curl` (for installation)
- `git` (for deploys)
- Ubuntu 20.04+ / Debian 10+ (recommended)
- Root access (for installation)
