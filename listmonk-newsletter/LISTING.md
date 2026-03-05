# Listing Copy: Listmonk Newsletter Manager

## Metadata
- **Type:** Skill
- **Name:** listmonk-newsletter
- **Display Name:** Listmonk Newsletter Manager
- **Categories:** [communication, marketing]
- **Price:** $15
- **Dependencies:** [docker, docker-compose, curl, jq]
- **Icon:** 📧

## Tagline

Self-hosted email newsletters — Send campaigns, manage subscribers, own your data

## Description

Paying $50-500/month for Mailchimp, ConvertKit, or Buttondown? Listmonk is a free, open-source alternative that runs on your own server — and this skill sets it up in 10 minutes.

Listmonk Newsletter Manager installs and configures [Listmonk](https://listmonk.app), a blazing-fast email newsletter and mailing list manager written in Go. Create subscriber lists, design HTML campaigns, import thousands of contacts from CSV, schedule sends, and track opens/clicks — all through simple CLI commands your OpenClaw agent can run.

**What you get:**
- 📧 Send unlimited newsletters — no per-subscriber pricing
- 📋 Manage multiple lists with single/double opt-in
- 📥 Import subscribers from CSV (handles thousands in seconds)
- ⏰ Schedule campaigns or send immediately
- 📊 Track opens, clicks, bounces, and unsubscribes
- 🔐 Full data ownership — GDPR-friendly, no third-party tracking
- 🔄 Automated backups and one-command updates
- 🌐 Optional reverse proxy setup (Caddy/Nginx) with auto-SSL

## Quick Start Preview

```bash
# Install Listmonk (Docker + PostgreSQL)
bash scripts/install.sh

# Configure SMTP
bash scripts/configure-smtp.sh --host smtp.gmail.com --port 587 --user you@gmail.com --password "app-password"

# Create a list and send a campaign
bash scripts/manage.sh create-list --name "Weekly Digest" --type public
bash scripts/manage.sh send-campaign --name "Launch!" --subject "We're live 🚀" --list 1 --body-file campaign.html
```

## Core Capabilities

1. One-command install — Docker + PostgreSQL + Listmonk, configured and running
2. SMTP configuration — Gmail, SES, Postmark, any SMTP provider
3. List management — Create, configure, and manage subscriber lists
4. Subscriber import — Bulk import from CSV with validation
5. Campaign sending — Create, schedule, and send HTML email campaigns
6. Analytics tracking — Opens, clicks, bounces, unsubscribes
7. Template management — Upload and use custom HTML email templates
8. Reverse proxy — Auto-SSL with Caddy or Nginx setup
9. Backup & restore — Full database + config backup to tarball
10. Service management — Start, stop, update, monitor via CLI

## Dependencies
- Docker (20.10+) and Docker Compose v2
- curl, jq
- ~512MB RAM, ~1GB disk
- SMTP access (Gmail, SES, Postmark, etc.)

## Installation Time
**10 minutes** — Run install script, configure SMTP, create first list

## Pricing Justification

**Why $15:**
- Replaces $50-500/mo SaaS newsletter tools (Mailchimp, ConvertKit, Buttondown)
- Complete automation: install, configure, manage, backup
- LarryBrain complexity tier: Medium-High (Docker, PostgreSQL, API integration, reverse proxy)
- One-time payment, unlimited use
