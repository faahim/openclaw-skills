# Listing Copy: Mise Version Manager

## Metadata
- **Type:** Skill
- **Name:** mise-version-manager
- **Display Name:** Mise Version Manager
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [curl, bash]

## Tagline

Manage Node, Python, Ruby, Go & 100+ tool versions — one tool replaces nvm, pyenv, and asdf

## Description

Juggling nvm for Node, pyenv for Python, rbenv for Ruby, and goenv for Go? That's four version managers doing one job. Mise replaces all of them with a single, fast Rust binary.

Mise Version Manager installs mise, configures your shell, and gives you ready-to-use workflows for installing any runtime, pinning per-project versions via `.mise.toml`, managing environment variables, and running project tasks — all from one tool.

**What it does:**
- 🔧 One-command install + shell setup (bash/zsh/fish)
- 📌 Per-project version pinning via `.mise.toml`
- ⚡ Instant version switching when you `cd` between projects
- 🔄 Auto-reads `.nvmrc`, `.python-version`, `.tool-versions` (drop-in migration)
- 🌍 Project-scoped environment variables
- 📋 Built-in task runner (like npm scripts, but language-agnostic)
- 📦 100+ supported tools: runtimes, CLIs, dev tools
- 🧹 Prune unused versions to free disk space

## Core Capabilities

1. Install any runtime — Node, Python, Ruby, Go, Java, Rust, Deno, Bun + 100 more
2. Per-project versioning — `.mise.toml` pins exact versions per directory
3. Global defaults — Set system-wide fallback versions
4. Auto-switching — Versions activate when you `cd` into a project
5. Legacy support — Reads .nvmrc, .python-version, .ruby-version, .tool-versions
6. Env var management — Project-scoped environment variables in `.mise.toml`
7. Task runner — Define and run project tasks from config
8. CI/CD ready — GitHub Actions integration included
9. Shell completions — Tab completion for bash, zsh, fish
10. Fast — Written in Rust, sub-millisecond version switching

## Installation Time
**3 minutes** — Run install script, source shell, start using
