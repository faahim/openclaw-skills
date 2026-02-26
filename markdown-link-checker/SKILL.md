---
name: markdown-link-checker
description: >-
  Scan markdown files for broken links — find dead URLs, missing anchors, and redirect chains before your users do.
categories: [dev-tools, automation]
dependencies: [bash, curl, grep]
---

# Markdown Link Checker

## What This Does

Scans markdown files (or entire directories) for URLs, then checks each one for broken links, redirects, and timeouts. Outputs a clear report showing which links are dead, which redirect, and which are fine.

**Example:** "Scan all `.md` files in my repo, find 3 broken links and 2 redirect chains, fix them before pushing."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are almost certainly already installed
which curl grep awk || echo "Install curl, grep, and awk"
```

### 2. Scan a Single File

```bash
bash scripts/check-links.sh README.md
```

### 3. Scan an Entire Directory

```bash
bash scripts/check-links.sh /path/to/docs/
```

### 4. Scan with Options

```bash
# Only check external links (skip relative paths)
bash scripts/check-links.sh --external-only /path/to/docs/

# Set timeout (default 10s)
bash scripts/check-links.sh --timeout 5 README.md

# Output as JSON
bash scripts/check-links.sh --json README.md

# Parallel checks (faster for many links)
bash scripts/check-links.sh --parallel 10 /path/to/docs/

# Exclude patterns
bash scripts/check-links.sh --exclude "localhost,example.com" README.md
```

## Core Workflows

### Workflow 1: Pre-Commit Link Check

**Use case:** Check all markdown links before committing

```bash
# Find all changed markdown files and check them
git diff --name-only --diff-filter=ACMR '*.md' | xargs bash scripts/check-links.sh
```

**Output:**
```
📄 README.md
  ✅ https://github.com/user/repo — 200 OK (85ms)
  ❌ https://old-docs.example.com/guide — 404 Not Found
  🔄 http://example.com/old-page — 301 → https://example.com/new-page
  ⏱️ https://slow-server.example.com — TIMEOUT (10000ms)

📄 docs/setup.md
  ✅ https://nodejs.org — 200 OK (120ms)
  ✅ https://github.com/user/repo/blob/main/config.md — 200 OK (95ms)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Summary: 6 links checked
  ✅ 3 OK
  ❌ 1 Broken
  🔄 1 Redirect
  ⏱️ 1 Timeout
```

### Workflow 2: Full Repo Audit

**Use case:** Audit all markdown files in a project

```bash
bash scripts/check-links.sh --recursive --json /path/to/repo > link-report.json
```

### Workflow 3: CI Integration

**Use case:** Fail CI if broken links found

```bash
bash scripts/check-links.sh --exit-code /path/to/docs/
# Exit code 0 = all links OK
# Exit code 1 = broken links found
```

### Workflow 4: Watch Mode (OpenClaw Cron)

**Use case:** Periodically check docs for link rot

```bash
# Run weekly via cron
bash scripts/check-links.sh --json /path/to/docs/ > /tmp/link-report.json

# Check if any broken
BROKEN=$(jq '[.results[] | select(.status == "broken")] | length' /tmp/link-report.json)
if [ "$BROKEN" -gt 0 ]; then
  echo "⚠️ Found $BROKEN broken links!"
  jq '.results[] | select(.status == "broken")' /tmp/link-report.json
fi
```

## Configuration

### Command-Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--timeout <seconds>` | 10 | HTTP request timeout |
| `--parallel <n>` | 5 | Concurrent checks |
| `--external-only` | off | Skip relative/anchor links |
| `--exclude <patterns>` | none | Comma-separated URL patterns to skip |
| `--json` | off | Output as JSON |
| `--exit-code` | off | Exit 1 if broken links found |
| `--recursive` | auto | Scan directories recursively |
| `--no-redirects` | off | Treat redirects as errors |
| `--cache <file>` | none | Cache results to avoid re-checking |
| `--verbose` | off | Show all links including OK ones |

### Environment Variables

```bash
# Custom user agent (some sites block curl default)
export LINK_CHECKER_UA="Mozilla/5.0 LinkChecker/1.0"

# Skip SSL verification (for self-signed certs)
export LINK_CHECKER_INSECURE=1
```

## Advanced Usage

### Caching Results

```bash
# First run: populates cache
bash scripts/check-links.sh --cache /tmp/link-cache.json docs/

# Second run: skips recently-checked URLs (within 1 hour)
bash scripts/check-links.sh --cache /tmp/link-cache.json docs/
```

### Custom Exclude Patterns

```bash
# Skip localhost, example domains, and archive.org (rate limited)
bash scripts/check-links.sh \
  --exclude "localhost,127.0.0.1,example.com,archive.org" \
  docs/
```

### JSON Output Format

```json
{
  "checked_at": "2026-02-26T18:00:00Z",
  "total_files": 5,
  "total_links": 42,
  "results": [
    {
      "file": "README.md",
      "line": 15,
      "url": "https://example.com/dead-link",
      "status": "broken",
      "http_code": 404,
      "response_ms": 230
    },
    {
      "file": "README.md",
      "line": 22,
      "url": "https://example.com",
      "status": "ok",
      "http_code": 200,
      "response_ms": 85
    }
  ],
  "summary": {
    "ok": 38,
    "broken": 2,
    "redirect": 1,
    "timeout": 1
  }
}
```

## Troubleshooting

### Issue: Too many timeouts

**Fix:** Increase timeout or reduce parallelism:
```bash
bash scripts/check-links.sh --timeout 20 --parallel 2 docs/
```

### Issue: Sites blocking requests

**Fix:** Set a browser-like user agent:
```bash
export LINK_CHECKER_UA="Mozilla/5.0 (compatible; LinkChecker/1.0)"
bash scripts/check-links.sh docs/
```

### Issue: SSL certificate errors

**Fix:** For self-signed certs in dev environments:
```bash
export LINK_CHECKER_INSECURE=1
bash scripts/check-links.sh docs/
```

### Issue: Rate limiting (429 responses)

**Fix:** Reduce parallelism and add delay:
```bash
bash scripts/check-links.sh --parallel 1 docs/
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests)
- `grep` (URL extraction)
- `awk` (text processing)
- Optional: `jq` (JSON output formatting)

## Key Principles

1. **Fast by default** — Parallel checks, smart caching
2. **Zero false positives** — Retries on timeout, follows redirects
3. **CI-friendly** — Exit codes, JSON output, quiet mode
4. **Respectful** — Rate limiting, custom user agent, configurable parallelism
