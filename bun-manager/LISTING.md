# Listing Copy: Bun Manager

## Metadata
- **Type:** Skill
- **Name:** bun-manager
- **Display Name:** Bun Runtime Manager
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [curl, bash, unzip]
- **Icon:** 🍞

## Tagline

Install, manage, and migrate to Bun — the blazing-fast JavaScript runtime

## Description

Tired of slow npm installs and juggling Node.js tooling? Bun is a drop-in replacement that's 10-30x faster — handling runtime, bundling, testing, and package management in one tool.

**Bun Runtime Manager** handles the complete lifecycle: install Bun with one command, switch between versions, and migrate existing npm/yarn/pnpm projects automatically. The migration script detects your current package manager, removes old lockfiles, reinstalls with Bun, tests your build, and flags any incompatible packages.

**What it does:**
- ⚡ One-command install (any version, any platform)
- 🔄 Migrate projects from npm/yarn/pnpm automatically
- 📦 Version management — list, install, switch versions
- 🔍 Compatibility checker — flags packages that need attention
- 🏗️ Project scaffolding — init, templates, TypeScript out of the box
- 🧪 Built-in test runner, bundler, and HTTP server guides

Perfect for developers who want faster installs, native TypeScript support, and a modern JS toolkit without the bloat.

## Quick Start Preview

```bash
# Install Bun
bash scripts/install.sh

# Migrate existing project
bash scripts/migrate.sh /path/to/my-project

# Switch versions
bash scripts/version.sh use 1.2.0
```

## Core Capabilities

1. Automated installation — Download, extract, configure PATH automatically
2. Version management — List releases, switch versions, pin per-project
3. Project migration — Convert npm/yarn/pnpm projects with one command
4. Compatibility analysis — Detect and warn about incompatible native addons
5. Build verification — Auto-tests your build after migration
6. TypeScript native — Run .ts files directly, no config needed
7. Built-in bundler guide — Bundle and minify for production
8. Built-in test runner — Replace Jest/Vitest with bun:test
9. SQLite built-in — Database without external packages
10. Cross-platform — Linux x64/arm64, macOS x64/arm64

## Installation Time
**2 minutes** — Run install script, start using immediately
