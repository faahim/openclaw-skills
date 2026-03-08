# Listing Copy: Stunnel TLS Wrapper

## Metadata
- **Type:** Skill
- **Name:** stunnel-tls-wrapper
- **Display Name:** Stunnel TLS Wrapper
- **Categories:** [security, automation]
- **Price:** $12
- **Dependencies:** [stunnel, openssl]
- **Icon:** 🔒

## Tagline

Wrap any TCP service in TLS encryption — zero code changes required

## Description

Legacy services like Redis, MySQL, SMTP, and custom TCP apps often transmit data in plain text. Adding TLS usually means modifying application code, updating libraries, and dealing with connection handling changes. That's hours of work per service.

Stunnel TLS Wrapper installs and configures stunnel to encrypt any TCP connection with TLS — without touching your application. Create encrypted tunnels in seconds: your app connects to localhost as usual, stunnel handles all the crypto.

**What it does:**
- 🔒 Wrap any TCP port in TLS encryption (Redis, MySQL, SMTP, custom apps)
- 🔑 Auto-generate self-signed certs or use Let's Encrypt
- 📊 Monitor tunnel health, connection counts, and cert expiry
- 🔄 Auto-renew self-signed certificates via cron
- 🛡️ Support mutual TLS (mTLS) for zero-trust setups
- ⚖️ Round-robin load balancing across multiple backends
- 📝 Per-tunnel configs with easy management CLI

Perfect for sysadmins, DevOps engineers, and self-hosters who need encrypted connections without refactoring applications.

## Quick Start Preview

```bash
# Install stunnel
bash scripts/install.sh

# Wrap Redis in TLS (auto-generates certificate)
bash scripts/tunnel.sh create \
  --name redis-tls \
  --accept 6380 \
  --connect 127.0.0.1:6379 \
  --mode server \
  --cert auto

# Check status
bash scripts/tunnel.sh status
# redis-tls  server  6380  127.0.0.1:6379  ✅ UP
```

## Core Capabilities

1. TLS tunnel creation — Wrap any TCP service with a single command
2. Server & client modes — Encrypt both ends of the connection
3. Auto certificate generation — Self-signed certs with one flag
4. Let's Encrypt support — Use existing ACME certificates
5. Certificate expiry monitoring — Dashboard showing all cert statuses
6. Auto-renewal — Cron-based renewal for self-signed certs
7. Mutual TLS (mTLS) — Require client certificates for zero-trust
8. STARTTLS support — Protocol-aware TLS for SMTP, POP3, IMAP
9. Load balancing — Round-robin across multiple backends
10. Health monitoring — Connection counts, error rates, uptime
11. Per-tunnel config — Independent configs for each tunnel
12. Cross-platform — Works on Debian, Ubuntu, RHEL, Arch, macOS

## Dependencies
- `stunnel` (4.x or 5.x) — installed by setup script
- `openssl` — certificate generation
- `bash` (4.0+)

## Installation Time
**5 minutes** — run install script, create first tunnel
