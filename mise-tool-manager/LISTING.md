# Listing Copy: Mise Tool Manager

## Metadata
- **Type:** Skill
- **Name:** mise-tool-manager
- **Display Name:** Mise Tool Manager
- **Categories:** [dev-tools, automation]
- **Icon:** 🔧
- **Dependencies:** [curl, bash]

## Tagline

Manage all your language runtimes with one tool — replace nvm, pyenv, rbenv, and more

## Description

Juggling nvm for Node, pyenv for Python, rbenv for Ruby, and goenv for Go is a mess. Different install methods, different config files, different shell integrations — all for the same basic task: picking a version.

Mise (formerly rtx) replaces all of them with a single, fast, Rust-built tool. This skill installs mise, configures your shell, and gives you workflows for managing 60+ language runtimes, project-level environment variables, and built-in task running.

**What it does:**
- 🔧 Install and switch between Node.js, Python, Ruby, Go, Java, Rust, Deno, Bun, and 50+ more
- 📁 Auto-switch versions when entering project directories
- 🌍 Manage per-project environment variables (no more .env files)
- 🏃 Built-in task runner (like npm scripts, but language-agnostic)
- 📋 Reads existing .nvmrc, .python-version, .ruby-version, .tool-versions files
- ⚡ Fast — written in Rust, activates in <10ms

Perfect for developers who work across multiple projects with different runtime requirements and want to stop managing a zoo of version managers.

## Quick Start Preview

```bash
# Install mise
bash scripts/install.sh

# Install Node + Python
mise use --global node@lts python@3.12

# Per-project versions auto-switch on cd
cd ~/my-project && mise use node@20 python@3.11
```

## Core Capabilities

1. Polyglot version management — One tool for Node, Python, Ruby, Go, Java, Rust, and 50+ more
2. Project-scoped versions — Auto-switch runtimes when entering directories
3. Environment variables — Per-project env vars without .env files or dotenv
4. Task runner — Define and run project tasks with dependencies
5. Legacy file support — Reads .nvmrc, .python-version, .ruby-version automatically
6. Fast activation — Rust-built, shell activation in under 10ms
7. Migration helper — Seamlessly replaces nvm, pyenv, rbenv, goenv
8. CI-ready — GitHub Actions integration with jdx/mise-action
9. Auto-install — Missing tools install automatically on directory change
10. Cleanup tools — Prune unused versions, reclaim disk space
