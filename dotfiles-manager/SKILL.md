---
name: dotfiles-manager
description: >-
  Backup, restore, and sync your dotfiles across machines using Git and GNU Stow.
categories: [dev-tools, productivity]
dependencies: [bash, git, stow]
---

# Dotfiles Manager

## What This Does

Automates dotfiles management across multiple machines. Initializes a Git-backed dotfiles repo, uses GNU Stow for symlink management, and provides workflows for backup, restore, sync, and migration. No more manually copying `.bashrc` between servers.

**Example:** "Back up all my config files, push to GitHub, pull and apply on a new server — in 3 commands."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install GNU Stow
# Ubuntu/Debian
sudo apt-get install -y stow git

# macOS
brew install stow git

# Arch
sudo pacman -S stow git
```

### 2. Initialize Dotfiles Repo

```bash
bash scripts/dotfiles.sh init
# Creates ~/dotfiles with Git repo structure
# Output:
# ✅ Created ~/dotfiles
# ✅ Initialized Git repo
# ✅ Created package directories: bash, git, vim, ssh, tmux
# ✅ Ready to adopt your configs
```

### 3. Adopt Existing Configs

```bash
# Adopt your .bashrc, .gitconfig, etc.
bash scripts/dotfiles.sh adopt bash ~/.bashrc ~/.bash_profile ~/.bash_aliases
bash scripts/dotfiles.sh adopt git ~/.gitconfig
bash scripts/dotfiles.sh adopt vim ~/.vimrc
bash scripts/dotfiles.sh adopt ssh ~/.ssh/config

# Output:
# 📦 Adopted .bashrc → ~/dotfiles/bash/.bashrc
# 🔗 Stowed bash → ~/.bashrc (symlink)
# ✅ 4 files adopted into 'bash' package
```

### 4. Push to Remote

```bash
bash scripts/dotfiles.sh push "Initial dotfiles backup"
# Commits all changes and pushes to origin
```

## Core Workflows

### Workflow 1: First-Time Setup (New Machine)

**Use case:** Set up a fresh machine with your dotfiles

```bash
# Clone and apply all packages
bash scripts/dotfiles.sh clone https://github.com/youruser/dotfiles.git
bash scripts/dotfiles.sh apply --all

# Output:
# 📥 Cloned dotfiles to ~/dotfiles
# 🔗 Stowed bash → 4 symlinks created
# 🔗 Stowed git → 1 symlink created
# 🔗 Stowed vim → 1 symlink created
# ✅ All packages applied
```

### Workflow 2: Add New Config Files

**Use case:** Start tracking a new config

```bash
# Create a new package and adopt files
bash scripts/dotfiles.sh adopt tmux ~/.tmux.conf
bash scripts/dotfiles.sh adopt alacritty ~/.config/alacritty/alacritty.yml

# For nested configs (.config/xxx), directory structure is preserved:
# ~/dotfiles/alacritty/.config/alacritty/alacritty.yml
```

### Workflow 3: Sync Changes Across Machines

**Use case:** Pull latest changes on another machine

```bash
# On any machine
bash scripts/dotfiles.sh sync

# Output:
# 📥 Pulled 3 new commits
# 🔄 Re-stowed bash (2 files updated)
# 🔄 Re-stowed vim (1 file updated)
# ✅ All packages synced
```

### Workflow 4: List & Status

**Use case:** See what's tracked and what's changed

```bash
bash scripts/dotfiles.sh status

# Output:
# 📦 Packages (5):
#   bash     → 4 files (✅ stowed)
#   git      → 1 file  (✅ stowed)
#   vim      → 1 file  (✅ stowed)
#   ssh      → 1 file  (⚠️ not stowed)
#   tmux     → 1 file  (✅ stowed)
#
# 📝 Git status:
#   Modified: bash/.bashrc
#   Untracked: tmux/.tmux.conf.local
```

### Workflow 5: Remove a Package

**Use case:** Stop managing a set of configs

```bash
bash scripts/dotfiles.sh unstow vim
# Removes symlinks, keeps files in dotfiles repo

bash scripts/dotfiles.sh remove vim
# Removes symlinks AND deletes from dotfiles repo
```

### Workflow 6: Machine-Specific Overrides

**Use case:** Different configs per machine (work vs personal)

```bash
# Tag files for specific machines
bash scripts/dotfiles.sh adopt bash-work ~/.bashrc --tag work
bash scripts/dotfiles.sh adopt bash-personal ~/.bashrc --tag personal

# Apply based on current machine
bash scripts/dotfiles.sh apply --tag $(hostname)
```

## Configuration

### Dotfiles Directory Structure

```
~/dotfiles/
├── .dotfiles.yml          # Config file
├── bash/
│   ├── .bashrc
│   ├── .bash_profile
│   └── .bash_aliases
├── git/
│   └── .gitconfig
├── vim/
│   └── .vimrc
├── ssh/
│   └── .ssh/
│       └── config
├── tmux/
│   └── .tmux.conf
└── alacritty/
    └── .config/
        └── alacritty/
            └── alacritty.yml
```

### Config File (.dotfiles.yml)

```yaml
# ~/dotfiles/.dotfiles.yml
dotfiles_dir: ~/dotfiles
remote: https://github.com/youruser/dotfiles.git
target: ~                    # Stow target directory

# Machine tags for selective apply
machine_tag: personal        # Set per machine

# Packages to auto-apply
auto_apply:
  - bash
  - git
  - vim

# Packages only for specific tags
tagged:
  work:
    - bash-work
    - git-work
  personal:
    - bash-personal
```

## Advanced Usage

### Diff Before Sync

```bash
# See what would change before pulling
bash scripts/dotfiles.sh diff
# Shows git diff of remote vs local
```

### Backup Before Overwrite

```bash
# When adopting, existing files are backed up
bash scripts/dotfiles.sh adopt bash ~/.bashrc
# If ~/.bashrc exists and isn't a symlink:
# 📋 Backed up ~/.bashrc → ~/.bashrc.dotfiles-backup.20260227
# 📦 Adopted .bashrc → ~/dotfiles/bash/.bashrc
# 🔗 Stowed bash → ~/.bashrc (symlink)
```

### Dry Run

```bash
# Preview what stow would do
bash scripts/dotfiles.sh apply --all --dry-run
# Shows planned symlinks without creating them
```

### Export for Sharing

```bash
# Generate a setup script others can use
bash scripts/dotfiles.sh export > setup.sh
# Creates a standalone script that clones + applies
```

## Troubleshooting

### Issue: "stow: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install stow

# macOS
brew install stow

# If no package manager, install from source:
curl -L http://ftp.gnu.org/gnu/stow/stow-latest.tar.gz | tar xz
cd stow-*/ && ./configure && make && sudo make install
```

### Issue: "CONFLICT: existing target is not owned by stow"

**Cause:** A real file exists where stow wants to create a symlink.

**Fix:**
```bash
# Back up and force adopt
bash scripts/dotfiles.sh adopt --force bash ~/.bashrc
# Backs up existing file, then stows
```

### Issue: Symlinks broken after git pull

**Fix:**
```bash
# Re-stow all packages
bash scripts/dotfiles.sh apply --all --restow
```

### Issue: Nested .config paths not working

**Fix:** Ensure directory structure in dotfiles mirrors home directory:
```bash
# Wrong: ~/dotfiles/alacritty/alacritty.yml
# Right: ~/dotfiles/alacritty/.config/alacritty/alacritty.yml
```

## Dependencies

- `bash` (4.0+)
- `git` (any recent version)
- `stow` (2.0+) — GNU Stow for symlink management
- Optional: `yq` for YAML config parsing (falls back to grep)
