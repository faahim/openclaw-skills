# Listing Copy: Age Encryption Tool

## Metadata
- **Type:** Skill
- **Name:** age-encryption
- **Display Name:** Age Encryption Tool
- **Categories:** [security, automation]
- **Price:** $8
- **Dependencies:** [age, bash]

## Tagline

Encrypt files with age — modern, simple, auditable encryption in seconds

## Description

GPG is powerful but painfully complex — keyrings, config files, trust models, and a 300,000-line codebase. For most encryption needs, it's massive overkill.

Age Encryption Tool brings modern file encryption to your OpenClaw agent using [age](https://github.com/FiloSottile/age) — a ~3000-line, audited tool designed to be simple and secure. No config files, no key servers, no web of trust. Just encrypt and decrypt.

**What it does:**
- 🔐 Encrypt/decrypt files with passphrases or key pairs
- 📁 Encrypt entire directories (tar + age)
- 📦 Batch encrypt/decrypt files by pattern
- 🔑 Generate and manage age key pairs
- 🔗 Encrypt using SSH keys you already have
- 👥 Multi-recipient encryption (multiple keys can decrypt)
- 🔄 Pipe-based encryption (encrypt database dumps, command output)

Perfect for developers and sysadmins who need to encrypt backups, secrets, configs, or sensitive files without the complexity of GPG.

## Quick Start Preview

```bash
# Install age
bash scripts/install.sh

# Encrypt with passphrase
bash scripts/run.sh encrypt --passphrase --input secret.txt --output secret.txt.age

# Decrypt
bash scripts/run.sh decrypt --passphrase --input secret.txt.age --output secret.txt
```

## Core Capabilities

1. Passphrase encryption — Simple password-based encryption for quick use
2. Key pair encryption — Generate age keys for passwordless, automated encryption
3. SSH key support — Encrypt using your existing ed25519/RSA SSH keys
4. Directory encryption — Archive and encrypt entire directories in one command
5. Batch operations — Encrypt/decrypt all matching files in a directory
6. Multi-recipient — Encrypt for multiple keys; any can decrypt
7. Pipe support — Encrypt stdin (database dumps, command output)
8. Auto-install — Detects OS and installs age automatically
9. Key management — Generate, list, and organize age key pairs
10. File verification — Check if a file is valid age-encrypted

## Dependencies
- `bash` (4.0+)
- `age` (auto-installed by scripts/install.sh)
- `tar` (for directory encryption)

## Installation Time
**2 minutes** — Run install script, start encrypting

## Pricing Justification

**Why $8:**
- Simple utility with clear value
- Replaces complex GPG workflows
- One-time purchase vs learning GPG for hours
- Includes auto-install, batch operations, directory encryption
