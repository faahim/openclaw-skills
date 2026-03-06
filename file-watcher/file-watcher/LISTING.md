# Listing Copy: File Watcher

## Metadata
- **Type:** Skill
- **Name:** file-watcher
- **Display Name:** File Watcher
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [inotify-tools, bash]
- **Icon:** 👁️

## Tagline

Watch files for changes — auto-build, auto-deploy, auto-anything on save

## Description

Every developer has a loop: edit file, switch terminal, run command, switch back. File Watcher kills that loop. It monitors files and directories in real time using Linux's inotify kernel subsystem and triggers any command you want — rebuild, deploy, restart, sync, alert.

File Watcher monitors your files using inotify (zero CPU overhead — kernel-level events, not polling). When something changes — a file is saved, created, deleted, or moved — your command runs automatically. Debouncing prevents rapid re-triggers during batch saves.

**What it does:**
- 👁️ Real-time file/directory monitoring (inotify + polling fallback)
- ⚡ Trigger any shell command on create, modify, delete, or move events
- ⏱️ Smart debouncing — batch rapid saves into one trigger
- 🎯 Regex filters — only react to specific file types
- 📋 YAML config for multi-path watching
- 🔄 Systemd service generation for persistent watchers
- 🐧 Works on any Linux (Ubuntu, Debian, RHEL, Arch, Alpine)
- 📡 Polling fallback for NFS/CIFS network mounts

Perfect for developers who want auto-rebuild on save, sysadmins automating config-change responses, or anyone tired of manually running commands after file edits.

## Quick Start Preview

```bash
# Auto-rebuild on code changes
bash scripts/watch.sh --path ./src --events modify,create --run "npm run build" --debounce 2

# Output:
# 👁️  Watching: ./src
# [2026-03-06 21:00:00] MODIFY ./src/index.ts
#   → Running: npm run build
```

## Core Capabilities

1. Real-time monitoring — Kernel-level inotify events, zero polling overhead
2. Custom triggers — Run any shell command when files change
3. Smart debouncing — Configurable delay prevents rapid re-triggers
4. Regex filtering — Watch only `.ts`, `.css`, `.yaml`, or any pattern
5. Exclusion patterns — Skip `node_modules`, `.git`, `dist` automatically
6. Multi-path configs — YAML config for complex multi-directory setups
7. Daemon mode — Background operation with PID management
8. Systemd integration — Generate service files for persistent watchers
9. Polling fallback — Works on NFS/CIFS where inotify doesn't
10. Environment variables — `$WATCH_FILE`, `$WATCH_EVENT` available in actions

## Dependencies
- `bash` (4.0+)
- `inotify-tools` (auto-installed via install.sh)

## Installation Time
**2 minutes** — Run install.sh, start watching
