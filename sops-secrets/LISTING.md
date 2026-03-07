# Listing Copy: SOPS Secrets Manager

## Metadata
- **Type:** Skill
- **Name:** sops-secrets
- **Display Name:** SOPS Secrets Manager
- **Categories:** [security, dev-tools]
- **Icon:** 🔐
- **Dependencies:** [sops, age]

## Tagline

Encrypt secrets in your config files — store API keys safely in git with Mozilla SOPS

## Description

Committing secrets to git is one of the most common security mistakes in software development. Leaked API keys, database passwords, and tokens cost companies millions every year. You need a way to keep secrets in your repo — encrypted.

**SOPS Secrets Manager** brings Mozilla SOPS to your OpenClaw agent. Encrypt YAML, JSON, ENV, and INI files with age encryption. Secrets stay encrypted in git and are decrypted only at runtime. No external services, no cloud dependencies — everything runs locally.

**What it does:**
- 🔐 Encrypt/decrypt config files with one command
- 🔑 Generate and manage age encryption keys
- 📁 Initialize SOPS in any project with `.sops.yaml`
- 🔄 Rotate encryption keys when team members leave
- 🏗️ Multi-environment support (dev/staging/prod)
- 🛡️ Git pre-commit hook blocks unencrypted secrets
- 📊 Audit which files are encrypted and who has access
- 🎯 Partial encryption — encrypt only sensitive keys, keep structure readable

Perfect for developers, DevOps engineers, and teams who want to stop using `.env.example` files and start managing secrets properly.

## Quick Start Preview

```bash
# Install SOPS + age
bash scripts/install.sh

# Generate encryption key
bash scripts/setup-keys.sh

# Initialize in your project
bash scripts/init-project.sh /path/to/project

# Encrypt a secrets file
sops encrypt -i secrets/database.yaml
# → File encrypted in-place, safe to commit
```

## Core Capabilities

1. Secret encryption — Encrypt YAML/JSON/ENV/INI files with Mozilla SOPS
2. Age key management — Generate, rotate, and manage modern encryption keys
3. Project initialization — One-command SOPS setup with .sops.yaml config
4. Key rotation — Re-encrypt all files when team members change
5. Multi-environment — Separate keys for dev/staging/prod
6. Partial encryption — Encrypt only sensitive fields, keep structure visible
7. Git hooks — Pre-commit hook blocks unencrypted secrets from being committed
8. Encryption audit — Scan projects for unencrypted secrets and key coverage
9. CI/CD ready — Decrypt at deploy time with environment variables
10. Team management — Add/remove recipients without re-sharing keys
