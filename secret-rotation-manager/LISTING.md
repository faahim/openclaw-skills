# Listing Copy: Secret Rotation Manager

## Metadata
- **Type:** Skill
- **Name:** secret-rotation-manager
- **Display Name:** Secret Rotation Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [bash, openssl, jq]

## Tagline

Track and rotate API keys, tokens & credentials — never let secrets expire silently

## Description

API keys expire. Tokens get stale. Database passwords sit unchanged for months. By the time you notice, your service is down or — worse — compromised. Manual tracking in spreadsheets doesn't scale, and enterprise secret managers cost more than your whole infrastructure.

Secret Rotation Manager tracks every credential you care about — API keys, database passwords, SSH keys, webhook secrets, OAuth tokens. It monitors expiry dates, alerts you before things expire, auto-generates secure replacements for passwords and keys, and updates your .env files in place. Everything runs locally with encrypted backups and a full audit trail.

**What it does:**
- 🔐 Track unlimited secrets with expiry dates and health status
- ⏰ Alert via Telegram or webhook when credentials are expiring
- 🔄 Auto-generate secure passwords and SSH keys on rotation
- 📁 Update .env files automatically when rotating secrets
- 🗄️ Encrypted backups of old values (AES-256)
- 📊 Generate inventory reports (Markdown or CSV)
- 📝 Full audit trail of every rotation event
- 📥 Bulk import secrets from existing .env files
- 🕐 Cron-ready for daily automated checks

**Who it's for:** Developers, sysadmins, and indie hackers managing credentials across multiple services who want automated tracking without enterprise complexity.

## Quick Start Preview

```bash
# Add a secret
bash rotate.sh add --name "stripe-key" --service "stripe" --type "api-key" \
  --value "sk_live_xxx" --expires "2026-06-15" --warn-days 14

# Check health
bash rotate.sh status
# ┌─────────────────┬──────────┬────────────┬──────────────┬──────────┐
# │ Name            │ Service  │ Expires    │ Status       │
# │ stripe-key      │ stripe   │ 2026-06-15 │ ✅ OK        │
# └─────────────────┴──────────┴────────────┴──────────────┘

# Auto-rotate a password
bash rotate.sh rotate --name "db-password" --length 32
# 🔄 Rotated 'db-password' — new expiry: 2026-06-08
```

## Core Capabilities

1. Secret lifecycle tracking — Add, monitor, rotate, and retire credentials
2. Expiry monitoring — Alert days/weeks before secrets expire
3. Auto-rotation — Generate secure passwords and SSH keys automatically
4. .env integration — Update config files in place during rotation
5. Encrypted backups — AES-256-CBC encrypted old value storage
6. Multi-channel alerts — Telegram, Slack/Discord webhooks, custom endpoints
7. Audit logging — Full trail of every create/rotate/delete event
8. Bulk import — Import entire .env files with one command
9. Report generation — Markdown and CSV inventory reports
10. Cron-ready — Daily automated checks with alerting
11. Offline-first — No external services required, fully self-hosted

## Dependencies
- `bash` (4.0+)
- `openssl`
- `jq`
- `curl` (optional, for alerts)

## Installation Time
**5 minutes**

## Pricing Justification

**Why $15:**
- Enterprise alternatives: $50-500/month (HashiCorp Vault, AWS Secrets Manager)
- LarryBrain range: $10-20 for automation tools
- Complexity: Medium-high (encryption, file updates, alerting, audit)
- Value: Prevents outages and security incidents from expired credentials
