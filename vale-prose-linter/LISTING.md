# Listing Copy: Vale Prose Linter

## Metadata
- **Type:** Skill
- **Name:** vale-prose-linter
- **Display Name:** Vale Prose Linter
- **Categories:** [writing, dev-tools]
- **Icon:** ✍️
- **Dependencies:** [bash, curl, unzip]

## Tagline

Lint your prose like code — catch style issues, jargon, and bad writing habits automatically

## Description

Writing clear documentation and content is hard. Style guides exist, but nobody checks them manually. Your README has passive voice, your docs use "utilize" instead of "use", and your job postings have exclusionary language — but you'd never know without a linter.

Vale Prose Linter installs [Vale](https://vale.sh), the syntax-aware prose linter used by GitHub, Spotify, and Linode. It configures five style packs (Google, Microsoft, write-good, proselint, Joblint) and gives your agent the power to lint any markdown, text, or HTML file from the terminal. No SaaS, no subscriptions — just fast, local prose checking.

**What it does:**
- ✍️ Lint markdown, text, HTML, and reStructuredText files
- 📏 Enforce Google, Microsoft, or custom style guides
- 🔍 Catch passive voice, weasel words, jargon, and clichés
- 🚫 Flag exclusionary or biased language (Joblint)
- 📊 Generate readability reports with quality scores
- 🪝 Git pre-commit hook — lint before every commit
- 👁️ Watch mode — auto-lint on file save
- 🔧 Fully configurable — enable/disable rules per project
- 📤 JSON output for CI/CD integration
- ⚡ Fast — lints thousands of files in seconds

Perfect for developers writing docs, content creators maintaining style consistency, and teams enforcing writing standards across repositories.

## Quick Start Preview

```bash
# Install Vale + style guides
bash scripts/install.sh && bash scripts/setup-styles.sh

# Lint a file
vale README.md
# 3:12 warning 'Utilize' is complex. Use 'use'. Google.WordList
# 5:1  warning 'There are' is a weasel phrase.  write-good.Weasel
```

## Core Capabilities

1. One-command install — downloads Vale binary for Linux/macOS (x64/ARM)
2. Five style packs — Google, Microsoft, write-good, proselint, Joblint
3. Single file or entire directory linting
4. Per-project configuration via `.vale.ini`
5. Custom rules in simple YAML format
6. Git pre-commit hook for automated checks
7. Readability report with quality scoring
8. Watch mode for real-time feedback
9. JSON output for CI/CD pipelines
10. GitHub Actions integration template included
