# Listing Copy: Environment Manager

## Metadata
- **Type:** Skill
- **Name:** env-manager
- **Display Name:** Environment Manager
- **Categories:** [dev-tools, security]
- **Price:** $12
- **Dependencies:** [bash, age, diff, git]

## Tagline
Manage, validate, encrypt, and sync .env files — never leak secrets again

## Description

Missing environment variables break deploys. Leaked .env files expose API keys. Manually diffing staging vs production configs wastes time. These are solved problems — but most developers still manage .env files by hand.

Environment Manager automates the entire .env lifecycle. Validate that your .env matches .env.example before every deploy. Encrypt production secrets with `age` (modern, audited encryption) so you can safely commit them to git. Diff any two environments to spot misconfigurations. Sync missing vars between dev/staging/prod. Scan your git history for accidentally committed secrets.

**What it does:**
- ✅ Validate .env against .env.example — catch missing vars before deploys
- 🔒 Encrypt/decrypt .env files with age (no GPG complexity)
- 🔍 Diff environments — compare staging vs production side-by-side
- 🔄 Sync missing vars between environments
- 🚨 Scan git history for leaked .env files
- 📝 Auto-generate .env.example templates from existing .env
- ⚡ Zero config — works immediately, optional .env-manager.yaml for teams

Perfect for developers and teams who deploy to multiple environments and need bulletproof secret management without the complexity of Vault or AWS Secrets Manager.

## Core Capabilities

1. Env validation — Check .env against .env.example, flag missing/extra vars
2. Secret encryption — Encrypt .env with age (modern, audited crypto)
3. Environment diffing — Side-by-side comparison of any two .env files
4. Var syncing — Copy missing vars between environments (with dry-run)
5. Git leak scanning — Detect .env files in git history
6. Template generation — Create .env.example from .env (strips secrets)
7. Key management — Generate and manage age encryption keys
8. Strict mode — Fail CI on extra vars not in .env.example
9. Team encryption — Encrypt for multiple recipients
10. Gitignore checking — Warns if .env isn't in .gitignore

## Installation Time
**5 minutes** — Install age, run keygen, start validating
