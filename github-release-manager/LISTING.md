# Listing Copy: GitHub Release Manager

## Metadata
- **Type:** Skill
- **Name:** github-release-manager
- **Display Name:** GitHub Release Manager
- **Categories:** [dev-tools, automation]
- **Price:** $10
- **Dependencies:** [gh, git, bash]

## Tagline

Automate GitHub releases — changelogs from commits, semantic versioning, asset uploads

## Description

Manually writing release notes is tedious. Clicking through the GitHub UI to create releases, copy-paste commit messages, and upload binaries wastes time every release cycle. If you're doing this more than once a month, you're doing it wrong.

GitHub Release Manager automates the entire release workflow. It reads your commit history (conventional commits), groups changes by type (features, fixes, docs, etc.), bumps the version using semver, creates the GitHub release, and uploads your build artifacts — all in one command.

**What it does:**
- 🚀 Auto-generate changelogs grouped by commit type (feat, fix, docs, etc.)
- 🏷️ Semantic versioning with major/minor/patch bumps
- 📦 Upload binary assets alongside releases
- 📝 Draft and pre-release (alpha/beta/RC) support
- 🔄 Monorepo support with path filtering
- 📋 List, inspect, publish, and delete releases
- 🔐 Optional GPG-signed tags
- ⚡ One command: `bash scripts/release.sh --bump minor`

Perfect for developers and teams who release regularly and want consistent, professional release notes without the manual work.

## Core Capabilities

1. Changelog generation — Groups commits by conventional commit type with emoji headers
2. Semantic versioning — Auto-bumps major, minor, or patch based on your choice
3. Asset uploads — Attach binaries, archives, checksums to releases
4. Draft releases — Create drafts for team review before publishing
5. Pre-releases — Alpha, beta, RC releases with auto-incrementing numbers
6. Monorepo support — Filter commits by path, custom tag prefixes
7. Release management — List, inspect, publish, delete releases
8. GPG signing — Optionally sign release tags
9. CI/CD ready — Drop into GitHub Actions workflows
10. Idempotent — Won't create duplicate releases

## Dependencies
- `gh` CLI (2.0+) — authenticated
- `git` (2.20+)
- `bash` (4.0+)

## Installation Time
**2 minutes** — Copy script, run it
