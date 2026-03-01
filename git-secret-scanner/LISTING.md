# Listing Copy: Git Secret Scanner

## Metadata
- **Type:** Skill
- **Name:** git-secret-scanner
- **Display Name:** Git Secret Scanner
- **Categories:** [security, dev-tools]
- **Price:** $10
- **Dependencies:** [bash, curl, git]

## Tagline

Scan git repos for leaked API keys, passwords, and tokens — prevent credential disasters

## Description

Accidentally committed an API key? You're not alone — leaked secrets in git repos cause millions in damages every year. By the time you realize a key is in your commit history, it's already been scraped by bots.

Git Secret Scanner installs and wraps **gitleaks**, the industry-standard secret detection tool, giving your OpenClaw agent the ability to scan repositories for 150+ types of leaked credentials. Scan working directories or full git history, generate reports, and set up pre-commit hooks to prevent future leaks.

**What it does:**
- 🔍 Detect 150+ secret types (AWS, Stripe, GitHub, database URLs, SSH keys, JWTs)
- 📜 Scan full git history — find secrets buried in old commits
- 🛡️ Pre-commit hooks — block secrets before they're committed
- 📊 Export reports in JSON, CSV, or SARIF format
- 📁 Batch scan — audit all repos in a directory at once
- 🎯 Custom rules — add your own patterns via TOML config
- ✅ Baseline support — track new secrets only, ignore acknowledged ones

Perfect for developers, DevSecOps engineers, and anyone who wants to make sure their repos are clean.

## Quick Start Preview

```bash
# Install gitleaks
bash scripts/install.sh

# Scan a repo
bash scripts/run.sh --scan . --history

# Install pre-commit hook
bash scripts/run.sh --hook .
```

## Core Capabilities

1. Secret detection — 150+ built-in rules for cloud keys, tokens, passwords
2. History scanning — Find secrets in any commit, not just current files
3. Pre-commit hooks — Block secrets before they reach the repo
4. Multi-repo audit — Scan all repos in a directory with one command
5. Report generation — JSON, CSV, SARIF formats for CI/CD integration
6. Custom rules — Define your own patterns with TOML config
7. Baseline support — Acknowledge known findings, alert only on new ones
8. GitHub Actions integration — CI/CD workflow included
9. Cross-platform — Linux (x64/arm64) and macOS
10. Zero config — Works out of the box with sensible defaults

## Dependencies
- `bash` (4.0+)
- `curl` (for installation)
- `git`
- `gitleaks` (auto-installed)

## Installation Time
**5 minutes** — run install script, scan immediately
