# Listing Copy: Static Site Deployer

## Metadata
- **Type:** Skill
- **Name:** static-site-deployer
- **Display Name:** Static Site Deployer
- **Categories:** [dev-tools, automation]
- **Icon:** 🚀
- **Price:** $10
- **Dependencies:** [bash, node, npm]

## Tagline

Deploy static sites to Cloudflare Pages, Netlify, or Vercel in one command

## Description

Deploying a static site shouldn't require memorizing three different CLI syntaxes. Whether you use Cloudflare Pages, Netlify, or Vercel, it's the same frustrating dance: install the CLI, authenticate, figure out the right flags, set up the project, and hope the deploy works.

**Static Site Deployer** gives your OpenClaw agent a unified interface for all three major hosting providers. One command deploys your `./dist`, `./build`, or `./out` folder to any provider. It handles CLI installation, project auto-creation, preview vs production deploys, environment variables, custom domains, and rollbacks.

**What it does:**
- 🚀 One-command deploy to Cloudflare Pages, Netlify, or Vercel
- 📦 Auto-installs provider CLIs (wrangler, netlify-cli, vercel)
- 🌐 Custom domain setup with DNS instructions
- 🔄 Preview deployments for branches/PRs
- 🔑 Environment variable management across providers
- ⏪ Rollback to previous deployments
- 🔨 Build + deploy pipeline (git pull → build → deploy)
- 📋 List and compare recent deployments

Perfect for developers and indie hackers who ship frequently and want their AI agent to handle deploys without context-switching between provider dashboards.

## Quick Start Preview

```bash
# Install provider CLI
bash scripts/install.sh cloudflare

# Deploy in one command
bash scripts/deploy.sh --provider cloudflare --dir ./dist --project my-site

# Output:
# 🚀 Deploying to Cloudflare Pages...
# ✅ Deployed! URL: https://my-site.pages.dev (12s)
```

## Core Capabilities

1. Multi-provider support — Cloudflare Pages, Netlify, Vercel with identical interface
2. One-command deploy — `deploy.sh --provider cf --dir ./dist --project my-site`
3. Auto-install — Installs provider CLIs if missing
4. Preview deploys — Branch-based previews without touching production
5. Build pipeline — Git pull + build + deploy in one step
6. Env management — Set/list/delete environment variables per provider
7. Custom domains — Add domains with DNS setup instructions
8. Rollback — Revert to previous deployment
9. Config file — Optional YAML config for repeated deploys
10. CI/CD ready — Works with OpenClaw cron for scheduled deploys

## Dependencies
- `bash` (4.0+)
- `node` (18+) and `npm`
- `curl`

## Installation Time
**5 minutes** — Install CLI, authenticate, deploy
