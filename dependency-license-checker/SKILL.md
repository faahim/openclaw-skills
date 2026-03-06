---
name: dependency-license-checker
description: >-
  Scan project dependencies for license compliance. Detect copyleft, unknown, and risky licenses across Node.js, Python, Go, and Rust projects.
categories: [dev-tools, security]
dependencies: [bash, node, python3]
---

# Dependency License Checker

## What This Does

Scans your project's dependencies and produces a license compliance report. Flags copyleft licenses (GPL, AGPL), unknown/missing licenses, and generates CSV/JSON/Markdown reports. Supports Node.js (npm/yarn/pnpm), Python (pip), Go, and Rust (cargo) projects.

**Example:** "Scan my Node.js project, flag any GPL dependencies, output a compliance report."

## Quick Start (5 minutes)

### 1. Install Scanners

```bash
# Node.js projects (install globally)
npm install -g license-checker

# Python projects
pip install pip-licenses

# Go projects (uses built-in `go-licenses` or parses go.sum)
go install github.com/google/go-licenses@latest 2>/dev/null || true

# Rust projects
cargo install cargo-license 2>/dev/null || true
```

### 2. Scan a Project

```bash
# Auto-detect project type and scan
bash scripts/scan.sh /path/to/your/project

# Output:
# 🔍 Scanning /path/to/your/project...
# 📦 Detected: Node.js (package.json)
# ✅ 142 dependencies scanned
# ⚠️  3 copyleft licenses found
# ❌ 1 unknown license
# 📄 Report: /path/to/your/project/license-report.md
```

### 3. Scan with Policy

```bash
# Fail on copyleft licenses (for CI/CD)
bash scripts/scan.sh /path/to/project --policy strict

# Allow specific licenses only
bash scripts/scan.sh /path/to/project --allow "MIT,Apache-2.0,BSD-2-Clause,BSD-3-Clause,ISC"

# Output JSON for programmatic use
bash scripts/scan.sh /path/to/project --format json
```

## Core Workflows

### Workflow 1: Quick Compliance Check

**Use case:** Check if your project has any license issues before release.

```bash
bash scripts/scan.sh . --policy strict
```

**Output:**
```
🔍 Scanning current directory...
📦 Detected: Node.js (package.json)

LICENSE COMPLIANCE REPORT
========================
Total dependencies: 142
✅ Permissive (MIT, Apache-2.0, BSD, ISC): 138
⚠️  Copyleft (GPL, LGPL, MPL): 3
  - node-sass@4.14.1 — GPL-3.0
  - readline-sync@1.4.10 — GPL-3.0
  - colors@1.4.0 — GPL-3.0 (indirect via mocha)
❌ Unknown/Missing: 1
  - custom-lib@0.1.0 — UNLICENSED

Policy: STRICT — ❌ FAILED (copyleft detected)
```

### Workflow 2: Multi-Project Scan

**Use case:** Scan all projects in a directory.

```bash
bash scripts/scan.sh ~/projects --recursive
```

**Output:**
```
📂 Scanning 5 projects in ~/projects...

1/5 web-app (Node.js): ✅ Clean — 89 deps, all permissive
2/5 api-server (Python): ⚠️ 1 copyleft — chardet@5.1.0 (LGPL-2.1)
3/5 cli-tool (Rust): ✅ Clean — 34 deps, all permissive
4/5 data-pipeline (Go): ✅ Clean — 21 deps, all permissive
5/5 mobile-app (Node.js): ❌ 2 unknown licenses

Summary: 3 clean, 1 warning, 1 failure
Full report: ~/projects/license-report-all.md
```

### Workflow 3: CI/CD Integration

**Use case:** Add license checks to your CI pipeline.

```bash
# In your CI script (GitHub Actions, etc.)
bash scripts/scan.sh . --policy strict --format json --output license-check.json

# Exit code:
# 0 = all clear
# 1 = copyleft or unknown licenses found
# 2 = scan error
```

### Workflow 4: Generate NOTICE/THIRD-PARTY File

**Use case:** Generate a legal NOTICE file for distribution.

```bash
bash scripts/scan.sh . --notice > THIRD-PARTY-NOTICES.md
```

**Output file:**
```markdown
# Third-Party Notices

This project uses the following open-source packages:

## express (4.18.2) — MIT
Copyright (c) 2009-2014 TJ Holowaychuk
https://github.com/expressjs/express

## lodash (4.17.21) — MIT
Copyright JS Foundation and other contributors
https://github.com/lodash/lodash

...
```

## Configuration

### License Categories

The scanner classifies licenses into risk tiers:

| Tier | Licenses | Risk |
|------|----------|------|
| **Permissive** | MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, Unlicense, 0BSD, CC0-1.0 | ✅ Safe |
| **Weak Copyleft** | LGPL-2.1, LGPL-3.0, MPL-2.0, EPL-1.0, EPL-2.0 | ⚠️ Review |
| **Strong Copyleft** | GPL-2.0, GPL-3.0, AGPL-3.0, EUPL-1.1 | ❌ Risky |
| **Unknown** | UNLICENSED, missing, custom | ❌ Investigate |

### Policy Modes

```bash
# Permissive: warn on copyleft, fail on unknown
bash scripts/scan.sh . --policy permissive

# Strict: fail on any copyleft or unknown
bash scripts/scan.sh . --policy strict

# Custom: specify allowed licenses
bash scripts/scan.sh . --allow "MIT,Apache-2.0,ISC,BSD-3-Clause"
```

### Output Formats

```bash
--format markdown   # Human-readable (default)
--format json       # Machine-readable
--format csv        # Spreadsheet-friendly
--format notice     # THIRD-PARTY-NOTICES format
```

## Advanced Usage

### Exclude Dev Dependencies

```bash
bash scripts/scan.sh . --production
```

### Ignore Specific Packages

```bash
bash scripts/scan.sh . --ignore "internal-lib,test-utils"
```

### Compare Against Baseline

```bash
# Save current state
bash scripts/scan.sh . --format json --output baseline.json

# Later, check for new license issues
bash scripts/scan.sh . --baseline baseline.json
```

## Troubleshooting

### Issue: "license-checker not found"

**Fix:**
```bash
npm install -g license-checker
```

### Issue: "pip-licenses not found"

**Fix:**
```bash
pip install pip-licenses
# Or in a virtualenv:
python3 -m pip install pip-licenses
```

### Issue: Missing licenses in monorepo

**Fix:** Use `--recursive` to scan all workspaces:
```bash
bash scripts/scan.sh . --recursive
```

### Issue: False positives on custom licenses

**Fix:** Add to ignore list or manually verify:
```bash
bash scripts/scan.sh . --ignore "my-internal-pkg"
```

## Dependencies

- `bash` (4.0+)
- `node` + `npm` (for JS scanning — `license-checker`)
- `python3` + `pip` (for Python scanning — `pip-licenses`)
- Optional: `go` (for Go scanning)
- Optional: `cargo` (for Rust scanning)
- `jq` (for JSON output processing)
