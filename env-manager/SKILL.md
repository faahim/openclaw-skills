---
name: env-manager
description: >-
  Manage, validate, encrypt, and sync .env files across projects. Never leak secrets again.
categories: [dev-tools, security]
dependencies: [bash, age, diff]
---

# Environment Manager

## What This Does

Manages `.env` files across your projects — validates vars against `.env.example`, encrypts sensitive values with `age` (modern encryption), diffs environments, and syncs secrets between dev/staging/prod. Prevents missing vars from breaking deploys and secrets from leaking into git.

**Example:** "Validate all .env files match their .env.example, encrypt production secrets, diff staging vs prod configs."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install age (modern encryption — replacement for GPG)
# Ubuntu/Debian
sudo apt-get install -y age

# macOS
brew install age

# Or download binary
curl -LO https://github.com/FiloSottile/age/releases/latest/download/age-v1.2.0-linux-amd64.tar.gz
tar xzf age-v1.2.0-linux-amd64.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/

# Verify
age --version
```

### 2. Generate Encryption Key (one-time)

```bash
bash scripts/env-manager.sh keygen
# Output:
# 🔑 Key generated at ~/.config/env-manager/key.txt
# Public key: age1ql3z7hjy5...
# Add this public key to your team's .env-manager.yaml
```

### 3. Validate a Project

```bash
bash scripts/env-manager.sh validate /path/to/project
# Output:
# ✅ DATABASE_URL — present
# ✅ API_KEY — present
# ❌ STRIPE_SECRET — MISSING (defined in .env.example)
# ❌ REDIS_URL — MISSING (defined in .env.example)
# 
# Result: 2 missing variables. Fix before deploying.
```

## Core Workflows

### Workflow 1: Validate .env Against .env.example

**Use case:** Ensure no vars are missing before deployment

```bash
bash scripts/env-manager.sh validate /path/to/project

# With strict mode (fail on any extra vars not in .env.example)
bash scripts/env-manager.sh validate /path/to/project --strict
```

**Output:**
```
📋 Validating /path/to/project/.env against .env.example
✅ DATABASE_URL — present
✅ API_KEY — present  
✅ NODE_ENV — present (default: development)
❌ STRIPE_SECRET — MISSING
❌ REDIS_URL — MISSING
⚠️  LEGACY_FLAG — Extra (not in .env.example)

Result: 2 missing, 1 extra. Exit code: 1
```

### Workflow 2: Encrypt Secrets

**Use case:** Store encrypted .env files safely in git

```bash
# Encrypt .env → .env.enc (using your age key)
bash scripts/env-manager.sh encrypt /path/to/project/.env

# Encrypt with specific recipient (team member's public key)
bash scripts/env-manager.sh encrypt /path/to/project/.env --recipient age1ql3z7hjy5...

# Decrypt
bash scripts/env-manager.sh decrypt /path/to/project/.env.enc
```

**Output:**
```
🔒 Encrypting /path/to/project/.env
   → /path/to/project/.env.enc (423 bytes)
   Encrypted with: ~/.config/env-manager/key.txt
   ✅ Safe to commit .env.enc to git
```

### Workflow 3: Diff Environments

**Use case:** Compare staging vs production configs

```bash
bash scripts/env-manager.sh diff /project/.env.staging /project/.env.production
```

**Output:**
```
🔍 Comparing .env.staging vs .env.production

  DATABASE_URL:
    staging:    postgres://localhost:5432/myapp_staging
    production: postgres://rds.amazonaws.com:5432/myapp_prod

  API_KEY:
    staging:    sk_test_abc123
    production: sk_live_xyz789

  NODE_ENV:
    staging:    staging
    production: production

  Only in staging:
    DEBUG=true

  Only in production:
    SENTRY_DSN=https://abc@sentry.io/123

Summary: 3 different, 1 staging-only, 1 prod-only
```

### Workflow 4: Sync Environments

**Use case:** Copy missing vars from one env to another

```bash
# Preview what would be synced
bash scripts/env-manager.sh sync /project/.env.staging /project/.env.production --dry-run

# Sync missing vars (adds to target, doesn't overwrite existing)
bash scripts/env-manager.sh sync /project/.env.staging /project/.env.production
```

### Workflow 5: Scan for Leaked Secrets

**Use case:** Check if .env files are accidentally committed to git

```bash
bash scripts/env-manager.sh scan /path/to/repo
```

**Output:**
```
🔍 Scanning git history for .env files...

⚠️  Found .env files in git history:
  - .env (commit abc123, 2026-01-15) — ACTIVE in working tree
  - config/.env.local (commit def456, 2026-02-01) — deleted but in history

🚨 Secrets may be exposed! Run:
  git filter-branch --force --index-filter \
    'git rm --cached --ignore-unmatch .env' HEAD
  
  Or use BFG Repo Cleaner:
  bfg --delete-files .env
```

### Workflow 6: Generate .env.example from .env

**Use case:** Create a template from existing .env (strips values)

```bash
bash scripts/env-manager.sh template /path/to/project/.env
```

**Output:**
```
📝 Generated .env.example from .env

DATABASE_URL=
API_KEY=
NODE_ENV=development
STRIPE_SECRET=
REDIS_URL=redis://localhost:6379
DEBUG=

Written to: /path/to/project/.env.example
(Kept default-looking values, stripped secrets)
```

## Configuration

### Project Config (.env-manager.yaml)

```yaml
# .env-manager.yaml (place in project root)
environments:
  - name: development
    file: .env
    example: .env.example
  - name: staging
    file: .env.staging
  - name: production
    file: .env.production
    
encryption:
  recipients:
    - age1ql3z7hjy5...  # Alice
    - age1abc123def...   # Bob
    
validation:
  strict: false          # Allow extra vars not in .env.example
  required_prefix: ""    # Require all vars to have a prefix
  
gitignore:
  auto_check: true       # Warn if .env not in .gitignore
```

### Environment Variables

```bash
# Custom key location (default: ~/.config/env-manager/key.txt)
export ENV_MANAGER_KEY="$HOME/.config/env-manager/key.txt"

# Default project path
export ENV_MANAGER_PROJECT="/path/to/project"
```

## Troubleshooting

### Issue: "age: command not found"

```bash
# Install age
sudo apt-get install -y age  # Debian/Ubuntu
brew install age              # macOS
```

### Issue: "No .env.example found"

The validate command requires `.env.example` in the same directory. Generate one:
```bash
bash scripts/env-manager.sh template /path/to/.env
```

### Issue: "Cannot decrypt — wrong key"

The file was encrypted with a different age key. You need the matching private key:
```bash
# Decrypt with specific key
bash scripts/env-manager.sh decrypt .env.enc --identity /path/to/other-key.txt
```

## Dependencies

- `bash` (4.0+)
- `age` (1.0+ — modern file encryption)
- `diff` (standard — for env comparison)
- `git` (optional — for secret scanning)
- `sort`, `grep`, `awk` (standard Unix tools)
