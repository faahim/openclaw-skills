---
name: letsencrypt-ssl
description: >-
  Install and manage free SSL/TLS certificates from Let's Encrypt with automatic renewal.
categories: [security, automation]
dependencies: [certbot, openssl, cron]
---

# Let's Encrypt SSL Manager

## What This Does

Automates the entire SSL certificate lifecycle: install certbot, obtain free certificates from Let's Encrypt, configure auto-renewal via cron, and monitor expiry across all your domains. No more expired certs or manual renewal headaches.

**Example:** "Get SSL certs for 3 domains, set up auto-renewal, get Telegram alerts 14 days before expiry."

## Quick Start (5 minutes)

### 1. Install Certbot

```bash
bash scripts/install.sh
```

This detects your OS (Ubuntu/Debian/CentOS/Alpine/Mac) and installs certbot + dependencies.

### 2. Get Your First Certificate

```bash
# Standalone mode (no web server needed — uses port 80 temporarily)
bash scripts/ssl.sh obtain --domain example.com --email admin@example.com

# Webroot mode (if you already have Nginx/Apache running)
bash scripts/ssl.sh obtain --domain example.com --email admin@example.com --webroot /var/www/html

# Wildcard certificate (requires DNS challenge)
bash scripts/ssl.sh obtain --domain "*.example.com" --email admin@example.com --dns
```

### 3. Set Up Auto-Renewal

```bash
bash scripts/ssl.sh setup-renewal
# Installs a cron job that checks twice daily and renews certs expiring within 30 days
```

## Core Workflows

### Workflow 1: Obtain Certificate (Standalone)

**Use case:** Get SSL cert for a domain when no web server is running yet.

```bash
bash scripts/ssl.sh obtain \
  --domain example.com \
  --domain www.example.com \
  --email admin@example.com
```

**Output:**
```
[2026-02-21 12:00:00] 🔐 Requesting certificate for example.com, www.example.com...
[2026-02-21 12:00:15] ✅ Certificate obtained!
  Certificate: /etc/letsencrypt/live/example.com/fullchain.pem
  Private Key: /etc/letsencrypt/live/example.com/privkey.pem
  Expires: 2026-05-22
```

### Workflow 2: Obtain Certificate (Webroot)

**Use case:** Get SSL cert while your web server is already running.

```bash
bash scripts/ssl.sh obtain \
  --domain api.example.com \
  --email admin@example.com \
  --webroot /var/www/html
```

### Workflow 3: Wildcard Certificate (DNS Challenge)

**Use case:** Single cert covering all subdomains.

```bash
bash scripts/ssl.sh obtain \
  --domain "*.example.com" \
  --email admin@example.com \
  --dns
```

You'll be prompted to create a DNS TXT record. The script waits for propagation and verifies.

### Workflow 4: Check All Certificates

```bash
bash scripts/ssl.sh status
```

**Output:**
```
┌─────────────────────┬─────────────┬──────────┬────────┐
│ Domain              │ Expires     │ Days Left│ Status │
├─────────────────────┼─────────────┼──────────┼────────┤
│ example.com         │ 2026-05-22  │ 90       │ ✅ OK  │
│ api.example.com     │ 2026-04-15  │ 53       │ ✅ OK  │
│ old.example.com     │ 2026-03-05  │ 12       │ ⚠️ SOON│
└─────────────────────┴─────────────┴──────────┴────────┘
```

### Workflow 5: Force Renewal

```bash
# Renew a specific domain
bash scripts/ssl.sh renew --domain example.com

# Renew all certificates expiring within 30 days
bash scripts/ssl.sh renew --all
```

### Workflow 6: Revoke Certificate

```bash
bash scripts/ssl.sh revoke --domain old.example.com
```

### Workflow 7: Monitor Expiry with Alerts

```bash
# Check expiry and send Telegram alert for certs expiring within N days
export TELEGRAM_BOT_TOKEN="your-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/ssl.sh monitor --alert-days 14
```

**Alert output:**
```
🚨 SSL Certificate Expiring Soon!
Domain: old.example.com
Expires: 2026-03-05 (12 days remaining)
Run: bash scripts/ssl.sh renew --domain old.example.com
```

## Configuration

### Environment Variables

```bash
# Required for certificate requests
export LETSENCRYPT_EMAIL="admin@example.com"

# Optional: Telegram alerts
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

# Optional: Cloudflare DNS (for wildcard certs)
export CLOUDFLARE_API_TOKEN="your-token"

# Optional: post-renewal hook (e.g., reload nginx)
export RENEWAL_HOOK="systemctl reload nginx"
```

### Post-Renewal Hooks

Automatically reload your web server after renewal:

```bash
# Nginx
bash scripts/ssl.sh setup-renewal --hook "systemctl reload nginx"

# Apache
bash scripts/ssl.sh setup-renewal --hook "systemctl reload apache2"

# Custom
bash scripts/ssl.sh setup-renewal --hook "/path/to/your/script.sh"
```

## Advanced Usage

### Nginx SSL Configuration

After obtaining a certificate, configure Nginx:

```bash
bash scripts/ssl.sh nginx-config --domain example.com
```

Generates an optimized Nginx SSL config block with:
- TLS 1.2+ only
- Strong cipher suite
- HSTS header
- OCSP stapling

### Test Certificate (Staging)

Use Let's Encrypt staging for testing (no rate limits):

```bash
bash scripts/ssl.sh obtain --domain test.example.com --email admin@example.com --staging
```

### Run as OpenClaw Cron

```bash
# Check expiry daily at 9am, alert if any cert expires within 14 days
# Add to OpenClaw cron:
# schedule: { kind: "cron", expr: "0 9 * * *" }
# payload: { kind: "agentTurn", message: "Run: bash /path/to/scripts/ssl.sh monitor --alert-days 14" }
```

## Troubleshooting

### Issue: "Could not bind to port 80"

**Cause:** Another service (Nginx, Apache) is using port 80.
**Fix:** Use webroot mode instead of standalone:
```bash
bash scripts/ssl.sh obtain --domain example.com --email admin@example.com --webroot /var/www/html
```

### Issue: "Rate limit exceeded"

**Cause:** Let's Encrypt limits 50 certs per domain per week.
**Fix:** Use `--staging` for testing, only use production for real certs.

### Issue: "DNS challenge failed"

**Cause:** DNS TXT record not propagated yet.
**Fix:** Wait 2-5 minutes after creating the record, then retry.

### Issue: "certbot: command not found"

**Fix:** Run `bash scripts/install.sh` to install certbot.

## Dependencies

- `certbot` (installed by scripts/install.sh)
- `openssl` (for certificate inspection)
- `curl` (for Telegram alerts)
- `cron` (for auto-renewal scheduling)
- Optional: `jq` (for JSON output)
