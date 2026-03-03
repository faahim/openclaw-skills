---
name: kamal-deploy
description: >-
  Install and manage Kamal — zero-downtime Docker deployments to any server via SSH.
categories: [dev-tools, automation]
dependencies: [docker, ruby, ssh]
---

# Kamal Deploy Manager

## What This Does

Deploy any Dockerized web app to bare metal or VPS with zero downtime using [Kamal](https://kamal-deploy.org/) (by 37signals/Basecamp). Handles Docker builds, Traefik load balancing, rolling deploys, secrets management, and multi-server orchestration — all over SSH.

**Example:** "Deploy my Rails/Node/Python app to a $5 VPS with SSL, zero-downtime rolling deploys, and automatic health checks."

## Quick Start (10 minutes)

### 1. Install Kamal

```bash
# Install via Ruby gem (recommended)
gem install kamal

# Verify installation
kamal version

# If Ruby not installed:
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y ruby ruby-dev
gem install kamal

# Mac
brew install ruby
gem install kamal
```

### 2. Initialize a New Project

```bash
cd /path/to/your/app

# Generate Kamal config files
kamal init

# This creates:
# config/deploy.yml  — Main deployment config
# .kamal/secrets     — Environment secrets (git-ignored)
# .env               — Local env template
```

### 3. Configure Deployment

Edit `config/deploy.yml`:

```yaml
service: my-app
image: your-dockerhub-username/my-app

servers:
  web:
    - 123.45.67.89  # Your server IP
  # workers:
  #   - 123.45.67.90

proxy:
  ssl: true
  host: myapp.example.com

registry:
  username: your-dockerhub-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    NODE_ENV: production
    PORT: "3000"
  secret:
    - DATABASE_URL
    - SECRET_KEY_BASE
```

### 4. Set Secrets

Edit `.kamal/secrets`:

```bash
KAMAL_REGISTRY_PASSWORD=your-dockerhub-password
DATABASE_URL=postgres://user:pass@db-host:5432/myapp
SECRET_KEY_BASE=your-secret-key
```

### 5. Deploy

```bash
# First deploy (sets up Docker + Traefik on server)
kamal setup

# Subsequent deploys
kamal deploy
```

## Core Workflows

### Workflow 1: First-Time Server Setup

**Use case:** Provision a fresh VPS for deployments

**Prerequisites:**
- Server with SSH access (root or sudo user)
- Docker Hub account (or any container registry)
- Domain pointing to server IP

```bash
# Ensure SSH access works
ssh root@123.45.67.89 "echo connected"

# Run full setup (installs Docker, Traefik, deploys app)
kamal setup

# Output:
# Acquiring the deploy lock...
# Building Docker image...
# Pushing Docker image...
# Starting Traefik on 123.45.67.89...
# Starting container on 123.45.67.89...
# Releasing the deploy lock...
```

### Workflow 2: Zero-Downtime Deploy

**Use case:** Ship a new version without interrupting users

```bash
# Deploy latest code
kamal deploy

# Deploy a specific git ref
kamal deploy --version=$(git rev-parse HEAD)

# Skip build (use existing image)
kamal deploy --skip-push
```

### Workflow 3: Rollback

**Use case:** Something went wrong, revert immediately

```bash
# Rollback to previous version
kamal rollback

# Rollback to specific version
kamal rollback --version abc123def

# Check available versions
kamal app containers
```

### Workflow 4: Run Commands on Server

**Use case:** Run migrations, console, or one-off tasks

```bash
# Run a command in the app container
kamal app exec "rails db:migrate"
kamal app exec "node scripts/seed.js"

# Interactive console
kamal app exec -i "rails console"
kamal app exec -i "bash"

# Run on specific server
kamal app exec --hosts 123.45.67.89 "rake task:run"
```

### Workflow 5: Manage Secrets

**Use case:** Update environment variables without code changes

```bash
# Edit secrets
vi .kamal/secrets

# Push updated env to servers (restarts containers)
kamal env push
kamal deploy
```

### Workflow 6: Multi-Server Deployment

**Use case:** Deploy across multiple servers with different roles

```yaml
# config/deploy.yml
servers:
  web:
    - 10.0.0.1
    - 10.0.0.2
    - 10.0.0.3
  workers:
    hosts:
      - 10.0.0.4
    cmd: "bundle exec sidekiq"
```

```bash
# Deploy to all servers
kamal deploy

# Deploy only web servers
kamal deploy --roles web
```

### Workflow 7: Monitoring & Logs

**Use case:** Check app health and debug issues

```bash
# View app logs (follow mode)
kamal app logs -f

# View logs from specific server
kamal app logs --hosts 123.45.67.89

# View Traefik proxy logs
kamal proxy logs -f

# Check running containers
kamal app containers

# Check app details
kamal app details
```

### Workflow 8: Accessory Services

**Use case:** Deploy databases, Redis, etc. alongside your app

```yaml
# config/deploy.yml
accessories:
  db:
    image: postgres:16
    host: 123.45.67.89
    port: "127.0.0.1:5432:5432"
    env:
      clear:
        POSTGRES_DB: myapp_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data

  redis:
    image: redis:7
    host: 123.45.67.89
    port: "127.0.0.1:6379:6379"
    directories:
      - data:/data
```

```bash
# Boot accessories
kamal accessory boot db
kamal accessory boot redis

# Check accessory logs
kamal accessory logs db -f

# Restart an accessory
kamal accessory reboot redis
```

## Configuration Reference

### Full config/deploy.yml Template

```yaml
# Service name (used in container naming)
service: my-app

# Docker image name
image: username/my-app

# Servers by role
servers:
  web:
    - 123.45.67.89
    labels:
      traefik.http.routers.my-app.rule: Host(`myapp.com`)

# Container registry
registry:
  server: ghcr.io          # Default: Docker Hub
  username: your-username
  password:
    - KAMAL_REGISTRY_PASSWORD

# Proxy (Traefik) config
proxy:
  ssl: true
  host: myapp.com
  app_port: 3000           # Port your app listens on
  healthcheck:
    path: /up
    interval: 3
    timeout: 3

# Build configuration
builder:
  multiarch: false          # Set true for ARM + x86
  args:
    RUBY_VERSION: "3.3"
  cache:
    type: registry
    image: username/my-app-build-cache

# Environment variables
env:
  clear:
    RAILS_ENV: production
    NODE_ENV: production
  secret:
    - DATABASE_URL
    - REDIS_URL
    - SECRET_KEY_BASE

# SSH configuration
ssh:
  user: deploy              # Default: root
  port: 22
  # proxy: "ssh -W %h:%p bastion.example.com"

# Health check
healthcheck:
  path: /up
  port: 3000
  max_attempts: 10
  interval: 3
```

## Troubleshooting

### Issue: "Permission denied (publickey)"

**Fix:**
```bash
# Ensure SSH key is added
ssh-add ~/.ssh/id_rsa

# Test connection
ssh root@your-server "echo ok"

# If using non-root user, ensure they have Docker permissions
ssh deploy@your-server "docker ps"
```

### Issue: "Docker build failed"

**Fix:**
```bash
# Build locally first to debug
docker build -t test .

# Check Dockerfile exists in project root
ls Dockerfile

# For multi-platform builds
kamal build push --verbose
```

### Issue: "Health check failed"

**Fix:**
```bash
# Check your app's health endpoint
curl http://your-server:3000/up

# View container logs
kamal app logs

# Check if port matches config
kamal app exec "netstat -tlnp"
```

### Issue: "Traefik not routing traffic"

**Fix:**
```bash
# Check Traefik status
kamal proxy logs

# Restart Traefik
kamal proxy reboot

# Verify DNS points to server
dig myapp.com
```

### Issue: "Deploy lock stuck"

**Fix:**
```bash
# Release stuck lock
kamal lock release

# Check lock status
kamal lock status
```

## Installation Script

For automated setup, use:

```bash
bash scripts/install.sh
```

This installs Ruby (if needed), Kamal gem, and verifies Docker is available.

## Key Principles

1. **Zero downtime** — Rolling deploys with health checks
2. **Simple config** — One YAML file, no Kubernetes complexity
3. **SSH-based** — No agents on servers, just SSH + Docker
4. **Registry-backed** — Build once, deploy to many servers
5. **Secrets management** — Encrypted secrets, never in git
6. **Multi-role** — Web servers, workers, accessories in one config
