# Listing Copy: Email Auth Setup

## Metadata
- **Type:** Skill
- **Name:** email-auth-setup
- **Display Name:** Email Auth Setup
- **Categories:** [communication, security]
- **Price:** $10
- **Dependencies:** [openssl, dig, bash]

## Tagline
Set up DKIM, SPF & DMARC for any domain — stop landing in spam

## Description

Your emails are landing in spam because you haven't set up email authentication. SPF, DKIM, and DMARC are the three DNS records every domain needs — but generating DKIM keys, formatting records correctly, and validating the setup is tedious and error-prone.

Email Auth Setup generates everything in one command. Run the script with your domain name and get ready-to-paste DNS records for all three protocols. It generates 2048-bit RSA keys for DKIM, builds SPF records with your providers' includes, and creates DMARC policies with reporting. Then verify everything resolves correctly.

**What it does:**
- 🔑 Generate DKIM keypairs (2048/4096-bit RSA)
- 📋 Build SPF records with provider includes (Google, Microsoft, SendGrid, etc.)
- 🛡️ Create DMARC policies with aggregate reporting
- ✅ Verify existing email auth for any domain
- 🔍 Audit SPF lookup counts (stay under the 10-lookup limit)
- 📊 Flatten SPF records to avoid lookup limits
- 🔄 Support DKIM key rotation with new selectors
- 📁 Batch audit multiple domains from a file

Perfect for developers, sysadmins, and anyone running email on a custom domain who wants to stop landing in spam.

## Quick Start Preview

```bash
# Full setup for a domain
bash scripts/setup.sh --domain mydomain.com

# Verify existing email auth
bash scripts/setup.sh --verify gmail.com
```

## Core Capabilities

1. DKIM key generation — 2048/4096-bit RSA with custom selectors
2. SPF record builder — Include providers, add IPs, validate limits
3. DMARC policy generator — None/quarantine/reject with reporting
4. Email auth verifier — Check SPF, DKIM, DMARC, MX for any domain
5. SPF lookup counter — Detect when you're over the 10-lookup limit
6. SPF flattener — Convert includes to direct IPs
7. Multi-domain audit — Batch verify from a domain list file
8. DKIM key rotation — Generate new selectors for scheduled rotation
9. DNS record splitting — Handle long DKIM records for strict providers
10. ESP presets — Quick includes for Google, Microsoft, SendGrid, Mailchimp

## Dependencies
- `bash` (4.0+)
- `openssl`
- `dig` (dnsutils/bind-utils)

## Installation Time
**2 minutes** — No installation needed, just run the script
