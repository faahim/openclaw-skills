---
name: tmux-session-manager
description: >-
  Create, save, restore, and manage tmux sessions with predefined layouts for development workflows.
categories: [dev-tools, productivity]
dependencies: [tmux, bash]
---

# Tmux Session Manager

## What This Does

Automate tmux session management — create project-specific workspaces with predefined window/pane layouts, save running sessions to disk, and restore them after reboot. No more manually recreating your dev environment every time.

**Example:** "Spin up a 3-window dev workspace (editor, server, logs) with one command, save it, restore it tomorrow."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Install tmux if not present
which tmux || sudo apt-get install -y tmux  # Debian/Ubuntu
# which tmux || brew install tmux            # macOS
```

### 2. Create Your First Workspace

```bash
# Create a dev workspace with 3 windows
bash scripts/tmux-manager.sh create dev-project \
  --window "editor:vim ." \
  --window "server:npm run dev" \
  --window "logs:tail -f /var/log/syslog"
```

### 3. Save & Restore

```bash
# Save current session layout
bash scripts/tmux-manager.sh save dev-project

# Later, restore it
bash scripts/tmux-manager.sh restore dev-project
```

## Core Workflows

### Workflow 1: Create a Named Session with Layout

```bash
bash scripts/tmux-manager.sh create myproject \
  --window "code:cd ~/projects/myapp && vim" \
  --window "server:cd ~/projects/myapp && npm start" \
  --window "shell:cd ~/projects/myapp"
```

Creates session `myproject` with 3 named windows, each running their command.

### Workflow 2: Split Panes Layout

```bash
bash scripts/tmux-manager.sh create monitoring \
  --layout "split-h:htop|tail -f /var/log/syslog" \
  --window "shell:bash"
```

First window splits horizontally: htop on left, log tail on right. Second window is a plain shell.

### Workflow 3: Save All Sessions

```bash
# Save every running tmux session to ~/.tmux-sessions/
bash scripts/tmux-manager.sh save-all
```

### Workflow 4: Restore All Sessions

```bash
# After reboot, restore all saved sessions
bash scripts/tmux-manager.sh restore-all
```

### Workflow 5: List Sessions

```bash
bash scripts/tmux-manager.sh list
# Output:
# Active Sessions:
#   dev-project    3 windows  (attached)
#   monitoring     2 windows  (detached)
# Saved Sessions:
#   dev-project    saved 2026-02-23 06:00:00
#   backend-api    saved 2026-02-22 18:30:00
```

### Workflow 6: Kill a Session

```bash
bash scripts/tmux-manager.sh kill dev-project
```

### Workflow 7: Use Layout Templates

```bash
# Predefined layouts: dev, ops, fullstack
bash scripts/tmux-manager.sh template dev ~/projects/myapp
# Creates: editor + server + git-log windows

bash scripts/tmux-manager.sh template ops
# Creates: htop + logs + shell windows

bash scripts/tmux-manager.sh template fullstack ~/projects/myapp
# Creates: frontend + backend + database + shell windows
```

## Configuration

### Session Profiles (YAML)

Save to `~/.tmux-sessions/profiles/`:

```yaml
# ~/.tmux-sessions/profiles/web-dev.yaml
name: web-dev
root: ~/projects/webapp
windows:
  - name: editor
    command: vim .
  - name: frontend
    command: npm run dev
    panes:
      - command: npm run dev
        size: 70%
      - command: npx tailwindcss --watch
        size: 30%
  - name: backend
    command: cd api && python manage.py runserver
  - name: logs
    command: tail -f logs/*.log
```

```bash
# Launch from profile
bash scripts/tmux-manager.sh profile web-dev
```

### Environment Variables

```bash
# Custom save directory (default: ~/.tmux-sessions)
export TMUX_SESSIONS_DIR="$HOME/.tmux-sessions"

# Auto-save interval in minutes (0 = disabled)
export TMUX_AUTOSAVE_INTERVAL=30
```

## Advanced Usage

### Auto-Save with Cron

```bash
# Save all sessions every 30 minutes
*/30 * * * * bash /path/to/scripts/tmux-manager.sh save-all >> /tmp/tmux-autosave.log 2>&1
```

### Attach to Session

```bash
# Attach (or create if missing)
bash scripts/tmux-manager.sh attach dev-project
```

### Export/Import Sessions

```bash
# Export session config for sharing
bash scripts/tmux-manager.sh export dev-project > dev-project.yaml

# Import on another machine
bash scripts/tmux-manager.sh import dev-project.yaml
```

## Troubleshooting

### Issue: "tmux: command not found"

```bash
sudo apt-get install -y tmux   # Debian/Ubuntu
brew install tmux               # macOS
sudo yum install -y tmux        # CentOS/RHEL
```

### Issue: Session restore runs commands in wrong directory

Check that your profile YAML has the correct `root:` path. Paths are expanded at restore time.

### Issue: Pane splits not sizing correctly

Tmux applies sizes sequentially. Use percentages (e.g., `70%`) rather than absolute values.

## Key Principles

1. **Instant workspace** — One command to full dev environment
2. **Persist across reboots** — Save/restore eliminates setup time
3. **Template-driven** — Reusable layouts for common workflows
4. **Profile YAML** — Declarative session definitions
5. **Lightweight** — Pure bash + tmux, no extra dependencies
