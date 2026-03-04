---
name: zellij-manager
description: >-
  Install, configure, and manage Zellij terminal multiplexer — layouts, sessions, keybindings, and plugins.
categories: [dev-tools, productivity]
dependencies: [bash, curl]
---

# Zellij Terminal Multiplexer Manager

## What This Does

Installs and configures [Zellij](https://zellij.dev), a modern terminal multiplexer (tmux alternative) with built-in layout system, plugin support, and floating panes. Manages sessions, creates reusable layouts for dev workflows, and configures keybindings.

**Example:** "Install Zellij, create a dev layout with editor + terminal + logs panes, and set up custom keybindings."

## Quick Start (5 minutes)

### 1. Install Zellij

```bash
bash scripts/install.sh
```

This auto-detects your platform (Linux/macOS, x86_64/aarch64) and installs the latest release.

### 2. Verify Installation

```bash
zellij --version
```

### 3. Start a Session

```bash
# Default session
zellij

# Named session
zellij -s myproject

# With a layout
zellij --layout scripts/layouts/dev.kdl
```

## Core Workflows

### Workflow 1: Install or Update Zellij

```bash
# Install latest version
bash scripts/install.sh

# Install specific version
ZELLIJ_VERSION="0.41.2" bash scripts/install.sh

# Update to latest
bash scripts/install.sh --update
```

### Workflow 2: Create Dev Layout

```bash
# Generate a dev layout (editor + 2 terminals + log viewer)
bash scripts/create-layout.sh dev

# Generate a monitoring layout (htop + logs + network)
bash scripts/create-layout.sh monitor

# Custom layout from template
bash scripts/create-layout.sh custom --name myproject \
  --panes "editor:60%,terminal:20%,logs:20%"
```

**Generated layout file (`~/.config/zellij/layouts/dev.kdl`):**

```kdl
layout {
    pane size=1 borderless=true {
        plugin location="compact-bar"
    }
    pane split_direction="vertical" {
        pane size="60%" {
            // Editor pane
            command "nvim"
            args "."
        }
        pane split_direction="horizontal" {
            pane size="50%" {
                // Terminal
            }
            pane size="50%" {
                // Logs / tests
                command "tail"
                args "-f" "logs/dev.log"
            }
        }
    }
}
```

### Workflow 3: Manage Sessions

```bash
# List active sessions
bash scripts/session.sh list

# Attach to existing session
bash scripts/session.sh attach myproject

# Kill a session
bash scripts/session.sh kill myproject

# Kill all sessions
bash scripts/session.sh kill-all
```

### Workflow 4: Configure Keybindings

```bash
# Apply recommended keybinding preset
bash scripts/configure.sh keybindings

# This creates ~/.config/zellij/config.kdl with:
# - Ctrl+a as prefix (tmux-like)
# - Quick pane navigation
# - Layout switching shortcuts
```

### Workflow 5: Apply Theme

```bash
# List available themes
bash scripts/configure.sh themes --list

# Apply a theme
bash scripts/configure.sh themes --apply dracula

# Apply from built-in themes: dracula, catppuccin, nord, gruvbox, tokyo-night
```

## Configuration

### Config Location

Zellij config lives at `~/.config/zellij/config.kdl`. Layouts go in `~/.config/zellij/layouts/`.

### Environment Variables

```bash
# Default shell for new panes
export ZELLIJ_DEFAULT_SHELL="/bin/bash"

# Default layout on startup
export ZELLIJ_DEFAULT_LAYOUT="dev"

# Auto-attach to existing session
export ZELLIJ_AUTO_ATTACH="true"

# Auto-exit when last pane closes
export ZELLIJ_AUTO_EXIT="true"
```

### Shell Integration

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Auto-start Zellij on terminal open (if not already in a session)
if [[ -z "$ZELLIJ" ]]; then
    if [[ "$ZELLIJ_AUTO_ATTACH" == "true" ]]; then
        zellij attach -c
    else
        zellij
    fi
fi
```

## Layout Templates

### Preset: `dev` — Full-stack Development

```
┌─────────────────┬──────────────┐
│                  │   Terminal   │
│     Editor       ├──────────────┤
│     (60%)        │  Tests/Logs  │
│                  │              │
└─────────────────┴──────────────┘
```

### Preset: `monitor` — System Monitoring

```
┌─────────────────┬──────────────┐
│     htop         │   Logs       │
│     (50%)        │   (50%)      │
├─────────────────┴──────────────┤
│         Network / Custom        │
└─────────────────────────────────┘
```

### Preset: `api` — API Development

```
┌──────────┬──────────┬──────────┐
│  Server  │  Client  │   Logs   │
│  (33%)   │  (33%)   │  (33%)   │
├──────────┴──────────┴──────────┤
│          Test Runner            │
└─────────────────────────────────┘
```

## Troubleshooting

### Issue: "zellij: command not found"

**Fix:**
```bash
# Check install location
ls ~/.local/bin/zellij || ls /usr/local/bin/zellij

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Issue: Layout file syntax error

**Fix:** Validate KDL syntax:
```bash
zellij setup --check
```

### Issue: Colors look wrong

**Fix:** Ensure terminal supports 256 colors:
```bash
echo $TERM  # Should be xterm-256color or similar
export TERM=xterm-256color
```

### Issue: Keybindings conflict with vim/emacs

**Fix:** Use `locked` mode prefix:
```bash
# In config.kdl, Ctrl+g enters locked mode (default)
# All Zellij keybindings are disabled in locked mode
```

## Key Principles

1. **Modern alternative to tmux** — Better defaults, built-in UI, KDL config
2. **Layout-first** — Define your workspace once, reuse everywhere
3. **Plugin support** — Extend with WebAssembly plugins
4. **Discoverable** — Built-in keybinding hints (no memorization needed)
5. **Session persistence** — Detach and reattach without losing state

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- Linux (x86_64/aarch64) or macOS (x86_64/aarch64)
- Optional: `nvim`, `htop` (for layout presets)
