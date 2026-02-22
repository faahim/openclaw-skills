---
name: git-hooks-manager
description: >-
  Install, configure, and manage Git hooks with pre-commit framework — linting, formatting, secret detection, and custom hooks.
categories: [dev-tools, automation]
dependencies: [git, python3, pip]
---

# Git Hooks Manager

## What This Does

Automates Git hook setup across repositories using the [pre-commit](https://pre-commit.com) framework. Installs linters, formatters, secret scanners, and custom hooks — so bad code and leaked secrets never make it into commits.

**Example:** "Set up pre-commit hooks in my repo with secret detection, Python linting, Markdown formatting, and large file blocking — in 2 minutes."

## Quick Start (2 minutes)

### 1. Install pre-commit

```bash
bash scripts/install.sh
```

This installs `pre-commit` via pip and verifies it works.

### 2. Initialize hooks in a repo

```bash
bash scripts/init.sh /path/to/your/repo
```

Creates `.pre-commit-config.yaml` with sensible defaults (secret detection, trailing whitespace, large file check, YAML/JSON validation).

### 3. Run hooks manually

```bash
bash scripts/run.sh /path/to/your/repo
```

Runs all configured hooks against all files (not just staged).

## Core Workflows

### Workflow 1: Secret Detection Setup

**Use case:** Prevent API keys, passwords, tokens from being committed.

```bash
bash scripts/init.sh /path/to/repo --profile security
```

Installs:
- `detect-secrets` — scans for high-entropy strings, AWS keys, private keys
- `gitleaks` — comprehensive secret pattern matching
- `check-added-large-files` — blocks files >500KB (binary dumps with embedded secrets)

**On commit attempt with a secret:**
```
Detect Secrets..........................................................Failed
- hook id: detect-secrets
  ERROR: Potential secret detected in config.py:12
  AWS Access Key ID found: AKIA...
```

### Workflow 2: Python Project Hooks

**Use case:** Enforce code quality in Python repos.

```bash
bash scripts/init.sh /path/to/repo --profile python
```

Installs:
- `ruff` — fast Python linter + formatter (replaces flake8/black/isort)
- `mypy` — type checking
- `detect-secrets` — secret scanning
- Standard hooks (trailing whitespace, EOF fixer, YAML check)

### Workflow 3: JavaScript/TypeScript Project Hooks

**Use case:** Enforce quality in JS/TS repos.

```bash
bash scripts/init.sh /path/to/repo --profile javascript
```

Installs:
- `eslint` — JS/TS linting via mirror
- `prettier` — code formatting via mirror
- `detect-secrets` — secret scanning
- Standard hooks (trailing whitespace, EOF fixer, JSON check)

### Workflow 4: Full Stack (All Languages)

```bash
bash scripts/init.sh /path/to/repo --profile full
```

Combines security + language-agnostic checks:
- Secret detection (detect-secrets + gitleaks)
- Trailing whitespace, mixed line endings, merge conflict markers
- YAML, JSON, TOML validation
- Large file blocking
- Commit message format enforcement (conventional commits)

### Workflow 5: Custom Hook Addition

**Use case:** Add a specific hook to existing config.

```bash
bash scripts/add-hook.sh /path/to/repo \
  --repo https://github.com/pre-commit/mirrors-prettier \
  --rev v3.1.0 \
  --hook prettier
```

### Workflow 6: Update All Hooks

```bash
bash scripts/update.sh /path/to/repo
```

Updates all hook versions to latest. Shows diff of what changed.

### Workflow 7: List Installed Hooks

```bash
bash scripts/list.sh /path/to/repo
```

Shows all configured hooks, their versions, and last run status.

## Configuration

### Profile Configs

Profiles are pre-built `.pre-commit-config.yaml` templates:

| Profile | Hooks Included | Best For |
|---------|---------------|----------|
| `minimal` | Whitespace, EOF, YAML/JSON check | Any repo |
| `security` | detect-secrets, gitleaks, large file check | Security-focused |
| `python` | ruff, mypy, detect-secrets + minimal | Python projects |
| `javascript` | eslint, prettier, detect-secrets + minimal | JS/TS projects |
| `full` | All of the above + conventional commits | Full stack |

### Custom Config

Edit `.pre-commit-config.yaml` directly:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=500']
      - id: detect-private-key

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks
```

### Environment Variables

```bash
# Skip hooks temporarily
export SKIP=detect-secrets,gitleaks

# Skip all hooks for one commit
git commit --no-verify -m "emergency fix"
```

## Advanced Usage

### CI Integration

Add to GitHub Actions:

```yaml
# .github/workflows/pre-commit.yml
name: pre-commit
on: [push, pull_request]
jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
      - uses: pre-commit/action@v3.0.1
```

### Baseline Secrets (Ignore Existing)

```bash
# Create baseline of existing secrets (won't flag these again)
cd /path/to/repo
detect-secrets scan > .secrets.baseline
git add .secrets.baseline
```

### Multi-Repo Setup

```bash
# Initialize hooks in all repos under a directory
for repo in /path/to/repos/*/; do
  if [ -d "$repo/.git" ]; then
    bash scripts/init.sh "$repo" --profile security
    echo "✅ Initialized: $repo"
  fi
done
```

### Commit Message Enforcement

The `full` profile includes conventional commit checks:

```
# Valid:
feat: add user authentication
fix(api): handle null response
docs: update README

# Invalid (will be rejected):
updated stuff
fixed bug
```

## Troubleshooting

### Issue: "pre-commit: command not found"

```bash
# Re-run install
bash scripts/install.sh

# Or install manually
pip install pre-commit
# or
pipx install pre-commit
```

### Issue: Hook fails on first run

```bash
# Clear hook cache and retry
pre-commit clean
pre-commit install --install-hooks
```

### Issue: Hooks too slow

```bash
# Run only on staged files (default behavior on commit)
# For manual runs, specify files:
pre-commit run --files src/*.py
```

### Issue: Want to skip a hook once

```bash
SKIP=detect-secrets git commit -m "add test fixtures with fake keys"
```

## Dependencies

- `git` (2.0+)
- `python3` (3.8+)
- `pip` or `pipx`
- Internet access (to download hook repos on first run)
