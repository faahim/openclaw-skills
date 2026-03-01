---
name: uv-python-manager
description: >-
  Install and manage uv — the blazing-fast Python package manager by Astral. Manage Python versions, virtual environments, dependencies, and project scaffolding 10-100x faster than pip.
categories: [dev-tools, automation]
dependencies: [curl, bash]
---

# UV Python Manager

## What This Does

Installs and manages [uv](https://github.com/astral-sh/uv) — the Rust-powered Python package/project manager that replaces pip, pip-tools, pipx, poetry, pyenv, and virtualenv. It's 10-100x faster than pip and handles Python version management, virtual environments, dependency resolution, and project scaffolding in one tool.

**Example:** "Install Python 3.12, create a project with FastAPI + SQLAlchemy, lock dependencies, and set up a dev environment — all in under 10 seconds."

## Quick Start (2 minutes)

### 1. Install uv

```bash
bash scripts/install.sh
```

This installs uv to `~/.local/bin/uv` and adds it to your PATH.

### 2. Verify Installation

```bash
uv --version
# uv 0.6.x

# Install a Python version
uv python install 3.12

# Check installed Pythons
uv python list --only-installed
```

### 3. Create Your First Project

```bash
# Scaffold a new Python project
uv init my-project
cd my-project

# Add dependencies (blazing fast)
uv add fastapi uvicorn sqlalchemy

# Run the project
uv run python -c "import fastapi; print(f'FastAPI {fastapi.__version__} ready!')"
```

## Core Workflows

### Workflow 1: Manage Python Versions

**Use case:** Install, switch, and manage multiple Python versions without pyenv.

```bash
# Install specific Python versions
uv python install 3.11 3.12 3.13

# List all installed versions
uv python list --only-installed

# Pin a project to a specific version
uv python pin 3.12

# Use a specific version for a one-off command
uv run --python 3.11 python -c "import sys; print(sys.version)"
```

### Workflow 2: Project Management

**Use case:** Create and manage Python projects with locked dependencies.

```bash
# Create a new project
uv init my-api --python 3.12

# Create a library (for publishing to PyPI)
uv init my-lib --lib

# Add production dependencies
uv add fastapi uvicorn[standard] sqlalchemy alembic

# Add dev dependencies
uv add --dev pytest pytest-cov ruff mypy

# Remove a dependency
uv remove sqlalchemy

# Sync environment (install all locked deps)
uv sync

# Update all dependencies to latest compatible versions
uv lock --upgrade
```

### Workflow 3: Virtual Environment Management

**Use case:** Create and manage isolated environments without virtualenv/venv.

```bash
# Create a venv (auto-selects Python)
uv venv

# Create a venv with specific Python
uv venv --python 3.12 .venv-312

# Activate (standard activation)
source .venv/bin/activate

# Install packages into the venv
uv pip install requests flask

# Install from requirements.txt
uv pip install -r requirements.txt

# Compile requirements (like pip-compile)
uv pip compile requirements.in -o requirements.txt
```

### Workflow 4: Run Tools Without Installing (pipx replacement)

**Use case:** Run Python CLI tools without polluting your environment.

```bash
# Run a tool once (downloads, runs, cleans up)
uvx ruff check .
uvx black --check .
uvx mypy src/
uvx pytest

# Run a specific version
uvx --from 'ruff==0.3.0' ruff check .

# Install a tool globally (persistent)
uv tool install ruff
uv tool install httpie
uv tool install cookiecutter

# List installed tools
uv tool list

# Update all tools
uv tool upgrade --all
```

### Workflow 5: Migrate from pip/poetry

**Use case:** Move an existing project to uv.

```bash
# From requirements.txt
cd existing-project
uv init  # creates pyproject.toml
uv add $(cat requirements.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ')

# From poetry (pyproject.toml already exists)
cd poetry-project
uv sync  # uv reads poetry's pyproject.toml format

# Verify everything works
uv run python -m pytest
```

### Workflow 6: CI/CD Integration

**Use case:** Speed up CI pipelines with uv's caching.

```bash
# GitHub Actions setup
cat > .github/workflows/test.yml << 'EOF'
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
        with:
          enable-cache: true
      - run: uv sync --all-extras --dev
      - run: uv run pytest
EOF
```

## Configuration

### Project Config (pyproject.toml)

```toml
[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.100",
    "uvicorn[standard]>=0.20",
]

[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "ruff>=0.3",
]

[tool.uv.sources]
# Use a git dependency
my-lib = { git = "https://github.com/user/my-lib", tag = "v1.0" }

# Use a local path dependency
shared = { path = "../shared", editable = true }
```

### Environment Variables

```bash
# Custom cache directory (default: ~/.cache/uv)
export UV_CACHE_DIR="/path/to/cache"

# Use a specific Python
export UV_PYTHON="3.12"

# Default index URL
export UV_INDEX_URL="https://pypi.org/simple"

# Extra index (e.g., private PyPI)
export UV_EXTRA_INDEX_URL="https://pypi.company.com/simple"

# Disable cache (for CI)
export UV_NO_CACHE=1
```

## Advanced Usage

### Workspaces (Monorepo)

```bash
# Create workspace root
uv init my-monorepo
cd my-monorepo

# Add workspace members
mkdir -p packages/core packages/api packages/cli
uv init packages/core --lib
uv init packages/api
uv init packages/cli

# Configure workspace in root pyproject.toml
cat >> pyproject.toml << 'EOF'

[tool.uv.workspace]
members = ["packages/*"]
EOF

# Add cross-package dependency
cd packages/api
uv add --editable ../core
```

### Build & Publish to PyPI

```bash
# Build distribution
uv build

# Publish to PyPI
uv publish --token $PYPI_TOKEN

# Publish to test PyPI
uv publish --publish-url https://test.pypi.org/legacy/ --token $TEST_PYPI_TOKEN
```

### Cache Management

```bash
# Show cache size and location
uv cache dir
du -sh $(uv cache dir)

# Clean entire cache
uv cache clean

# Clean specific package cache
uv cache clean requests

# Prune unused cache entries
uv cache prune
```

## Troubleshooting

### Issue: "uv: command not found"

**Fix:**
```bash
# Re-run installer
bash scripts/install.sh

# Or add to PATH manually
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Issue: "No Python found"

**Fix:**
```bash
# Install a Python version
uv python install 3.12

# Or specify one explicitly
uv venv --python /usr/bin/python3
```

### Issue: "Dependency conflict"

**Fix:**
```bash
# Show resolution details
uv lock -v

# Override a conflicting dependency
uv add 'package>=2.0,<3.0' --override
```

### Issue: Slow first run

This is normal — uv downloads Python on first use. Subsequent runs use the cache and are nearly instant.

## Key Principles

1. **Fast** — uv is 10-100x faster than pip (written in Rust)
2. **All-in-one** — Replaces pip, pip-tools, pipx, poetry, pyenv, virtualenv
3. **Standards-compliant** — Uses pyproject.toml, PEP 517/518/621
4. **Cached** — Aggressive caching for near-instant repeated installs
5. **Cross-platform** — Works on Linux, macOS, Windows

## Dependencies

- `curl` (for installation)
- `bash` (4.0+)
- Internet connection (for first install + package downloads)
- No Python required — uv manages its own Python installations
