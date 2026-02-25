---
name: github-release-manager
description: >-
  Automate GitHub releases — generate changelogs from commits, create tagged releases, upload assets, and manage release lifecycle.
categories: [dev-tools, automation]
dependencies: [gh, git, bash]
---

# GitHub Release Manager

## What This Does

Automates the entire GitHub release workflow: generates changelogs from commits/PRs, creates semantic-versioned releases, uploads binary assets, and manages draft/pre-release states. No more manually writing release notes or clicking through the GitHub UI.

**Example:** "Generate a changelog from the last 50 commits, create v2.3.0 release, upload the build artifacts, and notify the team."

## Quick Start (2 minutes)

### 1. Verify Dependencies

```bash
# gh CLI must be authenticated
gh auth status

# Git repo must exist
git remote -v
```

### 2. Create Your First Release

```bash
# Auto-generate changelog and create release
bash scripts/release.sh --bump minor

# Output:
# 📋 Generating changelog from v2.2.0...
# 📝 Found 12 commits, 4 PRs merged
# 🏷️  Creating release v2.3.0...
# ✅ Release v2.3.0 published: https://github.com/user/repo/releases/tag/v2.3.0
```

### 3. Upload Assets

```bash
# Create release with binary assets
bash scripts/release.sh --bump patch --assets "dist/app-linux,dist/app-darwin,dist/app-windows.exe"
```

## Core Workflows

### Workflow 1: Auto-Changelog Release

**Use case:** Create a release with auto-generated changelog from commits since last tag

```bash
bash scripts/release.sh --bump minor
```

**What happens:**
1. Finds the latest tag (e.g., `v2.2.0`)
2. Collects all commits since that tag
3. Groups by type (feat, fix, chore, docs, etc.) using conventional commits
4. Creates the next version tag (`v2.3.0`)
5. Publishes the release on GitHub

**Changelog output:**
```markdown
## What's Changed

### 🚀 Features
- Add dark mode support (#45)
- Implement API rate limiting (#42)

### 🐛 Bug Fixes
- Fix memory leak in websocket handler (#44)
- Correct timezone offset calculation (#41)

### 📚 Documentation
- Update API reference (#43)

**Full Changelog:** v2.2.0...v2.3.0
```

### Workflow 2: Draft Release

**Use case:** Create a draft for review before publishing

```bash
bash scripts/release.sh --bump major --draft

# Later, publish it:
bash scripts/release.sh --publish v3.0.0
```

### Workflow 3: Pre-release

**Use case:** Create an alpha/beta/RC release

```bash
bash scripts/release.sh --bump minor --prerelease beta
# Creates: v2.3.0-beta.1

bash scripts/release.sh --bump minor --prerelease rc
# Creates: v2.3.0-rc.1
```

### Workflow 4: Upload Assets to Existing Release

```bash
bash scripts/release.sh --upload v2.3.0 --assets "dist/build.tar.gz,dist/checksums.txt"
```

### Workflow 5: List & Manage Releases

```bash
# List recent releases
bash scripts/release.sh --list

# Delete a release
bash scripts/release.sh --delete v2.3.0-beta.1

# Get release info
bash scripts/release.sh --info v2.3.0
```

## Configuration

### Environment Variables

```bash
# Optional: Override repo (defaults to current git remote)
export RELEASE_REPO="owner/repo"

# Optional: GPG sign tags
export RELEASE_SIGN_TAGS="true"

# Optional: Custom changelog template
export RELEASE_TEMPLATE="scripts/changelog-template.md"
```

### Conventional Commit Mapping

The changelog generator recognizes these prefixes:

| Prefix | Category | Emoji |
|--------|----------|-------|
| `feat:` | Features | 🚀 |
| `fix:` | Bug Fixes | 🐛 |
| `docs:` | Documentation | 📚 |
| `perf:` | Performance | ⚡ |
| `refactor:` | Refactoring | ♻️ |
| `test:` | Tests | 🧪 |
| `ci:` | CI/CD | 🔧 |
| `chore:` | Chores | 🏗️ |
| `breaking:` or `!:` | Breaking Changes | ⚠️ |

Commits without a prefix go under "Other Changes".

## Advanced Usage

### Custom Changelog Template

Create `scripts/changelog-template.md`:

```markdown
# Release {{version}}

Released on {{date}}

{{#if breaking}}
## ⚠️ Breaking Changes
{{#each breaking}}
- {{this.message}} ({{this.hash}})
{{/each}}
{{/if}}

{{#if features}}
## 🚀 Features
{{#each features}}
- {{this.message}} ({{this.hash}})
{{/each}}
{{/if}}

{{#if fixes}}
## 🐛 Bug Fixes
{{#each fixes}}
- {{this.message}} ({{this.hash}})
{{/each}}
{{/if}}
```

### CI/CD Integration

```yaml
# .github/workflows/release.yml
name: Release
on:
  workflow_dispatch:
    inputs:
      bump:
        type: choice
        options: [patch, minor, major]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash scripts/release.sh --bump ${{ inputs.bump }}
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Monorepo Support

```bash
# Release a specific package in a monorepo
bash scripts/release.sh --bump minor --prefix "packages/core" --tag-prefix "core-v"
# Creates: core-v2.3.0
```

## Troubleshooting

### Issue: "No tags found"

**Fix:** Create an initial tag first:
```bash
git tag v0.0.0
git push origin v0.0.0
bash scripts/release.sh --bump minor  # Creates v0.1.0
```

### Issue: "gh: not logged in"

**Fix:**
```bash
gh auth login
```

### Issue: Changelog is empty

**Check:** Are commits using conventional commit format?
```bash
# Good: feat: add dark mode
# Bad: added dark mode
```

Non-conventional commits are grouped under "Other Changes".

### Issue: Asset upload fails

**Check:**
1. File exists: `ls -la dist/`
2. Release isn't a draft that was already published
3. Asset name doesn't conflict with existing uploads

## Dependencies

- `gh` CLI (2.0+) — authenticated
- `git` (2.20+)
- `bash` (4.0+)
- `sed`, `awk`, `date` (standard Unix tools)

## Key Principles

1. **Conventional commits** — Best results with `feat:`, `fix:`, etc. prefixes
2. **Semantic versioning** — Major.Minor.Patch with optional pre-release
3. **Non-destructive** — Never force-pushes or deletes without `--delete` flag
4. **Idempotent** — Running twice won't create duplicate releases
5. **Offline-safe** — Changelog generation works offline; only publish needs network
