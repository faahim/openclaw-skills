# Listing Copy: License Scanner

## Metadata
- **Type:** Skill
- **Name:** license-scanner
- **Display Name:** License Scanner
- **Categories:** [dev-tools, security]
- **Price:** $12
- **Dependencies:** [bash, jq, node, python3]

## Tagline

Scan dependencies for license violations — Flag GPL, generate SBOM, enforce compliance policies

## Description

Shipping code with the wrong license dependency can cost you. GPL in a commercial project? That's a legal headache waiting to happen. Most developers don't check until it's too late.

License Scanner automatically scans your Node.js, Python, and Rust projects for license compliance issues. It detects copyleft licenses in commercial projects, generates CycloneDX SBOM reports, and can gate your CI/CD pipeline to block violations before they ship.

**What it does:**
- 🔍 Auto-detect project type and scan all dependencies
- ❌ Flag GPL/AGPL violations in commercial projects
- ⚠️ Highlight LGPL/MPL packages needing review
- 📊 Generate reports in JSON, CSV, Markdown, or SBOM format
- 🚫 Strict mode for CI/CD gates (exit code 1 on violations)
- 📋 Custom policy files for team-wide enforcement
- 🐍 Multi-language: Node.js, Python, Rust

Perfect for developers, open-source maintainers, and teams that need license compliance without enterprise tooling prices.

## Quick Start Preview

```bash
bash scripts/scan.sh --dir /path/to/project --policy commercial

# ✅ 186 dependencies scanned
# ❌ VIOLATIONS: 3 packages with copyleft licenses
#   GPL-3.0  │ node-sass@4.14.1
#   AGPL-3.0 │ mongodb-client@3.2.0
```

## Core Capabilities

1. Auto-detect project type — Node.js, Python, Rust supported
2. Built-in policies — Commercial, permissive, copyleft presets
3. Custom policy files — Define allow/deny/review lists per project
4. SBOM generation — CycloneDX 1.4 compatible output
5. CI/CD integration — Strict mode exits non-zero on violations
6. Multi-format reports — Terminal, JSON, CSV, Markdown
7. Production-only mode — Skip dev dependencies for faster scans
8. Deep scan — Check LICENSE files when package metadata is missing
9. Diff mode — Compare scans over time, catch new violations
10. Zero config — Works out of the box with sensible defaults

## Dependencies
- `bash` (4.0+)
- `jq`
- `node` + `npm` (license-checker)
- `python3` + `pip` (pip-licenses, optional)
- `cargo` (cargo-license, optional)

## Installation Time
**5 minutes** — Run install.sh, scan immediately
