# Listing Copy: GPG Encryption Tool

## Metadata
- **Type:** Skill
- **Name:** gpg-encryption-tool
- **Display Name:** GPG Encryption Tool
- **Categories:** [security, automation]
- **Price:** $8
- **Dependencies:** [gpg, bash]
- **Icon:** 🔐

## Tagline

Manage GPG keys, encrypt files, and sign documents — no flag memorization required

## Description

Remembering GPG command flags is painful. Was it `--export-secret-keys` or `--export-secret-subkeys`? `--detach-sign` or `--clearsign`? One wrong flag and you're reading man pages for 20 minutes.

GPG Encryption Tool wraps the entire GPG CLI into simple, memorable commands. Generate key pairs, encrypt files for recipients, sign documents, verify signatures, audit expiring keys, and backup/restore your keyring — all with readable flags like `--recipient` and `--file`.

**What it does:**
- 🔑 Generate RSA 4096-bit key pairs in one command
- 🔒 Encrypt files (asymmetric or symmetric/passphrase)
- 🔓 Decrypt files with automatic output naming
- ✍️ Sign documents (detached or clearsign)
- ✅ Verify signatures
- 📋 List, export, import, and delete keys
- 🔍 Audit keys for upcoming expiry
- 💾 Backup & restore entire keyring
- 📁 Batch encrypt entire directories

Perfect for developers who need encryption in their workflow but don't want to memorize GPG's 200+ flags.

## Core Capabilities

1. Key generation — RSA 4096-bit pairs with configurable expiry
2. Asymmetric encryption — Encrypt for one or multiple recipients
3. Symmetric encryption — Passphrase-based encryption (no keys needed)
4. Detached signatures — Sign files without modifying them
5. Clearsign — Human-readable signed text documents
6. Signature verification — Verify authenticity of signed files
7. Key audit — Find expired or expiring keys automatically
8. Batch encryption — Encrypt all files in a directory
9. Key backup/restore — Full keyring export with trust database
10. Armor output — ASCII-safe output for email/chat

## Dependencies
- `gpg` (GnuPG 2.x) — pre-installed on most systems
- `bash` (4.0+)

## Installation Time
**2 minutes** — GPG is pre-installed; just run the script
