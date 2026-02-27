# Listing Copy: Dotfiles Manager

## Metadata
- **Type:** Skill
- **Name:** dotfiles-manager
- **Display Name:** Dotfiles Manager
- **Categories:** [dev-tools, productivity]
- **Price:** $8
- **Dependencies:** [bash, git, stow]
- **Icon:** 📁

## Tagline

Backup, restore & sync dotfiles across machines — Git + GNU Stow automation

## Description

Setting up a new machine means hours of copying config files, hunting down that perfect `.bashrc`, and remembering which `.vimrc` tweaks you made last year. Dotfiles management shouldn't be painful.

Dotfiles Manager automates the entire workflow using Git for version control and GNU Stow for symlink management. Initialize a dotfiles repo, adopt your existing configs into organized packages, push to GitHub, and apply them on any new machine in one command. Supports machine-specific tags for work vs personal configs.

**What it does:**
- 📦 Organize configs into packages (bash, git, vim, ssh, tmux, etc.)
- 🔗 Symlink management via GNU Stow — no manual `ln -s`
- 🔄 Sync across machines with `dotfiles sync`
- 💾 Auto-backup before overwriting existing files
- 🏷️ Machine-specific tags (work vs personal configs)
- 📋 Export standalone setup scripts for sharing
- 🔍 Status overview of all tracked configs
- 🏃 5-minute setup, one-command restore

Perfect for developers, sysadmins, and anyone who works across multiple machines.

## Quick Start Preview

```bash
# Initialize
bash scripts/dotfiles.sh init

# Adopt configs
bash scripts/dotfiles.sh adopt bash ~/.bashrc ~/.bash_profile
bash scripts/dotfiles.sh adopt git ~/.gitconfig

# Push to remote
bash scripts/dotfiles.sh push "Initial backup"

# On new machine
bash scripts/dotfiles.sh clone https://github.com/you/dotfiles.git
bash scripts/dotfiles.sh apply --all
```

## Core Capabilities

1. Init & adopt — Turn existing configs into a managed dotfiles repo
2. Git-backed — Full version history, branch per machine if needed
3. GNU Stow symlinks — Clean, reversible symlink management
4. One-command restore — Clone + apply on any new machine
5. Package organization — Group configs logically (bash, vim, ssh, etc.)
6. Machine tags — Work/personal/server-specific overrides
7. Auto-backup — Never lose existing configs when applying
8. Sync — Pull + re-stow in one command
9. Dry run — Preview changes before applying
10. Export — Generate standalone setup scripts for sharing

## Installation Time
**5 minutes** — Install stow, init repo, adopt configs
