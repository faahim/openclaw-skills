---
name: postfix-smtp-relay
description: >-
  Set up Postfix as an outbound SMTP relay so your server can send email notifications, alerts, and reports through Gmail, SendGrid, or any SMTP provider.
categories: [communication, automation]
dependencies: [postfix, libsasl2-modules, mailutils]
---

# Postfix SMTP Relay

## What This Does

Installs and configures Postfix as an outbound SMTP relay on your Linux server. This lets your server send email — cron job notifications, monitoring alerts, application emails — through a real SMTP provider (Gmail, SendGrid, Mailgun, Amazon SES, or any SMTP server).

**Without this:** Your server's emails land in spam or never arrive. ISPs block port 25 from most VPS providers.

**With this:** Reliable email delivery through authenticated SMTP relay in under 5 minutes.

## Quick Start (5 minutes)

### 1. Install Postfix

```bash
bash scripts/install.sh
```

This installs `postfix`, `libsasl2-modules`, and `mailutils` non-interactively.

### 2. Configure SMTP Relay

```bash
# Gmail relay (use App Password, not your real password)
bash scripts/configure.sh \
  --provider gmail \
  --user "yourname@gmail.com" \
  --password "xxxx-xxxx-xxxx-xxxx"

# SendGrid relay
bash scripts/configure.sh \
  --provider sendgrid \
  --user "apikey" \
  --password "SG.xxxxxxxxxxxx"

# Custom SMTP server
bash scripts/configure.sh \
  --host "smtp.yourprovider.com" \
  --port 587 \
  --user "you@domain.com" \
  --password "yourpassword"
```

### 3. Send Test Email

```bash
bash scripts/send-test.sh recipient@example.com
```

**Expected output:**
```
✅ Test email sent to recipient@example.com via smtp.gmail.com:587
   Check inbox (and spam folder) in 1-2 minutes.
```

## Core Workflows

### Workflow 1: Gmail Relay Setup

**Use case:** Send server notifications through your Gmail account.

**Prerequisites:** Create a Gmail App Password at https://myaccount.google.com/apppasswords

```bash
bash scripts/install.sh
bash scripts/configure.sh --provider gmail --user "you@gmail.com" --password "abcd-efgh-ijkl-mnop"
bash scripts/send-test.sh you@gmail.com
```

### Workflow 2: SendGrid Relay (Production)

**Use case:** High-volume email from applications/services.

```bash
bash scripts/install.sh
bash scripts/configure.sh --provider sendgrid --user "apikey" --password "SG.your-api-key"
bash scripts/send-test.sh test@example.com
```

### Workflow 3: Send Alerts from Cron Jobs

**Use case:** Get email when cron jobs fail.

```bash
# Add to crontab:
MAILTO="admin@example.com"
0 * * * * /path/to/hourly-check.sh

# Or send directly from a script:
echo "Disk usage at 90%!" | mail -s "⚠️ Disk Alert on $(hostname)" admin@example.com
```

### Workflow 4: Custom From Address

**Use case:** Send as `alerts@yourdomain.com` instead of `root@hostname`.

```bash
bash scripts/configure.sh \
  --provider gmail \
  --user "you@gmail.com" \
  --password "app-password" \
  --from "alerts@yourdomain.com"
```

### Workflow 5: Check Relay Status

```bash
bash scripts/status.sh
```

**Output:**
```
📧 Postfix SMTP Relay Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Service:    ✅ running (pid 12345)
Relay host: [smtp.gmail.com]:587
Auth:       ✅ SASL configured
Queue:      0 messages
Last sent:  2026-03-01 07:30:00 → admin@example.com (delivered)
Errors:     0 in last 24h
```

### Workflow 6: View Mail Queue & Logs

```bash
# Check mail queue
bash scripts/queue.sh

# View recent send log
bash scripts/log.sh --last 20

# Flush stuck messages
bash scripts/queue.sh --flush
```

## Configuration

### Supported Providers (Presets)

| Provider | Host | Port | Notes |
|----------|------|------|-------|
| `gmail` | smtp.gmail.com | 587 | Requires App Password |
| `sendgrid` | smtp.sendgrid.net | 587 | User is literally "apikey" |
| `mailgun` | smtp.mailgun.org | 587 | Domain-specific credentials |
| `ses` | email-smtp.us-east-1.amazonaws.com | 587 | IAM SMTP credentials |
| `outlook` | smtp.office365.com | 587 | Microsoft 365 account |
| `zoho` | smtp.zoho.com | 587 | Zoho Mail account |

### Environment Variables

```bash
# Alternative to CLI flags
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="you@gmail.com"
export SMTP_PASS="app-password"
export SMTP_FROM="alerts@yourdomain.com"  # Optional
```

### Manual Configuration

If you prefer to edit files directly:

```bash
# Main config: /etc/postfix/main.cf
# Key settings the script configures:
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

## Advanced Usage

### Multiple Relay Accounts (per-destination)

```bash
# Route different domains through different relays
bash scripts/configure.sh \
  --host "smtp.gmail.com" --port 587 \
  --user "alerts@gmail.com" --password "pass1" \
  --destination "gmail.com"

bash scripts/configure.sh \
  --host "smtp.office365.com" --port 587 \
  --user "alerts@company.com" --password "pass2" \
  --destination "company.com"
```

### Rate Limiting

```bash
# Limit sending rate (important for Gmail's 500/day limit)
bash scripts/configure.sh --provider gmail --user "..." --password "..." --rate-limit 20
# Sets: smtp_destination_rate_delay = 3s (≈20 msgs/min)
```

### Sender Address Rewriting

```bash
# Rewrite all outgoing "From" addresses
bash scripts/configure.sh --provider gmail --user "you@gmail.com" --password "..." \
  --rewrite-from "noreply@yourdomain.com"
```

## Troubleshooting

### Issue: "SASL authentication failed"

**Causes:**
1. Wrong password (Gmail needs App Password, not regular password)
2. Wrong username format

**Fix:**
```bash
# Verify credentials
bash scripts/send-test.sh --verbose you@email.com
# Look for: "SASL authentication with server ... succeeded"
```

### Issue: "Connection timed out"

**Causes:**
1. Firewall blocking port 587
2. VPS provider blocking outbound SMTP

**Fix:**
```bash
# Test connectivity
bash scripts/diagnose.sh
# Checks: DNS resolution, port 587 reachability, TLS handshake
```

### Issue: Emails going to spam

**Causes:**
1. Missing SPF/DKIM records for your domain
2. Sending from a hostname with no reverse DNS

**Fix:**
```bash
# Check your sending reputation
bash scripts/diagnose.sh --full
# Reports: SPF, DKIM, reverse DNS, blacklist status
```

### Issue: "Relay access denied"

**Fix:** The relay host is rejecting your auth. Double-check credentials:
```bash
bash scripts/configure.sh --provider gmail --user "..." --password "..." --test
```

## Uninstall

```bash
bash scripts/uninstall.sh
# Removes postfix config, keeps postfix installed
# Use --purge to fully remove postfix
```

## Dependencies

- `postfix` (MTA)
- `libsasl2-modules` (SMTP authentication)
- `mailutils` (mail command for sending)
- `openssl` (TLS verification)
- Works on: Ubuntu 20.04+, Debian 11+, RHEL/CentOS 8+, Fedora 36+

## Key Principles

1. **Secure by default** — TLS encryption, SASL auth, password file permissions (0600)
2. **Provider presets** — Gmail, SendGrid, etc. configured in one command
3. **Non-destructive** — Backs up existing Postfix config before changes
4. **Diagnostic tools** — Built-in connectivity and deliverability checks
5. **Relay only** — Configures outbound relay, not a full mail server
