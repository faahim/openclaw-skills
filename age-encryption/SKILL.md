---
name: age-encryption
description: >-
  Modern file encryption using age — simple, secure, no configuration needed.
categories: [security, automation]
dependencies: [age, bash]
---

# Age Encryption Tool

## What This Does

Encrypt and decrypt files using [age](https://github.com/FiloSottile/age), the modern replacement for GPG. No key servers, no configuration files, no complexity — just simple, auditable encryption that works.

**Example:** "Encrypt my backup archive with a passphrase, or use age key pairs for automated encryption between machines."

## Quick Start (3 minutes)

### 1. Install age

```bash
bash scripts/install.sh
```

### 2. Encrypt a File

```bash
# Passphrase-based (interactive)
bash scripts/run.sh encrypt --passphrase --input secret.txt --output secret.txt.age

# Key-based (automated)
bash scripts/run.sh keygen --output ~/.age/key.txt
bash scripts/run.sh encrypt --key ~/.age/key.txt --input secret.txt --output secret.txt.age
```

### 3. Decrypt a File

```bash
# Passphrase
bash scripts/run.sh decrypt --passphrase --input secret.txt.age --output secret.txt

# Key-based
bash scripts/run.sh decrypt --identity ~/.age/key.txt --input secret.txt.age --output secret.txt
```

## Core Workflows

### Workflow 1: Encrypt with Passphrase

**Use case:** Protect sensitive files with a memorable passphrase

```bash
bash scripts/run.sh encrypt --passphrase \
  --input ~/documents/tax-return-2025.pdf \
  --output ~/documents/tax-return-2025.pdf.age
```

**Output:**
```
🔒 Encrypted: tax-return-2025.pdf → tax-return-2025.pdf.age (2.3 MB)
   Method: scrypt passphrase
   Original deleted: No (use --shred to securely delete)
```

### Workflow 2: Batch Encrypt Directory

**Use case:** Encrypt all files in a directory

```bash
bash scripts/run.sh batch-encrypt \
  --passphrase \
  --dir ~/sensitive-docs/ \
  --output ~/encrypted-docs/
```

**Output:**
```
🔒 Batch encryption complete:
   Files encrypted: 15
   Total size: 48.2 MB → 48.3 MB
   Output: ~/encrypted-docs/
```

### Workflow 3: Key-Based Encryption (Automated)

**Use case:** Encrypt files for another machine or person without sharing passwords

```bash
# Generate a key pair
bash scripts/run.sh keygen --output ~/.age/server-key.txt

# Output shows public key:
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# Encrypt for that public key
bash scripts/run.sh encrypt \
  --recipient age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p \
  --input backup.tar.gz \
  --output backup.tar.gz.age
```

### Workflow 4: Multi-Recipient Encryption

**Use case:** Encrypt a file that multiple people can decrypt

```bash
bash scripts/run.sh encrypt \
  --recipient age1abc...person1 \
  --recipient age1def...person2 \
  --recipient-file team-keys.txt \
  --input shared-secret.txt \
  --output shared-secret.txt.age
```

### Workflow 5: Pipe-Based Encryption

**Use case:** Encrypt data streams (backups, database dumps)

```bash
# Encrypt a database dump on the fly
pg_dump mydb | bash scripts/run.sh encrypt --passphrase --armor > db-backup.age

# Decrypt and restore
bash scripts/run.sh decrypt --passphrase --input db-backup.age | psql mydb
```

### Workflow 6: Secure File Shredding After Encryption

**Use case:** Encrypt and securely delete the original

```bash
bash scripts/run.sh encrypt --passphrase --shred \
  --input ~/secrets/credentials.json \
  --output ~/secrets/credentials.json.age
```

**Output:**
```
🔒 Encrypted: credentials.json → credentials.json.age
🗑️ Original securely shredded (3-pass overwrite)
```

## Configuration

### Environment Variables

```bash
# Default identity file for decryption
export AGE_IDENTITY="~/.age/key.txt"

# Default recipient for encryption
export AGE_RECIPIENT="age1ql3z7hjy..."

# Enable armor (ASCII output) by default
export AGE_ARMOR=true
```

### Recipients File

```text
# team-keys.txt — one public key per line
# Alice
age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
# Bob
age1uf4k0dks8n2hka60xg0r5yvj0vxz9az8s8lhp4e3lp2e7xyqk6pqhm7dxt
```

## Advanced Usage

### Encrypt with SSH Keys

```bash
# age supports SSH keys natively
bash scripts/run.sh encrypt \
  --recipient "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..." \
  --input secret.txt \
  --output secret.txt.age

# Decrypt with SSH key
bash scripts/run.sh decrypt \
  --identity ~/.ssh/id_ed25519 \
  --input secret.txt.age \
  --output secret.txt
```

### Automated Backup Encryption

```bash
# Add to crontab: encrypt daily backups
0 2 * * * tar czf - /home/data | /path/to/scripts/run.sh encrypt \
  --recipient age1abc... \
  --armor > /backups/$(date +\%Y\%m\%d).tar.gz.age
```

### Verify Encryption

```bash
bash scripts/run.sh info --input encrypted-file.age
```

**Output:**
```
📄 File: encrypted-file.age
   Format: age v1
   Recipients: 2 (X25519)
   Size: 1.2 MB
   Armor: No
```

## Troubleshooting

### Issue: "age: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt install age
# Mac: brew install age
# From source: go install filippo.io/age/cmd/...@latest
```

### Issue: "no identity matched any of the recipients"

**Check:**
1. You're using the correct identity file: `age-keygen -y ~/.age/key.txt`
2. The file was encrypted for your public key
3. For passphrase-encrypted files, use `--passphrase` flag

### Issue: "unknown format"

The file may not be age-encrypted. Check with:
```bash
file encrypted-file.age
head -1 encrypted-file.age  # Should start with "age-encryption.org"
```

## Why age over GPG?

| Feature | age | GPG |
|---------|-----|-----|
| Setup time | 0 config | Key servers, trust model, config |
| Key format | Simple string | Complex key rings |
| Auditable | ~600 lines of Go | 500k+ lines |
| SSH key support | Native | Plugin needed |
| Streaming | Yes | Yes |
| Multiple recipients | Yes | Yes |

## Dependencies

- `age` (1.0+) — installed by `scripts/install.sh`
- `bash` (4.0+)
- Optional: `shred` (secure deletion, included in coreutils)
