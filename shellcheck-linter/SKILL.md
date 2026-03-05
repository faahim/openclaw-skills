---
name: shellcheck-linter
description: >-
  Install ShellCheck and lint bash/sh scripts — catch bugs, security issues, and bad practices automatically.
categories: [dev-tools, automation]
dependencies: [bash, curl]
---

# ShellCheck Linter

## What This Does

Installs [ShellCheck](https://github.com/koalaman/shellcheck) (the industry-standard shell script analyzer) and provides workflows for linting individual scripts, batch-checking entire directories, generating CI-ready reports, and auto-fixing common issues. Catches bugs, security vulnerabilities, and portability problems before they hit production.

**Example:** "Lint all .sh files in my project, output a report with severity levels, and show me how to fix each issue."

## Quick Start (2 minutes)

### 1. Install ShellCheck

```bash
bash scripts/install.sh
```

### 2. Lint a Script

```bash
bash scripts/lint.sh /path/to/script.sh
```

### 3. Lint an Entire Directory

```bash
bash scripts/lint.sh --dir /path/to/project --recursive
```

## Core Workflows

### Workflow 1: Lint a Single Script

```bash
bash scripts/lint.sh /path/to/script.sh
```

**Output:**
```
📋 ShellCheck Report: script.sh
────────────────────────────────────
Line 5: SC2086 (info): Double quote to prevent globbing and word splitting.
Line 12: SC2034 (warning): VAR appears unused. Verify use (or export if externally used).
Line 18: SC2155 (warning): Declare and assign separately to avoid masking return values.

Summary: 0 errors, 2 warnings, 1 info — 3 issues total
```

### Workflow 2: Batch Lint a Directory

```bash
bash scripts/lint.sh --dir ./scripts --recursive
```

**Output:**
```
📋 ShellCheck Batch Report
────────────────────────────────────
scripts/deploy.sh ........... 2 errors, 1 warning
scripts/backup.sh ........... 0 errors, 0 warnings ✅
scripts/setup.sh ............ 0 errors, 3 warnings
scripts/utils/helpers.sh .... 1 error, 0 warnings

Total: 4 files | 3 errors | 4 warnings | 1 info
```

### Workflow 3: Severity Filter

```bash
# Only show errors (skip warnings/info)
bash scripts/lint.sh --dir ./scripts --severity error

# Show warnings and above
bash scripts/lint.sh --dir ./scripts --severity warning
```

### Workflow 4: JSON Report for CI

```bash
bash scripts/lint.sh --dir ./scripts --format json > shellcheck-report.json
```

### Workflow 5: Check Specific Shell Dialect

```bash
# Force POSIX sh checking
bash scripts/lint.sh --shell sh /path/to/script.sh

# Force bash checking
bash scripts/lint.sh --shell bash /path/to/script.sh
```

### Workflow 6: Exclude Specific Rules

```bash
# Ignore SC2086 (double quoting) and SC2034 (unused vars)
bash scripts/lint.sh --exclude SC2086,SC2034 --dir ./scripts
```

### Workflow 7: Git Pre-Commit Hook

```bash
bash scripts/setup-hook.sh /path/to/repo
```

This installs a git pre-commit hook that runs ShellCheck on all staged .sh files and blocks commits with errors.

### Workflow 8: Watch Mode (Continuous Linting)

```bash
bash scripts/lint.sh --watch /path/to/script.sh
```

Re-lints automatically when the file changes (requires `inotifywait` or `fswatch`).

## Configuration

### Inline Directives

Add to the top of any script to configure ShellCheck per-file:

```bash
#!/bin/bash
# shellcheck disable=SC2086,SC2034
# shellcheck shell=bash
```

### .shellcheckrc (Project Config)

Create `.shellcheckrc` in your project root:

```
# Disable specific rules project-wide
disable=SC2086,SC2034

# Set default shell
shell=bash

# Set severity
severity=warning
```

## Troubleshooting

### Issue: "shellcheck: command not found"

Run `bash scripts/install.sh` — it auto-detects your OS and installs the correct binary.

### Issue: "SC1091: Not following sourced file"

ShellCheck can't follow `source` / `.` includes. Either:
1. Add `# shellcheck source=path/to/sourced.sh` before the source line
2. Add `# shellcheck disable=SC1091` to suppress

### Issue: Too many warnings on legacy scripts

Use severity filtering: `--severity error` to focus on actual bugs first.

## Dependencies

- `bash` (4.0+)
- `curl` or `wget` (for installation)
- `shellcheck` (installed by `scripts/install.sh`)
- Optional: `inotifywait` / `fswatch` (for watch mode)
- Optional: `jq` (for JSON report formatting)
