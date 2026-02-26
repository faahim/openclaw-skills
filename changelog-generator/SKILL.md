---
name: changelog-generator
description: >-
  Auto-generate beautiful changelogs from git commit history using conventional commits.
categories: [dev-tools, writing]
dependencies: [git, bash]
---

# Changelog Generator

## What This Does

Automatically generates structured CHANGELOG.md files from your git commit history. Parses conventional commits (feat, fix, chore, etc.), groups by version tags, and outputs clean markdown. No more manually writing changelogs.

**Example:** "Scan 500 commits across 12 tags → produce a complete CHANGELOG.md in 2 seconds."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# Only needs git and bash (already installed on most systems)
which git bash || echo "Install git and bash"
```

### 2. Generate Your First Changelog

```bash
# Navigate to any git repo
cd /path/to/your/repo

# Run the generator
bash scripts/changelog.sh

# Output: CHANGELOG.md created with all tagged releases
```

### 3. Preview Output

```bash
# Generate to stdout instead of file
bash scripts/changelog.sh --stdout
```

## Core Workflows

### Workflow 1: Full Changelog from Tags

**Use case:** Generate changelog for all tagged releases

```bash
bash scripts/changelog.sh --repo /path/to/repo

# Output: CHANGELOG.md
# ## v2.1.0 (2026-02-20)
# ### Features
# - Add dark mode support (#142)
# - Implement API rate limiting (#138)
# ### Bug Fixes
# - Fix memory leak in worker pool (#141)
# - Correct timezone handling (#139)
#
# ## v2.0.0 (2026-02-01)
# ...
```

### Workflow 2: Changelog Since Last Release

**Use case:** Generate changelog for unreleased changes only

```bash
bash scripts/changelog.sh --unreleased

# Output:
# ## Unreleased
# ### Features
# - Add webhook retry logic
# ### Bug Fixes  
# - Fix CSV export encoding
```

### Workflow 3: Changelog Between Two Tags

**Use case:** Generate changelog for a specific version range

```bash
bash scripts/changelog.sh --from v1.0.0 --to v2.0.0
```

### Workflow 4: Append to Existing Changelog

**Use case:** Add new release to existing CHANGELOG.md

```bash
bash scripts/changelog.sh --unreleased --prepend CHANGELOG.md
```

### Workflow 5: Custom Commit Types

**Use case:** Customize which commit types to include

```bash
bash scripts/changelog.sh --types "feat,fix,perf,refactor,docs"
```

## Configuration

### Environment Variables

```bash
# Override output file (default: CHANGELOG.md)
export CHANGELOG_OUTPUT="HISTORY.md"

# Override repo path (default: current directory)
export CHANGELOG_REPO="/path/to/repo"

# Include commit hashes (default: false)
export CHANGELOG_HASHES="true"

# Include commit authors (default: false)
export CHANGELOG_AUTHORS="true"

# Remote URL for linking issues/PRs (auto-detected from git remote)
export CHANGELOG_REMOTE="https://github.com/user/repo"
```

### Command-Line Options

```
Usage: changelog.sh [OPTIONS]

Options:
  --repo PATH        Path to git repository (default: .)
  --output FILE      Output file (default: CHANGELOG.md)
  --stdout           Print to stdout instead of file
  --unreleased       Only show unreleased changes
  --from TAG         Start from this tag
  --to TAG           End at this tag
  --prepend FILE     Prepend new entries to existing file
  --types LIST       Comma-separated commit types (default: feat,fix,perf,refactor,docs,style,test,build,ci,chore)
  --hashes           Include commit short hashes
  --authors          Include commit authors
  --no-links         Don't generate issue/PR links
  --title TEXT       Custom title (default: "Changelog")
  --help             Show this help
```

## Conventional Commit Format

The generator parses commits following the [Conventional Commits](https://www.conventionalcommits.org/) spec:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Supported Types → Changelog Sections

| Commit Type | Changelog Section |
|-------------|-------------------|
| `feat` | 🚀 Features |
| `fix` | 🐛 Bug Fixes |
| `perf` | ⚡ Performance |
| `refactor` | ♻️ Refactoring |
| `docs` | 📚 Documentation |
| `style` | 💄 Style |
| `test` | ✅ Tests |
| `build` | 📦 Build |
| `ci` | 🔧 CI |
| `chore` | 🧹 Chores |

### Breaking Changes

Commits with `BREAKING CHANGE:` in footer or `!` after type get a special section:

```
feat!: remove deprecated API endpoints

BREAKING CHANGE: /v1/users endpoint removed, use /v2/users
```

→ Generates a **⚠️ Breaking Changes** section.

## Advanced Usage

### CI/CD Integration

```bash
# In GitHub Actions or similar
bash scripts/changelog.sh --unreleased --stdout > release-notes.md
gh release create v1.2.0 --notes-file release-notes.md
```

### Monorepo Support

```bash
# Filter by path (only changes in src/)
bash scripts/changelog.sh --path src/

# Filter by scope
bash scripts/changelog.sh --scope "api,core"
```

### JSON Output

```bash
# Machine-readable output
bash scripts/changelog.sh --format json > changelog.json
```

## Troubleshooting

### Issue: "Not a git repository"

**Fix:** Run from inside a git repo or use `--repo /path/to/repo`

### Issue: No tags found

**Fix:** The generator falls back to grouping by date ranges. Or create tags:
```bash
git tag v1.0.0
```

### Issue: Commits not showing up

**Check:** Are commits using conventional commit format? Non-conventional commits go under "Other Changes".

### Issue: Wrong remote URL for links

**Fix:** Set explicitly:
```bash
bash scripts/changelog.sh --remote https://github.com/user/repo
```

## Dependencies

- `bash` (4.0+)
- `git` (2.0+)
- `sed`, `awk`, `sort`, `date` (standard POSIX utils)
