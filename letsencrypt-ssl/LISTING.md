# Listing Copy: Let's Encrypt SSL

## Metadata
- **Type:** Skill
- **Name:** letsencrypt-ssl
- **Display Name:** Let's Encrypt SSL Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [certbot, openssl, cron]
- **Icon:** 🔐

## Tagline

"Automated SSL certificates — obtain, renew, and monitor Let's Encrypt certs with zero manual effort."

## Description

### The Problem
Managing SSL certificates manually is tedious and error-prone. Expired certs cause browser warnings, kill SEO rankings, and break user trust. Certbot helps but you still need to install it correctly, set up renewal, and actually remember to check expiry dates.

### The Solution
Let's Encrypt SSL Manager handles the entire certificate lifecycle for your OpenClaw agent. One command installs certbot on any Linux distro or Mac. Another obtains certificates — standalone, webroot, or wildcard via DNS challenge. Auto-renewal runs twice daily via cron. Expiry monitoring sends Telegram alerts before anything expires.

### Key Features
- 🔐 Obtain free SSL certificates (standalone, webroot, DNS/wildcard)
- 🔄 Automated renewal via cron (twice daily checks)
- 📊 Certificate status dashboard — see all domains and expiry dates
- 🚨 Expiry alerts via Telegram (configurable threshold)
- 🌐 Nginx SSL config generator (TLS 1.2+, HSTS, OCSP stapling)
- 🖥️ Cross-platform installer (Ubuntu, Debian, CentOS, Alpine, Arch, Mac)
- 🧪 Staging mode for testing without rate limits
- 🔁 Post-renewal hooks (auto-reload Nginx/Apache)

### Who It's For
Developers, sysadmins, and indie hackers running web servers who want SSL on autopilot.

## Quick Start Preview

```bash
# Install certbot
bash scripts/install.sh

# Get a certificate
bash scripts/ssl.sh obtain --domain yoursite.com --email you@email.com

# Set up auto-renewal
bash scripts/ssl.sh setup-renewal --hook "systemctl reload nginx"
```

## Core Capabilities

1. Certificate obtaining — standalone, webroot, or DNS challenge modes
2. Wildcard support — *.yourdomain.com via DNS validation
3. Auto-renewal cron — checks twice daily, renews within 30 days of expiry
4. Status dashboard — table view of all domains, expiry dates, days remaining
5. Expiry monitoring — Telegram alerts at configurable thresholds
6. Nginx config generator — production-ready SSL server block
7. Post-renewal hooks — automatically reload web servers
8. Cross-platform install — detects OS, installs correct certbot package
9. Staging mode — test without hitting rate limits
10. Revocation — clean removal of unwanted certificates
