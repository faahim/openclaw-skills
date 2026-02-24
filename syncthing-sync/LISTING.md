# Listing Copy: Syncthing File Sync Manager

## Metadata
- **Type:** Skill
- **Name:** syncthing-sync
- **Display Name:** Syncthing File Sync Manager
- **Categories:** [data, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, jq, syncthing]
- **Icon:** 🔄

## Tagline
Sync files across devices peer-to-peer — no cloud, no subscriptions, fully encrypted.

## Description

Keeping files in sync across multiple machines shouldn't require a cloud subscription or trusting a third party with your data. But setting up self-hosted sync tools manually is tedious — config files, device pairing, conflict resolution, service management.

Syncthing File Sync Manager installs and configures Syncthing for you in under 5 minutes. Add folders, pair devices, monitor sync progress, detect conflicts, and manage everything through simple CLI commands. All data stays on your devices — encrypted in transit, no cloud middleman.

**What it does:**
- 📥 One-command install on any Linux distro or macOS
- 📂 Add/remove shared folders with ignore patterns
- 🖥️ Pair devices by ID with optional direct addressing
- 🔄 Real-time sync status monitoring per folder
- ⚠️ Conflict detection and auto-resolution
- ⏸️ Pause/resume individual folders
- 🔒 Send-only, receive-only, and encrypted modes
- 🔧 Systemd service setup for auto-start on boot
- 📊 Full config export as JSON

Perfect for developers syncing code across machines, sysadmins maintaining config consistency, or anyone who wants Dropbox-like sync without the cloud.

## Core Capabilities

1. Auto-install — Detects OS, installs from official repos
2. Device pairing — Exchange device IDs, add remote peers
3. Folder sharing — Share any directory with any paired device
4. Sync monitoring — Per-folder progress, file counts, transfer rates
5. Conflict management — Find and auto-resolve sync conflicts
6. Ignore patterns — Skip node_modules, .git, temp files
7. Folder types — Send-only (backup), receive-only (mirror), encrypted
8. Service management — Enable systemd auto-start
9. Pause/resume — Control sync on demand
10. JSON config — Full API access for advanced automation

## Installation Time
**5 minutes** — Install + first sync
