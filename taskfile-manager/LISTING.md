# Listing Copy: Taskfile Manager

## Metadata
- **Type:** Skill
- **Name:** taskfile-manager
- **Display Name:** Taskfile Manager
- **Categories:** [dev-tools, productivity]
- **Price:** $8
- **Dependencies:** [bash, curl]

## Tagline
Replace Makefiles with simple YAML — Modern task runner for any project

## Description

Tired of Makefile syntax quirks? Tabs vs spaces, shell escaping, cryptic automatic variables — Make was built in 1976 and it shows.

**Taskfile Manager** installs and configures [Task](https://taskfile.dev) (go-task), a modern task runner that uses clean YAML instead of Makefile syntax. Define your project's build, test, deploy, and dev tasks in a simple `Taskfile.yml`. Supports file watching, parallel dependencies, dotenv loading, and cross-platform execution out of the box.

**What it does:**
- 🚀 One-command install (auto-detects OS & architecture)
- 📋 Project scaffolding with templates (Node, Python, Go, Rust, Docker)
- 🔄 Makefile → Taskfile converter (best-effort automatic migration)
- 👀 Built-in watch mode (rerun on file changes)
- ⚡ Parallel task dependencies
- 🔒 Source/generate tracking (skip tasks when outputs are fresh)
- 📦 Dotenv support, variables, namespaces, includes

Perfect for developers who want a clean, modern way to define project tasks without learning Make's arcane syntax.

## Core Capabilities

1. Cross-platform installation — Linux, macOS, Windows (auto-detect)
2. Project templates — Node.js, Python, Go, Rust, Docker, generic
3. Makefile converter — Migrate existing Makefiles to Taskfile.yml
4. Watch mode — Auto-rerun tasks on file changes
5. Parallel deps — Run dependency tasks concurrently
6. Source tracking — Skip tasks when outputs are up-to-date
7. Dotenv loading — Automatic .env file support
8. Namespaced tasks — Organize with `docker:build`, `ci:test` patterns
9. Task includes — Split large configs across multiple files
10. Zero dependencies — Single binary, no runtime needed

## Dependencies
- `bash` (4.0+)
- `curl` (for downloading Task binary)

## Installation Time
**2 minutes** — Run install script, scaffold Taskfile
