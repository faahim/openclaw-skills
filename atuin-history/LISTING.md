# Listing Copy: Atuin Shell History Manager

## Metadata
- **Type:** Skill
- **Name:** atuin-history
- **Display Name:** Atuin Shell History Manager
- **Categories:** [security, productivity]
- **Price:** $10
- **Dependencies:** [bash, curl]

## Tagline

"Encrypted, synced shell history — search 100k commands instantly with Ctrl+R"

## Description

Your shell history is one of your most valuable productivity assets, yet it's fragile — limited to a single machine, easily lost, and completely unencrypted. One server rebuild and thousands of commands disappear.

Atuin Shell History Manager installs and configures Atuin, which replaces your basic shell history with an encrypted SQLite database that syncs across all your machines. Search through your entire history with fuzzy matching, filter by directory or host, and never lose a command again. Everything is end-to-end encrypted — even the sync server can't read your commands.

**What you get:**
- 🔒 E2E encrypted shell history with automatic sync
- 🔍 Lightning-fast fuzzy search (replaces Ctrl+R)
- 🖥️ Cross-machine sync — access history from any device
- 📊 Usage statistics and command analytics
- 🏠 Self-hosted server option (Docker or systemd)
- 🛡️ Privacy filters to exclude sensitive commands
- ⚡ Shell integration for bash, zsh, and fish
- 🗑️ Clean uninstall script

Perfect for developers and sysadmins who work across multiple machines and want their command history to be searchable, synced, and secure.

## Quick Start Preview

```bash
# Install Atuin
bash scripts/install.sh

# Import existing history & set up shell
atuin import auto
bash scripts/setup-shell.sh bash
exec $SHELL

# Press Ctrl+R — welcome to the future of shell history
```

## Core Capabilities

1. One-command install — works on Linux and macOS (x86_64 and ARM64)
2. Shell integration — bash, zsh, and fish with automatic setup
3. History import — migrate from existing shell history instantly
4. Fuzzy search — find any command by typing fragments
5. Directory-aware — filter history by where you ran commands
6. Cross-machine sync — encrypted sync via Atuin cloud or self-hosted
7. Self-hosted server — Docker Compose or systemd deployment
8. Privacy filters — regex-based exclusion of sensitive commands
9. Usage statistics — see your most-used commands and patterns
10. Daemon mode — background service for faster recording and sync
11. Clean uninstall — removes binary, config, and shell integration

## Dependencies
- `bash` (4.0+)
- `curl`
- Shell: bash, zsh, or fish
- Optional: Docker (self-hosted sync)

## Installation Time
**5 minutes** — install, import history, configure shell
