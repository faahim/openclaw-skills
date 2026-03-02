# Listing Copy: Modern CLI Toolkit

## Metadata
- **Type:** Skill
- **Name:** modern-cli-toolkit
- **Display Name:** Modern CLI Toolkit
- **Categories:** [dev-tools, productivity]
- **Price:** $8
- **Icon:** 🛠️
- **Dependencies:** [bash, curl]

## Tagline

Transform your terminal — Install 12 modern replacements for core Unix commands

## Description

Still using plain `ls`, `cat`, `grep`, and `find`? These tools were designed in the 1970s. Modern alternatives are faster, more colorful, and more intuitive — but installing and configuring them all takes time.

Modern CLI Toolkit installs and configures 12 best-in-class replacements in one command: `eza` (ls with git & icons), `bat` (cat with syntax highlighting), `fd` (find but 5x faster), `ripgrep` (grep but blazing), `delta` (beautiful git diffs), `dust` (visual du), `duf` (pretty df), `procs` (colorful ps), `bottom` (gorgeous top), `zoxide` (smart cd), `sd` (simple sed), and `tokei` (code line counter).

**What you get:**
- ✅ One-command installation (auto-detects apt/brew/cargo)
- 🎨 Shell aliases that preserve muscle memory (ls→eza, cat→bat, etc.)
- ⚙️ Git integration (delta as pager, side-by-side diffs)
- 🔍 Smart ripgrep config (ignores node_modules, .git, dist)
- 🚀 zoxide shell init (jump to dirs with `z`)
- 🗑️ Clean uninstall (removes all aliases and configs)

Perfect for developers, sysadmins, and anyone who lives in the terminal.

## Quick Start Preview

```bash
# Install all 12 tools
bash scripts/install.sh

# Configure shell aliases
bash scripts/configure.sh

# Your terminal is now upgraded:
ls          # → eza with colors and git status
cat file.py # → bat with syntax highlighting
grep TODO   # → ripgrep (10x faster)
git diff    # → delta with side-by-side view
```

## Core Capabilities

1. Auto-detect OS & package manager (apt, brew, cargo)
2. Install 12 modern CLI tools in one command
3. Configure shell aliases (bash, zsh, fish)
4. Git delta integration (side-by-side, line numbers)
5. Ripgrep smart config (ignore common dirs)
6. Zoxide shell init (smart directory jumping)
7. Selective install/skip specific tools
8. Update existing tools to latest versions
9. Verify installation status
10. Clean uninstall (all configs removed)

## Dependencies
- `bash` (4.0+)
- `curl`
- Package manager: `apt`, `brew`, or `cargo`

## Installation Time
**5 minutes** — One script installs everything
