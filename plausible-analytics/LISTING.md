# Listing Copy: Plausible Analytics Manager

## Metadata
- **Type:** Skill
- **Name:** plausible-analytics
- **Display Name:** Plausible Analytics Manager
- **Categories:** [analytics, automation]
- **Price:** $15
- **Icon:** 📊
- **Dependencies:** [docker, docker-compose, curl, openssl, jq]

## Tagline

Deploy self-hosted Plausible Analytics — privacy-friendly web analytics you own

## Description

Tired of Google Analytics tracking your users, slowing your site with 45KB scripts, and requiring cookie consent banners? Plausible Analytics is the lightweight, privacy-friendly alternative — and this skill deploys it on your server in 10 minutes.

Plausible Analytics Manager handles the entire lifecycle: deploy with Docker Compose (Plausible + PostgreSQL + ClickHouse), configure reverse proxy, add tracking to your sites, pull traffic stats from the CLI, set up automated reports, and manage backups and updates. No manual Docker wrestling required.

**What you get:**
- 🚀 One-command deployment with Docker Compose
- 📊 CLI traffic stats (visitors, pageviews, sources, top pages)
- 🔔 Automated weekly reports via Telegram
- 💾 Backup and restore your analytics data
- 🔄 One-command updates to latest version
- 🔒 Nginx reverse proxy config with SSL
- 📈 API access for custom integrations
- 🛡️ GDPR-compliant, no cookies, <1KB tracking script

Perfect for developers, indie hackers, and anyone who wants web analytics without selling their users' data to Google.

## Core Capabilities

1. One-command deployment — Docker Compose setup with Plausible, PostgreSQL, and ClickHouse
2. CLI traffic stats — Visitors, pageviews, bounce rate, top pages, and sources from terminal
3. Multi-site support — Track unlimited domains from one instance
4. Automated reports — Weekly traffic summaries via Telegram or email
5. Backup & restore — Export and import all analytics data
6. Auto-update — Pull latest Plausible version with one command
7. Nginx integration — Generate reverse proxy config with SSL termination
8. Custom events — Track button clicks, signups, purchases
9. Google Analytics import — Migrate historical data from GA
10. Ad-blocker bypass — Proxy tracking script through your domain
11. Resource tuning — Configure memory limits for ClickHouse and Plausible
12. Health monitoring — Check container status and service health

## Installation Time
**10 minutes** — Run setup, configure reverse proxy, add tracking snippet
