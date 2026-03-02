# Listing Copy: Environment Manager

## Metadata
- **Type:** Skill
- **Name:** env-manager
- **Display Name:** Environment Manager
- **Categories:** [dev-tools, security]
- **Price:** $10
- **Dependencies:** [bash, age, git]
- **Icon:** 🔐

## Tagline
Encrypt, sync, validate, and protect .env files across all your projects

## Description

Managing `.env` files across projects is a mess. Secrets get committed to git, staging is missing vars that prod has, and onboarding a new dev means hunting down API keys. You need a system.

Environment Manager handles the full `.env` lifecycle: encrypt secrets with `age` (modern, audited encryption), sync variables between dev/staging/prod while keeping overrides, validate required vars before deploy, diff configs side-by-side, and install git hooks that prevent accidental commits.

**What it does:**
- 🔐 Encrypt/decrypt .env files with `age` (commit encrypted files safely)
- 🔄 Sync between environments (adds missing vars, keeps overrides)
- ✅ Validate against schema (required vars, types, allowed values)
- 📊 Diff two env files (shows differences, masks secrets)
- 🛡️ Git protection (pre-commit hooks, .gitignore, history scanning)
- 📋 Generate .env.example templates (strips secrets, keeps defaults)
- 🔑 Key rotation (re-encrypt all files with new key)

Perfect for developers and teams managing multiple environments who want bulletproof secret management without heavy tools like HashiCorp Vault.

## Quick Start Preview

```bash
# Encrypt secrets
bash scripts/env-manager.sh encrypt .env
# ✅ Encrypted → .env.age (safe to commit)

# Validate before deploy
bash scripts/env-manager.sh validate .env.prod --schema .env.schema
# ✅ DATABASE_URL = set
# ❌ REDIS_URL = MISSING (required)

# Diff environments
bash scripts/env-manager.sh diff .env.dev .env.prod
```

## Core Capabilities

1. **Age encryption** — Encrypt .env files with modern, audited `age` tool
2. **Environment sync** — Copy vars between envs, preserving overrides
3. **Schema validation** — Required/optional, types, default values, allowed values
4. **Side-by-side diff** — Compare any two env files with secret masking
5. **Git protection** — Pre-commit hooks block accidental .env commits
6. **Template generation** — Auto-create .env.example from real .env
7. **Bulk operations** — Encrypt/validate all projects at once
8. **Key rotation** — Re-encrypt everything with a new key
9. **CI/CD ready** — Decrypt + validate in pipelines
10. **Zero external services** — Runs locally, no SaaS dependency
