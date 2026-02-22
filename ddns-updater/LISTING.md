# Listing Copy: DDNS Updater

## Metadata
- **Type:** Skill
- **Name:** ddns-updater
- **Display Name:** DDNS Updater
- **Categories:** [automation, dev-tools]
- **Price:** $10
- **Dependencies:** [bash, curl, jq]
- **Icon:** 🌐

## Tagline

"Auto-update DNS records when your IP changes — Cloudflare, DuckDNS, Namecheap & more"

## Description

Your ISP changes your IP without warning. Your self-hosted services go offline. Your VPN stops working. You don't notice for hours.

DDNS Updater monitors your public IP and automatically updates your DNS records when it changes. Supports Cloudflare, DuckDNS, Namecheap, and any webhook-based provider. Set it up once, forget about it forever.

**What it does:**
- 🔍 Detects public IP changes (IPv4 and IPv6)
- 🔄 Updates DNS records automatically via provider APIs
- 📱 Sends Telegram/webhook alerts on IP changes
- ⏰ Runs as cron job or daemon — your choice
- 🏠 Supports multiple domains and providers simultaneously
- 🧪 Dry-run mode to preview changes safely
- 💾 Caches last IP — only calls APIs when something changes

Perfect for self-hosters, home lab operators, and anyone running services on a dynamic IP.

## Core Capabilities

1. Multi-provider support — Cloudflare, DuckDNS, Namecheap, generic webhook
2. IP change detection — Polls multiple sources, caches results, updates only on change
3. IPv4 + IPv6 — Full dual-stack support
4. Telegram alerts — Get notified instantly when your IP changes
5. Daemon mode — Run continuously with configurable check intervals
6. Cron-ready — One-liner crontab setup
7. Dry-run mode — Preview updates without making changes
8. Multi-domain — Update multiple records across multiple providers
9. Force update — Override cache and push current IP
10. Zero dependencies — Pure bash + curl + jq
