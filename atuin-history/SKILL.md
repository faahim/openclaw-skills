---
name: atuin-history
description: >-
  Install and manage Atuin — encrypted, synced shell history across all your machines.
categories: [security, productivity]
dependencies: [bash, curl]
---

# Atuin Shell History Manager

## What This Does

Atuin replaces your shell history with an encrypted SQLite database, synced across machines. Search history with fuzzy find, filter by directory/session/host, and never lose a command again. All data is end-to-end encrypted — even the sync server can't read your history.

**Example:** "Install Atuin, import 50k commands from bash history, sync across 3 machines, search with Ctrl+R on steroids."

## Quick Start (5 minutes)

### 1. Install Atuin

```bash
# One-line install (Linux/macOS)
bash scripts/install.sh

# Verify installation
atuin --version
```

### 2. Import Existing History

```bash
# Import from your current shell history
atuin import auto

# Check how many commands were imported
atuin stats
```

### 3. Configure Shell Integration

```bash
# For Bash (add to ~/.bashrc)
bash scripts/setup-shell.sh bash

# For Zsh (add to ~/.zshrc)
bash scripts/setup-shell.sh zsh

# For Fish (add to ~/.config/fish/config.fish)
bash scripts/setup-shell.sh fish

# Reload your shell
exec $SHELL
```

### 4. Try It

Press `Ctrl+R` to search history with Atuin's interactive UI. Type any part of a command to find it instantly.

## Core Workflows

### Workflow 1: Search History

**Use case:** Find a command you ran last week

```bash
# Interactive search (replaces Ctrl+R)
atuin search -i

# Search for specific text
atuin search "docker run"

# Search commands run in current directory
atuin search --cwd .

# Search commands from a specific host
atuin search --host myserver

# Search commands from today only
atuin search --after "today"
```

### Workflow 2: Sync Across Machines

**Use case:** Access your history from any machine

```bash
# Register for sync (uses Atuin's free server or self-hosted)
bash scripts/setup-sync.sh

# Manual sync
atuin sync

# Check sync status
atuin sync status
```

### Workflow 3: Self-Host Sync Server

**Use case:** Keep history on your own infrastructure

```bash
# Deploy Atuin server with Docker
bash scripts/self-host.sh docker

# Or deploy with systemd (no Docker needed)
bash scripts/self-host.sh systemd

# Point client to your server
bash scripts/configure.sh sync_address "https://atuin.yourdomain.com"
```

### Workflow 4: History Statistics

**Use case:** See your shell usage patterns

```bash
# Overall stats
atuin stats

# Top 10 most-used commands
atuin stats --count 10

# Stats for current directory
atuin stats --cwd .

# Stats for specific time period
atuin stats --after "2026-01-01" --before "2026-02-01"
```

### Workflow 5: History Management

**Use case:** Clean up or manage stored history

```bash
# Delete a specific command from history
atuin search "secret-command" --delete

# Delete all history from a host
atuin search --host old-server --delete

# Compact the database
atuin compact
```

## Configuration

### Config File (~/.config/atuin/config.toml)

```bash
# Generate default config
bash scripts/configure.sh init

# Key settings
bash scripts/configure.sh search_mode "fuzzy"        # fuzzy, prefix, fulltext, skim
bash scripts/configure.sh filter_mode "global"        # global, host, session, directory
bash scripts/configure.sh style "compact"             # auto, full, compact
bash scripts/configure.sh inline_height 20            # Rows for inline search UI
bash scripts/configure.sh show_preview true           # Show command preview
bash scripts/configure.sh max_preview_height 4        # Preview window height
bash scripts/configure.sh history_filter '["^secret"]' # Regex patterns to exclude
```

### Key Configuration Options

| Setting | Default | Options | Description |
|---------|---------|---------|-------------|
| `search_mode` | `fuzzy` | fuzzy, prefix, fulltext, skim | How search matches commands |
| `filter_mode` | `global` | global, host, session, directory | Default search scope |
| `style` | `auto` | auto, full, compact | UI layout |
| `sync_frequency` | `10m` | Duration string | How often to auto-sync |
| `update_check` | `true` | true, false | Check for updates |
| `history_filter` | `[]` | Regex array | Patterns to never record |

### Privacy & Security

```bash
# Exclude sensitive commands from recording
bash scripts/configure.sh history_filter '["^export.*TOKEN", "^export.*SECRET", "^export.*KEY", "^.*password.*"]'

# Disable sync entirely (local-only mode)
bash scripts/configure.sh sync_address ""

# Use your own encryption key (advanced)
# Key is auto-generated on first login; backup at ~/.local/share/atuin/key
cat ~/.local/share/atuin/key
```

## Advanced Usage

### Key Bindings

```bash
# Default: Ctrl+R for search
# You can also use:
# - Up arrow: Search with current input as prefix
# - Ctrl+R: Full interactive search

# Customize keybindings in config
bash scripts/configure.sh ctrl_n_shortcuts '["atuin search"]'
```

### Daemon Mode (Atuin v18+)

```bash
# Enable daemon for faster syncs and recording
bash scripts/configure.sh daemon.enabled true

# Start daemon
atuin daemon

# Or add to systemd
bash scripts/setup-daemon.sh
```

### Export & Backup

```bash
# Export all history to JSON
atuin history list --format json > history-backup.json

# Export to plain text
atuin history list --format "{time} {command}" > history-backup.txt

# Database location for manual backup
ls ~/.local/share/atuin/history.db
```

## Troubleshooting

### Issue: Ctrl+R doesn't work after install

**Fix:** Shell integration wasn't loaded. Re-run:
```bash
bash scripts/setup-shell.sh $(basename $SHELL)
exec $SHELL
```

### Issue: Sync fails with "encryption error"

**Fix:** Key mismatch between machines. Copy key from original machine:
```bash
# On original machine
cat ~/.local/share/atuin/key

# On new machine
echo "<key>" > ~/.local/share/atuin/key
atuin sync --force
```

### Issue: History not being recorded

**Check:**
```bash
# Verify Atuin is running
atuin doctor

# Check shell integration
grep -r "atuin" ~/.bashrc ~/.zshrc ~/.config/fish/config.fish 2>/dev/null

# Test manual recording
atuin history start -- "test-command"
```

### Issue: Too much history / slow search

**Fix:** Enable search index:
```bash
bash scripts/configure.sh search_mode "skim"  # Faster for large histories
atuin compact  # Clean up database
```

## Uninstall

```bash
bash scripts/uninstall.sh
# Removes: binary, shell integration, config (optionally keeps history DB)
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- Shell: bash, zsh, or fish
- Optional: Docker (for self-hosted sync server)
- Optional: systemd (for daemon mode)

## Key Principles

1. **E2E Encrypted** — Your history is encrypted before leaving your machine
2. **Fast** — SQLite-backed, instant search even with 500k+ commands
3. **Cross-machine** — Sync history across all your devices securely
4. **Private** — Self-host option, exclude sensitive commands
5. **Drop-in** — Replaces Ctrl+R, minimal workflow change
