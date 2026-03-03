---
name: mise-version-manager
description: >-
  Install and manage dev tool versions (Node, Python, Ruby, Go, Java, Rust, etc.) with mise — the polyglot version manager that replaces nvm, pyenv, rbenv, and asdf.
categories: [dev-tools, automation]
dependencies: [curl, bash]
---

# Mise Version Manager

## What This Does

Mise (formerly rtx) is a polyglot version manager that replaces nvm, pyenv, rbenv, goenv, and asdf — all in one fast tool written in Rust. This skill installs mise, configures it, and provides workflows for managing any dev tool version across projects.

**Example:** "Install Node 22 + Python 3.12 for this project, pin versions in `.mise.toml`, and auto-activate when entering the directory."

## Quick Start (3 minutes)

### 1. Install Mise

```bash
# Install mise (single binary, no dependencies)
curl https://mise.run | sh

# Add to shell (bash)
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Verify
mise --version
```

### 2. Install Your First Tool

```bash
# Install latest Node.js
mise use --global node@lts

# Verify
node --version

# Install a specific version
mise use --global python@3.12
python3 --version
```

### 3. Per-Project Versions

```bash
cd /path/to/your/project

# Set project-specific versions (creates .mise.toml)
mise use node@20
mise use python@3.11

# Check active versions
mise current
```

## Core Workflows

### Workflow 1: Install and Manage Tool Versions

**Use case:** Install any supported runtime

```bash
# List all available tools
mise registry

# Search for a tool
mise registry | grep -i ruby

# Install specific version
mise install node@22.5.0
mise install python@3.12.4
mise install ruby@3.3.0
mise install go@1.22.0
mise install java@21

# Install latest
mise install node@latest

# List installed versions
mise ls

# List installed versions of a specific tool
mise ls node
```

### Workflow 2: Global Default Versions

**Use case:** Set system-wide defaults

```bash
# Set global defaults
mise use --global node@22
mise use --global python@3.12
mise use --global go@1.22

# View global config
cat ~/.config/mise/config.toml

# List all active versions
mise current
```

### Workflow 3: Per-Project Version Pinning

**Use case:** Different projects need different versions

```bash
cd ~/project-a
mise use node@20 python@3.11

cd ~/project-b
mise use node@22 python@3.12

# Versions auto-switch when you cd between directories
# Check: .mise.toml is created in each project root
cat .mise.toml
```

**Example `.mise.toml`:**
```toml
[tools]
node = "22"
python = "3.12"

[env]
NODE_ENV = "development"
```

### Workflow 4: Environment Variables per Project

**Use case:** Set env vars that activate with the project

```bash
# Edit project config
cat > .mise.toml << 'EOF'
[tools]
node = "22"

[env]
DATABASE_URL = "postgres://localhost/mydb"
NODE_ENV = "development"
API_KEY = "dev-key-123"

[tasks.dev]
run = "npm run dev"

[tasks.test]
run = "npm test"
EOF

# Env vars activate when you cd into the directory
echo $DATABASE_URL  # → postgres://localhost/mydb
```

### Workflow 5: Run Tasks

**Use case:** Define and run project tasks (like npm scripts but language-agnostic)

```bash
# Define tasks in .mise.toml
cat >> .mise.toml << 'EOF'

[tasks.dev]
run = "npm run dev"
description = "Start dev server"

[tasks.build]
run = "npm run build"
description = "Build for production"

[tasks.lint]
run = "npx eslint src/"
description = "Run linter"

[tasks.db-migrate]
run = "python manage.py migrate"
description = "Run database migrations"
EOF

# Run tasks
mise run dev
mise run build
mise run lint

# List available tasks
mise tasks
```

### Workflow 6: Upgrade Tools

**Use case:** Keep tools up to date

```bash
# Check for outdated versions
mise outdated

# Upgrade a specific tool
mise upgrade node

# Upgrade all tools
mise upgrade

# Prune unused versions (free disk space)
mise prune
```

### Workflow 7: Legacy Config Support (nvm, pyenv, asdf)

**Use case:** Migrate from other version managers

```bash
# Mise reads existing config files automatically:
# - .nvmrc → Node version
# - .python-version → Python version
# - .ruby-version → Ruby version
# - .tool-versions → asdf format

# If you have .nvmrc with "20", mise picks it up
cat .nvmrc
# 20

mise current node
# 20.x.x (auto-detected from .nvmrc)

# Migrate to mise format
mise use node@20  # Creates .mise.toml, can remove .nvmrc
```

## Supported Tools (100+)

```bash
# Popular runtimes
mise use node@22          # Node.js
mise use python@3.12      # Python
mise use ruby@3.3         # Ruby
mise use go@1.22          # Go
mise use java@21          # Java (via Adoptium)
mise use rust@1.77        # Rust (via rustup)
mise use deno@1.42        # Deno
mise use bun@1.1          # Bun

# CLI tools
mise use terraform@1.8    # Terraform
mise use kubectl@1.30     # Kubernetes CLI
mise use awscli@2         # AWS CLI
mise use gh@2             # GitHub CLI
mise use just@1           # Just (command runner)
mise use jq@1.7           # jq
mise use ripgrep@14       # ripgrep
mise use fd@10            # fd-find
mise use bat@0.24         # bat (cat replacement)
mise use delta@0.17       # delta (git diff)
mise use lazygit@0.41     # lazygit
mise use starship@1       # starship prompt

# See all 100+ tools
mise registry
```

## Configuration

### Config File (`.mise.toml`)

```toml
# .mise.toml — per-project config
[tools]
node = "22"
python = "3.12"
terraform = "1.8"

[env]
NODE_ENV = "development"
DATABASE_URL = "postgres://localhost:5432/mydb"

# Load .env file
[env]
_.file = ".env"

[settings]
# Auto-install missing tools
auto_install = true
```

### Global Config (`~/.config/mise/config.toml`)

```toml
# Global defaults
[tools]
node = "lts"
python = "3.12"
go = "latest"

[settings]
# Always install missing tools automatically
auto_install = true
# Number of parallel installs
jobs = 4
```

## Advanced Usage

### CI/CD Integration

```bash
# GitHub Actions
# Add to your workflow:
- name: Install mise
  uses: jdx/mise-action@v2
  with:
    install_args: "node python"

# Or manual:
- run: |
    curl https://mise.run | sh
    eval "$(mise activate bash)"
    mise install
```

### Docker Integration

```dockerfile
# In Dockerfile
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:$PATH"
RUN mise install node@22 python@3.12
RUN eval "$(mise activate bash)"
```

### Shell Completions

```bash
# Bash
mise completion bash > /etc/bash_completion.d/mise

# Zsh
mise completion zsh > ~/.zfunc/_mise

# Fish
mise completion fish > ~/.config/fish/completions/mise.fish
```

## Troubleshooting

### Issue: "mise: command not found"

**Fix:**
```bash
# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Re-activate
eval "$(mise activate bash)"
```

### Issue: Tool install fails

**Fix:**
```bash
# Check build dependencies (Python example)
sudo apt-get install -y build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev libffi-dev

# Retry
mise install python@3.12
```

### Issue: Versions not switching on cd

**Fix:**
```bash
# Ensure activation is in your shell rc file
grep "mise activate" ~/.bashrc

# If missing, add:
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: Conflicts with nvm/pyenv

**Fix:**
```bash
# Remove old version managers from shell rc
# Comment out or remove these lines from ~/.bashrc:
# export NVM_DIR=...
# source $NVM_DIR/nvm.sh
# eval "$(pyenv init -)"

# Mise replaces all of them
```

## Uninstall

```bash
# Remove mise
rm -rf ~/.local/bin/mise ~/.local/share/mise ~/.config/mise

# Remove shell activation from ~/.bashrc
# Delete the line: eval "$(mise activate bash)"
```

## Key Principles

1. **One tool to rule them all** — Replaces nvm, pyenv, rbenv, goenv, asdf
2. **Fast** — Written in Rust, instant version switching
3. **Compatible** — Reads .nvmrc, .python-version, .tool-versions
4. **Per-project** — .mise.toml pins exact versions per directory
5. **Tasks + env** — Also manages env vars and project tasks

## Dependencies

- `curl` (for installation)
- `bash` (4.0+) or `zsh` or `fish`
- Build tools for compiling runtimes (gcc, make, etc. — only if installing tools that compile from source)
