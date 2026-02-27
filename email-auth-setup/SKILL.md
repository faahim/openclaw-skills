---
name: email-auth-setup
description: >-
  Generate DKIM keys, SPF records, and DMARC policies for email authentication. Validate existing configs and diagnose deliverability issues.
categories: [communication, security]
dependencies: [openssl, dig, bash]
---

# Email Auth Setup

## What This Does

Set up email authentication (DKIM, SPF, DMARC) for any domain in minutes. Generates cryptographic keys, produces ready-to-paste DNS records, and validates existing configurations. Prevents your emails from landing in spam.

**Example:** "Generate DKIM keys for mydomain.com, create SPF and DMARC records, then verify everything resolves correctly."

## Quick Start (5 minutes)

### 1. Check Dependencies

```bash
# All standard Linux tools
which openssl dig || echo "Install openssl and dnsutils/bind-utils"
```

### 2. Generate Full Email Auth for a Domain

```bash
bash scripts/setup.sh --domain example.com --selector default
```

**Output:**
```
=== Email Authentication Setup for example.com ===

✅ DKIM Key Generated (2048-bit RSA)
   Selector: default
   Private key: output/example.com/default.private
   Public key:  output/example.com/default.txt

📋 DNS Records to Add:

--- SPF Record ---
Type: TXT
Host: @
Value: v=spf1 mx a ~all

--- DKIM Record ---
Type: TXT
Host: default._domainkey
Value: v=DKIM1; k=rsa; p=MIIBIjANBgkq...

--- DMARC Record ---
Type: TXT
Host: _dmarc
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; pct=100

Add these DNS records, then run:
  bash scripts/setup.sh --verify example.com
```

## Core Workflows

### Workflow 1: Generate DKIM Keys

```bash
bash scripts/setup.sh --dkim --domain example.com --selector mail2026 --bits 2048
```

Generates a 2048-bit RSA keypair and outputs the DNS TXT record.

### Workflow 2: Generate SPF Record

```bash
bash scripts/setup.sh --spf --domain example.com \
  --include "_spf.google.com" \
  --include "sendgrid.net" \
  --ip4 "203.0.113.5"
```

**Output:**
```
v=spf1 include:_spf.google.com include:sendgrid.net ip4:203.0.113.5 ~all
```

### Workflow 3: Generate DMARC Policy

```bash
bash scripts/setup.sh --dmarc --domain example.com \
  --policy quarantine \
  --rua dmarc-reports@example.com \
  --pct 100
```

**Output:**
```
v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@example.com; pct=100; adkim=r; aspf=r
```

### Workflow 4: Verify Existing Setup

```bash
bash scripts/setup.sh --verify example.com
```

**Output:**
```
=== Email Auth Verification: example.com ===

SPF:   ✅ Found: v=spf1 include:_spf.google.com ~all
DKIM:  ✅ Found: v=DKIM1; k=rsa; p=MIIBIj... (selector: default)
DMARC: ⚠️  Policy is 'none' — consider upgrading to 'quarantine' or 'reject'
MX:    ✅ Found: 10 mx1.example.com, 20 mx2.example.com
```

### Workflow 5: Audit Multiple Domains

```bash
echo -e "domain1.com\ndomain2.com\ndomain3.com" > domains.txt
bash scripts/setup.sh --audit domains.txt
```

Generates a report for all domains.

## Configuration

### Environment Variables (Optional)

```bash
# Default DKIM selector
export DKIM_SELECTOR="default"

# Default DKIM key size
export DKIM_BITS="2048"

# Default DMARC policy
export DMARC_POLICY="quarantine"

# Default DMARC report email
export DMARC_RUA="dmarc@yourdomain.com"
```

## Advanced Usage

### Rotate DKIM Keys

```bash
# Generate new key with new selector
bash scripts/setup.sh --dkim --domain example.com --selector mail2026q2

# Keep old selector active for 48h, then remove old DNS record
```

### Strict DMARC (After Testing)

```bash
bash scripts/setup.sh --dmarc --domain example.com \
  --policy reject \
  --rua reports@example.com \
  --ruf forensics@example.com \
  --pct 100
```

### ESP-Specific SPF Includes

```bash
# Google Workspace
bash scripts/setup.sh --spf --domain example.com --include "_spf.google.com"

# Microsoft 365
bash scripts/setup.sh --spf --domain example.com --include "spf.protection.outlook.com"

# SendGrid
bash scripts/setup.sh --spf --domain example.com --include "sendgrid.net"

# Mailchimp
bash scripts/setup.sh --spf --domain example.com --include "servers.mcsv.net"
```

## Troubleshooting

### Issue: "dig: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install dnsutils

# RHEL/CentOS
sudo yum install bind-utils

# Mac
# dig is included with macOS
```

### Issue: DKIM record too long for DNS

Some DNS providers have a 255-char limit per TXT string. Split the value:

```bash
bash scripts/setup.sh --dkim --domain example.com --split
```

This outputs the record split into multiple quoted strings.

### Issue: SPF "too many lookups" (>10)

```bash
# Check lookup count
bash scripts/setup.sh --spf-check example.com

# Output: "SPF lookup count: 12 ⚠️ Exceeds 10-lookup limit"
# Solution: Flatten includes to IP addresses
bash scripts/setup.sh --spf-flatten example.com
```

### Issue: DMARC reports not arriving

1. Verify `rua` email is correct
2. Check if receiving domain allows external DMARC reports
3. Add authorization record: `example.com._report._dmarc.reportdomain.com TXT "v=DMARC1"`

## Dependencies

- `bash` (4.0+)
- `openssl` (key generation)
- `dig` (DNS lookups) — part of `dnsutils` or `bind-utils`
- Optional: `python3` (for SPF flattening)

## Key Principles

1. **2048-bit minimum** — 1024-bit DKIM keys are deprecated
2. **Start with quarantine** — Don't go straight to `reject` policy
3. **Monitor first** — Use `p=none` with `rua` to collect reports before enforcing
4. **Rotate keys** — Change DKIM selectors every 6-12 months
5. **SPF limit** — Stay under 10 DNS lookups in SPF records
