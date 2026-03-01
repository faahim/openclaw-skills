---
name: sops-secrets-manager
description: >-
  Encrypt and manage secrets in git repos using Mozilla SOPS with age or GPG keys.
categories: [security, dev-tools]
dependencies: [sops, age]
---

# SOPS Secrets Manager

## What This Does

Manage encrypted secrets directly in your git repositories using Mozilla SOPS. Encrypt YAML, JSON, ENV, and INI files so you can safely commit secrets to version control. Uses `age` for simple, modern key management — no GPG complexity needed.

**Example:** "Encrypt my `.env.production` file, commit it to git, and decrypt it on deploy."

## Quick Start (5 minutes)

### 1. Install SOPS + age

```bash
bash scripts/install.sh
```

### 2. Generate an age key

```bash
bash scripts/setup-keys.sh
# Output:
# ✅ age key generated at ~/.config/sops/age/keys.txt
# 📋 Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Add this public key to .sops.yaml in your repo
```

### 3. Create .sops.yaml config

```bash
bash scripts/init-repo.sh --key "age1your-public-key-here"
# Creates .sops.yaml in current directory
```

### 4. Encrypt a file

```bash
bash scripts/run.sh encrypt secrets.yaml
# Output:
# ✅ Encrypted secrets.yaml (age key: age1xxxx...)
# Safe to commit to git!
```

### 5. Decrypt a file

```bash
bash scripts/run.sh decrypt secrets.yaml
# Output:
# ✅ Decrypted secrets.yaml
```

## Core Workflows

### Workflow 1: Encrypt Secrets for a Project

**Use case:** Store production secrets safely in git

```bash
# Create a secrets file
cat > secrets.yaml <<EOF
database:
  host: db.production.example.com
  password: super-secret-password-123
  port: 5432
api:
  stripe_key: sk_live_xxx
  sendgrid_key: SG.xxx
EOF

# Encrypt it
bash scripts/run.sh encrypt secrets.yaml

# The file is now encrypted — safe to git add
git add secrets.yaml .sops.yaml
git commit -m "Add encrypted secrets"
```

### Workflow 2: Edit Encrypted File In-Place

**Use case:** Update a secret without full decrypt/re-encrypt

```bash
bash scripts/run.sh edit secrets.yaml
# Opens $EDITOR with decrypted content
# Re-encrypts on save
```

### Workflow 3: Encrypt .env Files

**Use case:** Encrypt dotenv files for deployment

```bash
bash scripts/run.sh encrypt .env.production
# Encrypts values, keeps keys readable
```

### Workflow 4: Rotate Keys

**Use case:** Team member leaves, rotate encryption keys

```bash
bash scripts/run.sh rotate secrets.yaml --add-key "age1new-team-member-key"
# Re-encrypts with updated key set
```

### Workflow 5: Decrypt for CI/CD

**Use case:** Decrypt secrets in a deployment pipeline

```bash
# Export age key as env var in CI
export SOPS_AGE_KEY="AGE-SECRET-KEY-1XXXXXXX..."

# Decrypt to stdout (pipe to env loader)
bash scripts/run.sh decrypt secrets.env --stdout | source /dev/stdin
```

### Workflow 6: Encrypt Specific Keys Only

**Use case:** Keep some values readable (like hostnames) while encrypting secrets

```bash
bash scripts/run.sh encrypt secrets.yaml --encrypted-regex "^(password|key|secret|token)$"
# Only encrypts values whose keys match the regex
```

## Configuration

### .sops.yaml (Per-Repo Config)

```yaml
creation_rules:
  # Encrypt all yaml files in secrets/ directory
  - path_regex: secrets/.*\.yaml$
    age: >-
      age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p,
      age1second-team-member-key

  # Encrypt .env files — only encrypt values matching pattern
  - path_regex: \.env.*$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
    encrypted_regex: ".*"

  # Different keys for staging vs production
  - path_regex: staging/.*$
    age: age1staging-key
  - path_regex: production/.*$
    age: age1prod-key-1,age1prod-key-2
```

### Environment Variables

```bash
# Path to age key file (default: ~/.config/sops/age/keys.txt)
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

# Or inline key (useful in CI/CD)
export SOPS_AGE_KEY="AGE-SECRET-KEY-1XXXXXXX..."
```

## Advanced Usage

### Multiple Recipients (Team Setup)

```bash
# Each team member generates their own key
bash scripts/setup-keys.sh

# Collect all public keys into .sops.yaml
bash scripts/init-repo.sh \
  --key "age1alice-public-key" \
  --key "age1bob-public-key" \
  --key "age1ci-server-key"

# Anyone with a matching private key can decrypt
```

### Audit Encrypted Files

```bash
bash scripts/run.sh audit
# Scans repo for:
# - Unencrypted secrets (files matching patterns but not encrypted)
# - Stale keys (keys in .sops.yaml that should be rotated)
# - Missing .sops.yaml
```

### Encrypt Entire Directory

```bash
bash scripts/run.sh encrypt-dir ./secrets/
# Encrypts all supported files in directory
```

### Convert Between Formats

```bash
# Decrypt YAML secrets to .env format
bash scripts/run.sh decrypt secrets.yaml --output-type dotenv > .env
```

## Troubleshooting

### Issue: "no matching keys found"

**Fix:** Ensure your age key file exists and matches the public key in `.sops.yaml`:
```bash
cat ~/.config/sops/age/keys.txt | grep "public key"
# Compare with keys in .sops.yaml
```

### Issue: "could not decrypt"

**Check:**
1. Key file exists: `ls ~/.config/sops/age/keys.txt`
2. Key matches: public key in `keys.txt` matches one in `.sops.yaml`
3. File was encrypted with your key

### Issue: sops not found after install

**Fix:**
```bash
# Check installation
which sops || echo "sops not in PATH"

# Re-install
bash scripts/install.sh --force
```

## Dependencies

- `sops` (3.8+) — Mozilla Secrets OPerationS
- `age` (1.1+) — Modern encryption tool
- `bash` (4.0+)
- Optional: `jq` (for JSON secrets)
