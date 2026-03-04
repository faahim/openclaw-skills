# Listing Copy: Zellij Manager

## Metadata
- **Type:** Skill
- **Name:** zellij-manager
- **Display Name:** Zellij Terminal Multiplexer Manager
- **Categories:** [dev-tools, productivity]
- **Price:** $10
- **Dependencies:** [bash, curl]

## Tagline

Install and configure Zellij — modern terminal multiplexer with layouts, sessions, and plugins

## Description

Setting up a proper terminal multiplexer takes time — choosing keybindings, creating layouts for different projects, configuring themes. Most developers either stick with tmux defaults or spend hours customizing.

Zellij Manager installs Zellij (the modern tmux alternative) and sets up production-ready configurations in minutes. Pre-built layout templates for development, monitoring, and API work. Tmux-like keybindings that feel familiar. Theme support out of the box.

**What it does:**
- 🚀 One-command install on Linux and macOS (x86_64 + ARM)
- 📐 Pre-built layout templates (dev, monitor, API, three-column)
- ⌨️ Tmux-compatible keybinding preset (Ctrl+a prefix)
- 🎨 Built-in themes (Dracula, Catppuccin, Nord, Gruvbox, Tokyo Night)
- 📋 Session management (list, attach, kill, kill-all)
- 🐚 Shell integration with auto-start

Perfect for developers and sysadmins who want a modern terminal multiplexer without the configuration overhead.

## Quick Start Preview

```bash
# Install Zellij
bash scripts/install.sh

# Create a dev layout
bash scripts/create-layout.sh dev

# Start with layout
zellij --layout ~/.config/zellij/layouts/dev.kdl
```

## Core Capabilities

1. Auto-install — Detects platform, downloads correct binary, sets up config directory
2. Layout templates — Dev, monitoring, API, and custom layouts in KDL format
3. Session management — List, attach, create, kill sessions from one script
4. Tmux keybindings — Familiar Ctrl+a prefix with vim-style navigation
5. Theme engine — Apply Dracula, Nord, Catppuccin, etc. with one command
6. Shell integration — Auto-start Zellij on terminal open
7. Custom layouts — Define pane splits with simple `name:size%` syntax
8. Update support — Update to latest version with `--update` flag
9. Cross-platform — Linux + macOS, x86_64 + aarch64
10. No dependencies — Only needs bash and curl to install

## Dependencies
- `bash` (4.0+)
- `curl`

## Installation Time
**5 minutes**
