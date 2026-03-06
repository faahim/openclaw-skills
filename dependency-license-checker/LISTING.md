# Listing Copy: Dependency License Checker

## Metadata
- **Type:** Skill
- **Name:** dependency-license-checker
- **Display Name:** Dependency License Checker
- **Categories:** [dev-tools, security]
- **Icon:** ⚖️
- **Dependencies:** [bash, node, python3, jq]

## Tagline

Scan project dependencies for license compliance — Flag copyleft and risky licenses instantly

## Description

Shipping code with GPL dependencies in a proprietary project? That's a lawsuit waiting to happen. Most developers don't check dependency licenses until legal asks — and by then it's a painful audit.

Dependency License Checker scans your Node.js, Python, Go, and Rust projects in seconds. It classifies every dependency's license (permissive, weak copyleft, strong copyleft, unknown), flags issues, and generates compliance reports. Run it locally or in CI/CD — exit code tells you pass/fail.

**What it does:**
- ⚖️ Scan all dependencies and classify licenses by risk tier
- 🚨 Flag copyleft (GPL, AGPL) and unknown/missing licenses
- 📊 Generate reports in Markdown, JSON, CSV, or NOTICE format
- 🔄 Multi-project scanning (monorepos, recursive)
- 🏗️ CI/CD ready — strict/permissive policy modes with exit codes
- 📋 Generate THIRD-PARTY-NOTICES.md for distribution

Perfect for developers, open-source maintainers, and teams shipping commercial software who need to stay license-compliant without expensive legal tools.

## Quick Start Preview

```bash
# Scan your project
bash scripts/scan.sh /path/to/project --policy strict

# Output:
# 📦 Detected: Node.js (package.json)
# ✅ 142 dependencies — 138 permissive
# ❌ 3 copyleft (GPL-3.0), 1 unknown
# Policy: STRICT — ❌ FAILED
```

## Core Capabilities

1. Multi-language scanning — Node.js, Python, Go, Rust out of the box
2. License classification — Permissive, weak copyleft, strong copyleft, unknown
3. Policy enforcement — Strict, permissive, or custom allowed-list modes
4. CI/CD integration — Exit codes (0=pass, 1=fail) for pipeline gates
5. Multiple output formats — Markdown, JSON, CSV, NOTICE file
6. Recursive scanning — Scan monorepos and multi-project directories
7. Dev dependency filtering — Exclude devDependencies with --production
8. Package ignore list — Skip known-safe internal packages
9. NOTICE file generation — Legal-ready third-party attribution
10. Baseline comparison — Detect new license issues between releases
