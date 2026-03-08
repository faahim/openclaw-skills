# Listing Copy: ACME.sh SSL Certificate Manager

## Metadata
- **Type:** Skill
- **Name:** acme-sh-ssl
- **Display Name:** ACME.sh SSL Certificate Manager
- **Categories:** [security, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, cron]
- **Icon:** 🔐

## Tagline

"Free SSL certificates with wildcard support, DNS-01 challenges, and auto-renewal"

## Description

SSL certificates shouldn't be hard. But certbot needs Python, doesn't support many DNS providers natively, and wildcard certs require plugins. You need something lighter and more flexible.

ACME.sh SSL Certificate Manager installs and configures acme.sh — a pure-shell ACME client that issues free SSL/TLS certificates from Let's Encrypt, ZeroSSL, Buypass, or Google. It supports DNS-01 challenges for wildcard certificates (*.example.com) with 30+ built-in DNS provider APIs, automatic renewal via cron, and one-command deployment to Nginx, Apache, or custom paths.

**What it does:**
- 🔐 Issue free SSL certs from Let's Encrypt, ZeroSSL, Buypass, or Google
- 🌐 Wildcard certificates via DNS-01 (Cloudflare, Route53, DigitalOcean, 30+ more)
- 🔄 Auto-renewal with cron — set and forget
- 🚀 One-command deploy to Nginx/Apache with auto-reload
- ⚡ ECC certificates (ec-256/ec-384) — faster, smaller than RSA
- 📋 Multi-domain SAN certificates
- 🛡️ No root required — runs as regular user
- 🗑️ Clean uninstall

Perfect for developers, sysadmins, and homelab enthusiasts who want hassle-free SSL without heavy dependencies.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Issue wildcard cert via Cloudflare DNS
export CF_Token="your-token"
bash scripts/issue.sh --domain "*.example.com" --dns dns_cf

# Deploy to Nginx
bash scripts/deploy.sh --domain example.com --server nginx
# ✅ Certificate deployed! Auto-renew configured.
```

## Installation Time
**5 minutes**
