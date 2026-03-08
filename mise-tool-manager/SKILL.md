---
name: mise-tool-manager
description: >-
  Install and manage multiple language runtimes (Node.js, Python, Ruby, Go, Java, Rust) with mise — one tool to replace nvm, pyenv, rbenv, and more.
categories: [dev-tools, automation]
dependencies: [curl, bash]
---

# Mise Tool Manager

## What This Does

Mise (formerly `rtx`) is a polyglot version manager that replaces nvm, pyenv, rbenv, goenv, and 20+ other version managers with a single tool. This skill installs mise, configures your shell, and provides workflows for managing language runtimes, project-level tool versions, and environment variables.

**Example:** "Set Node 22 globally, Python 3.12 for this project, and auto-switch when entering directories."

## Quick Start (3 minutes)

### 1. Install Mise

```bash
# Install mise (Linux/Mac)
curl https://mise.run | sh

# Add to shell (bash)
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Or for zsh
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc

# Or for fish
echo '~/.local/bin/mise activate fish | source' >> ~/.config/fish/config.fish
```

### 2. Verify Installation

```bash
mise --version
# mise 2025.x.x

mise doctor
# Checks shell integration, paths, and configuration
```

### 3. Install Your First Runtime

```bash
# Install latest Node.js LTS
mise use --global node@lts

# Verify
node --version
```

## Core Workflows

### Workflow 1: Install and Manage Runtimes

**Use case:** Install specific versions of languages

```bash
# Install specific versions
mise install node@22.0.0
mise install python@3.12.0
mise install go@1.22.0
mise install ruby@3.3.0
mise install java@21
mise install rust@1.77.0
mise install deno@1.42.0
mise install bun@1.1.0

# List installed versions
mise ls

# List all available versions for a tool
mise ls-remote node | tail -20
```

### Workflow 2: Global vs Project-Level Versions

**Use case:** Different versions per project

```bash
# Set global defaults
mise use --global node@22
mise use --global python@3.12

# Set project-specific versions (creates .mise.toml)
cd ~/my-project
mise use node@20
mise use python@3.11

# Check what's active
mise current
```

**Result:** When you `cd` into a project directory, mise auto-switches to the correct versions.

### Workflow 3: Environment Variables per Project

**Use case:** Manage env vars without .env files

```bash
# Set project-level env vars in .mise.toml
cat > .mise.toml << 'EOF'
[tools]
node = "22"
python = "3.12"

[env]
DATABASE_URL = "postgres://localhost:5432/mydb"
API_KEY = "dev-key-123"
NODE_ENV = "development"
EOF

# Env vars activate when entering directory
cd ~/my-project
echo $DATABASE_URL  # postgres://localhost:5432/mydb
```

### Workflow 4: Task Runner

**Use case:** Define and run project tasks (like npm scripts but language-agnostic)

```bash
# Add tasks to .mise.toml
cat >> .mise.toml << 'EOF'

[tasks.dev]
run = "npm run dev"
description = "Start development server"

[tasks.test]
run = "pytest tests/"
description = "Run test suite"

[tasks.lint]
run = ["eslint src/", "ruff check ."]
description = "Run all linters"

[tasks.build]
run = "npm run build"
depends = ["lint", "test"]
description = "Build after lint+test"
EOF

# Run tasks
mise run dev
mise run test
mise run build  # runs lint → test → build
```

### Workflow 5: Migrate from Existing Version Managers

**Use case:** Replace nvm, pyenv, rbenv

```bash
# Mise reads existing config files automatically:
# .nvmrc          → Node.js version
# .python-version → Python version
# .ruby-version   → Ruby version
# .tool-versions  → asdf format (also supported)

# If you have .nvmrc with "20.11.0":
cd ~/old-project
mise install  # Automatically reads .nvmrc and installs Node 20.11.0

# Remove old version managers (optional)
# nvm: remove from .bashrc, delete ~/.nvm
# pyenv: remove from .bashrc, delete ~/.pyenv
# rbenv: remove from .bashrc, delete ~/.rbenv
```

### Workflow 6: Pin Exact Versions for CI

**Use case:** Reproducible builds

```bash
# Pin exact versions
mise use node@22.12.0
mise use python@3.12.8

# Generate lockfile
mise ls --json > .mise-lock.json

# In CI (GitHub Actions example):
# - uses: jdx/mise-action@v2
#   with:
#     install: true
```

## Configuration

### .mise.toml (Recommended)

```toml
# .mise.toml — project root
[tools]
node = "22"           # Latest 22.x
python = "3.12.8"     # Exact version
go = "latest"         # Always latest
ruby = "3.3"          # Latest 3.3.x

[env]
NODE_ENV = "development"

[settings]
experimental = true   # Enable tasks feature

[tasks.start]
run = "node server.js"
```

### Global Config

```bash
# ~/.config/mise/config.toml
cat > ~/.config/mise/config.toml << 'EOF'
[tools]
node = "lts"
python = "3.12"
usage = "latest"

[settings]
always_keep_download = false
always_keep_install = false
legacy_version_file = true  # Read .nvmrc, .python-version, etc.
EOF
```

## Advanced Usage

### Install from Custom Plugin/Backend

```bash
# Mise supports multiple backends:
# - core (built-in for node, python, etc.)
# - asdf plugins
# - aqua registry
# - ubi (GitHub releases)

# Install a tool from GitHub releases
mise use ubi:junegunn/fzf
mise use ubi:sharkdp/bat
mise use ubi:BurntSushi/ripgrep
```

### Auto-Install on Directory Change

```bash
# In ~/.config/mise/config.toml
[settings]
auto_install = true  # Auto-install missing tools on cd
```

### List & Clean Up Old Versions

```bash
# See all installed versions
mise ls

# Prune unused versions
mise prune

# Remove specific version
mise uninstall node@18.0.0

# Remove all versions of a tool
mise uninstall --all node
```

### Use with Docker

```dockerfile
# Dockerfile
FROM ubuntu:24.04
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:$PATH"
COPY .mise.toml .
RUN mise install
```

## Troubleshooting

### Issue: "mise: command not found"

**Fix:** Ensure mise is in PATH and shell activation is configured:
```bash
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"
```

### Issue: "No version set for node"

**Fix:** Set a version:
```bash
mise use --global node@lts
# Or create .mise.toml in project root
```

### Issue: Slow shell startup

**Fix:** Use shims mode instead of activate:
```bash
# Instead of eval "$(mise activate bash)"
echo 'export PATH="$HOME/.local/share/mise/shims:$PATH"' >> ~/.bashrc
```
Note: Shims are slightly less accurate than activate but faster.

### Issue: Conflicts with nvm/pyenv

**Fix:** Remove old version managers from shell config, then:
```bash
mise implode  # Full reset
curl https://mise.run | sh  # Reinstall clean
```

## Supported Tools (60+)

Common runtimes: `node`, `python`, `ruby`, `go`, `java`, `rust`, `deno`, `bun`, `erlang`, `elixir`, `php`, `perl`, `lua`, `julia`, `zig`, `kotlin`, `scala`, `groovy`, `terraform`, `kubectl`, `helm`, `awscli`, and many more.

Full list: `mise plugins ls-remote`

## Key Principles

1. **One tool** — Replace 10+ version managers with one
2. **Fast** — Written in Rust, activates in <10ms
3. **Compatible** — Reads `.nvmrc`, `.python-version`, `.tool-versions`
4. **Project-scoped** — Auto-switch versions per directory
5. **Tasks built-in** — No need for separate task runners
