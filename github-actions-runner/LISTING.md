# Listing Copy: GitHub Actions Self-Hosted Runner

## Metadata
- **Type:** Skill
- **Name:** github-actions-runner
- **Display Name:** GitHub Actions Self-Hosted Runner
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, jq, systemd]
- **Icon:** 🏃

## Tagline

Set up & manage GitHub Actions self-hosted runners — register, run as a service, auto-update

## Description

Running GitHub Actions on GitHub's hosted runners means waiting in queues, paying per-minute, and limited control over the environment. Self-hosted runners give you faster builds, free unlimited minutes, and full control — but setting them up is tedious: download the binary, register, create a service, manage updates.

This skill handles everything. One command installs the runner, registers it with your repo or org, and creates a systemd service. It detects your architecture (x64/ARM64), verifies checksums, and sets up proper service management. No more following GitHub's multi-page setup docs.

**What it does:**
- ✅ One-command install & registration (repo or org level)
- 🔄 Systemd service with auto-restart on failure
- 📊 Status check via both systemd and GitHub API
- 🏷️ Manage runner labels (add/remove/list)
- 🆕 One-command updates to latest runner version
- 🗑️ Clean removal with GitHub unregistration
- 📦 Multi-runner support on a single machine
- 🔐 Secure — no stored tokens, user-level service

## Core Capabilities

1. **Automated install** — Downloads correct binary for x64/ARM64, verifies checksum
2. **One-step registration** — Registers with repo or org using GitHub API
3. **Systemd integration** — Runs as persistent user service, survives reboots
4. **Status monitoring** — Combined local + GitHub API status view
5. **Label management** — Add/remove labels for workflow routing
6. **Auto-update** — Check + update to latest runner version
7. **Multi-runner** — Run multiple runners on one machine
8. **Clean removal** — Unregisters from GitHub, removes service + files

## Quick Start Preview

```bash
export GITHUB_TOKEN="ghp_your_token"
export RUNNER_REPO="myuser/myrepo"

bash scripts/install.sh    # Install, register, create service
bash scripts/manage.sh start  # Start accepting jobs
bash scripts/manage.sh status # Check status
```

## Dependencies
- `bash` (4.0+), `curl`, `jq`, `systemd`

## Installation Time
**10 minutes** — Set token, run install, start service
