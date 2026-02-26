# Listing Copy: Changelog Generator

## Metadata
- **Type:** Skill
- **Name:** changelog-generator
- **Display Name:** Changelog Generator
- **Categories:** [dev-tools, writing]
- **Price:** $8
- **Dependencies:** [git, bash]

## Tagline

Auto-generate changelogs from git commits — Never write release notes manually again

## Description

Writing changelogs by hand is tedious and error-prone. You forget commits, miss breaking changes, and the formatting is never consistent. By the time you publish a release, the changelog is an afterthought.

Changelog Generator parses your git history using the Conventional Commits standard, groups changes by type (features, fixes, performance, etc.), and generates clean, structured markdown. It detects breaking changes, links issue references, and supports tag-based versioning — all in one command.

**What it does:**
- 📋 Parse conventional commits (feat, fix, perf, refactor, etc.)
- 🏷️ Group changes by git tags/versions automatically
- ⚠️ Detect and highlight breaking changes
- 🔗 Auto-link issue and PR references to GitHub/GitLab
- 📁 Full repo changelog or unreleased-only mode
- 🔧 Configurable: custom types, scopes, output formats
- 🤖 CI/CD ready — pipe to GitHub Releases, GitLab, etc.
- 📂 Monorepo support — filter by path or scope

Perfect for developers and teams who use conventional commits and want automated, consistent changelogs without external services or complex toolchains.

## Quick Start Preview

```bash
# Generate full changelog
bash scripts/changelog.sh --repo /path/to/project

# Only unreleased changes (great for release notes)
bash scripts/changelog.sh --unreleased --stdout | gh release create v1.2.0 --notes-file -
```

## Core Capabilities

1. Conventional commit parsing — Understands feat, fix, perf, docs, chore, and custom types
2. Tag-based versioning — Automatically groups commits between git tags
3. Breaking change detection — Flags BREAKING CHANGE footers and ! suffix
4. Issue/PR linking — Auto-links #123 references to your remote
5. Unreleased mode — Generate notes for changes since last tag
6. Prepend mode — Add new release to existing CHANGELOG.md
7. Author attribution — Optionally include commit authors
8. Commit hash links — Link to specific commits on GitHub/GitLab
9. Path filtering — Monorepo support, changelog per package
10. Scope filtering — Only include specific conventional commit scopes
11. CI/CD integration — Pipe output to gh release, GitLab API, etc.
12. Zero dependencies — Just bash + git, nothing to install

## Dependencies
- `bash` (4.0+)
- `git` (2.0+)

## Installation Time
**1 minute** — Copy script, run in any git repo

## Pricing Justification

**Why $8:**
- LarryBrain utility tier: $5-15
- Saves 15-30 min per release (manual changelog writing)
- Alternatives: conventional-changelog (npm, complex setup), git-cliff (Rust, requires install)
- Our advantage: Single bash script, no dependencies beyond git, OpenClaw-native
