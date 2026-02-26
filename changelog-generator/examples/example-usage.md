# Changelog Generator — Examples

## Basic Usage

```bash
# Generate full changelog in current repo
bash scripts/changelog.sh

# Preview without writing file
bash scripts/changelog.sh --stdout
```

## CI/CD Integration (GitHub Actions)

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history needed
      - name: Generate release notes
        run: bash scripts/changelog.sh --unreleased --stdout > notes.md
      - name: Create release
        run: gh release create ${{ github.ref_name }} --notes-file notes.md
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## OpenClaw Cron Integration

```bash
# Auto-update changelog weekly
# Add to OpenClaw cron:
cd /path/to/repo && bash /path/to/changelog.sh --output CHANGELOG.md && git add CHANGELOG.md && git commit -m "docs: update changelog" && git push
```

## Monorepo Example

```bash
# Only changes in packages/api/
bash scripts/changelog.sh --path "packages/api/" --output packages/api/CHANGELOG.md

# Only changes scoped to "api" or "core"
bash scripts/changelog.sh --scope "api,core"
```

## Sample Output

```markdown
# Changelog

*Auto-generated from git commit history.*

## Unreleased

### 🚀 Features

- **auth:** Add OAuth2 PKCE flow support
- Implement rate limiting middleware

## v2.1.0 (2026-02-15)

### 🚀 Features

- **api:** Add batch endpoint for bulk operations ([#142](https://github.com/user/repo/issues/142))
- **ui:** Implement dark mode toggle ([#138](https://github.com/user/repo/issues/138))

### 🐛 Bug Fixes

- **worker:** Fix memory leak in connection pool ([#141](https://github.com/user/repo/issues/141))
- Correct timezone handling in scheduler ([#139](https://github.com/user/repo/issues/139))

### ⚡ Performance

- **db:** Optimize query planner for large datasets

## v2.0.0 (2026-02-01)

### ⚠️ Breaking Changes

- Removed deprecated /v1/* endpoints, migrate to /v2/*

### 🚀 Features

- **api:** Complete v2 API redesign
- Add WebSocket support for real-time updates

### 🐛 Bug Fixes

- Fix race condition in concurrent writes
```
