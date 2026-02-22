# Listing Copy: Git Hooks Manager

## Metadata
- **Type:** Skill
- **Name:** git-hooks-manager
- **Display Name:** Git Hooks Manager
- **Categories:** [dev-tools, automation]
- **Price:** $10
- **Dependencies:** [git, python3, pip]

## Tagline

"Automate Git hooks — secret detection, linting, formatting on every commit"

## Description

Leaked an API key in a commit? Pushed code that fails linting? These mistakes cost hours to fix and can be security nightmares. Manual code review catches some issues, but by then the damage is in git history.

Git Hooks Manager sets up pre-commit hooks in any repository in under 2 minutes. Choose a profile (security, Python, JavaScript, or full-stack) and get automatic secret scanning, code formatting, linting, and commit message enforcement — all running locally before code ever leaves your machine.

**What it does:**
- 🔐 Detect secrets (API keys, tokens, private keys) before they're committed
- 🧹 Auto-format code with ruff, prettier, eslint
- ✅ Validate YAML, JSON, TOML configs
- 📏 Enforce conventional commit messages
- 🚫 Block large files and merge conflict markers
- 🔄 One-command hook updates across all repos

**Who it's for:** Developers and teams who want automated code quality gates without complex CI setup.

## Quick Start Preview

```bash
# Install pre-commit framework
bash scripts/install.sh

# Set up hooks with security + Python linting
bash scripts/init.sh /path/to/repo --profile python

# Hooks run automatically on every commit!
```

## Core Capabilities

1. Secret detection — Block API keys, tokens, passwords from being committed
2. Multi-language linting — Python (ruff), JavaScript (eslint), universal (prettier)
3. Profile-based setup — minimal, security, python, javascript, full-stack presets
4. Commit message enforcement — Conventional commits format validation
5. Config validation — Auto-check YAML, JSON, TOML syntax
6. One-command updates — Update all hook versions to latest
7. Custom hook addition — Add any pre-commit hook with one command
8. CI integration — GitHub Actions workflow template included
9. Multi-repo support — Initialize hooks across all repos in a directory
10. Secret baselines — Ignore existing secrets, only flag new ones
