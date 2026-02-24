---
name: totp-manager
description: >-
  Generate TOTP 2FA codes, manage secrets, and automate two-factor authentication from the command line.
categories: [security, productivity]
dependencies: [oathtool, gpg, bash]
---

# TOTP Manager

## What This Does

Manage TOTP (Time-based One-Time Password) two-factor authentication codes entirely from the command line. Add secrets, generate live codes, and automate 2FA login flows — all without a phone authenticator app.

**Example:** "Generate a 6-digit TOTP code for my GitHub account right now."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This installs `oathtool` (TOTP generation) and optionally `gpg` (encrypted secret storage).

### 2. Add Your First Secret

```bash
# Add a TOTP secret (from your service's QR code / setup key)
bash scripts/run.sh add --name github --secret JBSWY3DPEHPK3PXP

# Output:
# ✅ Added 'github' — current code: 482193 (expires in 22s)
```

### 3. Generate a Code

```bash
bash scripts/run.sh get --name github

# Output:
# 🔑 github: 482193 (expires in 22s)
```

## Core Workflows

### Workflow 1: Add a TOTP Secret

**Use case:** You have a new service's 2FA secret key

```bash
# Standard 6-digit, 30-second TOTP (most common)
bash scripts/run.sh add --name github --secret JBSWY3DPEHPK3PXP

# Custom digits/period (some services use 8 digits or 60s)
bash scripts/run.sh add --name aws --secret ABCDEF123456 --digits 6 --period 30

# From otpauth:// URI (copied from QR code)
bash scripts/run.sh add --uri "otpauth://totp/GitHub:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub"
```

### Workflow 2: Generate Current Code

**Use case:** Need a 2FA code right now

```bash
# Get code for a specific service
bash scripts/run.sh get --name github

# Get all codes at once
bash scripts/run.sh list

# Output:
# 🔑 github:    482193 (22s)
# 🔑 aws:       719384 (22s)
# 🔑 cloudflare: 093847 (22s)
```

### Workflow 3: Export/Backup Secrets

**Use case:** Backup your 2FA secrets

```bash
# Export all secrets (encrypted with GPG)
bash scripts/run.sh export --gpg-recipient your@email.com > backup.gpg

# Export as plain text (careful!)
bash scripts/run.sh export --plain > backup.txt

# Import from backup
bash scripts/run.sh import --file backup.gpg
```

### Workflow 4: Remove a Secret

```bash
bash scripts/run.sh remove --name github
# ⚠️ Remove 'github'? (y/N): y
# ✅ Removed 'github'
```

## Configuration

### Secret Storage

Secrets are stored in `~/.config/totp-manager/secrets.enc` (GPG-encrypted) or `~/.config/totp-manager/secrets.json` (plain, chmod 600).

### Environment Variables

```bash
# Use GPG encryption (recommended)
export TOTP_ENCRYPT=true
export TOTP_GPG_ID="your@email.com"

# Or use plain storage (simpler but less secure)
export TOTP_ENCRYPT=false

# Custom storage path
export TOTP_STORE="$HOME/.config/totp-manager"
```

## Advanced Usage

### Generate Code for a Specific Timestamp

```bash
# Useful for debugging time-sync issues
bash scripts/run.sh get --name github --time "2026-02-24T12:00:00Z"
```

### Verify a Code

```bash
# Check if a code is currently valid (within ±1 window)
bash scripts/run.sh verify --name github --code 482193
# ✅ Code is valid (window: current)
```

### Batch Code Generation (CI/CD)

```bash
# Output just the code (no formatting) for scripting
bash scripts/run.sh get --name github --raw
# 482193
```

### Watch Mode (Live Updates)

```bash
# Continuously display codes with countdown
bash scripts/run.sh watch
# 🔑 github:     482193 ████████░░ 22s
# 🔑 aws:        719384 ████████░░ 22s
# (refreshes automatically)
```

## Troubleshooting

### Issue: "oathtool: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install oathtool

# Mac
brew install oath-toolkit

# Alpine
apk add oath-toolkit-oathtool
```

### Issue: Codes don't match the service

**Check:**
1. System clock is accurate: `date -u` — should match actual UTC
2. Fix with: `sudo ntpdate pool.ntp.org` or `timedatectl set-ntp true`
3. Secret was entered correctly (no spaces, correct base32)
4. Digits/period match service settings (default: 6 digits, 30 seconds)

### Issue: GPG encryption errors

**Fix:**
```bash
# Generate a GPG key if you don't have one
gpg --gen-key

# List keys
gpg --list-keys

# Set your key ID
export TOTP_GPG_ID="your@email.com"
```

## Security Notes

1. **Encrypted storage** — Use `TOTP_ENCRYPT=true` (default) to GPG-encrypt secrets at rest
2. **File permissions** — Scripts automatically set 600 on secret files
3. **No network** — Everything runs locally, no API calls, no cloud sync
4. **Memory safety** — Secrets are not logged or echoed to terminal during add
5. **Consider the tradeoff** — Storing 2FA on same machine as passwords reduces security vs a separate device. Use for automation accounts, not your primary bank.

## Dependencies

- `oathtool` (oath-toolkit) — TOTP code generation
- `bash` (4.0+)
- `jq` — JSON parsing
- `gpg` (optional) — Secret encryption
- `date` (GNU coreutils) — Timestamp handling
