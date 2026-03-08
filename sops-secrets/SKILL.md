---
name: sops-secrets
description: >-
  Encrypt, decrypt, and manage application secrets in YAML/JSON/ENV files using Mozilla SOPS and age encryption.
categories: [security, dev-tools]
dependencies: [sops, age, bash, jq]
---

# SOPS Secret Manager

## What This Does

Manage encrypted secrets directly in your config files using Mozilla SOPS and age encryption. Secrets stay encrypted in git — only authorized keys can decrypt. No external secret management service needed.

**Example:** "Encrypt all API keys in config.yaml, commit safely to git, decrypt on deploy."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This installs:
- **sops** — Mozilla's Secrets OPerationS editor
- **age** — Modern file encryption (simpler than GPG)

### 2. Generate Encryption Key

```bash
bash scripts/setup-key.sh
# Output:
# ✅ Age key generated at ~/.config/sops/age/keys.txt
# 📋 Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Add this public key to .sops.yaml in your project
```

### 3. Initialize a Project

```bash
bash scripts/init-project.sh /path/to/your/project
# Creates .sops.yaml with your age public key
```

### 4. Encrypt Your First Secret File

```bash
bash scripts/encrypt.sh secrets.yaml
# Encrypts in-place — values become ENC[AES256_GCM,...] while keys stay readable
```

### 5. Decrypt When Needed

```bash
bash scripts/decrypt.sh secrets.yaml
# Decrypts in-place using your age key
```

## Core Workflows

### Workflow 1: Encrypt a New Secrets File

**Use case:** You have plaintext secrets that need to be encrypted before committing to git.

```bash
# Create your secrets file
cat > secrets.yaml << 'EOF'
database:
  host: db.example.com
  password: super-secret-password
api:
  stripe_key: sk_live_abc123
  sendgrid_key: SG.xyz789
EOF

# Encrypt it
bash scripts/encrypt.sh secrets.yaml

# Result: values are encrypted, keys are readable
# database:
#     host: ENC[AES256_GCM,data:...,type:str]
#     password: ENC[AES256_GCM,data:...,type:str]
```

### Workflow 2: Edit Encrypted Secrets

**Use case:** Update a secret value without manually decrypting/re-encrypting.

```bash
bash scripts/edit.sh secrets.yaml
# Opens in $EDITOR with decrypted values
# On save, automatically re-encrypts
```

### Workflow 3: Rotate Encryption Keys

**Use case:** Team member leaves, need to re-encrypt with new keys.

```bash
bash scripts/rotate-keys.sh /path/to/project --remove-key "age1oldkey..." --add-key "age1newkey..."
# Re-encrypts all secret files with updated key set
```

### Workflow 4: Encrypt .env Files

**Use case:** Protect environment variable files.

```bash
# Encrypt a .env file
bash scripts/encrypt.sh .env.production

# Decrypt for deployment
bash scripts/decrypt.sh .env.production --output .env
```

### Workflow 5: Multi-Environment Secrets

**Use case:** Different keys for dev/staging/production.

```bash
bash scripts/init-project.sh . --multi-env
# Creates .sops.yaml with path-based rules:
# - secrets/dev/* → dev team keys
# - secrets/staging/* → staging keys  
# - secrets/prod/* → prod team keys only
```

### Workflow 6: Export Decrypted Secrets as Environment Variables

**Use case:** Load secrets into shell environment for local development.

```bash
eval $(bash scripts/export-env.sh secrets.yaml)
# Sets all values as environment variables
echo $DATABASE_PASSWORD  # super-secret-password
```

### Workflow 7: Diff Encrypted Files

**Use case:** See what changed in encrypted files in git.

```bash
bash scripts/setup-git-diff.sh
# Configures git to show decrypted diffs for sops-encrypted files
# Now `git diff` shows readable secret changes
```

## Configuration

### .sops.yaml (Project Config)

```yaml
# .sops.yaml — place in project root
creation_rules:
  # Default: encrypt with these age keys
  - path_regex: secrets/.*\.yaml$
    age: >-
      age1key1...,
      age1key2...

  # Production secrets: restricted keys
  - path_regex: secrets/prod/.*\.yaml$
    age: >-
      age1prodkey1...

  # .env files
  - path_regex: \.env\..*$
    age: >-
      age1key1...
```

### Environment Variables

```bash
# Age key location (default: ~/.config/sops/age/keys.txt)
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

# Or inline key (for CI/CD)
export SOPS_AGE_KEY="AGE-SECRET-KEY-1..."
```

## Advanced Usage

### CI/CD Integration

```bash
# In your CI pipeline:
# 1. Set SOPS_AGE_KEY as a CI secret
# 2. Decrypt at deploy time
bash scripts/decrypt.sh secrets/prod/config.yaml --output /tmp/config.yaml
# 3. Use decrypted config
```

### Multiple Recipients

```bash
# Add a team member's key
bash scripts/add-recipient.sh age1newteammember... /path/to/project
# Re-encrypts all files to include the new key
```

### Audit Encrypted Files

```bash
bash scripts/audit.sh /path/to/project
# Scans for:
# - Unencrypted secret files that should be encrypted
# - Files encrypted with outdated keys
# - .sops.yaml misconfigurations
```

### Encrypt Specific Keys Only

```bash
# Only encrypt 'password' and 'key' fields, leave others plaintext
bash scripts/encrypt.sh config.yaml --encrypted-regex "^(password|key|secret|token)$"
```

## Troubleshooting

### Issue: "no matching creation rules found"

**Fix:** Ensure `.sops.yaml` exists in project root with a `path_regex` matching your file.

```bash
bash scripts/init-project.sh .
```

### Issue: "could not decrypt key"

**Fix:** Your age key file is missing or wrong.

```bash
# Check key exists
ls ~/.config/sops/age/keys.txt

# Regenerate if needed
bash scripts/setup-key.sh
# Then re-encrypt files with the new key
```

### Issue: "MAC mismatch"

**Fix:** File was modified after encryption without using sops.

```bash
# Decrypt, fix, re-encrypt
sops --decrypt --in-place file.yaml
# Edit file
sops --encrypt --in-place file.yaml
```

## Key Principles

1. **Keys readable, values encrypted** — You can see WHAT's configured, not the secret values
2. **Git-friendly** — Encrypted files commit and diff cleanly
3. **No external service** — Everything runs locally, no HashiCorp Vault needed
4. **Multiple recipients** — Share secrets with team via public keys
5. **Rotation built-in** — Easy key rotation when team changes

## Dependencies

- `sops` (3.8+) — Mozilla Secrets OPerationS
- `age` (1.1+) — Modern encryption tool
- `bash` (4.0+)
- `jq` (for JSON processing)
- Optional: `git` (for diff integration)
