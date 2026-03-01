---
name: env-manager
description: >-
  Manage .env files across projects — encrypt secrets, diff environments, generate from templates, sync between dev/staging/prod.
categories: [dev-tools, security]
dependencies: [bash, age, diff]
---

# Environment Manager

## What This Does

Manages `.env` files across your projects with encryption, diffing, templating, and syncing. Encrypt secrets at rest with `age`, compare dev vs prod configs, generate `.env` from templates, and catch missing variables before deployment.

**Example:** "Encrypt my production .env, diff it against staging, and find missing variables."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install age for encryption (modern, simple alternative to GPG)
# Ubuntu/Debian
sudo apt-get install -y age

# macOS
brew install age

# Or download from https://github.com/FiloSottile/age/releases

# Verify
which age diff && echo "Ready!" || echo "Install age and ensure diff is available"
```

### 2. Initialize

```bash
# Generate an encryption key (first time only)
bash scripts/env-manager.sh init

# Output:
# ✅ Age key generated at ~/.config/env-manager/key.txt
# ✅ Config created at ~/.config/env-manager/config.yaml
# ⚠️  Back up ~/.config/env-manager/key.txt — losing it means losing access to encrypted .env files!
```

### 3. Encrypt Your First .env

```bash
# Encrypt a .env file (creates .env.age alongside it)
bash scripts/env-manager.sh encrypt .env

# Output:
# 🔐 Encrypted .env → .env.age (23 variables, 1.2KB)
# 💡 Add .env to .gitignore, commit .env.age instead
```

## Core Workflows

### Workflow 1: Encrypt/Decrypt .env Files

**Use case:** Store secrets safely in git

```bash
# Encrypt
bash scripts/env-manager.sh encrypt .env
# → Creates .env.age (encrypted)

# Decrypt
bash scripts/env-manager.sh decrypt .env.age
# → Creates .env (plaintext)

# Encrypt with custom output
bash scripts/env-manager.sh encrypt .env -o secrets/production.env.age
```

### Workflow 2: Diff Environments

**Use case:** Compare dev vs prod, find missing vars

```bash
# Compare two .env files
bash scripts/env-manager.sh diff .env.dev .env.prod

# Output:
# 📊 Environment Diff: .env.dev ↔ .env.prod
# ────────────────────────────────────────
# ONLY IN .env.dev:
#   DEBUG=true
#   MOCK_PAYMENTS=1
#
# ONLY IN .env.prod:
#   SENTRY_DSN=https://...
#   REDIS_URL=redis://...
#
# DIFFERENT VALUES:
#   DATABASE_URL: sqlite:///dev.db → postgres://prod:5432/app
#   API_URL: http://localhost:3000 → https://api.example.com
#
# SAME IN BOTH: 15 variables

# Compare encrypted files (auto-decrypts)
bash scripts/env-manager.sh diff .env.dev.age .env.prod.age
```

### Workflow 3: Validate Against Template

**Use case:** Ensure all required vars are set before deploy

```bash
# Create a template (.env.template)
bash scripts/env-manager.sh template .env
# → Creates .env.template with keys only (no values)

# Validate .env against template
bash scripts/env-manager.sh validate .env --template .env.template

# Output:
# ✅ All 23 required variables present
# ⚠️  Missing optional variables: SENTRY_DSN, NEW_RELIC_KEY
# ❌ Missing required variables: STRIPE_SECRET_KEY
```

### Workflow 4: Generate .env from Template

**Use case:** Onboard new developers

```bash
# Generate .env with placeholder values
bash scripts/env-manager.sh generate .env.template -o .env.local

# Output:
# 📝 Generated .env.local from template
# ⚠️  Fill in these values:
#   DATABASE_URL=<required>
#   API_KEY=<required>
#   DEBUG=true (default)
```

### Workflow 5: List & Search Variables

**Use case:** Quick lookup across environments

```bash
# List all variables in a .env
bash scripts/env-manager.sh list .env

# Search for a variable across multiple files
bash scripts/env-manager.sh search DATABASE_URL .env.*

# Output:
# 🔍 DATABASE_URL found in:
#   .env.dev     = sqlite:///dev.db
#   .env.staging = postgres://staging:5432/app
#   .env.prod    = postgres://prod:5432/app
```

### Workflow 6: Sync Variables

**Use case:** Copy missing vars from one env to another

```bash
# Sync missing vars from template to .env (interactive)
bash scripts/env-manager.sh sync .env.template .env

# Output:
# 🔄 Syncing .env.template → .env
# New variables to add:
#   REDIS_URL= (no default)
#   CACHE_TTL=3600 (default)
# Add these? [y/N]: y
# ✅ Added 2 variables to .env
```

## Configuration

### Config File (~/.config/env-manager/config.yaml)

```yaml
# Default encryption key location
key_path: ~/.config/env-manager/key.txt

# Default template file name
template_name: .env.template

# Variables to always redact in diffs/logs
redact_patterns:
  - "*_SECRET*"
  - "*_KEY*"
  - "*_PASSWORD*"
  - "*_TOKEN*"

# Auto-backup before overwriting
backup: true
backup_dir: ~/.config/env-manager/backups/
```

## Advanced Usage

### Rotate Encryption Key

```bash
# Generate new key and re-encrypt all .age files in a directory
bash scripts/env-manager.sh rotate-key ./secrets/

# Output:
# 🔄 Rotating encryption key...
# ✅ New key generated
# 🔐 Re-encrypted 5 files
# ⚠️  Old key backed up to ~/.config/env-manager/key.txt.bak
```

### Bulk Operations

```bash
# Encrypt all .env files in a project
find . -name ".env*" ! -name "*.age" ! -name "*.template" | \
  xargs -I {} bash scripts/env-manager.sh encrypt {}

# Validate all projects against their templates
for dir in ~/projects/*/; do
  if [ -f "$dir/.env.template" ] && [ -f "$dir/.env" ]; then
    echo "=== $(basename $dir) ==="
    bash scripts/env-manager.sh validate "$dir/.env" --template "$dir/.env.template"
  fi
done
```

### CI/CD Integration

```bash
# In your CI pipeline — decrypt and validate before deploy
bash scripts/env-manager.sh decrypt .env.prod.age -o .env
bash scripts/env-manager.sh validate .env --template .env.template --strict
# --strict exits with code 1 if any required var is missing
```

## Troubleshooting

### Issue: "age: command not found"

```bash
# Install age
# Ubuntu/Debian
sudo apt-get install -y age
# macOS
brew install age
# Manual: https://github.com/FiloSottile/age/releases
```

### Issue: "permission denied" on key file

```bash
chmod 600 ~/.config/env-manager/key.txt
```

### Issue: Can't decrypt (lost key)

If you lost `~/.config/env-manager/key.txt`, encrypted files are unrecoverable. Always back up your key.

```bash
# Check if key exists
ls -la ~/.config/env-manager/key.txt
```

### Issue: Diff shows binary data

Make sure your `.env` files are UTF-8 text, not binary. The encrypted `.age` files will be auto-decrypted before diffing.

## Dependencies

- `bash` (4.0+)
- `age` (encryption — https://github.com/FiloSottile/age)
- `diff` (comparison — pre-installed on Linux/Mac)
- `sort`, `grep`, `awk` (parsing — pre-installed)
