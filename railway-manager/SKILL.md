---
name: railway-manager
description: >-
  Deploy and manage Railway services from the terminal — projects, deployments, environments, domains, and logs.
categories: [dev-tools, automation]
dependencies: [curl, jq]
---

# Railway Manager

## What This Does

Installs and configures the Railway CLI, then provides workflows for deploying apps, managing environments, configuring domains, viewing logs, and monitoring services. Covers the full Railway lifecycle from project creation to production deployment.

**Example:** "Create a project, deploy from GitHub, add a custom domain, set environment variables, and tail production logs."

## Quick Start (5 minutes)

### 1. Install Railway CLI

```bash
bash scripts/install.sh
```

### 2. Authenticate

```bash
railway login
# Opens browser for auth, or use token:
# export RAILWAY_TOKEN="your-token"
# railway login --token "$RAILWAY_TOKEN"
```

### 3. Check Status

```bash
railway status
```

## Core Workflows

### Workflow 1: Create & Deploy a New Project

**Use case:** Deploy an app to Railway from scratch

```bash
# Initialize a new project
railway init

# Link to current directory
railway link

# Deploy
railway up

# Output:
# Deploying from /path/to/app...
# ✅ Deployment successful
# 🔗 https://your-app.up.railway.app
```

### Workflow 2: Manage Environment Variables

**Use case:** Set secrets and config for your services

```bash
# Set a variable
railway variables set DATABASE_URL="postgresql://..."

# Set multiple
railway variables set \
  NODE_ENV=production \
  PORT=3000 \
  API_KEY=secret123

# List all variables
railway variables

# Delete a variable
railway variables delete API_KEY
```

### Workflow 3: Custom Domains

**Use case:** Add your own domain to a Railway service

```bash
# Add custom domain
railway domain add app.example.com

# List domains
railway domain

# Output:
# ✅ app.example.com → CNAME your-app.up.railway.app
# Add this CNAME record to your DNS provider
```

### Workflow 4: View Logs

**Use case:** Debug production issues

```bash
# Tail live logs
railway logs --follow

# Last 100 lines
railway logs --lines 100

# Filter by deployment
railway logs --deployment-id <id>
```

### Workflow 5: Manage Multiple Environments

**Use case:** Separate staging and production

```bash
# List environments
railway environment

# Switch environment
railway environment staging

# Deploy to specific environment
railway up --environment production
```

### Workflow 6: Database Services

**Use case:** Add a managed database

```bash
# Add PostgreSQL
railway add --plugin postgresql

# Add Redis
railway add --plugin redis

# Get connection string
railway variables | grep DATABASE_URL
```

### Workflow 7: Deployment Management

**Use case:** Roll back or redeploy

```bash
# List deployments
railway deployments

# Redeploy latest
railway up --detach

# Check deployment status
railway status
```

## Configuration

### Environment Variables

```bash
# Railway API token (for CI/CD)
export RAILWAY_TOKEN="your-project-token"

# Default project (skip linking)
export RAILWAY_PROJECT_ID="your-project-id"
```

### Project Config (railway.json)

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm run build"
  },
  "deploy": {
    "startCommand": "npm start",
    "healthcheckPath": "/health",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

### Nixpacks Config (nixpacks.toml)

```toml
[phases.setup]
nixPkgs = ["...", "ffmpeg"]

[phases.build]
cmds = ["npm run build"]

[start]
cmd = "npm start"
```

## Advanced Usage

### CI/CD Integration

```bash
# In GitHub Actions:
# - Install CLI
# - Set RAILWAY_TOKEN secret
# - Run deploy

# .github/workflows/deploy.yml
# name: Deploy to Railway
# on: push: branches: [main]
# jobs:
#   deploy:
#     runs-on: ubuntu-latest
#     steps:
#       - uses: actions/checkout@v4
#       - name: Install Railway
#         run: bash scripts/install.sh
#       - name: Deploy
#         run: railway up --detach
#         env:
#           RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

### Service-to-Service Networking

```bash
# Railway services on the same project can communicate via internal DNS:
# SERVICE_NAME.railway.internal:PORT

# Example: API connecting to database
# DATABASE_URL=postgresql://user:pass@postgres.railway.internal:5432/db
```

### Resource Monitoring

```bash
# Check usage via CLI
railway status

# Or use the Railway dashboard API
curl -s -H "Authorization: Bearer $RAILWAY_TOKEN" \
  https://backboard.railway.app/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ me { projects { edges { node { name updatedAt } } } } }"}' | jq .
```

### Monorepo Deploys

```bash
# Deploy specific directory
railway up --src ./apps/api

# Or set in railway.json
# { "build": { "rootDirectory": "apps/api" } }
```

## Troubleshooting

### Issue: "railway: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
curl -fsSL https://railway.app/install.sh | sh
export PATH="$HOME/.railway/bin:$PATH"
```

### Issue: "Not linked to a project"

**Fix:**
```bash
railway link
# Select your project from the list
```

### Issue: Build fails

**Check:**
```bash
# View build logs
railway logs --build

# Common fixes:
# 1. Check Node version: add "engines" to package.json
# 2. Check start command in railway.json
# 3. Verify environment variables are set
```

### Issue: Health check fails

**Fix:**
```bash
# Ensure your app responds on the correct port
# Railway sets PORT env var automatically
# Your app must listen on $PORT (not hardcoded 3000)
```

### Issue: Deployment stuck

**Fix:**
```bash
# Cancel and redeploy
railway up --detach

# Or from dashboard: cancel the deployment manually
```

## Examples

### Deploy a Node.js API

```bash
cd my-api
railway init
railway variables set NODE_ENV=production
railway up
railway domain add api.mysite.com
railway logs --follow
```

### Deploy with PostgreSQL

```bash
railway init
railway add --plugin postgresql
railway variables  # Note the DATABASE_URL
railway up
```

### Deploy a Static Site

```bash
# Create railway.json
echo '{"build":{"builder":"STATIC"}}' > railway.json
railway init
railway up
```

## Dependencies

- `curl` (for installation)
- `jq` (for API queries, optional)
- Railway account (free tier available)

## Key Principles

1. **One command deploys** — `railway up` handles build + deploy
2. **Environment-first** — Use Railway variables, never hardcode secrets
3. **Internal networking** — Services communicate via `.railway.internal`
4. **Auto-scaling** — Railway handles scaling based on usage
5. **Git integration** — Auto-deploy on push when connected to GitHub
