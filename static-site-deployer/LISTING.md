# Listing Copy: Static Site Deployer

## Metadata
- **Type:** Skill
- **Name:** static-site-deployer
- **Display Name:** Static Site Deployer
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [bash, curl, git, npm]

## Tagline

Deploy static sites to Netlify, Surge, Cloudflare Pages, or GitHub Pages in one command

## Description

Deploying a static site shouldn't require clicking through three dashboards and remembering provider-specific commands. Whether it's a React build, Hugo output, docs folder, or plain HTML — you just want it live.

Static Site Deployer gives your OpenClaw agent a single unified command that works across all major static hosting platforms. Point it at a directory, pick a provider, and get a live URL in seconds. Supports draft previews, production deploys, multi-platform deploys, teardowns, and CI/CD integration.

**What it does:**
- 🚀 One-command deploy to Surge, Netlify, Cloudflare Pages, or GitHub Pages
- 🔄 Multi-provider deploy (same build → multiple platforms)
- 👀 Draft/preview deploys before going live (Netlify)
- 🏗️ Pre-deploy build hooks (`--build "npm run build"`)
- 🗑️ Teardown/delete deployments
- 📋 List recent deployments
- ⚙️ Config file support for repeatable deploys
- 🤖 CI/CD ready — works headless with environment variables

Perfect for developers, indie hackers, and anyone who ships static sites and wants deployment automated without vendor lock-in.

## Core Capabilities

1. Surge deployment — Instant deploy, no account needed for first try
2. Netlify deployment — Draft previews + production deploys via CLI
3. Cloudflare Pages — Deploy to the global edge network
4. GitHub Pages — Push to gh-pages branch automatically
5. Multi-provider — Deploy to multiple platforms in one command
6. Build hooks — Run build commands before deploying
7. Config files — YAML config for repeatable deployments
8. Teardown — Remove deployments cleanly
9. Idempotent — Re-run to update, won't create duplicates
10. Provider-agnostic — Same interface regardless of hosting platform

## Dependencies
- `bash` (4.0+)
- `git`
- `npm` / `npx`
- Provider CLIs installed per-use: `surge`, `netlify-cli`, `wrangler`

## Installation Time
**5 minutes** — Install provider CLI, set token, deploy
