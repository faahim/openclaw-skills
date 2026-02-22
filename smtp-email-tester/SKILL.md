---
name: smtp-email-tester
description: >-
  Test SMTP connections, verify email deliverability, and audit DNS records (SPF/DKIM/DMARC) from the command line.
categories: [communication, dev-tools]
dependencies: [bash, openssl, dig, curl]
---

# SMTP Email Tester

## What This Does

Test and debug email infrastructure without leaving your terminal. Verify SMTP server connectivity, check SPF/DKIM/DMARC DNS records, send test emails, and diagnose deliverability issues — all with a single script.

**Example:** "Check if my domain's email is properly configured, test SMTP auth, and send a test email to verify delivery."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are pre-installed on most Linux/Mac systems
which openssl dig || echo "Install openssl and bind-utils (dig)"
```

### 2. Test SMTP Connection

```bash
bash scripts/smtp-test.sh connect --host smtp.gmail.com --port 587
```

**Output:**
```
[SMTP] Connecting to smtp.gmail.com:587...
[SMTP] ✅ Connection successful
[SMTP] Banner: 220 smtp.gmail.com ESMTP
[SMTP] STARTTLS: ✅ Supported
[SMTP] TLS Version: TLSv1.3
[SMTP] Certificate: *.gmail.com (valid until 2026-08-15)
```

### 3. Audit Domain Email DNS

```bash
bash scripts/smtp-test.sh dns --domain example.com
```

**Output:**
```
[DNS] Checking email records for example.com...

[MX Records]
  ✅ 10 mail.example.com
  ✅ 20 mail2.example.com

[SPF Record]
  ✅ v=spf1 include:_spf.google.com ~all

[DKIM Record]
  ⚠️  No DKIM record found at google._domainkey.example.com
  💡 Check your DKIM selector — try: bash scripts/smtp-test.sh dns --domain example.com --dkim-selector default

[DMARC Record]
  ✅ v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com
```

## Core Workflows

### Workflow 1: Test SMTP Connection & Auth

**Use case:** Verify your SMTP server accepts connections and credentials.

```bash
# Test connection only
bash scripts/smtp-test.sh connect --host smtp.example.com --port 587

# Test with authentication
bash scripts/smtp-test.sh auth --host smtp.example.com --port 587 \
  --user "you@example.com" --pass "app-password"
```

### Workflow 2: Full Domain Email Audit

**Use case:** Check if a domain's email DNS is properly configured.

```bash
bash scripts/smtp-test.sh dns --domain example.com --dkim-selector google
```

Checks: MX records, SPF, DKIM (with custom selector), DMARC, reverse DNS for MX hosts.

### Workflow 3: Send Test Email

**Use case:** Send an actual test email to verify end-to-end delivery.

```bash
bash scripts/smtp-test.sh send \
  --host smtp.gmail.com --port 587 \
  --user "you@gmail.com" --pass "app-password" \
  --from "you@gmail.com" --to "test@example.com" \
  --subject "SMTP Test" --body "Delivery test from smtp-email-tester"
```

### Workflow 4: Check Email Blacklists

**Use case:** See if your mail server IP is on any spam blacklists.

```bash
bash scripts/smtp-test.sh blacklist --ip 203.0.113.1
```

**Output:**
```
[Blacklist] Checking 203.0.113.1 against 12 blacklists...
  ✅ zen.spamhaus.org — Not listed
  ✅ bl.spamcop.net — Not listed
  ❌ dnsbl.sorbs.net — LISTED (contact sorbs.net for removal)
  ✅ b.barracudacentral.org — Not listed
  ...
[Result] Listed on 1/12 blacklists
```

### Workflow 5: TLS Certificate Check

**Use case:** Verify SMTP server's TLS certificate validity and expiry.

```bash
bash scripts/smtp-test.sh tls --host smtp.example.com --port 587
```

## Configuration

### Environment Variables (for auth workflows)

```bash
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="you@gmail.com"
export SMTP_PASS="your-app-password"
```

When set, you can omit `--host`, `--port`, `--user`, `--pass` flags.

## Troubleshooting

### "Connection refused" on port 587
- Try port 465 (SSL) or 25 (plain)
- Check firewall: `nc -zv smtp.example.com 587`

### "Authentication failed"
- Gmail/Google: Use App Passwords (not regular password)
- Check 2FA is enabled first, then generate app password

### "No DKIM record found"
- DKIM selectors vary by provider. Common ones: `google`, `default`, `selector1`, `k1`
- Try: `dig TXT selector1._domainkey.example.com`

### dig not found
```bash
# Ubuntu/Debian
sudo apt-get install dnsutils
# RHEL/CentOS
sudo yum install bind-utils
# Mac
brew install bind
```

## Dependencies

- `bash` (4.0+)
- `openssl` (SMTP TLS connections)
- `dig` (DNS record lookups)
- `nc`/`netcat` (port checks, optional)
- `curl` (blacklist API checks, optional)
