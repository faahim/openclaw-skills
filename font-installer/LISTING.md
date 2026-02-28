# Listing Copy: Font Installer

## Metadata
- **Type:** Skill
- **Name:** font-installer
- **Display Name:** Font Installer
- **Categories:** [design, productivity]
- **Icon:** 🔤
- **Dependencies:** [bash, curl, unzip, fontconfig]

## Tagline

Install and manage Google Fonts from the terminal — no browser needed

## Description

Installing fonts on Linux usually means opening a browser, downloading zip files, extracting them, copying to the right directory, and refreshing the font cache. Every time. For every font.

Font Installer automates the entire process. Search the Google Fonts catalog (1900+ families), install fonts with a single command, batch-install from a list, or use curated packs for developers and designers. It downloads directly from the Google Fonts GitHub repository — no API key needed.

**What it does:**
- 🔍 Search 1900+ Google Fonts by name or category
- ⬇️ Install fonts with one command — handles download, extraction, and cache refresh
- 📦 Curated font packs: developer fonts, UI/design fonts, serif fonts, handwriting
- 📋 List, check, and remove installed fonts
- 📁 Install local .ttf/.otf files and .zip archives
- 📝 Batch install from a text file (one font per line)
- 🗂️ Browse fonts by category (serif, sans-serif, monospace, display, handwriting)

Perfect for developers setting up new machines, designers managing font libraries, or anyone tired of the manual font install dance.

## Core Capabilities

1. Google Fonts search — Find fonts by name across 1900+ families
2. One-command install — Download, extract, install, and refresh cache
3. Batch install — Install multiple fonts from a list file
4. Font packs — Curated collections (dev, design, serif, handwriting)
5. Category browsing — Browse fonts by type (monospace, serif, etc.)
6. Local file install — Support for .ttf, .otf, .woff2, and .zip
7. Font management — List installed fonts, check status, remove families
8. No API key needed — Downloads from Google Fonts GitHub repo
9. Lightweight — Uses only bash, curl, unzip, and fontconfig
10. User-space install — No sudo required (~/.local/share/fonts)

## Installation Time
**2 minutes** — Run script, install fonts

## Dependencies
- `bash` (4.0+)
- `curl`
- `unzip`
- `fontconfig` (fc-cache, fc-list)
- Optional: `jq` (for enhanced catalog browsing)
