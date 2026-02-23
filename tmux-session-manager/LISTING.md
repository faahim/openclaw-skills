# Listing Copy: Tmux Session Manager

## Metadata
- **Type:** Skill
- **Name:** tmux-session-manager
- **Display Name:** Tmux Session Manager
- **Categories:** [dev-tools, productivity]
- **Icon:** 🖥️
- **Dependencies:** [tmux, bash]

## Tagline
Manage tmux sessions — create, save, and restore dev workspaces instantly

## Description

Recreating your development environment every time you reboot is tedious. Multiple terminal windows, the right directories, running processes — it adds up to 5-10 minutes of friction every day.

Tmux Session Manager automates your entire workspace setup. Define project layouts with named windows and split panes, save running sessions to disk, and restore everything with one command. Comes with built-in templates for common workflows (dev, ops, fullstack).

**What it does:**
- 🖥️ Create named sessions with custom window/pane layouts
- 💾 Save running sessions to YAML — persist across reboots
- ♻️ Restore saved sessions with one command
- 📐 Built-in templates: dev, ops, fullstack workspaces
- 📋 YAML profiles for declarative session definitions
- 📦 Export/import sessions across machines
- ⏱️ Cron-ready auto-save for continuous persistence
- 🔍 List active and saved sessions at a glance

Perfect for developers and sysadmins who live in the terminal and want instant, reproducible workspaces.

## Quick Start Preview

```bash
# Create a 3-window dev workspace
bash scripts/tmux-manager.sh create myproject \
  --window "editor:vim ." \
  --window "server:npm run dev" \
  --window "logs:tail -f /var/log/syslog"

# Save it
bash scripts/tmux-manager.sh save myproject

# Restore after reboot
bash scripts/tmux-manager.sh restore myproject
```
