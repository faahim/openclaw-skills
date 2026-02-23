# Listing Copy: System Cleanup & Maintenance

## Metadata
- **Type:** Skill
- **Name:** system-cleanup
- **Display Name:** System Cleanup & Maintenance
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, coreutils]

## Tagline
Automated disk cleanup — reclaim gigabytes by purging temp files, caches, logs, and Docker bloat

## Description

Servers and dev machines accumulate junk — package caches, rotated logs, Docker dangling images, bloated systemd journals, old npm/pip/cargo caches. By the time you notice, you're at 90% disk with no idea what to delete.

System Cleanup scans your machine, identifies reclaimable space, and frees it in one command. It auto-detects your package manager (apt, yum, dnf, pacman, brew), finds Docker if installed, and handles journal rotation. Dry-run mode previews everything before deleting a single byte.

**What it does:**
- 🗑️ Purge temp files, old logs, and trash
- 📦 Clean apt/yum/dnf/pacman/brew package caches
- 🐳 Prune Docker containers, images, volumes, and build cache
- 📓 Vacuum systemd journal to configurable size
- 📦 Clear npm, pip, and cargo caches
- ⚡ Aggressive mode: remove old kernels, orphaned packages, truncate huge logs
- 🔍 Dry-run mode: preview before deleting
- 📊 JSON report output for monitoring integration
- ⏰ Cron-ready with quiet mode

Perfect for developers, sysadmins, and anyone running servers who wants automated disk hygiene without remembering 15 different cleanup commands.

## Core Capabilities

1. Multi-target cleanup — temp, packages, logs, Docker, journal, trash, npm, pip, cargo
2. Auto-detection — finds your package manager and Docker automatically
3. Dry-run preview — see exactly what would be freed before deleting
4. Selective targeting — clean only what you want (--docker, --packages, etc.)
5. Aggressive mode — emergency cleanup including old kernels and orphaned packages
6. JSON reports — machine-readable output for monitoring/alerting
7. Configurable thresholds — log age, journal size, temp file age
8. Exclusion patterns — skip specific directories from cleanup
9. Cron-ready — quiet mode for scheduled runs
10. Zero external deps — uses only standard Unix tools
