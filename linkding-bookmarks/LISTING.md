# Listing Copy: Linkding Bookmark Manager

## Metadata
- **Type:** Skill
- **Name:** linkding-bookmarks
- **Display Name:** Linkding Bookmark Manager
- **Categories:** [productivity, home]
- **Icon:** 🔖
- **Dependencies:** [docker, curl, jq]

## Tagline

Self-hosted bookmark manager — Save, tag, search, and archive your bookmarks privately

## Description

Tired of bookmarks scattered across browsers, devices, and cloud services you don't control? Linkding is a lightweight, self-hosted bookmark manager that keeps everything in one place — on your own server.

This skill installs and manages Linkding via Docker, giving you a full bookmark management system with tagging, full-text search, page archiving (save pages before they disappear), and browser bookmark import/export. Everything runs locally with zero cloud dependency.

**What it does:**
- 🔖 Save bookmarks with tags, titles, and descriptions
- 🔍 Full-text search across all your saved content
- 📦 Archive web pages for offline reading (linkrot protection)
- 📥 Import bookmarks from any browser (Netscape HTML format)
- 📤 Export as HTML or JSON for backup/migration
- 🏷️ Bulk tag management across multiple bookmarks
- 💾 Automated backup and restore
- 🔧 Nginx reverse proxy config generation
- 🔑 REST API for automation and integration

**Who it's for:** Developers, researchers, and knowledge workers who want their bookmarks private, searchable, and permanent.

## Core Capabilities

1. One-command Docker install — Running in 5 minutes
2. Bookmark CRUD — Add, search, list, delete via CLI
3. Tag system — Organize with tags, bulk-tag operations
4. Full-text search — Find bookmarks by any keyword
5. Page archiving — Save page content before URLs die
6. Browser import — Import Netscape HTML bookmark files
7. Backup/restore — Scheduled database backups with one command
8. Reverse proxy — Auto-generate Nginx config for domain access
9. REST API — Full API access for custom automation
10. Auto-update — Pull latest Linkding image with data preservation

## Dependencies
- Docker
- curl
- jq
- bash (4.0+)

## Installation Time
**5 minutes** — Docker pull + container start
