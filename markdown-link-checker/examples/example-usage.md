# Example Usage

## Basic: Check a Single File

```bash
bash scripts/check-links.sh README.md
```

## Scan Entire Documentation

```bash
bash scripts/check-links.sh docs/
```

## CI Pipeline (GitHub Actions)

```yaml
- name: Check links
  run: bash scripts/check-links.sh --exit-code --json docs/ > link-report.json
```

## Weekly Cron Check (OpenClaw)

```bash
bash scripts/check-links.sh --json --cache /tmp/links.cache /path/to/repo > /tmp/report.json
BROKEN=$(jq '.summary.broken' /tmp/report.json)
[ "$BROKEN" -gt 0 ] && echo "⚠️ $BROKEN broken links found"
```

## Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
git diff --cached --name-only '*.md' | xargs bash scripts/check-links.sh --exit-code
```
