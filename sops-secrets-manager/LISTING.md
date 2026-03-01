# Listing Copy: SOPS Secrets Manager

## Metadata
- **Type:** Skill
- **Name:** sops-secrets-manager
- **Display Name:** SOPS Secrets Manager
- **Categories:** [security, dev-tools]
- **Price:** $12
- **Icon:** 🔐
- **Dependencies:** [sops, age]

## Tagline

Encrypt secrets in git repos — Commit credentials safely with SOPS + age

## Description

Storing secrets in git repos is dangerous — one leaked `.env` file and your API keys are public. But managing separate secret stores adds complexity and slows down deployment.

SOPS Secrets Manager lets your OpenClaw agent install Mozilla SOPS and age encryption, generate key pairs, and encrypt/decrypt secrets files directly in your repositories. YAML, JSON, ENV, and INI files are all supported. Encrypted files stay human-readable (keys visible, values encrypted) so you can review diffs in pull requests.

**What it does:**
- 🔐 Encrypt secrets files in-place (YAML, JSON, ENV, INI)
- 🔑 Generate and manage age encryption keys
- ✏️ Edit encrypted files without manual decrypt/re-encrypt
- 🔄 Rotate keys when team members change
- 🔍 Audit repos for accidentally unencrypted secrets
- 📁 Bulk-encrypt entire directories
- 🚀 CI/CD-ready — decrypt via environment variable

Perfect for developers and DevOps engineers who want secrets in version control without the risk. One-time install, works across all your repos.

## Quick Start Preview

```bash
# Install sops + age
bash scripts/install.sh

# Generate key & encrypt a secrets file
bash scripts/setup-keys.sh
bash scripts/run.sh encrypt secrets.yaml

# Safe to commit!
git add secrets.yaml .sops.yaml && git commit -m "Add encrypted secrets"
```

## Core Capabilities

1. File encryption — Encrypt YAML, JSON, ENV, INI files in-place with SOPS
2. age key management — Generate, distribute, and rotate modern encryption keys
3. In-place editing — Edit encrypted files directly (auto decrypt → edit → re-encrypt)
4. Selective encryption — Encrypt only sensitive keys (passwords, tokens) via regex
5. Key rotation — Re-encrypt files when team members join or leave
6. Directory encryption — Bulk-encrypt all secrets files in a directory
7. Security audit — Scan repos for unencrypted secrets that should be encrypted
8. CI/CD integration — Decrypt via environment variable, no key file needed
9. Multi-recipient — Encrypt for multiple team members with separate keys
10. Cross-platform — Works on Linux (x86/ARM) and macOS
