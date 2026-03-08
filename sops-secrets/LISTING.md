# Listing Copy: SOPS Secret Manager

## Metadata
- **Type:** Skill
- **Name:** sops-secrets
- **Display Name:** SOPS Secret Manager
- **Categories:** [security, dev-tools]
- **Price:** $12
- **Dependencies:** [sops, age, bash, jq]
- **Icon:** 🔐

## Tagline

Encrypt secrets in config files — commit safely to git, decrypt on deploy

## Description

Hardcoding API keys and passwords in config files is a ticking time bomb. One accidental git push and your secrets are public. You need encryption that's developer-friendly.

SOPS Secret Manager sets up Mozilla SOPS with age encryption so your secrets stay encrypted in git while keys remain readable. No external vault service, no monthly fees — everything runs locally on your machine.

**What it does:**
- 🔐 Encrypt values in YAML, JSON, and .env files (keys stay readable)
- 🔑 Generate and manage age encryption keys for your team
- 📝 Edit encrypted files inline — decrypts in editor, re-encrypts on save
- 🔄 Rotate keys when team members join or leave
- 📤 Export decrypted secrets as environment variables for local dev
- 🔍 Audit projects for unencrypted secrets and misconfigurations
- 🔀 Git diff integration — see decrypted changes in `git diff`
- 🏗️ Multi-environment support (dev/staging/prod with separate keys)

Perfect for developers and teams who want simple, git-native secret management without the complexity of HashiCorp Vault or AWS Secrets Manager.

## Quick Start Preview

```bash
# Install sops + age
bash scripts/install.sh

# Generate your key
bash scripts/setup-key.sh

# Encrypt secrets
bash scripts/encrypt.sh secrets.yaml

# Edit encrypted file
bash scripts/edit.sh secrets.yaml
```

## Core Capabilities

1. File encryption — Encrypt YAML, JSON, and .env files in-place
2. Key management — Generate, distribute, and rotate age encryption keys
3. Team support — Multiple recipients can decrypt with their own keys
4. Inline editing — Edit encrypted files without manual decrypt/re-encrypt
5. Env export — Load decrypted secrets as shell environment variables
6. Git integration — Decrypted diffs, safe commits
7. Multi-environment — Separate keys for dev/staging/production
8. Key rotation — Re-encrypt everything when team membership changes
9. Secret auditing — Scan for unencrypted secrets and misconfigurations
10. CI/CD ready — Decrypt at deploy time with a single env var

## Dependencies
- `sops` (3.8+)
- `age` (1.1+)
- `bash` (4.0+)
- `jq`

## Installation Time
**5 minutes** — auto-installs sops + age, generates key, ready to encrypt
