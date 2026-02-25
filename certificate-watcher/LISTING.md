# Listing Copy: Certificate Watcher

## Metadata
- **Type:** Skill
- **Name:** certificate-watcher
- **Display Name:** Certificate Watcher
- **Categories:** [security, automation]
- **Icon:** 🔐
- **Dependencies:** [openssl, bash, curl]

## Tagline

Monitor SSL/TLS certificate expiry — Get alerts before your sites go down

## Description

Expired SSL certificates break your sites and destroy user trust. By the time you notice, search engines have already flagged you and users are seeing scary browser warnings. You need automated monitoring.

Certificate Watcher scans your domains on schedule, checks certificate validity and chain integrity, and alerts you via Telegram, Slack, or webhook before anything expires. No external monitoring service needed — it runs locally with just `openssl` and `bash`.

**What it does:**
- 🔍 Scan unlimited domains for certificate expiry
- ⏱️ Configurable warning thresholds (default: 30 days warning, 7 days critical)
- 🔔 Instant alerts via Telegram, Slack, or webhook
- 📊 JSON output for pipeline integration
- 🔐 STARTTLS support for mail servers (SMTP, IMAP)
- 🛠️ Detailed cert info: issuer, SANs, chain, serial number
- 📋 Cron-ready for daily automated checks

Perfect for developers, sysadmins, and anyone running HTTPS services who needs reliable certificate monitoring without paying for Pingdom or UptimeRobot.

## Quick Start Preview

```bash
# Check a single domain
bash scripts/certwatch.sh check example.com
# ✅ example.com — Valid 247 days (expires 2026-10-30) — Let's Encrypt R3

# Scan multiple domains with alerts
bash scripts/certwatch.sh scan --warn 30 --alert telegram example.com api.example.com
```

## Core Capabilities

1. Single domain check — Detailed certificate report with issuer, SANs, chain info
2. Multi-domain scan — Batch check with summary (OK/WARNING/CRITICAL/EXPIRED)
3. Expiry alerting — Telegram, Slack, webhook notifications on approaching expiry
4. STARTTLS support — Check mail servers (SMTP, IMAP, POP3)
5. Non-standard ports — Check services on any port (8443, 9443, etc.)
6. JSON output — Machine-readable output for CI/CD pipelines
7. Config file — Manage domain lists in simple text files
8. Cron integration — Daily automated checks with log rotation
9. Self-signed support — Check expiry on internal/self-signed certs
10. Zero dependencies — Uses openssl + bash (pre-installed everywhere)
