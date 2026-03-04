# Listing Copy: Directory Watcher

## Metadata
- **Type:** Skill
- **Name:** directory-watcher
- **Display Name:** Directory Watcher
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [inotify-tools, bash]
- **Icon:** 👁️

## Tagline

Watch directories for file changes — auto-build, sync, alert, and deploy on save

## Description

Manually rebuilding projects, syncing files, or checking for config changes wastes time and attention. You need file events to trigger actions automatically — without running heavy tools like Webpack or complex CI pipelines for simple tasks.

Directory Watcher monitors directories using kernel-level inotify (Linux) or fswatch (macOS) and runs any command when files change. Auto-rebuild on save, sync new files to S3, restart services when configs change, or get Telegram alerts when someone modifies system files.

**What it does:**
- 👁️ Watch any directory for create, modify, delete, and move events
- ⚡ Run commands automatically with debounce (no spam on rapid saves)
- 🔍 Filter by file extension — only trigger on `*.js`, `*.conf`, etc.
- 🚫 Exclude patterns — skip `node_modules`, `.git`, temp files
- 🔔 Send alerts via Telegram, email, or webhook on file changes
- 🔄 Run as systemd service for production use
- 🖥️ Cross-platform — inotifywait (Linux) + fswatch (macOS)
- 📊 JSON output mode for piping to other tools
- ⚙️ YAML config for managing multiple watchers
- 📝 Full event logging with timestamps

Perfect for developers who want auto-build on save, sysadmins monitoring config changes, and anyone who needs file-triggered automation without heavy tools.

## Quick Start Preview

```bash
# Auto-rebuild when source files change
bash scripts/watch.sh --dir ./src --filter "*.js,*.ts" --on-change "npm run build" --debounce 3

# Output:
# [2026-03-04 10:00:01] 👁️ Watching: ./src (filter: *.js,*.ts)
# [2026-03-04 10:02:33] 📝 MODIFY: ./src/App.tsx
# [2026-03-04 10:02:36] ⚡ Running: npm run build
# [2026-03-04 10:02:38] ✅ Command completed (exit: 0, 2100ms)
```

## Dependencies
- `inotify-tools` (Linux) or `fswatch` (macOS)
- `bash` (4.0+)
- Optional: `curl` (notifications), `yq` (YAML config)

## Installation Time
**3 minutes** — Install inotify-tools, run watcher
