---
name: file-encryption
description: >-
  Encrypt and decrypt files using GPG and OpenSSL. Supports symmetric and asymmetric encryption, batch operations, and secure key management.
categories: [security, automation]
dependencies: [gpg, openssl]
---

# File Encryption Tool

## What This Does

Encrypt and decrypt files using industry-standard tools (GPG and OpenSSL). Supports password-based symmetric encryption, GPG key-pair asymmetric encryption, batch encrypt/decrypt of directories, and secure file shredding after encryption.

**Example:** "Encrypt all `.env` files in a project before pushing to backup, then securely shred the originals."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# GPG and OpenSSL are pre-installed on most systems
which gpg openssl || echo "Install gpg and openssl first"

# Check versions
gpg --version | head -1
openssl version
```

### 2. Encrypt a File (Symmetric / Password-Based)

```bash
bash scripts/encrypt.sh --file secret.txt --method symmetric
# Enter passphrase when prompted
# Output: secret.txt.gpg
```

### 3. Decrypt a File

```bash
bash scripts/encrypt.sh --decrypt --file secret.txt.gpg
# Enter passphrase when prompted
# Output: secret.txt
```

## Core Workflows

### Workflow 1: Symmetric Encryption (Password)

**Use case:** Encrypt a file with a passphrase — no keys needed.

```bash
# Encrypt
bash scripts/encrypt.sh --file credentials.json --method symmetric

# Encrypt with passphrase inline (non-interactive)
bash scripts/encrypt.sh --file credentials.json --method symmetric --passphrase "my-strong-pass"

# Decrypt
bash scripts/encrypt.sh --decrypt --file credentials.json.gpg --passphrase "my-strong-pass"
```

### Workflow 2: OpenSSL AES-256 Encryption

**Use case:** Use OpenSSL instead of GPG (lighter, no keyring).

```bash
# Encrypt with AES-256-CBC
bash scripts/encrypt.sh --file data.csv --method openssl

# Decrypt
bash scripts/encrypt.sh --decrypt --file data.csv.enc --method openssl
```

### Workflow 3: GPG Key-Pair (Asymmetric)

**Use case:** Encrypt for a specific recipient using their public key.

```bash
# Generate a key pair (if you don't have one)
bash scripts/encrypt.sh --generate-key --name "Agent Backup" --email "agent@local"

# Encrypt for a recipient
bash scripts/encrypt.sh --file report.pdf --method asymmetric --recipient "agent@local"

# Decrypt (uses your private key automatically)
bash scripts/encrypt.sh --decrypt --file report.pdf.gpg
```

### Workflow 4: Batch Encrypt a Directory

**Use case:** Encrypt all files in a folder (e.g., before cloud backup).

```bash
# Encrypt all files in a directory
bash scripts/encrypt.sh --dir ./sensitive-data --method symmetric --passphrase "backup-key"
# Output: Each file gets a .gpg extension, originals optionally shredded

# Decrypt all
bash scripts/encrypt.sh --decrypt --dir ./sensitive-data --passphrase "backup-key"
```

### Workflow 5: Encrypt + Shred Original

**Use case:** Securely delete the plaintext after encrypting.

```bash
bash scripts/encrypt.sh --file secret.txt --method symmetric --shred
# Encrypts to secret.txt.gpg, then overwrites and deletes secret.txt
```

### Workflow 6: Encrypt for Archive (tar + encrypt)

**Use case:** Compress and encrypt a directory into a single file.

```bash
bash scripts/encrypt.sh --archive ./project-secrets --method symmetric --passphrase "archive-key"
# Output: project-secrets.tar.gz.gpg

# Decrypt and extract
bash scripts/encrypt.sh --decrypt --extract --file project-secrets.tar.gz.gpg --passphrase "archive-key"
```

## Configuration

### Environment Variables

```bash
# Default encryption method (symmetric|openssl|asymmetric)
export ENCRYPT_METHOD="symmetric"

# Default recipient for asymmetric encryption
export ENCRYPT_RECIPIENT="user@example.com"

# Shred originals after encryption (true|false)
export ENCRYPT_SHRED="false"

# OpenSSL cipher (default: aes-256-cbc)
export ENCRYPT_CIPHER="aes-256-cbc"
```

## Advanced Usage

### List GPG Keys

```bash
bash scripts/encrypt.sh --list-keys
```

### Export/Import Keys

```bash
# Export public key
bash scripts/encrypt.sh --export-key "agent@local" --output agent-public.asc

# Import someone's public key
bash scripts/encrypt.sh --import-key colleague-public.asc
```

### Verify File Integrity

```bash
# Generate checksum before encryption
bash scripts/encrypt.sh --checksum --file important.db
# Output: important.db.sha256

# Verify after decryption
bash scripts/encrypt.sh --verify-checksum --file important.db
```

## Troubleshooting

### Issue: "gpg: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install gnupg

# Mac
brew install gnupg

# Alpine
apk add gnupg
```

### Issue: "gpg: decryption failed: No secret key"

The file was encrypted with asymmetric encryption for a different key. You need the matching private key.

### Issue: "openssl: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install openssl

# Mac (usually pre-installed)
brew install openssl
```

### Issue: Batch encryption missed hidden files

Add `--include-hidden` flag:
```bash
bash scripts/encrypt.sh --dir ./data --method symmetric --include-hidden
```

## Dependencies

- `gpg` (GnuPG 2.x) — asymmetric + symmetric encryption
- `openssl` (1.1+) — AES encryption
- `shred` (coreutils) — secure file deletion
- `tar` (optional) — archive mode
- `sha256sum` (coreutils) — checksum verification
