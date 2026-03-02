---
name: license-scanner
description: >-
  Scan project dependencies for license compliance — flag risky licenses, generate SBOM reports, enforce policies.
categories: [dev-tools, security]
dependencies: [bash, jq, node, python3]
---

# License Scanner

## What This Does

Scans your project's dependencies for license compliance issues. Detects GPL/AGPL in commercial projects, generates Software Bill of Materials (SBOM), and enforces license policies across Node.js, Python, and Rust projects.

**Example:** "Scan my Node.js project, flag any GPL dependencies, output a compliance report."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install the scanner
bash scripts/install.sh

# This installs:
# - license-checker (npm) for Node.js projects
# - pip-licenses (pip) for Python projects  
# - cargo-license (cargo) for Rust projects (if cargo available)
```

### 2. Scan a Project

```bash
# Scan current directory (auto-detects project type)
bash scripts/scan.sh --dir /path/to/project

# Output:
# 📦 Scanning Node.js project...
# ✅ 142 dependencies scanned
# ⚠️  3 copyleft licenses found
# ❌ 1 unknown license
#
# FLAGGED:
#   GPL-3.0    | node-sass@4.14.1
#   AGPL-3.0   | mongodb-client@3.2.0  
#   GPL-2.0    | readline@1.3.0
#   UNKNOWN    | custom-lib@0.1.0
```

### 3. Generate Report

```bash
# Full SBOM report (JSON)
bash scripts/scan.sh --dir /path/to/project --format json --output sbom.json

# CSV export for spreadsheets
bash scripts/scan.sh --dir /path/to/project --format csv --output licenses.csv

# Markdown report for docs/PRs
bash scripts/scan.sh --dir /path/to/project --format markdown --output LICENSE-REPORT.md
```

## Core Workflows

### Workflow 1: Quick Compliance Check

**Use case:** Before shipping, verify no license violations

```bash
bash scripts/scan.sh --dir . --policy commercial
```

**Output:**
```
📦 Scanning Node.js project (package.json found)...
✅ 186 dependencies scanned in 3.2s

LICENSE SUMMARY:
  MIT          │ 142 (76.3%)
  ISC          │  18 (9.7%)
  Apache-2.0   │  14 (7.5%)
  BSD-2-Clause │   8 (4.3%)
  ⚠️  GPL-3.0  │   3 (1.6%)
  ❌ UNKNOWN   │   1 (0.5%)

POLICY: commercial (copyleft = violation)
❌ VIOLATIONS FOUND: 3 packages with copyleft licenses
  1. node-sass@4.14.1 (GPL-3.0) — Consider: dart-sass (MIT)
  2. readline@1.3.0 (GPL-2.0) — Consider: readline-sync (MIT)
  3. chardet@0.7.0 (LGPL-2.1) — Review: may be OK for dynamic linking

🔍 UNKNOWN: 1 package needs manual review
  1. custom-lib@0.1.0 — No license field in package.json
```

### Workflow 2: Full SBOM Generation

**Use case:** Compliance audit, supply chain security

```bash
bash scripts/scan.sh --dir . --format json --output sbom.json --sbom
```

**Generates CycloneDX-compatible SBOM:**
```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "components": [
    {
      "name": "express",
      "version": "4.18.2",
      "licenses": [{"id": "MIT"}],
      "purl": "pkg:npm/express@4.18.2"
    }
  ]
}
```

### Workflow 3: CI/CD Gate

**Use case:** Block PRs with license violations

```bash
# Exit code 1 if violations found (for CI pipelines)
bash scripts/scan.sh --dir . --policy commercial --strict

# In GitHub Actions:
# - name: License Check
#   run: bash scripts/scan.sh --dir . --policy commercial --strict
```

### Workflow 4: Multi-Project Scan

**Use case:** Scan all repos in a directory

```bash
bash scripts/scan.sh --dir /home/projects --recursive --format csv --output all-licenses.csv
```

### Workflow 5: Python Project Scan

```bash
# Scans requirements.txt or pyproject.toml
bash scripts/scan.sh --dir /path/to/python-project --type python
```

**Output:**
```
📦 Scanning Python project (requirements.txt found)...
✅ 47 dependencies scanned

LICENSE SUMMARY:
  MIT          │ 28 (59.6%)
  BSD-3-Clause │ 11 (23.4%)
  Apache-2.0   │  6 (12.8%)
  PSF          │  2 (4.3%)
```

## Configuration

### Policy Files

Create `.license-policy.json` in your project root:

```json
{
  "policy": "commercial",
  "allow": ["MIT", "ISC", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "0BSD", "Unlicense", "CC0-1.0"],
  "deny": ["GPL-2.0", "GPL-3.0", "AGPL-3.0"],
  "review": ["LGPL-2.1", "LGPL-3.0", "MPL-2.0"],
  "ignore_packages": ["my-internal-lib"],
  "fail_on_unknown": true
}
```

### Built-in Policies

- **`commercial`** — Deny all copyleft (GPL, AGPL). Flag LGPL/MPL for review.
- **`permissive`** — Allow everything except AGPL. Flag GPL for review.
- **`copyleft`** — Allow copyleft. Only flag UNKNOWN licenses.
- **`custom`** — Use `.license-policy.json` from project root.

### Environment Variables

```bash
# Override default policy
export LICENSE_POLICY="commercial"

# Skip dev dependencies
export LICENSE_SKIP_DEV=true

# Custom policy file location
export LICENSE_POLICY_FILE="/path/to/.license-policy.json"
```

## Advanced Usage

### Compare Scans Over Time

```bash
# Save baseline
bash scripts/scan.sh --dir . --format json --output baseline.json

# Later, diff against baseline
bash scripts/scan.sh --dir . --diff baseline.json
```

**Output:**
```
CHANGES since baseline (2026-02-15):
  + lodash@4.17.21 (MIT) — NEW
  - moment@2.29.4 (MIT) — REMOVED
  ~ express@4.17.1→4.18.2 (MIT) — UPDATED
  ⚠️ + gpl-lib@1.0.0 (GPL-3.0) — NEW VIOLATION
```

### Suggest Alternatives for Flagged Packages

```bash
bash scripts/scan.sh --dir . --policy commercial --suggest
```

Appends suggestions for each violation:
```
❌ node-sass@4.14.1 (GPL-3.0)
   💡 Alternative: sass@1.57.1 (MIT) — Drop-in replacement
```

### Run as OpenClaw Cron Job

```bash
# Check license compliance daily
# In OpenClaw cron:
# schedule: { kind: "cron", expr: "0 8 * * *" }
# payload: { kind: "agentTurn", message: "Run license scan on /home/projects/my-app using the license-scanner skill. Alert me if any violations found." }
```

## Troubleshooting

### Issue: "license-checker not found"

```bash
# Re-run install
bash scripts/install.sh

# Or install manually
npm install -g license-checker
```

### Issue: Slow scan on large projects

```bash
# Skip dev dependencies (much faster)
bash scripts/scan.sh --dir . --production-only
```

### Issue: Many UNKNOWN licenses

Some packages don't declare licenses in package.json but have LICENSE files:
```bash
# Deep scan — checks LICENSE/COPYING files too
bash scripts/scan.sh --dir . --deep
```

## Output Formats

| Format | Flag | Best For |
|--------|------|----------|
| Terminal | (default) | Quick checks |
| JSON | `--format json` | CI/CD, programmatic use |
| CSV | `--format csv` | Spreadsheets, audits |
| Markdown | `--format markdown` | PRs, documentation |
| SBOM | `--sbom` | Supply chain compliance |

## Dependencies

- `bash` (4.0+)
- `jq` (JSON processing)
- `node` + `npm` (for license-checker)
- `python3` + `pip` (for pip-licenses, optional)
- `cargo` (for cargo-license, optional — Rust projects only)
