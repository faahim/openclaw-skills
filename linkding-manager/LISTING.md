# Listing Copy: Linkding Bookmark Manager

## Metadata
- **Type:** Skill
- **Name:** linkding-manager
- **Display Name:** Linkding Bookmark Manager
- **Categories:** [productivity, data]
- **Price:** $10
- **Dependencies:** [docker, curl, jq]

## Tagline

Self-hosted bookmark manager — Save, tag, search, and archive your bookmarks from the terminal

## Description

Browser bookmarks are a graveyard. You save hundreds of links, never organize them, and can't find anything when you need it. Cloud bookmark services lock your data behind subscriptions and mine your browsing habits.

Linkding Manager sets up a self-hosted bookmark manager in 5 minutes via Docker. Save bookmarks with tags, search across your entire collection instantly, and automatically archive pages before they disappear. Your data stays on your machine — no subscriptions, no tracking.

**What you get:**
- 🔖 Save bookmarks with tags, titles, and descriptions from the CLI
- 🔍 Full-text search across all your bookmarks
- 📦 Bulk import from browser exports (Chrome, Firefox, Safari)
- 📸 Automatic page archiving (never lose a page to link rot)
- 💾 One-command backup and restore
- 🔄 Auto-updating Docker container
- 🌐 Clean web UI + full REST API
- 📤 Export to standard HTML format anytime

## Quick Start Preview

```bash
# Install Linkding (one command)
bash scripts/install.sh

# Save a bookmark
bash scripts/linkding.sh add "https://example.com" --tags "tools,reference"

# Search your bookmarks
bash scripts/linkding.sh search "docker tutorial"

# Backup your database
bash scripts/linkding.sh backup
```

## Core Capabilities

1. One-command install — Docker-based setup with auto-generated admin credentials
2. CLI bookmark management — Add, search, list, delete bookmarks without opening a browser
3. Tag-based organization — Hierarchical tagging with tag-based filtering
4. Full-text search — Search bookmark titles, descriptions, and archived content
5. Bulk import/export — Import from any browser, export to standard Netscape HTML
6. Page archiving — Save full page snapshots to prevent link rot
7. Automated backups — Scheduled database backups with one-command restore
8. Container management — Start, stop, restart, update, view logs from CLI
9. REST API access — Full API for custom integrations and automation
10. Self-hosted — Your data, your server, no third-party dependencies

## Dependencies
- Docker + Docker Compose
- curl
- jq

## Installation Time
**5 minutes** — Run install script, get credentials, start saving bookmarks
