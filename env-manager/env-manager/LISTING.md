# Listing Copy: Environment Manager

## Metadata
- **Type:** Skill
- **Name:** env-manager
- **Display Name:** Environment Manager
- **Categories:** [dev-tools, security]
- **Price:** $10
- **Dependencies:** [bash, age, diff]
- **Icon:** 🔐

## Tagline

Encrypt, diff, validate, and sync .env files across environments

## Description

Managing `.env` files across dev, staging, and production is a mess. Variables get out of sync, secrets end up in git history, and new developers spend 30 minutes figuring out what environment variables they need.

Environment Manager fixes this. Encrypt secrets at rest with `age` (a modern, simple alternative to GPG), diff environments to catch missing variables, generate templates for onboarding, and validate configs before deployment. All from a single bash script — no external services, no subscriptions.

**What it does:**
- 🔐 Encrypt/decrypt `.env` files with `age` (commit safely to git)
- 📊 Diff two environments side-by-side (shows missing, extra, and changed vars)
- ✅ Validate `.env` against a template (catch missing vars before deploy)
- 📝 Generate templates from existing `.env` files
- 🔄 Sync missing variables between environments
- 🔍 Search for a variable across all your `.env` files
- 🔑 Rotate encryption keys with one command

Perfect for developers, DevOps engineers, and teams managing multiple environments who want secure, organized `.env` management without SaaS tools.

## Quick Start Preview

```bash
# Initialize (one time)
bash scripts/env-manager.sh init

# Encrypt your .env
bash scripts/env-manager.sh encrypt .env

# Diff dev vs prod
bash scripts/env-manager.sh diff .env.dev .env.prod

# Validate before deploy
bash scripts/env-manager.sh validate .env --template .env.template --strict
```

## Core Capabilities

1. **Encryption at rest** — Encrypt .env with age, commit .env.age to git safely
2. **Environment diffing** — Compare any two .env files, see missing/changed vars
3. **Template generation** — Auto-generate .env.template from existing configs
4. **Validation** — Check .env against template, fail CI on missing vars
5. **Auto-decryption** — Diff and validate encrypted .age files transparently
6. **Variable search** — Find a variable across all your .env files
7. **Environment sync** — Copy missing vars from one env to another
8. **Key rotation** — Rotate encryption keys, re-encrypt all files
9. **Secret redaction** — Sensitive values auto-redacted in output
10. **Backup safety** — Auto-backup before any overwrite operation
