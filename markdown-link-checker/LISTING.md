# Listing Copy: Markdown Link Checker

## Metadata
- **Type:** Skill
- **Name:** markdown-link-checker
- **Display Name:** Markdown Link Checker
- **Categories:** [dev-tools, automation]
- **Icon:** 🔗
- **Dependencies:** [bash, curl, grep]

## Tagline

Scan markdown files for broken links — catch dead URLs before your users do.

## Description

Dead links in your docs make you look sloppy. By the time a user reports a broken link in your README, you've already lost credibility. You need automated link checking.

Markdown Link Checker scans your `.md` files (or entire directories), extracts every URL, and checks each one for broken links, redirects, and timeouts. Get a clear report showing exactly what's broken and where — no external services, no monthly fees.

**What it does:**
- 🔗 Extract and check every URL in markdown files
- ⚡ Parallel checking — scan 100+ links in seconds
- 📊 Clear reports with broken, redirect, and timeout status
- 🔄 Smart caching — skip recently-checked URLs
- 🚀 CI-friendly — exit codes and JSON output
- 🛡️ Configurable timeouts, user agents, and exclude patterns
- 📁 Scan single files or entire directories recursively

Perfect for developers, documentation maintainers, and open-source authors who want their links to always work.

## Quick Start Preview

```bash
# Check a README
bash scripts/check-links.sh README.md

# Scan all docs
bash scripts/check-links.sh --json docs/
```

## Core Capabilities

1. URL extraction — Finds all markdown links and bare URLs
2. HTTP status checking — Validates every link with real requests
3. Parallel scanning — Check multiple URLs simultaneously
4. Result caching — Avoid re-checking URLs within 1 hour
5. JSON output — Machine-readable reports for CI/CD
6. Exit codes — Fail builds on broken links
7. Exclude patterns — Skip localhost, example.com, etc.
8. Redirect detection — Catch 301/302 chains
9. Timeout handling — Configurable per-request timeouts
10. Recursive scanning — Process entire directory trees
