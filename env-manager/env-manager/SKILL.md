---
name: env-manager
description: >-
  Manage .env files across projects — encrypt secrets, sync between environments,
  validate required vars, diff changes, and prevent accidental commits.
categories: [dev-tools, security]
dependencies: [bash, age, git]
---

# Environment Manager

## What This Does

Manages `.env` files across your projects: encrypt secrets with `age`, sync between environments (dev/staging/prod), validate required variables, diff configs, and set up git hooks to prevent accidental `.env` commits.

**Example:** "Encrypt all .env files in a project, sync dev → staging with overrides, validate prod has all required vars before deploy."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install age (modern encryption tool)
# Ubuntu/Debian
sudo apt-get install -y age

# macOS
brew install age

# Or download from https://github.com/FiloSottile/age/releases
which age || echo "❌ age not installed"

# Generate encryption key (one-time)
mkdir -p ~/.config/env-manager
if [ ! -f ~/.config/env-manager/key.txt ]; then
  age-keygen -o ~/.config/env-manager/key.txt 2>&1 | head -1
  chmod 600 ~/.config/env-manager/key.txt
  echo "✅ Encryption key generated"
else
  echo "✅ Key already exists"
fi
```

### 2. Initialize a Project

```bash
bash scripts/env-manager.sh init /path/to/project

# Creates:
# .env.example (template with empty values)
# .env.schema (validation rules)
# .gitignore entry for .env files
# pre-commit hook to block .env commits
```

### 3. Encrypt Your .env

```bash
bash scripts/env-manager.sh encrypt /path/to/project/.env

# Output:
# ✅ Encrypted → /path/to/project/.env.age
# Safe to commit .env.age to git
```

## Core Workflows

### Workflow 1: Encrypt/Decrypt Secrets

**Use case:** Store encrypted .env in git, decrypt locally

```bash
# Encrypt
bash scripts/env-manager.sh encrypt .env
# → .env.age (commit this)

# Decrypt
bash scripts/env-manager.sh decrypt .env.age
# → .env (gitignored)

# Encrypt all .env files in project
bash scripts/env-manager.sh encrypt-all /path/to/project
```

### Workflow 2: Sync Between Environments

**Use case:** Copy dev config to staging with overrides

```bash
# Create env-specific files
# .env.dev, .env.staging, .env.prod

# Sync dev → staging (keeps staging overrides)
bash scripts/env-manager.sh sync .env.dev .env.staging

# Output:
# 🔄 Syncing .env.dev → .env.staging
# + Added: NEW_API_KEY (from dev)
# = Kept: DATABASE_URL (staging override)
# - Missing in dev: STAGING_ONLY_VAR (kept)
# ✅ Synced 15 vars (3 added, 10 kept, 2 staging-only)
```

### Workflow 3: Validate Before Deploy

**Use case:** Ensure prod has all required vars

```bash
# Define schema
cat > .env.schema << 'EOF'
DATABASE_URL=required
API_KEY=required
REDIS_URL=required
DEBUG=optional|default=false
LOG_LEVEL=optional|default=info|values=debug,info,warn,error
PORT=optional|default=3000|type=number
EOF

# Validate
bash scripts/env-manager.sh validate .env.prod --schema .env.schema

# Output:
# ✅ DATABASE_URL = set
# ✅ API_KEY = set
# ❌ REDIS_URL = MISSING (required)
# ✅ DEBUG = false (default)
# ✅ LOG_LEVEL = info (valid)
# ✅ PORT = 3000 (valid number)
#
# ❌ Validation FAILED: 1 required variable missing
```

### Workflow 4: Diff Environments

**Use case:** Compare dev vs prod configs

```bash
bash scripts/env-manager.sh diff .env.dev .env.prod

# Output:
# 📊 Environment Diff: .env.dev ↔ .env.prod
# ─────────────────────────────────────────
# Variable          │ dev              │ prod
# ─────────────────────────────────────────
# DATABASE_URL      │ localhost:5432   │ prod-db.aws:5432
# DEBUG             │ true             │ false
# API_KEY           │ dev-key-xxx      │ *** (masked)
# NEW_FEATURE_FLAG  │ true             │ (missing)
# CDN_URL           │ (missing)        │ cdn.example.com
# ─────────────────────────────────────────
# Summary: 2 different, 1 only-in-dev, 1 only-in-prod
```

### Workflow 5: Generate .env.example

**Use case:** Create a safe template for team onboarding

```bash
bash scripts/env-manager.sh example .env

# Output → .env.example:
# DATABASE_URL=
# API_KEY=
# REDIS_URL=
# DEBUG=false
# LOG_LEVEL=info
# PORT=3000
#
# ✅ Generated .env.example (6 vars, secrets stripped, defaults kept)
```

### Workflow 6: Git Protection

**Use case:** Prevent accidental .env commits

```bash
bash scripts/env-manager.sh protect /path/to/project

# Installs:
# 1. .gitignore rules for .env, .env.local, .env.*.local
# 2. pre-commit hook that blocks .env file commits
# 3. Scans git history for leaked .env files
#
# Output:
# ✅ .gitignore updated
# ✅ pre-commit hook installed
# ⚠️ Found .env in git history (commit abc123) — run `git filter-branch` to remove
```

## Configuration

### Key File Location

```bash
# Default key location
~/.config/env-manager/key.txt

# Custom key via environment variable
export ENV_MANAGER_KEY="/path/to/custom/key.txt"

# Team key (shared via secure channel)
export ENV_MANAGER_TEAM_KEY="/path/to/team/key.txt"
```

### Schema Format

```bash
# .env.schema — one rule per line
# Format: VAR_NAME=required|optional [|default=X] [|type=string|number|bool|url] [|values=a,b,c]

DATABASE_URL=required|type=url
API_KEY=required
SECRET_KEY=required
DEBUG=optional|default=false|type=bool
PORT=optional|default=3000|type=number
LOG_LEVEL=optional|default=info|values=debug,info,warn,error
WORKERS=optional|default=4|type=number
```

## Advanced Usage

### Rotate Encryption Key

```bash
# Generate new key
age-keygen -o ~/.config/env-manager/key-new.txt

# Re-encrypt all files
bash scripts/env-manager.sh rotate /path/to/project \
  --old-key ~/.config/env-manager/key.txt \
  --new-key ~/.config/env-manager/key-new.txt

# Replace old key
mv ~/.config/env-manager/key-new.txt ~/.config/env-manager/key.txt
```

### Bulk Operations

```bash
# Encrypt all .env files in all projects
find ~/projects -name ".env" -not -path "*/node_modules/*" | while read f; do
  bash scripts/env-manager.sh encrypt "$f"
done

# Validate all projects
find ~/projects -name ".env.schema" | while read s; do
  dir=$(dirname "$s")
  echo "=== $dir ==="
  bash scripts/env-manager.sh validate "$dir/.env" --schema "$s"
done
```

### CI/CD Integration

```bash
# In GitHub Actions / CI pipeline:
# 1. Decrypt .env from .env.age
bash scripts/env-manager.sh decrypt .env.age --key "$ENV_DECRYPTION_KEY"

# 2. Validate against schema
bash scripts/env-manager.sh validate .env --schema .env.schema --strict

# 3. Export to environment
set -a; source .env; set +a
```

## Troubleshooting

### Issue: "age: command not found"

**Fix:**
```bash
# Install age
# Ubuntu: sudo apt-get install age
# macOS: brew install age
# Manual: https://github.com/FiloSottile/age/releases
```

### Issue: "permission denied" on key file

**Fix:**
```bash
chmod 600 ~/.config/env-manager/key.txt
```

### Issue: Encrypted file won't decrypt

**Check:**
1. Correct key: `age-keygen -y ~/.config/env-manager/key.txt` (shows public key)
2. File not corrupted: `file .env.age` should show "data"
3. Key matches: encrypted with same public key

### Issue: Pre-commit hook not triggering

**Fix:**
```bash
chmod +x .git/hooks/pre-commit
# Verify: git commit should trigger the hook
```

## Dependencies

- `bash` (4.0+)
- `age` (encryption — https://github.com/FiloSottile/age)
- `git` (for hooks and history scanning)
- `diff` (standard unix tool)
- `awk`/`sed` (standard unix tools)
