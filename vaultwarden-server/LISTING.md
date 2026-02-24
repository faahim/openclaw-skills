# Listing Copy: Vaultwarden Password Server

## Metadata
- **Type:** Skill
- **Name:** vaultwarden-server
- **Display Name:** Vaultwarden Password Server
- **Categories:** [security, home]
- **Price:** $15
- **Dependencies:** [docker, docker-compose, openssl, curl, jq]

## Tagline

Deploy a self-hosted Bitwarden-compatible password vault — encrypted backups, SSL, admin controls

## Description

Storing passwords in your browser or a third-party cloud service means trusting someone else with your most sensitive data. If you want full control over your credentials, you need a self-hosted solution — but setting one up is tedious and error-prone.

Vaultwarden Password Server deploys a production-ready, Bitwarden-compatible password manager on your server with a single command. It handles Docker setup, automatic SSL via Caddy, encrypted nightly backups, admin panel configuration, and Fail2Ban brute-force protection. Works with every official Bitwarden client — browser extensions, mobile apps, and desktop.

**What it does:**
- 🚀 One-command deployment with Docker Compose
- 🔒 Automatic SSL certificates via Let's Encrypt + Caddy
- 📦 Encrypted nightly backups with configurable retention
- 🔄 Restore from backup in one command
- 🛡️ Fail2Ban integration for brute-force protection
- 👥 Admin panel for user management and invites
- 📧 SMTP email configuration for notifications
- 🔄 WebSocket live sync across all devices
- ⬆️ One-command updates to latest version
- 📊 Health checks: uptime, SSL expiry, data size, backup status

Perfect for developers, sysadmins, and privacy-conscious users who want a self-hosted password manager without the complexity of manual setup.

## Quick Start Preview

```bash
# Deploy with SSL
bash scripts/run.sh deploy --domain vault.yourdomain.com --ssl --email you@email.com

# Output:
# ✅ Vaultwarden deployed at https://vault.yourdomain.com
# 🔑 Admin panel: https://vault.yourdomain.com/admin
# 🔒 SSL: Let's Encrypt via Caddy (auto-renew)
```

## Dependencies
- `docker` (20.10+) with `docker compose` v2
- `openssl`, `curl`, `jq`
- Optional: `fail2ban`, `cron`

## Installation Time
**10 minutes** — run deploy script, create account, install Bitwarden clients
