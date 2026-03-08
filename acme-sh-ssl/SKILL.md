---
name: acme-sh-ssl
description: >-
  Issue, renew, and manage SSL/TLS certificates using acme.sh — supports wildcard certs, DNS-01 challenges, and 30+ DNS providers.
categories: [security, automation]
dependencies: [bash, curl, cron]
---

# ACME.sh SSL Certificate Manager

## What This Does

Issues free SSL/TLS certificates from Let's Encrypt, ZeroSSL, or other ACME CAs using acme.sh. Supports DNS-01 challenges for wildcard certificates (*.example.com), automatic renewal via cron, and 30+ DNS API providers (Cloudflare, AWS Route53, DigitalOcean, etc.). Lighter and more flexible than certbot.

**Example:** "Issue a wildcard cert for *.example.com via Cloudflare DNS, auto-deploy to Nginx, auto-renew every 60 days."

## Quick Start (5 minutes)

### 1. Install acme.sh

```bash
sudo bash scripts/install.sh

# Installs acme.sh to ~/.acme.sh
# Sets up automatic renewal cron job
# Registers with Let's Encrypt (default CA)
```

### 2. Issue Your First Certificate

**HTTP-01 (standalone — for servers with port 80 available):**
```bash
bash scripts/issue.sh --domain example.com --mode standalone

# Output:
# 🔐 Issuing certificate for example.com...
# ✅ Certificate issued!
#    Cert: ~/.acme.sh/example.com/fullchain.cer
#    Key:  ~/.acme.sh/example.com/example.com.key
#    Expires: 2026-05-07
```

**DNS-01 (for wildcard certs — no port 80 needed):**
```bash
# Set DNS provider credentials
export CF_Token="your-cloudflare-api-token"
export CF_Zone_ID="your-zone-id"

bash scripts/issue.sh --domain "*.example.com" --dns dns_cf

# Output:
# 🔐 Issuing wildcard certificate for *.example.com...
# ✅ Wildcard certificate issued!
#    Cert: ~/.acme.sh/*.example.com/fullchain.cer
#    Key:  ~/.acme.sh/*.example.com/*.example.com.key
```

### 3. Deploy to Web Server

```bash
# Deploy to Nginx
bash scripts/deploy.sh --domain example.com --server nginx

# Deploy to custom path
bash scripts/deploy.sh --domain example.com \
  --cert-path /etc/ssl/certs/example.com.pem \
  --key-path /etc/ssl/private/example.com.key \
  --reload "systemctl reload nginx"
```

## Core Workflows

### Workflow 1: Single Domain Certificate

```bash
# Standalone (acme.sh runs its own web server on port 80)
bash scripts/issue.sh --domain example.com --mode standalone

# Webroot (use existing web server's document root)
bash scripts/issue.sh --domain example.com --mode webroot --webroot /var/www/html

# Nginx plugin (auto-configures nginx)
bash scripts/issue.sh --domain example.com --mode nginx
```

### Workflow 2: Wildcard Certificate via DNS

```bash
# Cloudflare
export CF_Token="your-token"
export CF_Zone_ID="your-zone-id"
bash scripts/issue.sh --domain "*.example.com" --dns dns_cf

# AWS Route53
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
bash scripts/issue.sh --domain "*.example.com" --dns dns_aws

# DigitalOcean
export DO_API_KEY="your-api-key"
bash scripts/issue.sh --domain "*.example.com" --dns dns_dgon

# Manual DNS (add TXT record yourself)
bash scripts/issue.sh --domain "*.example.com" --dns dns_manual
```

### Workflow 3: Multi-Domain (SAN) Certificate

```bash
bash scripts/issue.sh \
  --domain example.com \
  --san "www.example.com" \
  --san "api.example.com" \
  --san "app.example.com" \
  --mode standalone
```

### Workflow 4: Auto-Deploy on Renewal

```bash
# Set up auto-deploy hook
bash scripts/deploy.sh --domain example.com \
  --cert-path /etc/nginx/ssl/cert.pem \
  --key-path /etc/nginx/ssl/key.pem \
  --fullchain-path /etc/nginx/ssl/fullchain.pem \
  --reload "systemctl reload nginx"

# Certificates auto-renew AND auto-deploy on renewal
```

### Workflow 5: Switch CA Provider

```bash
# Use ZeroSSL instead of Let's Encrypt
bash scripts/configure.sh --ca zerossl --email your@email.com

# Use Buypass (European CA)
bash scripts/configure.sh --ca buypass

# Use Google Trust Services
bash scripts/configure.sh --ca google

# Switch back to Let's Encrypt
bash scripts/configure.sh --ca letsencrypt
```

## DNS Provider Reference

| Provider | Flag | Required Env Vars |
|----------|------|-------------------|
| Cloudflare | `dns_cf` | `CF_Token`, `CF_Zone_ID` |
| AWS Route53 | `dns_aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| DigitalOcean | `dns_dgon` | `DO_API_KEY` |
| Hetzner | `dns_hetzner` | `HETZNER_Token` |
| Namecheap | `dns_namecheap` | `NAMECHEAP_API_USER`, `NAMECHEAP_API_KEY` |
| GoDaddy | `dns_gd` | `GD_Key`, `GD_Secret` |
| Linode | `dns_linode_v4` | `LINODE_V4_API_KEY` |
| Vultr | `dns_vultr` | `VULTR_API_KEY` |
| OVH | `dns_ovh` | `OVH_AK`, `OVH_AS`, `OVH_CK` |
| Google Cloud | `dns_gcloud` | `GOOGLECLOUD_JSON` (service account) |
| Azure | `dns_azure` | `AZUREDNS_SUBSCRIPTIONID`, `AZUREDNS_TENANTID`, etc. |
| Manual | `dns_manual` | (none — you add TXT records manually) |

Full list: https://github.com/acmesh-official/acme.sh/wiki/dnsapi

## Management Commands

### List Certificates

```bash
bash scripts/manage.sh --list

# Output:
# 📜 Issued Certificates:
#   example.com          | Expires: 2026-05-07 | Auto-renew: ✅
#   *.example.com        | Expires: 2026-05-12 | Auto-renew: ✅
#   api.mysite.com       | Expires: 2026-04-28 | Auto-renew: ✅
```

### Renew Certificates

```bash
# Renew a specific cert
bash scripts/manage.sh --renew example.com

# Force renew (even if not due)
bash scripts/manage.sh --renew example.com --force

# Renew all due certificates
bash scripts/manage.sh --renew-all
```

### Revoke a Certificate

```bash
bash scripts/manage.sh --revoke example.com
```

### Remove a Certificate

```bash
bash scripts/manage.sh --remove example.com
```

### Check Expiry

```bash
bash scripts/manage.sh --check-expiry

# Output:
# 📅 Certificate Expiry Report:
#   example.com       — 47 days remaining ✅
#   *.example.com     — 52 days remaining ✅
#   api.mysite.com    — 8 days remaining ⚠️  (renewing soon)
```

## Advanced Usage

### ECC (Elliptic Curve) Certificates

```bash
# Issue ECC cert (smaller, faster than RSA)
bash scripts/issue.sh --domain example.com --mode standalone --keylength ec-256
```

### Custom ACME Server

```bash
# Use a custom/internal ACME server
bash scripts/issue.sh --domain internal.corp \
  --server https://acme.internal.corp/directory \
  --mode standalone
```

### Pre/Post Hooks

```bash
# Run commands before/after certificate operations
bash scripts/issue.sh --domain example.com \
  --mode standalone \
  --pre-hook "systemctl stop nginx" \
  --post-hook "systemctl start nginx"
```

### Export Certificate

```bash
# Export cert + key as PKCS12 (for Java, Windows, etc.)
bash scripts/manage.sh --export example.com --format pkcs12 --output example.p12
```

## Troubleshooting

### Issue: "Could not verify domain"

**HTTP-01:** Ensure port 80 is open and not blocked by firewall:
```bash
sudo ufw allow 80/tcp  # or: sudo firewall-cmd --add-port=80/tcp
```

**DNS-01:** Check TXT record propagation:
```bash
dig TXT _acme-challenge.example.com
```

### Issue: "Rate limit exceeded"

Let's Encrypt has rate limits (50 certs/week per domain). Use staging first:
```bash
bash scripts/issue.sh --domain example.com --mode standalone --staging
# Test with staging CA, then issue for real
```

### Issue: "Renewal failed"

Check cron is running:
```bash
crontab -l | grep acme
# Should show: ... acme.sh --cron ...
```

Check renewal log:
```bash
cat ~/.acme.sh/acme.sh.log | tail -50
```

## Uninstall

```bash
bash scripts/uninstall.sh
# Removes acme.sh, cron job, and optionally certificates
```

## Dependencies

- `bash` (4.0+)
- `curl` or `wget`
- `cron` (auto-renewal)
- `openssl` (cert operations)
- Optional: `socat` (standalone mode alternative)
- Optional: DNS provider credentials (for wildcard certs)

## Why acme.sh over certbot?

- **Pure shell** — no Python dependencies, runs anywhere
- **30+ DNS providers** — built-in API support for wildcard certs
- **Lighter** — single script, no package manager needed
- **More CAs** — Let's Encrypt, ZeroSSL, Buypass, Google, custom
- **ECC support** — issue ec-256/ec-384 certs easily
- **No root required** — can run as regular user
