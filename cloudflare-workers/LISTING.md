# Listing Copy: Cloudflare Workers Deployer

## Metadata
- **Type:** Skill
- **Name:** cloudflare-workers
- **Display Name:** Cloudflare Workers Deployer
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [node, npm, wrangler]
- **Icon:** ⚡

## Tagline

Deploy serverless functions to Cloudflare's global edge — create, manage, and monitor Workers from CLI

## Description

Setting up serverless functions shouldn't require clicking through dashboards. Every new worker means navigating Cloudflare's UI, copy-pasting configs, and manually managing KV namespaces and secrets.

**Cloudflare Workers Deployer** gives your OpenClaw agent full control over Cloudflare Workers. Create workers from battle-tested templates (API routers, KV-backed CRUD, cron jobs, reverse proxies), deploy to 300+ edge locations, manage KV storage, set secrets, configure cron triggers, and tail live logs — all from the command line.

**What it does:**
- ⚡ Create workers from 5 templates (hello-world, router, kv-api, cron, proxy)
- 🚀 One-command deploy to Cloudflare's global network
- 📦 Manage KV namespaces (create, put, get, delete, bulk upload)
- 🔐 Set and manage worker secrets securely
- ⏰ Configure cron triggers for scheduled tasks
- 📊 Tail live logs with status and search filters
- 🌐 Custom domain routing
- 📏 Bundle size analysis

Perfect for developers and indie hackers who want to deploy edge functions fast without leaving the terminal.

## Core Capabilities

1. Worker creation — Scaffold from 5 production-ready templates
2. One-command deploy — Push to 300+ Cloudflare edge locations
3. KV namespace management — Full CRUD + bulk operations
4. Secret management — Securely set, list, and rotate secrets
5. Cron trigger config — Schedule workers with cron expressions
6. Live log tailing — Stream logs with status and search filters
7. Custom domain routing — Bind workers to your domains
8. Multi-environment support — Staging and production deploys
9. Bundle size analysis — Track worker size vs limits
10. CI/CD ready — Headless auth via API tokens

## Dependencies
- `node` (18+)
- `npm`
- `wrangler` (auto-installed)

## Installation Time
**3 minutes** — Run install script, authenticate, deploy
