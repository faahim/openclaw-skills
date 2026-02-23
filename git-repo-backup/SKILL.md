---
name: git-repo-backup
description: >-
  Automatically mirror and backup all your GitHub/GitLab repositories to local storage with scheduled sync.
categories: [data, automation]
dependencies: [bash, git, curl, jq]
---

# Git Repository Backup

## What This Does

Automatically clones and mirrors ALL your GitHub or GitLab repositories to local storage. Keeps mirrors up to date with scheduled fetches. Detects new repos automatically and backs them up without manual intervention.

**Example:** "Mirror all 47 GitHub repos to `/backups/git/`, sync every 6 hours, get notified if any fail."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# All common Linux tools — likely already installed
which git curl jq || sudo apt-get install -y git curl jq

# GitHub CLI (optional but recommended — handles auth seamlessly)
which gh || (curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt update && sudo apt install gh -y)
```

### 2. Configure

```bash
# Copy and edit config
cp scripts/config-template.yaml config.yaml

# Or use environment variables:
export GIT_BACKUP_DIR="$HOME/git-backups"
export GITHUB_TOKEN="ghp_your_token_here"  # or use `gh auth login`
export GITHUB_USER="your-username"
```

### 3. Run First Backup

```bash
# Backup all repos for a GitHub user
bash scripts/run.sh --provider github --user your-username --dir ~/git-backups

# Output:
# [2026-02-23 12:00:00] 📋 Found 47 repositories for user your-username
# [2026-02-23 12:00:01] 🔄 Cloning faahim/project-alpha (mirror)...
# [2026-02-23 12:00:05] ✅ faahim/project-alpha — cloned (2.3 MB)
# [2026-02-23 12:00:06] 🔄 Cloning faahim/project-beta (mirror)...
# ...
# [2026-02-23 12:02:30] ✅ Backup complete: 47/47 repos, 156 MB total
```

## Core Workflows

### Workflow 1: Backup All GitHub Repos

**Use case:** Mirror every repo you own (public + private)

```bash
bash scripts/run.sh \
  --provider github \
  --user faahim \
  --dir ~/git-backups \
  --include-private \
  --include-forks
```

### Workflow 2: Backup a GitHub Organization

**Use case:** Mirror all repos in an org

```bash
bash scripts/run.sh \
  --provider github \
  --org your-org-name \
  --dir ~/git-backups/org
```

### Workflow 3: Backup GitLab Repos

**Use case:** Mirror all GitLab projects

```bash
export GITLAB_TOKEN="glpat-your-token"
bash scripts/run.sh \
  --provider gitlab \
  --user your-username \
  --dir ~/git-backups/gitlab
```

### Workflow 4: Incremental Sync (Update Existing Mirrors)

**Use case:** Fetch latest changes for already-cloned repos

```bash
bash scripts/run.sh \
  --provider github \
  --user faahim \
  --dir ~/git-backups \
  --sync-only
```

**Output:**
```
[2026-02-23 18:00:00] 🔄 Syncing 47 existing mirrors...
[2026-02-23 18:00:01] ✅ faahim/project-alpha — up to date
[2026-02-23 18:00:02] 📥 faahim/project-beta — fetched 3 new commits
[2026-02-23 18:00:03] 🆕 faahim/new-project — new repo detected, cloning...
[2026-02-23 18:00:10] ✅ Sync complete: 47 synced, 1 new, 0 failed
```

### Workflow 5: Scheduled Backup via Cron

```bash
# Add to crontab — sync every 6 hours
0 */6 * * * cd /path/to/skill && bash scripts/run.sh --provider github --user faahim --dir ~/git-backups >> ~/git-backups/backup.log 2>&1
```

### Workflow 6: Backup with Telegram Notifications

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/run.sh \
  --provider github \
  --user faahim \
  --dir ~/git-backups \
  --notify telegram
```

**On completion:** `📦 Git Backup: 47/47 repos synced (156 MB). 1 new repo detected.`
**On failure:** `🚨 Git Backup: 2 repos failed to sync: project-x, project-y`

## Configuration

### Environment Variables

```bash
# GitHub
export GITHUB_TOKEN="ghp_..."       # Personal access token (repo scope)
export GITHUB_USER="username"        # Your GitHub username

# GitLab
export GITLAB_TOKEN="glpat-..."     # Personal access token (read_api scope)
export GITLAB_URL="https://gitlab.com"  # Or self-hosted URL

# Backup
export GIT_BACKUP_DIR="~/git-backups"
export GIT_BACKUP_THREADS=4          # Parallel clone/fetch threads

# Notifications
export TELEGRAM_BOT_TOKEN="..."
export TELEGRAM_CHAT_ID="..."
```

### Config File (YAML)

```yaml
# config.yaml
providers:
  - type: github
    user: faahim
    token_env: GITHUB_TOKEN    # reads from env var
    include_private: true
    include_forks: false
    include_archived: true
    
  - type: gitlab
    user: faahim
    token_env: GITLAB_TOKEN
    url: https://gitlab.com

backup:
  dir: ~/git-backups
  threads: 4
  mirror: true                 # Use --mirror flag (full backup)
  compress_old: true           # gzip repos not updated in 90 days
  compress_after_days: 90

notifications:
  - type: telegram
    on: [complete, failure]
  - type: webhook
    url: https://hooks.slack.com/services/...
    on: [failure]

schedule:
  interval: 21600             # 6 hours in seconds (for daemon mode)
```

## Advanced Usage

### Selective Backup (Include/Exclude)

```bash
# Only repos matching pattern
bash scripts/run.sh --provider github --user faahim --dir ~/git-backups \
  --include "dekhval*,openclaw*"

# Exclude certain repos
bash scripts/run.sh --provider github --user faahim --dir ~/git-backups \
  --exclude "test-*,old-*"
```

### Compression of Old Repos

```bash
# Compress mirrors not updated in 90+ days
bash scripts/run.sh --compress --dir ~/git-backups --older-than 90
```

### Backup Report

```bash
# Generate summary report
bash scripts/run.sh --report --dir ~/git-backups

# Output:
# 📊 Git Backup Report
# Total repos: 47
# Total size: 1.2 GB
# Last sync: 2026-02-23 12:00:00
# Repos by provider:
#   GitHub: 42 (faahim)
#   GitLab: 5 (faahim)
# Stale repos (>30 days since last fetch): 3
# Compressed archives: 8
```

### Restore from Backup

```bash
# Restore a repo from mirror
git clone ~/git-backups/github/faahim/project-alpha.git restored-project

# Restore with full history and all branches
cd restored-project
git remote remove origin
git remote add origin git@github.com:faahim/project-alpha.git
```

## Troubleshooting

### Issue: "Authentication failed"

**Fix:**
```bash
# GitHub: ensure token has 'repo' scope
gh auth status  # Check if gh CLI is authenticated

# Or set token directly
export GITHUB_TOKEN="ghp_your_new_token"
```

### Issue: "Permission denied" on private repos

**Fix:** Your token needs `repo` scope (GitHub) or `read_api` scope (GitLab).

### Issue: Large repos timing out

**Fix:**
```bash
# Increase git timeout
export GIT_HTTP_LOW_SPEED_LIMIT=1000
export GIT_HTTP_LOW_SPEED_TIME=600
```

### Issue: Disk space running low

**Fix:**
```bash
# Check backup size
du -sh ~/git-backups/

# Compress old repos
bash scripts/run.sh --compress --dir ~/git-backups --older-than 30

# Or exclude large repos
bash scripts/run.sh --exclude "mono-repo,huge-project"
```

## Directory Structure

```
~/git-backups/
├── github/
│   └── faahim/
│       ├── project-alpha.git/    # Bare mirror
│       ├── project-beta.git/
│       └── old-project.git.tar.gz  # Compressed
├── gitlab/
│   └── faahim/
│       └── gitlab-project.git/
├── backup.log                    # Sync log
└── manifest.json                 # Repo inventory
```

## Key Principles

1. **Mirror mode** — Uses `git clone --mirror` for complete backups (all branches, tags, refs)
2. **Incremental** — Only fetches new changes after initial clone
3. **Auto-discovery** — Detects new repos on each run
4. **Parallel** — Clones/fetches multiple repos simultaneously
5. **Idempotent** — Safe to run repeatedly; won't duplicate data
6. **Compression** — Optionally compress stale repos to save disk

## Dependencies

- `bash` (4.0+)
- `git` (2.20+)
- `curl` (HTTP API calls)
- `jq` (JSON parsing)
- Optional: `gh` CLI (GitHub auth), `pigz` (parallel compression)
