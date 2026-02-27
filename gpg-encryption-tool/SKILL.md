---
name: gpg-encryption-tool
description: >-
  Manage GPG keys, encrypt/decrypt files, sign documents, and verify signatures from the command line.
categories: [security, automation]
dependencies: [gpg, bash]
---

# GPG Encryption Tool

## What This Does

Automates GPG key management, file encryption/decryption, document signing, and signature verification. Handles the complex GPG CLI so you don't have to remember flags and options.

**Example:** "Generate a new GPG key pair, encrypt a file for a recipient, sign a document, verify a signature — all with simple commands."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# GPG is pre-installed on most Linux/Mac systems
gpg --version || echo "Install GPG: sudo apt install gnupg (Debian) or brew install gnupg (Mac)"
```

### 2. Generate Your First Key Pair

```bash
bash scripts/gpg-tool.sh keygen --name "Your Name" --email "you@example.com"

# Output:
# 🔑 Generating GPG key pair...
# ✅ Key generated: ABCD1234EFGH5678
# 📋 Public key fingerprint: ABCD 1234 EFGH 5678 ...
# 💡 Export your public key: bash scripts/gpg-tool.sh export --key ABCD1234EFGH5678
```

### 3. Encrypt a File

```bash
bash scripts/gpg-tool.sh encrypt --file secret.txt --recipient "you@example.com"

# Output:
# 🔒 Encrypting secret.txt...
# ✅ Encrypted: secret.txt.gpg (2.1 KB)
```

## Core Workflows

### Workflow 1: Key Management

**Generate a new key pair:**
```bash
bash scripts/gpg-tool.sh keygen --name "Alice Smith" --email "alice@example.com"
```

**List all keys:**
```bash
bash scripts/gpg-tool.sh list
# Output:
# 🔑 GPG Keys:
#   1. Alice Smith <alice@example.com> [ABCD1234] (expires: 2028-02-27)
#   2. Bob Jones <bob@example.com>     [EFGH5678] (expires: never)
```

**Export public key (to share with others):**
```bash
bash scripts/gpg-tool.sh export --key "alice@example.com" --output alice-public.asc
```

**Import someone's public key:**
```bash
bash scripts/gpg-tool.sh import --file bob-public.asc
```

**Delete a key:**
```bash
bash scripts/gpg-tool.sh delete --key "alice@example.com"
```

### Workflow 2: Encrypt & Decrypt Files

**Encrypt for a recipient (asymmetric):**
```bash
bash scripts/gpg-tool.sh encrypt --file report.pdf --recipient "bob@example.com"
# Creates: report.pdf.gpg
```

**Encrypt with passphrase (symmetric):**
```bash
bash scripts/gpg-tool.sh encrypt --file report.pdf --symmetric
# Prompts for passphrase, creates: report.pdf.gpg
```

**Encrypt multiple files:**
```bash
bash scripts/gpg-tool.sh encrypt --dir ./sensitive-docs/ --recipient "bob@example.com"
# Encrypts all files in directory
```

**Decrypt a file:**
```bash
bash scripts/gpg-tool.sh decrypt --file report.pdf.gpg
# Output:
# 🔓 Decrypting report.pdf.gpg...
# ✅ Decrypted: report.pdf
```

### Workflow 3: Sign & Verify Documents

**Sign a file (detached signature):**
```bash
bash scripts/gpg-tool.sh sign --file contract.pdf
# Creates: contract.pdf.sig
```

**Sign a file (clearsign for text):**
```bash
bash scripts/gpg-tool.sh sign --file message.txt --clear
# Creates: message.txt.asc (human-readable signed text)
```

**Verify a signature:**
```bash
bash scripts/gpg-tool.sh verify --file contract.pdf --sig contract.pdf.sig
# Output:
# ✅ Good signature from "Alice Smith <alice@example.com>"
# 🕐 Signed: 2026-02-27 18:53:00 UTC
```

### Workflow 4: Encrypt & Sign (Combined)

**Encrypt and sign in one step:**
```bash
bash scripts/gpg-tool.sh encrypt --file secret.txt --recipient "bob@example.com" --sign
# Bob can decrypt AND verify it came from you
```

### Workflow 5: Key Trust & Fingerprints

**Show key fingerprint:**
```bash
bash scripts/gpg-tool.sh fingerprint --key "alice@example.com"
# 🔑 ABCD 1234 EFGH 5678 9012 3456 7890 ABCD EF12 3456
```

**Sign (trust) someone's key:**
```bash
bash scripts/gpg-tool.sh trust --key "bob@example.com"
```

### Workflow 6: Backup & Restore Keys

**Backup all keys:**
```bash
bash scripts/gpg-tool.sh backup --output ~/gpg-backup/
# Exports public + private keys + trust database
```

**Restore from backup:**
```bash
bash scripts/gpg-tool.sh restore --input ~/gpg-backup/
```

## Advanced Usage

### Encrypt for Multiple Recipients

```bash
bash scripts/gpg-tool.sh encrypt --file secret.txt \
  --recipient "alice@example.com" \
  --recipient "bob@example.com" \
  --recipient "charlie@example.com"
```

### Armor Output (ASCII-safe for email)

```bash
bash scripts/gpg-tool.sh encrypt --file data.bin --recipient "bob@example.com" --armor
# Creates: data.bin.asc (base64-encoded, safe to paste in email)
```

### Key Expiry Management

```bash
# Check which keys expire soon
bash scripts/gpg-tool.sh audit
# Output:
# ⚠️  Alice Smith <alice@example.com> — expires in 30 days!
# ✅ Bob Jones <bob@example.com> — expires in 547 days

# Extend key expiry
bash scripts/gpg-tool.sh extend --key "alice@example.com" --years 2
```

### Batch Encryption with Cron

```bash
# Encrypt daily database dumps
0 3 * * * cd /backups && bash /path/to/scripts/gpg-tool.sh encrypt --dir ./daily/ --recipient "admin@example.com" --delete-original
```

## Troubleshooting

### Issue: "No public key" when encrypting

**Fix:** Import the recipient's public key first:
```bash
bash scripts/gpg-tool.sh import --file recipient-key.asc
```

### Issue: "gpg: decryption failed: No secret key"

**Fix:** You need the private key that matches the encryption. Check:
```bash
bash scripts/gpg-tool.sh list --secret
```

### Issue: Key expired

**Fix:**
```bash
bash scripts/gpg-tool.sh extend --key "user@example.com" --years 1
```

### Issue: "gpg: WARNING: unsafe permissions on homedir"

**Fix:**
```bash
chmod 700 ~/.gnupg
chmod 600 ~/.gnupg/*
```

## Dependencies

- `gpg` (GnuPG 2.x) — pre-installed on most Linux/Mac
- `bash` (4.0+)
- Optional: `pinentry` (for GUI passphrase prompts)
