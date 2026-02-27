---
name: vale-prose-linter
description: >-
  Install and configure Vale prose linter to enforce consistent, high-quality writing across docs, blogs, and READMEs.
categories: [writing, dev-tools]
dependencies: [bash, curl, unzip]
---

# Vale Prose Linter

## What This Does

Installs [Vale](https://vale.sh), the syntax-aware prose linter, and configures it with popular style guides (Google, Microsoft, write-good, Joblint, proselint). Lint markdown, text, HTML, and reStructuredText files for grammar, style, and readability issues — from your terminal or CI pipeline.

**Example:** "Lint all docs in a folder, enforce Google developer style, catch passive voice, weasel words, and jargon."

## Quick Start (5 minutes)

### 1. Install Vale

```bash
bash scripts/install.sh
```

This detects your OS/arch, downloads the latest Vale binary, and installs it to `/usr/local/bin/vale` (or `~/.local/bin/vale` if no sudo).

### 2. Set Up Style Guides

```bash
bash scripts/setup-styles.sh
```

Downloads and configures these style packs:
- **Google** — Google developer documentation style guide
- **Microsoft** — Microsoft Writing Style Guide
- **write-good** — Checks for passive voice, weasel words, clichés
- **proselint** — Catches common writing pitfalls
- **Joblint** — Flags biased/exclusionary language

### 3. Lint Your First File

```bash
vale README.md
```

**Output:**
```
 README.md
 3:12  warning  'Utilize' is unnecessarily       Google.WordList
                complex. Use 'use' instead.
 5:1   warning  'There are' is a weasel phrase.   write-good.Weasel
 8:22  error    'He/she' is exclusionary.          Joblint.TechTerms
                Consider 'they' instead.

✖ 2 warnings and 1 error in 1 file.
```

## Core Workflows

### Workflow 1: Lint a Single File

```bash
vale README.md
```

### Workflow 2: Lint an Entire Directory

```bash
vale docs/
```

### Workflow 3: Lint with Specific Style

```bash
# Only Google style rules
vale --config=<(echo -e 'StylesPath = ~/.local/share/vale/styles\nMinAlertLevel = suggestion\n[*.md]\nBasedOnStyles = Google') README.md
```

### Workflow 4: Check Only Errors (Skip Warnings)

```bash
vale --minAlertLevel=error docs/
```

### Workflow 5: Output as JSON (for CI/automation)

```bash
vale --output=JSON docs/ | jq '.[] | {file: .Path, alerts: [.Alerts[] | {line: .Line, message: .Message, severity: .Severity}]}'
```

### Workflow 6: Lint Specific File Types

```bash
# Only markdown files
vale --glob='*.md' .

# Markdown and HTML
vale --glob='*.{md,html}' .
```

### Workflow 7: Add to Git Pre-commit Hook

```bash
bash scripts/setup-precommit.sh
```

Installs a git pre-commit hook that lints changed `.md` files before each commit.

### Workflow 8: Generate Readability Report

```bash
bash scripts/readability-report.sh docs/
```

Runs Vale + word count analysis, outputs a summary report with readability scores per file.

## Configuration

### Config File (.vale.ini)

The setup script creates `~/.vale.ini`:

```ini
# Vale configuration
StylesPath = ~/.local/share/vale/styles

MinAlertLevel = suggestion

# File type associations
[*.md]
BasedOnStyles = Google, write-good, proselint

[*.txt]
BasedOnStyles = write-good, proselint

[*.html]
BasedOnStyles = Google, write-good
```

### Per-Project Configuration

Create `.vale.ini` in your project root to override global config:

```ini
StylesPath = .github/styles
MinAlertLevel = warning

[*.md]
BasedOnStyles = Google, write-good
# Disable specific rules
Google.Passive = NO
write-good.TooWordy = suggestion
```

### Custom Rules

Create custom Vale rules in YAML:

```yaml
# ~/.local/share/vale/styles/Custom/Acronyms.yml
extends: existence
message: "Define '%s' on first use."
level: warning
tokens:
  - API
  - CLI
  - SDK
  - UI
  - UX
```

## Troubleshooting

### Issue: "vale: command not found"

```bash
# Check if installed
which vale || echo "Not installed"

# Re-run installer
bash scripts/install.sh

# Or add to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: "No styles found"

```bash
# Re-download styles
bash scripts/setup-styles.sh

# Verify styles exist
ls ~/.local/share/vale/styles/
```

### Issue: Too many false positives

Edit `~/.vale.ini` to disable noisy rules:

```ini
[*.md]
BasedOnStyles = Google, write-good
Google.Passive = NO           # Disable passive voice check
write-good.Weasel = NO        # Disable weasel word check
write-good.TooWordy = suggestion  # Downgrade to suggestion
```

### Issue: Vale doesn't recognize file type

```bash
# Specify format explicitly
vale --ext=.md myfile.txt
```

## Advanced Usage

### CI Integration (GitHub Actions)

```yaml
# .github/workflows/prose-lint.yml
name: Prose Lint
on: [pull_request]
jobs:
  vale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: errata-ai/vale-action@v2
        with:
          files: docs/
```

### Watch Mode (lint on save)

```bash
# Using inotifywait (Linux)
bash scripts/watch.sh docs/
```

### Compare Before/After

```bash
# Lint count before editing
vale --output=JSON docs/ | jq '[.[].Alerts | length] | add'

# ... edit files ...

# Lint count after
vale --output=JSON docs/ | jq '[.[].Alerts | length] | add'
```

## Dependencies

- `bash` (4.0+)
- `curl` (downloading Vale + styles)
- `unzip` (extracting releases)
- Optional: `jq` (JSON output parsing)
- Optional: `inotifywait` (watch mode, from `inotify-tools`)
