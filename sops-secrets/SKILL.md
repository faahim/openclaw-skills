---
name: sops-secrets
description: >-
  Encrypt and manage secrets in config files using Mozilla SOPS. Keep secrets safely in git.
categories: [security, dev-tools]
dependencies: [sops, age]
---

# SOPS Secrets Manager

## What This Does

Manages encrypted secrets using [Mozilla SOPS](https://github.com/getsops/sops) — the industry-standard tool for encrypting YAML, JSON, ENV, and INI files. Secrets stay encrypted in git, decrypted only at runtime.

**Example:** Encrypt your `.env` file so API keys live safely in your repo. Decrypt on deploy. Rotate keys when needed.

## Quick Start (5 minutes)

### 1. Install SOPS & Age

```bash
bash scripts/install.sh
```

This installs:
- **sops** (v3.9+) — encryption/decryption engine
- **age** (v1.1+) — modern encryption key tool (simpler than GPG)

### 2. Generate Your Encryption Key

```bash
bash scripts/setup-keys.sh
```

This creates:
- `~/.config/sops/age/keys.txt` — your private key (NEVER share this)
- Prints your public key (use this in `.sops.yaml`)

### 3. Encrypt a File

```bash
# Encrypt a YAML file
sops encrypt --age $(bash scripts/get-pubkey.sh) secrets.yaml > secrets.enc.yaml

# Encrypt an .env file
sops encrypt --age $(bash scripts/get-pubkey.sh) .env > .env.encrypted
```

### 4. Decrypt a File

```bash
# Decrypt to stdout
sops decrypt secrets.enc.yaml

# Decrypt to file
sops decrypt secrets.enc.yaml > secrets.yaml

# Edit encrypted file in-place (opens $EDITOR)
sops secrets.enc.yaml
```

## Core Workflows

### Workflow 1: Encrypt Project Secrets

**Use case:** Store secrets safely in your git repo

```bash
# Create .sops.yaml in project root (one-time setup)
bash scripts/init-project.sh /path/to/project

# This creates .sops.yaml with your age public key
# and adds decrypted files to .gitignore

# Encrypt all secret files
bash scripts/encrypt-dir.sh /path/to/project/secrets/
```

**Output:**
```
✅ Encrypted secrets/database.yaml → secrets/database.yaml (encrypted in-place)
✅ Encrypted secrets/api-keys.yaml → secrets/api-keys.yaml (encrypted in-place)
📝 Updated .gitignore with decrypted file patterns
```

### Workflow 2: Rotate Encryption Keys

**Use case:** Team member leaves, rotate all secrets

```bash
# Generate new key
bash scripts/setup-keys.sh --name new-key

# Re-encrypt all files with new key
bash scripts/rotate-keys.sh /path/to/project --new-key $(bash scripts/get-pubkey.sh new-key)
```

**Output:**
```
🔄 Rotating keys for 5 encrypted files...
✅ secrets/database.yaml — re-encrypted
✅ secrets/api-keys.yaml — re-encrypted
✅ secrets/oauth.yaml — re-encrypted
✅ .env.encrypted — re-encrypted
✅ config/prod.yaml — re-encrypted
🔑 Old key can now be safely revoked
```

### Workflow 3: Multi-Environment Secrets

**Use case:** Different secrets for dev/staging/prod

```bash
# Set up environment-specific encryption
bash scripts/init-multienv.sh /path/to/project

# This creates:
# .sops.yaml with path-based rules:
#   - secrets/dev/* → dev team key
#   - secrets/staging/* → staging key
#   - secrets/prod/* → prod key (restricted)
```

### Workflow 4: Decrypt for CI/CD

**Use case:** Decrypt secrets in GitHub Actions / CI pipelines

```bash
# Export age key as env var in CI
export SOPS_AGE_KEY="AGE-SECRET-KEY-1..."

# Decrypt all secrets before deploy
bash scripts/decrypt-all.sh /path/to/project/secrets/

# Or decrypt a single file to env vars
eval $(sops decrypt --output-type dotenv secrets.enc.env)
```

### Workflow 5: Audit Encrypted Files

**Use case:** Check which files are encrypted and with which keys

```bash
bash scripts/audit.sh /path/to/project
```

**Output:**
```
📊 SOPS Encryption Audit
========================
Total encrypted files: 8
Encryption method: age

File                          | Recipients | Last Modified
------------------------------|------------|---------------
secrets/database.yaml         | 2 keys     | 2026-03-05
secrets/api-keys.yaml         | 2 keys     | 2026-03-01
.env.encrypted                | 1 key      | 2026-02-28
config/prod.yaml              | 3 keys     | 2026-03-07

⚠️ Warning: .env.encrypted has only 1 recipient (no backup key)
```

## Configuration

### .sops.yaml (Project Config)

```yaml
# .sops.yaml — place in project root
creation_rules:
  # Encrypt all files in secrets/ with these keys
  - path_regex: secrets/.*
    age: >-
      age1abc123...,
      age1def456...

  # Production secrets — restricted key
  - path_regex: secrets/prod/.*
    age: >-
      age1prod789...

  # Encrypt .env files
  - path_regex: \.env\.encrypted$
    age: >-
      age1abc123...
```

### Partial Encryption (YAML/JSON only)

SOPS can encrypt only specific keys, leaving structure visible:

```yaml
# Before encryption
database:
  host: db.example.com      # not secret
  port: 5432                 # not secret
  password: supersecret123   # SECRET!

# After: sops encrypt --encrypted-regex '^(password|secret|key|token)$' db.yaml
database:
  host: db.example.com
  port: 5432
  password: ENC[AES256_GCM,data:abc123...,type:str]
```

```bash
# Encrypt only sensitive keys
sops encrypt \
  --encrypted-regex '^(password|secret|key|token|api_key|private)$' \
  --age $(bash scripts/get-pubkey.sh) \
  config.yaml > config.enc.yaml
```

## Advanced Usage

### Multiple Recipients (Team Access)

```bash
# Add team member's public key
bash scripts/add-recipient.sh /path/to/project age1teammember...

# Remove team member (re-encrypts with remaining keys)
bash scripts/remove-recipient.sh /path/to/project age1oldmember...
```

### Using with Docker

```bash
# Decrypt secrets at container startup
# Dockerfile:
# COPY secrets.enc.yaml /app/secrets.enc.yaml
# RUN sops decrypt /app/secrets.enc.yaml > /app/secrets.yaml

# Or mount age key and decrypt at runtime
docker run -v ~/.config/sops/age:/root/.config/sops/age \
  -e SOPS_AGE_KEY_FILE=/root/.config/sops/age/keys.txt \
  myapp
```

### Git Pre-commit Hook

```bash
# Prevent committing unencrypted secrets
bash scripts/install-hook.sh /path/to/project

# This adds a pre-commit hook that:
# 1. Checks files matching secret patterns
# 2. Verifies they're SOPS-encrypted
# 3. Blocks commit if unencrypted secrets found
```

## Troubleshooting

### Issue: "no matching creation rule"

**Fix:** Ensure `.sops.yaml` exists in the project root and the file path matches a `path_regex`.

```bash
# Check .sops.yaml
cat .sops.yaml

# Verify regex matches your file
echo "secrets/db.yaml" | grep -E 'secrets/.*'
```

### Issue: "could not decrypt data key"

**Fix:** Your age key file is missing or doesn't match.

```bash
# Check key exists
ls -la ~/.config/sops/age/keys.txt

# Verify your public key is a recipient
sops filestatus secrets.enc.yaml
```

### Issue: "age: no identity matched any of the recipients"

**Fix:** The file was encrypted for a different key. Re-encrypt with your key:

```bash
# Need someone with the original key to re-encrypt for you
# Or use the backup key if available
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/install.sh` | Install SOPS + age binaries |
| `scripts/setup-keys.sh` | Generate age key pair |
| `scripts/get-pubkey.sh` | Print your age public key |
| `scripts/init-project.sh` | Initialize SOPS in a project |
| `scripts/encrypt-dir.sh` | Encrypt all files in a directory |
| `scripts/decrypt-all.sh` | Decrypt all SOPS files in a directory |
| `scripts/rotate-keys.sh` | Re-encrypt all files with new key |
| `scripts/audit.sh` | Audit encryption status |
| `scripts/add-recipient.sh` | Add team member's key |
| `scripts/remove-recipient.sh` | Remove team member's key |
| `scripts/install-hook.sh` | Install git pre-commit hook |
| `scripts/init-multienv.sh` | Set up multi-environment encryption |

## Dependencies

- `sops` (3.9+) — Mozilla Secrets OPerationS
- `age` (1.1+) — Modern file encryption
- `bash` (4.0+)
- `jq` (optional, for JSON inspection)
- `git` (optional, for hooks)
