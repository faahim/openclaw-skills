# Listing Copy: n8n Workflow Automation

## Metadata
- **Type:** Skill
- **Name:** n8n-workflow-automation
- **Display Name:** n8n Workflow Automation
- **Categories:** [automation, productivity]
- **Icon:** ⚙️
- **Dependencies:** [docker, bash, curl]

## Tagline

Deploy and manage n8n — self-hosted workflow automation with 400+ integrations.

## Description

### The Problem

You need to connect services — post RSS items to Slack, sync GitHub issues to Notion, send daily reports via email. Zapier charges $20+/month and your data leaves your machine. Setting up n8n manually means wrestling with Docker, environment variables, encryption keys, and reverse proxy configs.

### The Solution

This skill deploys and manages n8n in one command. Choose SQLite (simple) or PostgreSQL (production). Get auto-SSL with Caddy, webhook tunneling via Cloudflare, and full backup/restore. Your data stays local. No monthly fees.

### Key Features

- ⚙️ One-command deploy via Docker (SQLite or PostgreSQL)
- 🔒 Auto-SSL with Caddy reverse proxy
- 🔗 Webhook tunneling via Cloudflare (no port forwarding)
- 💾 Export/import workflows as JSON
- 🔄 Zero-downtime updates
- 📊 Health monitoring and status checks
- 🧹 Execution pruning and database maintenance
- 👥 Multi-user setup with role-based access

### Who It's For

Developers, indie hackers, and sysadmins who want powerful workflow automation without SaaS fees or data leaving their infrastructure.

## Quick Start Preview

```bash
# Deploy n8n (available at localhost:5678 in 60 seconds)
bash scripts/deploy.sh

# Production setup with PostgreSQL + HTTPS
bash scripts/deploy.sh --postgres --domain n8n.yourdomain.com --https
```

## Core Capabilities

1. Docker-based deployment — SQLite (simple) or PostgreSQL (production)
2. Auto-SSL — Caddy reverse proxy with automatic Let's Encrypt
3. Webhook tunneling — Cloudflare tunnel for NAT/firewall bypass
4. Backup/restore — Export all workflows as JSON, import anywhere
5. Zero-downtime updates — Pull latest, recreate, data preserved
6. Health monitoring — API latency, workflow counts, disk usage
7. Execution pruning — Auto-delete old runs, vacuum database
8. Multi-user mode — Admin/member roles, workflow sharing
9. Encryption — Credentials encrypted at rest, key management
10. Cron replacement — Schedule any workflow with visual editor
