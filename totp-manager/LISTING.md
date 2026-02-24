# Listing Copy: TOTP Manager

## Metadata
- **Type:** Skill
- **Name:** totp-manager
- **Display Name:** TOTP Manager
- **Categories:** [security, productivity]
- **Price:** $8
- **Dependencies:** [oathtool, jq, gpg, bash]

## Tagline

Manage 2FA codes from the CLI — generate TOTP tokens without a phone app

## Description

### The Problem

Two-factor authentication is essential, but phone-based authenticator apps create friction for automated workflows. When your OpenClaw agent needs to log into a service with 2FA, it can't tap your phone. You need TOTP codes generated programmatically.

### The Solution

TOTP Manager lets your agent generate standard 2FA codes using `oathtool`. Store secrets locally (optionally GPG-encrypted), generate codes on demand, verify tokens, and integrate 2FA into automated login flows. No cloud, no phone, no API calls.

### Key Features

- 🔑 Generate standard TOTP codes (RFC 6238 compliant)
- 🔐 GPG-encrypted secret storage at rest
- 📋 Manage multiple service secrets (add/remove/list)
- ✅ Verify codes against stored secrets
- 📤 Export/import secrets for backup
- 👁️ Watch mode with live countdown timers
- 🔧 Custom digits (6/8) and periods (30/60s)
- 🔗 Parse otpauth:// URIs from QR codes
- 🤖 Raw output mode for scripting (`--raw`)
- 🏠 Fully local — zero network calls

## Quick Start Preview

```bash
# Add a secret
bash scripts/run.sh add --name github --secret JBSWY3DPEHPK3PXP
# ✅ Added 'github' — current code: 482193 (expires in 22s)

# Get current code
bash scripts/run.sh get --name github
# 🔑 github: 482193 (expires in 22s)

# For scripting (just the code)
bash scripts/run.sh get --name github --raw
# 482193
```

## Installation Time
**2 minutes** — install oathtool, run script

## Pricing Justification

**Why $8:**
- Complexity: Low-medium (CLI wrapper + encrypted storage)
- Unique value: Agents literally cannot do 2FA without this
- Alternative: Manual phone codes (breaks automation entirely)
- One-time payment, unlimited use
