---
name: age-encryption
description: >-
  Encrypt and decrypt files using age — the modern, simple replacement for GPG.
categories: [security, automation]
dependencies: [age, bash]
---

# Age Encryption Tool

## What This Does

Encrypt and decrypt files using [age](https://github.com/FiloSottile/age), a modern and simple file encryption tool. No config files, no key servers, no complexity — just simple, auditable encryption that works.

**Example:** "Encrypt a backup archive with a passphrase, or use age key pairs for passwordless encryption between machines."

## Quick Start (2 minutes)

### 1. Install age

```bash
bash scripts/install.sh
```

### 2. Encrypt a File

```bash
# Passphrase-based (interactive)
bash scripts/run.sh encrypt --passphrase --input secret.txt --output secret.txt.age

# Key-based (generate key first)
bash scripts/run.sh keygen --output ~/.age/key.txt
bash scripts/run.sh encrypt --key ~/.age/key.txt --input secret.txt --output secret.txt.age
```

### 3. Decrypt a File

```bash
# Passphrase-based
bash scripts/run.sh decrypt --passphrase --input secret.txt.age --output secret.txt

# Key-based
bash scripts/run.sh decrypt --identity ~/.age/key.txt --input secret.txt.age --output secret.txt
```

## Core Workflows

### Workflow 1: Passphrase Encryption

**Use case:** Encrypt a single file with a password you'll remember.

```bash
bash scripts/run.sh encrypt --passphrase --input backup.tar.gz --output backup.tar.gz.age
# Enter passphrase when prompted

bash scripts/run.sh decrypt --passphrase --input backup.tar.gz.age --output backup.tar.gz
# Enter same passphrase
```

### Workflow 2: Key Pair Encryption

**Use case:** Encrypt files that only your server/machine can decrypt.

```bash
# Generate a key pair (do once)
bash scripts/run.sh keygen --output ~/.age/key.txt
# Prints public key: age1abc123...

# Encrypt for that public key
bash scripts/run.sh encrypt --recipient age1abc123... --input data.sql --output data.sql.age

# Decrypt with the private key
bash scripts/run.sh decrypt --identity ~/.age/key.txt --input data.sql.age --output data.sql
```

### Workflow 3: Encrypt Directory

**Use case:** Encrypt an entire directory (tar + encrypt).

```bash
bash scripts/run.sh encrypt-dir --passphrase --input ./secrets/ --output secrets.tar.age

bash scripts/run.sh decrypt-dir --passphrase --input secrets.tar.age --output ./secrets-restored/
```

### Workflow 4: Batch Encrypt Multiple Files

**Use case:** Encrypt all `.sql` files in a directory.

```bash
bash scripts/run.sh batch-encrypt --passphrase --pattern "*.sql" --dir ./backups/

# Creates .age files alongside originals
# backups/dump1.sql → backups/dump1.sql.age
# backups/dump2.sql → backups/dump2.sql.age
```

### Workflow 5: Multi-Recipient Encryption

**Use case:** Encrypt a file that multiple people/machines can decrypt.

```bash
bash scripts/run.sh encrypt \
  --recipient age1abc123... \
  --recipient age1def456... \
  --input shared-secret.txt \
  --output shared-secret.txt.age

# Either recipient's private key can decrypt
```

### Workflow 6: SSH Key Encryption

**Use case:** Encrypt using existing SSH keys (no age keys needed).

```bash
# Encrypt for an SSH public key
bash scripts/run.sh encrypt --ssh-key ~/.ssh/id_ed25519.pub --input secret.txt --output secret.txt.age

# Decrypt with SSH private key
bash scripts/run.sh decrypt --identity ~/.ssh/id_ed25519 --input secret.txt.age --output secret.txt
```

### Workflow 7: Pipe-Based Encryption

**Use case:** Encrypt data from stdin (database dumps, command output).

```bash
# Encrypt a database dump directly
pg_dump mydb | bash scripts/run.sh encrypt --passphrase --output db-backup.sql.age

# Decrypt and restore
bash scripts/run.sh decrypt --passphrase --input db-backup.sql.age | psql mydb
```

## Configuration

### Key Storage

```bash
# Default key location
~/.age/key.txt

# Custom location (set env var)
export AGE_KEY_FILE="/path/to/key.txt"
```

### Environment Variables

```bash
# Default identity file for decryption
export AGE_KEY_FILE="~/.age/key.txt"

# For automation: passphrase from env (non-interactive)
export AGE_PASSPHRASE="your-secret-passphrase"
```

## Advanced Usage

### Encrypt + Upload to S3

```bash
bash scripts/run.sh encrypt --passphrase --input backup.tar.gz --output - | \
  aws s3 cp - s3://my-bucket/backups/backup.tar.gz.age
```

### Scheduled Encrypted Backups (Cron)

```bash
# Add to crontab
0 2 * * * AGE_PASSPHRASE="secret" bash /path/to/scripts/run.sh encrypt \
  --passphrase --input /var/backups/daily.tar.gz \
  --output /var/backups/encrypted/daily-$(date +\%Y\%m\%d).tar.gz.age
```

### Verify Encryption

```bash
# Check file is valid age-encrypted
bash scripts/run.sh verify --input secret.txt.age
# Output: ✅ Valid age-encrypted file (1234 bytes, created 2026-03-05)
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
1. You're using the correct private key: `age-keygen -y ~/.age/key.txt` shows the public key
2. The file was encrypted for your public key
3. Key file permissions: `chmod 600 ~/.age/key.txt`

### Issue: "incorrect passphrase"

**Fix:** Double-check your passphrase. age uses scrypt for passphrase-based encryption — there's no recovery if forgotten.

## Why age Over GPG?

| Feature | age | GPG |
|---------|-----|-----|
| Setup time | 30 seconds | 30 minutes |
| Config files | None | ~/.gnupg/* |
| Key format | Simple text | Complex keyring |
| Learning curve | Minimal | Steep |
| Audit surface | ~3000 lines | ~300,000 lines |
| SSH key support | ✅ Built-in | ❌ No |

## Dependencies

- `age` (installed via scripts/install.sh)
- `bash` (4.0+)
- `tar` (for directory encryption)
- Optional: `ssh` keys (for SSH-based encryption)
