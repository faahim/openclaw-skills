# Listing Copy: Age Encryption Tool

## Metadata
- **Type:** Skill
- **Name:** age-encryption
- **Display Name:** Age Encryption Tool
- **Categories:** [security, automation]
- **Price:** $8
- **Dependencies:** [age, bash]
- **Icon:** 🔐

## Tagline

Encrypt files with age — modern, simple, GPG-free security

## Description

GPG is powerful but painful — key servers, trust models, config files, a 500k-line codebase. For most encryption needs, it's massive overkill.

**Age Encryption Tool** brings [age](https://github.com/FiloSottile/age) to your OpenClaw agent. Age is a modern file encryption tool designed by Filippo Valsorda (Go team at Google) — simple, auditable (~600 lines of Go), and just works. No configuration, no key servers, no complexity.

**What it does:**
- 🔒 Encrypt/decrypt files with passphrase or key pairs
- 📁 Batch encrypt entire directories
- 🔑 Generate and manage age key pairs
- 🔗 Multi-recipient encryption (share with teams)
- 🔐 SSH key support (use your existing ed25519 keys)
- 🗑️ Secure file shredding after encryption
- 📊 Pipe-friendly (encrypt database dumps, backups on the fly)

**Perfect for:** developers, sysadmins, and anyone who needs encryption without the GPG headache. Encrypt backups, protect sensitive configs, share secrets between machines — all with copy-paste commands.

## Quick Start Preview

```bash
# Install age
bash scripts/install.sh

# Encrypt with passphrase
bash scripts/run.sh encrypt --passphrase --input secret.txt --output secret.txt.age

# Decrypt
bash scripts/run.sh decrypt --passphrase --input secret.txt.age --output secret.txt

# Generate key pair for automated encryption
bash scripts/run.sh keygen --output ~/.age/key.txt
```

## Core Capabilities

1. Passphrase encryption — Protect files with a memorable password (scrypt KDF)
2. Key-based encryption — Automated encryption without interactive prompts
3. Batch operations — Encrypt/decrypt entire directories preserving structure
4. Multi-recipient — One file, multiple authorized decryptors
5. SSH key support — Use existing ed25519/RSA SSH keys, no new keys needed
6. Pipe-friendly — Stream encryption for database dumps, backups, tarballs
7. Secure shredding — 3-pass overwrite of originals after encryption
8. ASCII armor — Text-safe output for email or chat
9. Cross-platform — Linux, macOS, Windows (auto-detects and installs)
10. File info — Inspect encrypted files without decrypting

## Dependencies
- `age` (1.0+) — auto-installed by included script
- `bash` (4.0+)

## Installation Time
**3 minutes** — Run install script, start encrypting
