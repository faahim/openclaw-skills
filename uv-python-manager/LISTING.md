# Listing Copy: UV Python Manager

## Metadata
- **Type:** Skill
- **Name:** uv-python-manager
- **Display Name:** UV Python Manager
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [curl, bash]
- **Icon:** 🐍

## Tagline

Install and manage uv — the blazing-fast Python package manager that replaces pip, poetry, and pyenv

## Description

Managing Python environments is painful. You need pyenv for versions, virtualenv for environments, pip for packages, pip-tools for locking, pipx for CLI tools, and poetry for project management. That's 6 tools just to write Python.

UV Python Manager sets up [uv](https://github.com/astral-sh/uv) — Astral's Rust-powered replacement for ALL of those tools. One install, one command, 10-100x faster than pip. Your OpenClaw agent can install Python versions, scaffold projects, manage dependencies, and run tools in seconds.

**What it does:**
- 🚀 Install uv with one command (auto-configures PATH)
- 🐍 Manage multiple Python versions (no pyenv needed)
- 📦 Add/remove/lock dependencies 10-100x faster than pip
- 🏗️ Scaffold new projects with `uv init`
- 🔧 Run CLI tools without installing them (`uvx ruff`, `uvx pytest`)
- 🔄 Migrate from pip/poetry/requirements.txt automatically
- 💾 Smart caching for near-instant repeated installs
- 🏭 CI/CD integration with GitHub Actions

Perfect for developers who want fast, reliable Python environment management without the complexity of juggling multiple tools.

## Core Capabilities

1. One-command install — Sets up uv, configures PATH, verifies installation
2. Python version management — Install/switch/pin Python 3.8-3.13+ without pyenv
3. Project scaffolding — Create new apps or libraries with `uv init`
4. Dependency management — Add/remove/lock packages 10-100x faster than pip
5. Virtual environments — Create isolated envs without virtualenv
6. Tool runner — Run ruff, pytest, black, mypy without installing (like pipx)
7. Migration helper — Convert requirements.txt or poetry projects to uv
8. Workspace support — Monorepo with multiple packages
9. Build & publish — Build wheels and publish to PyPI
10. Health checker — Audit project deps, lock file, and env status

## Dependencies
- `curl` (for installation)
- `bash` (4.0+)
- No Python required — uv manages its own

## Installation Time
**2 minutes**
