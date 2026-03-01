---
name: git-secret-scanner
description: >-
  Scan git repositories for leaked secrets, API keys, and credentials using gitleaks.
categories: [security, dev-tools]
dependencies: [bash, curl, git]
---

# Git Secret Scanner

## What This Does

Scans your git repositories for accidentally committed secrets — API keys, passwords, tokens, private keys, and other credentials. Uses [gitleaks](https://github.com/gitleaks/gitleaks), the industry-standard secret detection tool.

**Example:** "Scan my entire repo history for leaked AWS keys, Stripe tokens, or database passwords. Set up a pre-commit hook to prevent future leaks."

## Quick Start (5 minutes)

### 1. Install Gitleaks

```bash
bash scripts/install.sh
```

### 2. Scan Current Directory

```bash
bash scripts/run.sh --scan .
```

### 3. Scan Full Git History

```bash
bash scripts/run.sh --scan . --history
```

## Core Workflows

### Workflow 1: Scan a Repository

**Use case:** Check if any secrets have been committed

```bash
# Scan current state only (fast)
bash scripts/run.sh --scan /path/to/repo

# Scan entire git history (thorough)
bash scripts/run.sh --scan /path/to/repo --history

# Output:
# 🔍 Scanning /path/to/repo...
# 
# ❌ SECRETS FOUND: 3
#
# [1] AWS Access Key
#     File: config/aws.js:12
#     Commit: a1b2c3d (2025-06-15)
#     Match: AKIA**************
#     Rule: aws-access-key-id
#
# [2] Stripe Secret Key
#     File: .env:5
#     Commit: f4e5d6c (2025-08-20)
#     Match: sk_live_**************
#     Rule: stripe-api-key
#
# Summary: 3 secrets in 2 files across 2 commits
```

### Workflow 2: Set Up Pre-Commit Hook

**Use case:** Prevent future secret commits

```bash
bash scripts/run.sh --hook /path/to/repo

# Output:
# ✅ Pre-commit hook installed at /path/to/repo/.git/hooks/pre-commit
# Future commits will be scanned for secrets automatically.
```

### Workflow 3: Generate Report

**Use case:** Export findings for team review

```bash
# JSON report
bash scripts/run.sh --scan /path/to/repo --history --format json --output report.json

# CSV report
bash scripts/run.sh --scan /path/to/repo --history --format csv --output report.csv

# SARIF report (for GitHub Security tab)
bash scripts/run.sh --scan /path/to/repo --history --format sarif --output report.sarif
```

### Workflow 4: Scan Multiple Repos

**Use case:** Audit all repos in a directory

```bash
bash scripts/run.sh --scan-all /path/to/projects

# Output:
# 🔍 Scanning 12 repositories...
#
# ✅ project-a: Clean
# ❌ project-b: 2 secrets found
# ✅ project-c: Clean
# ❌ project-d: 5 secrets found
# ...
# 
# Summary: 7 secrets across 2 of 12 repos
```

### Workflow 5: Custom Rules

**Use case:** Add your own secret patterns

```bash
# Scan with additional custom rules
bash scripts/run.sh --scan . --config custom-rules.toml
```

See `examples/custom-rules.toml` for the custom rules template.

### Workflow 6: Baseline (Ignore Known Secrets)

**Use case:** Acknowledge existing secrets and only flag new ones

```bash
# Create baseline from current state
bash scripts/run.sh --scan . --history --baseline .gitleaks-baseline.json

# Future scans compare against baseline
bash scripts/run.sh --scan . --history --use-baseline .gitleaks-baseline.json

# Only NEW secrets since baseline will be reported
```

## Configuration

### Environment Variables

```bash
# Optional: custom gitleaks config path
export GITLEAKS_CONFIG="/path/to/custom-config.toml"

# Optional: install location (default: /usr/local/bin)
export GITLEAKS_INSTALL_DIR="$HOME/.local/bin"
```

### Custom Rules File (TOML)

```toml
# custom-rules.toml
title = "Custom Secret Rules"

[[rules]]
id = "internal-api-key"
description = "Internal API Key"
regex = '''(?i)internal[_-]?api[_-]?key\s*[=:]\s*['"]?([a-zA-Z0-9_\-]{32,})['"]?'''
tags = ["internal", "api"]

[[rules]]
id = "database-url"
description = "Database Connection String"
regex = '''(?i)(postgres|mysql|mongodb)://[^\s'"]+'''
tags = ["database"]

[allowlist]
paths = [
  '''(.*?)test(.*?)''',
  '''(.*?)mock(.*?)''',
  '''\.gitleaks\.toml'''
]
```

## What It Detects

Gitleaks detects 150+ secret types out of the box:

- **Cloud:** AWS keys, GCP service accounts, Azure tokens
- **Payment:** Stripe, PayPal, Square API keys
- **Communication:** Slack tokens, Discord webhooks, Twilio keys
- **Database:** Connection strings, Redis URLs
- **Auth:** JWT secrets, OAuth tokens, SSH private keys
- **CI/CD:** GitHub tokens, GitLab tokens, CircleCI keys
- **Infrastructure:** Terraform tokens, Vault tokens, Heroku API keys
- **Email:** SendGrid, Mailgun, Mailchimp API keys
- **General:** Private keys, certificates, generic passwords

## Advanced Usage

### CI/CD Integration

Add to GitHub Actions:

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scan
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Scheduled Scans via OpenClaw Cron

```bash
# Scan repos weekly, alert on findings
# Use OpenClaw's cron system to schedule:
bash scripts/run.sh --scan-all /path/to/repos --format json --output /tmp/scan-results.json
```

### Allowlisting False Positives

Add `.gitleaks.toml` to your repo root:

```toml
[allowlist]
description = "Allowlist for known false positives"
paths = [
  '''vendor/''',
  '''node_modules/''',
  '''test/fixtures/'''
]
commits = [
  "abc123def456"
]
regexTarget = "match"
regexes = [
  '''EXAMPLE_KEY_DO_NOT_USE'''
]
```

## Troubleshooting

### Issue: "gitleaks: command not found"

**Fix:** Run the installer again:
```bash
bash scripts/install.sh
```

Or install manually:
```bash
# Linux (amd64)
curl -sSfL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_8.21.2_linux_amd64.tar.gz | tar xz -C /usr/local/bin gitleaks

# Linux (arm64)
curl -sSfL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_8.21.2_linux_arm64.tar.gz | tar xz -C /usr/local/bin gitleaks

# Mac
brew install gitleaks
```

### Issue: Too many false positives

**Fix:** Create a `.gitleaks.toml` allowlist in your repo (see Allowlisting section above).

### Issue: Scan takes too long on large repos

**Fix:** Scan only recent commits:
```bash
bash scripts/run.sh --scan . --since "2025-01-01"
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `git` (for repo scanning)
- `gitleaks` (auto-installed by `scripts/install.sh`)
