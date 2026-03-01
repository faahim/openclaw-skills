# Listing Copy: Postfix SMTP Relay

## Metadata
- **Type:** Skill
- **Name:** postfix-smtp-relay
- **Display Name:** Postfix SMTP Relay
- **Categories:** [communication, automation]
- **Price:** $10
- **Dependencies:** [postfix, libsasl2-modules, mailutils]

## Tagline
Set up outbound email relay — Send alerts and notifications from any server

## Description

Your server needs to send email. Cron job failures, monitoring alerts, application notifications — but raw SMTP from a VPS goes straight to spam (if it arrives at all). ISPs block port 25, Gmail flags unknown senders, and configuring Postfix manually means wrestling with main.cf, SASL auth, and TLS settings.

**Postfix SMTP Relay** installs and configures Postfix as an authenticated outbound relay in one command. Pick a provider preset (Gmail, SendGrid, Mailgun, Amazon SES, Outlook, Zoho) or point at any custom SMTP server. Your server sends email through a trusted relay — no more spam folder, no manual config editing.

**What it does:**
- 📧 Install Postfix non-interactively (apt/dnf/yum)
- 🔧 One-command provider setup (Gmail, SendGrid, Mailgun, SES, Outlook, Zoho)
- 🔐 SASL authentication with secure credential storage (0600 permissions)
- 🔒 TLS encryption enforced by default
- 📊 Status dashboard — service health, queue depth, last delivery, error count
- 🔍 Built-in diagnostics — DNS, port, TLS, SASL verification
- 📬 Queue management — view, flush, purge stuck messages
- ✉️ Sender address rewriting and rate limiting
- 🗑️ Clean uninstall with config backup/restore

**Perfect for:** Developers, sysadmins, and self-hosters who need reliable email from their servers without setting up a full mail server.

## Quick Start Preview

```bash
bash scripts/install.sh
bash scripts/configure.sh --provider gmail --user "you@gmail.com" --password "app-password"
bash scripts/send-test.sh admin@example.com
# ✅ Test email sent to admin@example.com via smtp.gmail.com:587
```

## Core Capabilities

1. Non-interactive install — No prompts, works in scripts and CI
2. Provider presets — Gmail, SendGrid, Mailgun, SES, Outlook, Zoho
3. Custom SMTP — Any server with host/port/user/password
4. Secure credentials — SASL password file with 0600 permissions
5. TLS by default — Encrypted relay connections
6. Status dashboard — Service, queue, delivery, and error overview
7. Connection diagnostics — DNS, port, TLS, SASL health checks
8. Queue management — View, flush, or purge queued messages
9. Sender rewriting — Change From address for all outgoing mail
10. Rate limiting — Stay within provider limits (e.g., Gmail 500/day)
11. Backup & restore — Config backed up before every change
12. Multi-distro — Ubuntu, Debian, RHEL, CentOS, Fedora

## Dependencies
- `postfix`, `libsasl2-modules`, `mailutils`/`mailx`
- Works on Linux (apt, dnf, or yum)

## Installation Time
**5 minutes** — install, configure, send test email

## Pricing Justification
**$10** — Medium complexity. Replaces manual Postfix configuration (30+ min), prevents email deliverability issues. One-time cost vs $10-20/mo for hosted email relay services.
