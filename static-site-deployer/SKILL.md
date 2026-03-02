---
name: static-site-deployer
description: >-
  Deploy static sites to GitHub Pages, Netlify, Cloudflare Pages, or Surge with one command.
categories: [dev-tools, automation]
dependencies: [bash, curl, git]
---

# Static Site Deployer

## What This Does

Deploy any static site (HTML, React build, Hugo output, docs) to popular hosting platforms with a single command. Supports GitHub Pages, Netlify, Cloudflare Pages, and Surge.sh — no clicking through dashboards.

**Example:** "Deploy my `./dist` folder to Netlify and get a live URL in 30 seconds."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install the deploy script
chmod +x scripts/deploy.sh

# For Surge (simplest — no account needed for first deploy):
npm install -g surge

# For Netlify:
npm install -g netlify-cli

# For Cloudflare Pages (wrangler):
npm install -g wrangler

# GitHub Pages needs only git (already installed)
```

### 2. Deploy to Surge (Fastest)

```bash
# Deploy any directory — get a URL instantly
bash scripts/deploy.sh --provider surge --dir ./dist

# Output:
# 🚀 Deploying ./dist to Surge...
# ✅ Live at: https://random-name.surge.sh
```

### 3. Deploy to Netlify

```bash
# Set token (one-time)
export NETLIFY_AUTH_TOKEN="your-token-here"

# Deploy
bash scripts/deploy.sh --provider netlify --dir ./build --site-name my-app

# Output:
# 🚀 Deploying ./build to Netlify...
# ✅ Live at: https://my-app.netlify.app
```

## Core Workflows

### Workflow 1: Deploy to GitHub Pages

**Use case:** Publish docs or a project site from a build directory

```bash
bash scripts/deploy.sh \
  --provider github-pages \
  --dir ./docs \
  --repo origin \
  --branch gh-pages

# Pushes contents of ./docs to the gh-pages branch
# ✅ Live at: https://username.github.io/repo-name
```

### Workflow 2: Deploy to Netlify (with draft preview)

**Use case:** Preview a deploy before going live

```bash
# Draft deploy (preview URL only)
bash scripts/deploy.sh \
  --provider netlify \
  --dir ./dist \
  --draft

# Output:
# 🔍 Draft deploy: https://abc123--my-site.netlify.app
# Run with --prod to publish to production
```

```bash
# Production deploy
bash scripts/deploy.sh \
  --provider netlify \
  --dir ./dist \
  --prod
```

### Workflow 3: Deploy to Cloudflare Pages

**Use case:** Deploy to Cloudflare's edge network for global performance

```bash
export CLOUDFLARE_API_TOKEN="your-token"
export CLOUDFLARE_ACCOUNT_ID="your-account-id"

bash scripts/deploy.sh \
  --provider cloudflare \
  --dir ./dist \
  --project-name my-project

# ✅ Live at: https://my-project.pages.dev
```

### Workflow 4: Deploy to Surge.sh

**Use case:** Quick throwaway deploys, prototypes, demos

```bash
# Deploy with custom domain
bash scripts/deploy.sh \
  --provider surge \
  --dir ./build \
  --domain my-demo.surge.sh

# Deploy with auto-generated name
bash scripts/deploy.sh \
  --provider surge \
  --dir ./build
```

### Workflow 5: Multi-Platform Deploy

**Use case:** Deploy the same build to multiple platforms

```bash
bash scripts/deploy.sh \
  --provider surge,netlify \
  --dir ./dist \
  --site-name my-app

# 🚀 Deploying to Surge... ✅ https://my-app.surge.sh
# 🚀 Deploying to Netlify... ✅ https://my-app.netlify.app
```

## Configuration

### Environment Variables

```bash
# Netlify
export NETLIFY_AUTH_TOKEN="<token>"       # Get from app.netlify.com/user/applications
export NETLIFY_SITE_ID="<site-id>"        # Optional: existing site ID

# Cloudflare Pages
export CLOUDFLARE_API_TOKEN="<token>"     # Get from dash.cloudflare.com/profile/api-tokens
export CLOUDFLARE_ACCOUNT_ID="<id>"       # Your account ID

# Surge
export SURGE_LOGIN="<email>"              # Optional: for persistent domains
export SURGE_TOKEN="<token>"              # Optional: for CI/CD

# GitHub Pages (uses git credentials already configured)
```

### Config File (Optional)

```yaml
# deploy.yaml
default_provider: netlify
default_dir: ./dist

providers:
  netlify:
    site_name: my-production-app
    prod: true
  surge:
    domain: my-app.surge.sh
  github-pages:
    branch: gh-pages
    repo: origin
  cloudflare:
    project_name: my-cf-project
```

```bash
# Deploy using config file
bash scripts/deploy.sh --config deploy.yaml
```

## Advanced Usage

### Pre-Deploy Build Hook

```bash
# Run build command before deploying
bash scripts/deploy.sh \
  --provider netlify \
  --dir ./dist \
  --build "npm run build"

# Runs: npm run build → deploys ./dist
```

### Teardown / Delete Site

```bash
# Remove a Surge deployment
bash scripts/deploy.sh --provider surge --teardown --domain my-app.surge.sh

# Remove Netlify site
bash scripts/deploy.sh --provider netlify --teardown --site-name my-app
```

### CI/CD Integration

```bash
# In GitHub Actions, GitLab CI, etc.
# Just set env vars and run:
bash scripts/deploy.sh --provider netlify --dir ./dist --prod

# Exit code 0 = success, 1 = failure
```

### List Deployments

```bash
# Netlify: list recent deploys
bash scripts/deploy.sh --provider netlify --list --site-name my-app

# Output:
# #1  2026-03-02 05:30  Production  https://my-app.netlify.app
# #2  2026-03-01 14:15  Draft       https://abc123--my-app.netlify.app
```

## Troubleshooting

### Issue: "netlify: command not found"

**Fix:**
```bash
npm install -g netlify-cli
# or
npx netlify-cli deploy --dir ./dist
```

### Issue: "Error: 401 Unauthorized" (Netlify)

**Fix:**
1. Generate a new token: https://app.netlify.com/user/applications#personal-access-tokens
2. Set: `export NETLIFY_AUTH_TOKEN="<new-token>"`

### Issue: GitHub Pages not updating

**Fix:**
1. Check if GitHub Pages is enabled in repo Settings → Pages
2. Ensure the branch matches: `--branch gh-pages`
3. Wait 1-2 minutes — GitHub Pages has a propagation delay

### Issue: Surge domain taken

**Fix:**
```bash
# Use a unique domain
bash scripts/deploy.sh --provider surge --dir ./dist --domain unique-name-12345.surge.sh
```

### Issue: Cloudflare "project not found"

**Fix:**
```bash
# Create the project first
wrangler pages project create my-project
# Then deploy
bash scripts/deploy.sh --provider cloudflare --dir ./dist --project-name my-project
```

## Key Principles

1. **One command** — No multi-step dashboard clicking
2. **Provider-agnostic** — Same interface for all platforms
3. **CI/CD ready** — Works headless with env vars
4. **Non-destructive** — Draft deploys by default (Netlify)
5. **Idempotent** — Run again to update, won't duplicate

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests)
- `git` (GitHub Pages)
- `npm` / `npx` (installing provider CLIs)
- Provider CLIs: `surge`, `netlify-cli`, `wrangler` (installed per-provider)
