# Listing Copy: Git Repository Backup

## Metadata
- **Type:** Skill
- **Name:** git-repo-backup
- **Display Name:** Git Repository Backup
- **Categories:** [data, automation]
- **Price:** $10
- **Dependencies:** [bash, git, curl, jq]

## Tagline

Mirror all your GitHub/GitLab repos locally — automatic discovery, incremental sync, zero data loss.

## Description

Your code lives on GitHub or GitLab. If your account gets compromised, a repo gets accidentally deleted, or a service goes down, your work is gone. Manual backups don't scale when you have dozens of repos.

Git Repository Backup automatically discovers and mirrors ALL your repositories to local storage using `git clone --mirror`. It handles private repos, organizations, new repo detection, and incremental syncing — fetching only new changes after the initial clone. Set it up once and run it on a schedule.

**What it does:**
- 🔄 Mirror all repos from GitHub or GitLab (public + private)
- 🆕 Auto-detect new repositories on each run
- 📥 Incremental sync — only fetch new commits
- ⚡ Parallel cloning (configurable thread count)
- 🗜️ Compress stale repos to save disk space
- 🔔 Telegram/webhook notifications on completion or failure
- 📊 Backup reports with size, counts, and staleness
- 🏢 Organization/group support
- 🔍 Include/exclude patterns for selective backup

**Perfect for** developers, teams, and anyone who values their code enough to not trust a single provider with it.

## Quick Start Preview

```bash
bash scripts/run.sh --provider github --user faahim --dir ~/git-backups --include-private

# [2026-02-23 12:00:00] 📋 Found 47 repositories for user faahim
# [2026-02-23 12:00:01] 🔄 Cloning faahim/dekhval (mirror)...
# [2026-02-23 12:02:30] ✅ Backup complete: 47/47 repos, 156 MB total
```

## Core Capabilities

1. Full mirror backup — all branches, tags, refs preserved via `--mirror`
2. Multi-provider — GitHub and GitLab (including self-hosted)
3. Auto-discovery — new repos backed up automatically
4. Incremental sync — only fetches delta changes
5. Parallel execution — configurable concurrent clones/fetches
6. Organization support — backup entire GitHub orgs
7. Smart filtering — include/exclude repos by name pattern
8. Compression — auto-compress repos inactive for 90+ days
9. Telegram alerts — get notified on success or failure
10. Manifest tracking — JSON inventory of all backed-up repos
11. Restore-ready — standard git mirrors, clone to restore
12. Cron-friendly — idempotent, safe to run on schedule

## Dependencies
- `bash` (4.0+), `git` (2.20+), `curl`, `jq`
- Optional: `gh` CLI, `pigz`

## Installation Time
**5 minutes** — set token, run script
