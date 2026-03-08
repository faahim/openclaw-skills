# Listing Copy: Age Encryption Tool

## Metadata
- **Type:** Skill
- **Name:** age-encryption
- **Display Name:** Age Encryption Tool
- **Categories:** [security, productivity]
- **Price:** $8
- **Dependencies:** [age]
- **Icon:** 🔐

## Tagline

Encrypt files with age — modern, simple, zero-config file encryption

## Description

Managing GPG keys is painful. Remembering which flags to use, configuring keyrings, dealing with trust models — it's complexity that gets in the way of actually encrypting things.

Age Encryption Tool brings modern file encryption to your OpenClaw agent using [age](https://github.com/FiloSottile/age), the simple and secure encryption tool by Filippo Valsorda. No configuration, no keyrings, no complexity. Generate a key pair, encrypt files, done.

**What it does:**
- 🔑 Generate and manage age key pairs
- 🔒 Encrypt files for one or multiple recipients
- 🔓 Decrypt with private key or passphrase
- 📦 Batch encrypt all sensitive files (`.env`, `.pem`, `.key`, etc.)
- 🗜️ Compress + encrypt directories in one pipeline
- 🔗 Works with existing SSH keys — no new keys needed
- 📂 Batch decrypt entire directories

**Who it's for:** Developers, sysadmins, and anyone who needs to encrypt files without the complexity of GPG.

## Core Capabilities

1. Key generation — Create X25519 key pairs in one command
2. Single file encryption — Encrypt any file for one or more recipients
3. Passphrase mode — Quick encryption without managing keys
4. Batch encryption — Auto-find and encrypt all sensitive files in a project
5. Batch decryption — Decrypt all `.age` files in a directory
6. SSH key support — Use existing ed25519/RSA SSH keys for encryption
7. Directory archives — Compress + encrypt entire directories via pipe
8. Multi-recipient — Encrypt for teams (multiple public keys)
9. Auto-install — Detects OS and installs age automatically
10. Git-friendly — Encrypted `.age` files are safe to commit

## Installation Time
**2 minutes** — Auto-installs age, generates key pair, ready to encrypt
