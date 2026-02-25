# Listing Copy: Uptime Kuma Manager

## Metadata
- **Type:** Skill
- **Name:** uptime-kuma
- **Display Name:** Uptime Kuma Manager
- **Categories:** [automation, dev-tools]
- **Icon:** 📡
- **Dependencies:** [docker, curl, jq]

## Tagline
Install & manage Uptime Kuma — self-hosted monitoring with 90+ alert integrations

## Description

Manually checking if your sites are up is a losing game. And SaaS monitoring tools charge $10-50/month for something you can run yourself for free.

Uptime Kuma Manager installs and manages the most popular open-source monitoring dashboard (58k+ GitHub stars) entirely from the command line. Install via Docker, add HTTP/TCP/ping/DNS/keyword monitors, set up Telegram/Slack/Discord/email alerts, and create public status pages — all without opening a browser.

**What it does:**
- 🐳 One-command Docker install, upgrade, backup, and restore
- 📡 Add/list/pause/delete monitors (HTTP, TCP, ping, DNS, keyword, Docker, databases)
- 🔔 Configure 90+ notification types (Telegram, Slack, Discord, email, webhooks)
- 📊 Create public status pages for your services
- 🔐 SSL certificate expiry monitoring with configurable alerts
- 📦 Bulk import monitors from YAML config files
- 🔄 Automated backup and restore of all data

Perfect for developers, sysadmins, and indie hackers who want professional monitoring without SaaS fees or vendor lock-in.

## Quick Start Preview

```bash
# Install Uptime Kuma
bash scripts/install.sh

# Add a monitor
bash scripts/monitor.sh add --name "My Site" --url "https://example.com" --interval 60

# Add Telegram alerts
bash scripts/notify.sh add --type telegram --name "Alerts" --token "BOT_TOKEN" --chat-id "CHAT_ID"
```
