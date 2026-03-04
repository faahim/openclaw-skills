---
name: static-site-deployer
description: >-
  Deploy static sites to Cloudflare Pages, Netlify, or Vercel from the terminal in one command.
categories: [dev-tools, automation]
dependencies: [bash, curl, node]
---

# Static Site Deployer

## What This Does

Deploy any static site (HTML, React, Vue, Hugo, Astro, etc.) to **Cloudflare Pages**, **Netlify**, or **Vercel** with a single command. Handles CLI installation, project setup, environment variables, and production/preview deployments.

**Example:** "Deploy my `./dist` folder to Cloudflare Pages as `my-portfolio`, set up custom domain, and get a live URL in 30 seconds."

## Quick Start (5 minutes)

### 1. Install a Provider CLI

```bash
# Pick one (or install all):
bash scripts/install.sh cloudflare   # Installs wrangler
bash scripts/install.sh netlify      # Installs netlify-cli
bash scripts/install.sh vercel       # Installs vercel CLI
```

### 2. Authenticate

```bash
# Cloudflare Pages
npx wrangler login
# — OR set token —
export CLOUDFLARE_API_TOKEN="<your-token>"
export CLOUDFLARE_ACCOUNT_ID="<your-account-id>"

# Netlify
npx netlify login
# — OR —
export NETLIFY_AUTH_TOKEN="<your-token>"

# Vercel
npx vercel login
# — OR —
export VERCEL_TOKEN="<your-token>"
```

### 3. Deploy

```bash
# Deploy ./dist to Cloudflare Pages
bash scripts/deploy.sh --provider cloudflare --dir ./dist --project my-site

# Deploy ./build to Netlify
bash scripts/deploy.sh --provider netlify --dir ./build --site my-site

# Deploy ./out to Vercel (production)
bash scripts/deploy.sh --provider vercel --dir ./out --prod
```

## Core Workflows

### Workflow 1: Deploy to Cloudflare Pages

**Use case:** Ship a static site to Cloudflare's global CDN

```bash
bash scripts/deploy.sh \
  --provider cloudflare \
  --dir ./dist \
  --project my-portfolio \
  --branch main
```

**Output:**
```
🚀 Deploying to Cloudflare Pages...
   Project: my-portfolio
   Directory: ./dist (42 files, 1.2 MB)
   Branch: main (production)

✅ Deployed successfully!
   URL: https://my-portfolio.pages.dev
   Preview: https://abc123.my-portfolio.pages.dev
   Time: 12s
```

### Workflow 2: Deploy to Netlify

**Use case:** Quick deploy with Netlify's features (forms, functions, redirects)

```bash
bash scripts/deploy.sh \
  --provider netlify \
  --dir ./build \
  --site my-app \
  --prod
```

**Output:**
```
🚀 Deploying to Netlify...
   Site: my-app
   Directory: ./build (67 files, 2.4 MB)
   Production: yes

✅ Deployed successfully!
   URL: https://my-app.netlify.app
   Deploy ID: 6543210fedcba
   Time: 8s
```

### Workflow 3: Deploy to Vercel

**Use case:** Deploy with Vercel's edge network and preview URLs

```bash
bash scripts/deploy.sh \
  --provider vercel \
  --dir ./out \
  --prod
```

### Workflow 4: Preview Deployment (Any Provider)

**Use case:** Deploy a branch/PR for review without touching production

```bash
# Cloudflare preview
bash scripts/deploy.sh --provider cloudflare --dir ./dist --project my-site --branch feature-redesign

# Netlify draft
bash scripts/deploy.sh --provider netlify --dir ./build --site my-site

# Vercel preview (default without --prod)
bash scripts/deploy.sh --provider vercel --dir ./out
```

### Workflow 5: Multi-Provider Deploy

**Use case:** Deploy the same site to multiple CDNs for redundancy

```bash
bash scripts/deploy.sh --provider cloudflare --dir ./dist --project my-site
bash scripts/deploy.sh --provider netlify --dir ./dist --site my-site --prod
bash scripts/deploy.sh --provider vercel --dir ./dist --prod
```

### Workflow 6: Set Environment Variables

```bash
# Cloudflare
bash scripts/env.sh --provider cloudflare --project my-site --set "API_URL=https://api.example.com"

# Netlify
bash scripts/env.sh --provider netlify --site my-site --set "API_URL=https://api.example.com"

# Vercel
bash scripts/env.sh --provider vercel --set "API_URL=https://api.example.com"
```

### Workflow 7: Custom Domain Setup

```bash
# Cloudflare
bash scripts/domain.sh --provider cloudflare --project my-site --domain example.com

# Netlify
bash scripts/domain.sh --provider netlify --site my-site --domain example.com

# Vercel
bash scripts/domain.sh --provider vercel --domain example.com
```

## Configuration

### Environment Variables

```bash
# Cloudflare
export CLOUDFLARE_API_TOKEN="<token>"
export CLOUDFLARE_ACCOUNT_ID="<account-id>"

# Netlify
export NETLIFY_AUTH_TOKEN="<token>"

# Vercel
export VERCEL_TOKEN="<token>"
export VERCEL_ORG_ID="<org-id>"        # optional
export VERCEL_PROJECT_ID="<project-id>" # optional
```

### Config File (Optional)

```yaml
# deploy.yaml — use with: bash scripts/deploy.sh --config deploy.yaml
provider: cloudflare
directory: ./dist
project: my-portfolio
branch: main
env:
  API_URL: https://api.example.com
  NODE_ENV: production
```

## Advanced Usage

### Build + Deploy Pipeline

```bash
# Build your site first, then deploy
npm run build && bash scripts/deploy.sh --provider cloudflare --dir ./dist --project my-site --prod

# Or use the all-in-one:
bash scripts/build-deploy.sh --provider netlify --build-cmd "npm run build" --dir ./dist --site my-site
```

### CI/CD Integration (Cron-Based)

```bash
# Deploy on schedule via OpenClaw cron
# Pulls latest from git, builds, deploys
bash scripts/build-deploy.sh \
  --provider cloudflare \
  --git-pull \
  --build-cmd "npm run build" \
  --dir ./dist \
  --project my-site
```

### Rollback

```bash
# Netlify — rollback to previous deploy
bash scripts/rollback.sh --provider netlify --site my-site

# Vercel — rollback to previous deployment
bash scripts/rollback.sh --provider vercel
```

### List Deployments

```bash
bash scripts/list.sh --provider cloudflare --project my-site
bash scripts/list.sh --provider netlify --site my-site --limit 10
bash scripts/list.sh --provider vercel --limit 5
```

## Troubleshooting

### Issue: "wrangler: command not found"

**Fix:**
```bash
bash scripts/install.sh cloudflare
# or manually:
npm install -g wrangler
```

### Issue: "Not authenticated"

**Fix:**
```bash
# Interactive login
npx wrangler login        # Cloudflare
npx netlify login         # Netlify
npx vercel login          # Vercel

# Or set token in environment
export CLOUDFLARE_API_TOKEN="..."
```

### Issue: "Project not found"

**Fix:** The script auto-creates projects on first deploy. If it fails:
```bash
# Cloudflare — create manually
npx wrangler pages project create my-site

# Netlify — create manually
npx netlify sites:create --name my-site
```

### Issue: "Directory is empty"

**Fix:** Make sure you've built your site first:
```bash
npm run build   # or your build command
ls ./dist/      # verify files exist
```

## Dependencies

- `bash` (4.0+)
- `node` (18+) and `npm` — for installing provider CLIs
- `curl` — for API fallback
- Provider CLI: `wrangler` (Cloudflare), `netlify-cli` (Netlify), or `vercel` (Vercel)

## Key Principles

1. **One command deploy** — No config files required for basic deploys
2. **Provider-agnostic** — Same interface for CF Pages, Netlify, Vercel
3. **Auto-create projects** — First deploy creates the project automatically
4. **Preview by default** — Production deploys require explicit `--prod` flag
5. **Fail gracefully** — Clear error messages, no silent failures
