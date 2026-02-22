# Listing Copy: SSH Key Manager

## Metadata
- **Type:** Skill
- **Name:** ssh-key-manager
- **Display Name:** SSH Key Manager
- **Categories:** [security, dev-tools]
- **Price:** $10
- **Dependencies:** [bash, ssh-keygen, ssh]

## Tagline
Manage SSH keys, configs, and connections — secure by default, zero hassle.

## Description

Managing SSH keys manually is tedious and error-prone. Wrong permissions, forgotten keys, messy config files, no backups — it's a disaster waiting to happen. One wrong `chmod` and you're locked out.

SSH Key Manager automates the entire SSH key lifecycle. Generate Ed25519 keys with best-practice defaults, manage `~/.ssh/config` entries for quick-connect aliases, audit and fix permissions, rotate keys safely, test connections, and create encrypted backups. Everything runs locally — no external services, no API keys needed.

**What it does:**
- 🔑 Generate Ed25519/RSA keys with secure defaults
- ⚙️ Manage `~/.ssh/config` entries (add, list, remove)
- 🔒 Audit & auto-fix file permissions
- 🔄 Rotate keys with automatic archival
- 🧪 Test SSH connections (including GitHub auth)
- 📦 Create encrypted backups of your entire SSH directory
- 📤 Copy public keys to remote servers
- 📋 Manage known_hosts entries

Perfect for developers, sysadmins, and anyone who SSHs into servers regularly and wants their key management handled properly.

## Quick Start Preview

```bash
# Generate a key
bash scripts/ssh-manager.sh generate --name github --email you@example.com

# Add config entry (now: ssh prod)
bash scripts/ssh-manager.sh config-add --alias prod --host 10.0.1.5 --user deploy --key ~/.ssh/deploy

# Audit permissions
bash scripts/ssh-manager.sh audit --fix
```

## Core Capabilities

1. Key generation — Ed25519 by default, RSA 4096 for legacy systems
2. Config management — Quick-connect aliases with security defaults
3. Permission auditing — Detect and fix insecure file modes automatically
4. Key rotation — Generate new key, archive old one, preserve config
5. Connection testing — Verify SSH connectivity including GitHub auth
6. Encrypted backups — AES-256 encrypted tar of your SSH directory
7. Remote key installation — ssh-copy-id wrapper with fallback
8. Known hosts management — Add, remove, verify host fingerprints
9. Agent forwarding — Configure jump host forwarding safely
10. Zero dependencies — Uses only OpenSSH tools (pre-installed everywhere)

## Dependencies
- `bash` (4.0+)
- `ssh-keygen`, `ssh`, `ssh-agent` (OpenSSH)
- `openssl` (for encrypted backups)

## Installation Time
**2 minutes** — No installation needed, just run the script.

## Pricing Justification
$10 — Comprehensive SSH management that handles key generation, config, auditing, rotation, backups, and connection testing. Replaces manual SSH administration with one tool.
