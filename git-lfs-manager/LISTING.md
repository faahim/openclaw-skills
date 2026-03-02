# Listing Copy: Git LFS Manager

## Metadata
- **Type:** Skill
- **Name:** git-lfs-manager
- **Display Name:** Git LFS Manager
- **Categories:** [dev-tools, data]
- **Price:** $10
- **Dependencies:** [git, git-lfs, bash]
- **Icon:** 📦

## Tagline
Manage Git Large File Storage — track, migrate, monitor quota, and optimize binary assets

## Description

Large binary files in git repos are a nightmare. Bloated clones, slow fetches, and hitting storage limits. Git LFS solves this — but configuring it correctly is fiddly and error-prone.

**Git LFS Manager** handles the entire LFS lifecycle: auto-install on any OS, track common binary patterns with one command, find and migrate large files buried in history, monitor storage quota, and guard against accidental large commits with a pre-commit hook.

**What it does:**
- 🔧 Auto-install git-lfs on Debian, Ubuntu, Fedora, Arch, macOS, Alpine
- 📎 One-command tracking for 30+ common binary patterns (PSD, MP4, ZIP, etc.)
- 🔍 Find large files hiding in git history
- 🔄 Migrate existing files to LFS (with safety prompts)
- 📊 Storage quota reports with top-N largest objects
- 🛡️ Pre-commit hook blocks untracked large files
- 🔒 File locking for binary collaboration
- 🧹 Prune and clean old LFS objects
- 📋 CSV export for auditing

Perfect for developers, game studios, design teams, and anyone storing binary assets in git. Works with GitHub, GitLab, Bitbucket, and any LFS-compatible host.

## Quick Start Preview

```bash
# Install git-lfs (auto-detects OS)
bash scripts/install.sh

# Track common binary formats
bash scripts/manage.sh track-defaults

# Find large files in history
bash scripts/manage.sh find-large --min-size 5M

# Check quota usage
bash scripts/manage.sh quota
```

## Core Capabilities

1. Auto-install — Detects OS and installs git-lfs automatically
2. Default tracking — 30+ binary patterns added with one command
3. Custom tracking — Track any file pattern with git LFS
4. History search — Find large files buried in git history
5. Migration — Move existing files to LFS (with safety prompts)
6. Quota monitoring — Track storage usage and largest objects
7. Pre-commit guard — Block large untracked files before commit
8. File locking — Lock binary files to prevent merge conflicts
9. Prune & clean — Reclaim disk space from old LFS objects
10. CSV export — Audit all LFS objects for compliance

## Installation Time
**5 minutes** — Run install script, track patterns, done
