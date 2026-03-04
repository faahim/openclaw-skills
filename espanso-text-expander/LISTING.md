# Listing Copy: Espanso Text Expander

## Metadata
- **Type:** Skill
- **Name:** espanso-text-expander
- **Display Name:** Espanso Text Expander
- **Categories:** [productivity, automation]
- **Price:** $8
- **Icon:** ⌨️
- **Dependencies:** [bash, curl, espanso]

## Tagline

Type shortcuts, get full text — automate repetitive typing everywhere on your system

## Description

Tired of typing the same emails, code snippets, and addresses over and over? Espanso is a cross-platform text expander that replaces short triggers with full text — in any app, instantly.

This skill installs Espanso, manages your snippet library, and includes three starter packs (general, developer, email) with 56+ ready-to-use snippets. Add new snippets in seconds, use dynamic variables (date, time, clipboard, shell commands), and back up your library automatically.

**What you get:**
- ⌨️ Install Espanso with one command (Linux & macOS)
- 📝 Add/remove/search snippets via simple scripts
- 📦 Three starter packs: general, developer, email templates
- 🕐 Dynamic snippets: dates, times, UUIDs, IP address, shell output
- 📋 Clipboard integration: wrap, transform, inject clipboard content
- 💾 Backup & restore your entire snippet library
- 🔧 App-specific snippets (only trigger in certain apps)
- ✏️ Auto-fix common typos as you type

Perfect for developers, writers, support agents, and anyone who types the same things repeatedly.

## Quick Start Preview

```bash
# Install espanso
bash scripts/install.sh

# Add a snippet
bash scripts/add-snippet.sh ":email" "you@example.com"

# Import 28 starter snippets
bash scripts/import-pack.sh starter

# Now type :email anywhere → you@example.com
```

## Core Capabilities

1. One-command installation — Detects OS, installs Espanso automatically
2. Simple snippet management — Add, remove, search, list snippets via CLI
3. Three starter packs — 56+ snippets for general use, coding, and email
4. Dynamic variables — Insert current date, time, UUID, IP, any shell command
5. Clipboard integration — Wrap or transform clipboard contents on paste
6. Multi-file organization — Separate snippets by category (work, personal, code)
7. Typo auto-correction — Fix common misspellings as you type
8. Backup & restore — Timestamped backups, one-command restore
9. App-specific triggers — Snippets that only work in certain applications
10. Regex triggers — Pattern-based expansions for advanced use cases
