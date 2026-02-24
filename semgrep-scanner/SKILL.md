---
name: semgrep-scanner
description: >-
  Run static analysis security scans on codebases using Semgrep — find vulnerabilities, bugs, and anti-patterns automatically.
categories: [security, dev-tools]
dependencies: [python3, pip]
---

# Semgrep Code Scanner

## What This Does

Scans your codebase for security vulnerabilities, bugs, and anti-patterns using Semgrep — the open-source static analysis engine used by Dropbox, Figma, and Snowflake. Supports 30+ languages including Python, JavaScript, TypeScript, Go, Java, Ruby, and more.

**Example:** "Scan my Node.js project for SQL injection, XSS, and hardcoded secrets — get a prioritized report in 2 minutes."

## Quick Start (5 minutes)

### 1. Install Semgrep

```bash
bash scripts/install.sh
```

### 2. Run Your First Scan

```bash
# Scan current directory with recommended rules
bash scripts/scan.sh --path /path/to/your/project

# Output:
# 🔍 Scanning /path/to/your/project...
# ┌─────────────────────────────────────────────────┐
# │ Semgrep Scan Results                            │
# │ Files scanned: 142                              │
# │ Findings: 7 (3 High, 2 Medium, 2 Low)          │
# └─────────────────────────────────────────────────┘
# 
# 🔴 HIGH: Hardcoded secret detected
#    File: src/config.js:14
#    Rule: generic.secrets.security.detected-generic-secret
#    Fix: Use environment variables instead of hardcoded values
# ...
```

### 3. Scan with Specific Rulesets

```bash
# Security-focused scan
bash scripts/scan.sh --path ./myapp --ruleset security

# OWASP Top 10
bash scripts/scan.sh --path ./myapp --ruleset owasp

# Language-specific best practices
bash scripts/scan.sh --path ./myapp --ruleset python
```

## Core Workflows

### Workflow 1: Full Security Audit

**Use case:** Run a comprehensive security scan before deployment

```bash
bash scripts/scan.sh \
  --path /path/to/project \
  --ruleset security \
  --output report.json \
  --severity HIGH,MEDIUM
```

**Output (report.json):**
```json
{
  "scan_date": "2026-02-24T05:53:00Z",
  "project": "/path/to/project",
  "summary": {
    "files_scanned": 142,
    "total_findings": 7,
    "high": 3,
    "medium": 2,
    "low": 2
  },
  "findings": [
    {
      "severity": "HIGH",
      "rule": "javascript.express.security.audit.xss.mustache-escape",
      "message": "Unescaped template variable may lead to XSS",
      "file": "src/views/profile.js",
      "line": 42,
      "fix": "Use {{{variable}}} or sanitize input before rendering"
    }
  ]
}
```

### Workflow 2: Pre-Commit Scan (Changed Files Only)

**Use case:** Quick scan of staged files before committing

```bash
bash scripts/scan.sh --path . --git-diff
```

### Workflow 3: CI/CD Integration

**Use case:** Add to your build pipeline, fail on high-severity findings

```bash
bash scripts/scan.sh \
  --path . \
  --ruleset security \
  --severity HIGH \
  --fail-on-findings
# Exit code 1 if any HIGH findings found
```

### Workflow 4: Secrets Detection

**Use case:** Find hardcoded API keys, passwords, tokens

```bash
bash scripts/scan.sh --path . --ruleset secrets
```

### Workflow 5: Custom Rules

**Use case:** Scan with your own Semgrep rules

```bash
bash scripts/scan.sh --path . --rules-file ./my-rules.yaml
```

## Available Rulesets

| Ruleset | What It Checks | Languages |
|---------|---------------|-----------|
| `security` | OWASP vulnerabilities, injection, XSS, CSRF | All |
| `owasp` | OWASP Top 10 specifically | All |
| `secrets` | Hardcoded API keys, passwords, tokens | All |
| `python` | Python best practices + security | Python |
| `javascript` | JS/TS best practices + security | JS/TS |
| `go` | Go best practices + security | Go |
| `java` | Java best practices + security | Java |
| `ruby` | Ruby best practices + security | Ruby |
| `docker` | Dockerfile best practices | Docker |
| `terraform` | IaC security misconfigurations | Terraform |
| `supply-chain` | Dependency confusion, typosquatting | All |
| `all` | Everything (slow but thorough) | All |

## Configuration

### Environment Variables

```bash
# Optional: Semgrep App token for team features (free tier available)
export SEMGREP_APP_TOKEN="<your-token>"

# Optional: Custom rules directory
export SEMGREP_RULES_DIR="/path/to/rules"
```

### Ignore Patterns

Create `.semgrepignore` in your project root:

```
# Ignore test files
tests/
*_test.go
*.test.js

# Ignore vendored code
vendor/
node_modules/
dist/
build/
```

## Advanced Usage

### Schedule Regular Scans

```bash
# Add to crontab — scan daily at midnight
0 0 * * * cd /path/to/project && bash /path/to/scripts/scan.sh --path . --ruleset security --output /var/log/semgrep-$(date +\%Y\%m\%d).json 2>&1
```

### Compare Scans (Diff Mode)

```bash
# Only show NEW findings since last scan
bash scripts/scan.sh --path . --baseline report-yesterday.json
```

### Output Formats

```bash
# JSON (for automation)
bash scripts/scan.sh --path . --format json --output results.json

# SARIF (for GitHub Security tab)
bash scripts/scan.sh --path . --format sarif --output results.sarif

# Text (human-readable, default)
bash scripts/scan.sh --path . --format text

# Markdown (for reports/PRs)
bash scripts/scan.sh --path . --format markdown --output SECURITY-REPORT.md
```

## Troubleshooting

### Issue: "semgrep: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
pip3 install semgrep
```

### Issue: Scan is very slow

**Fix:** Use `.semgrepignore` to exclude `node_modules/`, `vendor/`, `dist/`, etc. Or use `--ruleset security` instead of `--ruleset all`.

### Issue: Too many false positives

**Fix:** Use `--severity HIGH,MEDIUM` to filter low-confidence findings. Or add `# nosemgrep: <rule-id>` inline comments to suppress specific findings.

### Issue: Python version errors

**Fix:** Semgrep requires Python 3.8+. Check: `python3 --version`

## Key Principles

1. **Fast scans** — Security ruleset completes in <2 min for most projects
2. **Prioritized output** — HIGH/MEDIUM/LOW severity with fix suggestions
3. **Language-aware** — Understands code semantics, not just regex
4. **Low false positives** — Semgrep's pattern-matching is precise
5. **Offline capable** — All scanning runs locally, no data leaves your machine

## Dependencies

- `python3` (3.8+)
- `pip3`
- `semgrep` (installed by scripts/install.sh)
- `git` (optional, for diff mode)
- `jq` (optional, for JSON output processing)
