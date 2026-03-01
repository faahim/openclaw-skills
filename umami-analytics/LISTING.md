# Listing Copy: Umami Analytics Manager

## Metadata
- **Type:** Skill
- **Name:** umami-analytics
- **Display Name:** Umami Analytics Manager
- **Categories:** [analytics, automation]
- **Price:** $15
- **Dependencies:** [docker, docker-compose, curl, jq]
- **Icon:** 📊

## Tagline

Deploy self-hosted web analytics — privacy-first, no cookies, you own your data

## Description

Google Analytics is bloated, privacy-invasive, and slows down your site. But flying blind without analytics isn't an option either.

Umami Analytics Manager deploys and manages Umami — a lightweight, privacy-focused web analytics platform — entirely on your own server. No cookies, no tracking consent banners, fully GDPR/CCPA compliant. One command to deploy, one script tag to start tracking.

**What it does:**
- 🚀 One-command deployment via Docker (Umami + PostgreSQL)
- 📊 Check traffic stats, top pages, and referrers from your terminal
- 🌐 Add unlimited websites with auto-generated tracking scripts
- 💾 Automated database backups with cron scheduling
- 🔄 Painless updates to latest Umami version
- 📨 Weekly traffic reports via Telegram
- 🔧 Generate Nginx/Caddy reverse proxy configs
- 🔒 Ad-blocker bypass with custom script naming
- 📈 Full Umami API access for custom integrations

Perfect for developers, indie hackers, and privacy-conscious site owners who want actionable analytics without selling their visitors' data.

## Quick Start Preview

```bash
# Deploy Umami
bash scripts/run.sh deploy --port 3000

# Add a website
bash scripts/run.sh add-site --name "My Blog" --domain "myblog.com"

# Check today's stats
bash scripts/run.sh stats
```

## Core Capabilities

1. Docker deployment — Umami + PostgreSQL in one command
2. Multi-site tracking — Add unlimited websites, get tracking scripts
3. Terminal stats — Check visitors, views, bounce rate from CLI
4. Top pages & referrers — See what content performs best
5. Database backup — Manual or scheduled (cron) backups with gzip
6. One-command updates — Pull latest Umami version and restart
7. Telegram reports — Weekly/daily traffic digests to your phone
8. Reverse proxy configs — Auto-generate Nginx or Caddy configs
9. Ad-blocker bypass — Rename tracking script to avoid filters
10. Public dashboards — Share read-only analytics links
11. API access — Full Umami REST API with auth token management
12. Privacy-first — No cookies, no consent banners, GDPR compliant

## Dependencies
- `docker` (20.10+)
- `docker-compose` (v2+)
- `curl`
- `jq`

## Installation Time
**10 minutes** — Deploy, add site, start tracking

## Pricing Justification

**Why $15:**
- Comparable SaaS analytics: $10-50/month (Fathom, Plausible Cloud)
- Self-hosted Umami is free but setup takes 30-60 min manually
- This skill: one-time $15, deploy in 10 min, manage everything from CLI
- Includes backup automation, Telegram reports, proxy configs — beyond basic setup
