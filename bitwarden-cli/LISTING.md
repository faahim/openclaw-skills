# Listing Copy: Bitwarden CLI Manager

## Metadata
- **Type:** Skill
- **Name:** bitwarden-cli
- **Display Name:** Bitwarden CLI Manager
- **Categories:** [security, productivity]
- **Price:** $10
- **Dependencies:** [node, npm, jq]

## Tagline
Manage your Bitwarden vault from the terminal — search, generate, audit, and backup passwords

## Description

Tired of switching to a browser just to grab a password? Bitwarden CLI Manager lets your OpenClaw agent manage your entire password vault from the command line.

**What it does:**
- 🔍 Search credentials by name, username, or URL
- 🔐 Generate secure passwords and passphrases with entropy scoring
- ➕ Create login items, secure notes, and cards
- 📦 Export encrypted vault backups with timestamps
- 🛡️ Audit passwords against Have I Been Pwned breach database
- 📊 View vault status and statistics
- 🔄 Sync with Bitwarden/Vaultwarden servers

Works with both cloud Bitwarden and self-hosted Vaultwarden instances. All scripts use the official `bw` CLI — no custom API calls, no security risks.

Perfect for developers and sysadmins who live in the terminal and want fast credential access without context-switching.

## Core Capabilities

1. Credential search — Find logins by name, URL, or username instantly
2. Password generation — Create passwords with custom length, charset, entropy scoring
3. Passphrase generation — Word-based passphrases with configurable separators
4. Vault item creation — Add logins, secure notes, cards with folder organization
5. Encrypted backup — Export vault as encrypted JSON with timestamps
6. Breach auditing — Check all passwords against HIBP k-anonymity API
7. Weak password detection — Flag passwords under 8 characters
8. Old password alerts — Find credentials not rotated in N days
9. Self-hosted support — Works with Vaultwarden and custom servers
10. Pipe-friendly — Output passwords directly to clipboard or scripts
