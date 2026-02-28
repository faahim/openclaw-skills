---
name: github-actions-runner
description: >-
  Install, configure, and manage GitHub Actions self-hosted runners as a systemd service.
categories: [dev-tools, automation]
dependencies: [bash, curl, jq, systemd]
---

# GitHub Actions Self-Hosted Runner

## What This Does

Set up and manage GitHub Actions self-hosted runners on any Linux machine. Installs the runner binary, registers it with a repository or organization, configures it as a persistent systemd service, and provides monitoring/management commands.

**Example:** "Install a self-hosted runner for my repo, run it as a background service, monitor job status, and auto-update when GitHub releases new versions."

## Quick Start (10 minutes)

### 1. Prerequisites

```bash
# You need a GitHub Personal Access Token with repo or admin:org scope
export GITHUB_TOKEN="ghp_your_token_here"

# Target repository or organization
export RUNNER_REPO="owner/repo"    # For repo-level runner
# OR
export RUNNER_ORG="my-org"          # For org-level runner
```

### 2. Install Runner

```bash
bash scripts/install.sh
```

This will:
- Download the latest GitHub Actions runner for your architecture (x64/arm64)
- Verify the checksum
- Extract to `~/actions-runner/`
- Register with your repository/organization
- Configure as a systemd user service

### 3. Start Runner

```bash
bash scripts/manage.sh start
# Runner is now accepting jobs from GitHub Actions
```

### 4. Check Status

```bash
bash scripts/manage.sh status
# Shows: online/offline, current job, OS, labels
```

## Core Workflows

### Workflow 1: Install & Register Runner

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export RUNNER_REPO="myuser/myrepo"

bash scripts/install.sh

# Output:
# ✅ Downloaded actions-runner-linux-arm64-2.322.0.tar.gz
# ✅ Checksum verified
# ✅ Extracted to /home/user/actions-runner
# ✅ Registered runner 'myhost' with myuser/myrepo
# ✅ Created systemd service: github-actions-runner
# ✅ Runner is ready. Run: bash scripts/manage.sh start
```

### Workflow 2: Manage Runner Service

```bash
# Start runner
bash scripts/manage.sh start

# Stop runner
bash scripts/manage.sh stop

# Restart runner
bash scripts/manage.sh restart

# View runner logs
bash scripts/manage.sh logs

# Follow logs in real-time
bash scripts/manage.sh logs -f
```

### Workflow 3: Check Runner Status via API

```bash
bash scripts/manage.sh status

# Output:
# 🏃 Runner: myhost
# 📍 Status: online
# 🏷️  Labels: self-hosted, Linux, ARM64
# 💼 Current Job: none
# 📅 Last Active: 2026-02-28T19:30:00Z
```

### Workflow 4: Add Custom Labels

```bash
# Add labels for routing workflows
bash scripts/manage.sh labels add gpu,docker,production

# Remove a label
bash scripts/manage.sh labels remove gpu

# List current labels
bash scripts/manage.sh labels list
```

### Workflow 5: Update Runner

```bash
# Check for updates
bash scripts/manage.sh update --check

# Update to latest version (stops, updates, restarts)
bash scripts/manage.sh update
```

### Workflow 6: Unregister & Remove

```bash
# Remove runner from GitHub and clean up
bash scripts/manage.sh remove

# Output:
# ⏹️  Stopped runner service
# 🗑️  Removed systemd service
# 🔓 Unregistered runner from GitHub
# 🧹 Cleaned up /home/user/actions-runner
```

### Workflow 7: Multi-Runner Setup

```bash
# Install multiple runners on the same machine
RUNNER_NAME="runner-1" RUNNER_DIR="~/actions-runner-1" bash scripts/install.sh
RUNNER_NAME="runner-2" RUNNER_DIR="~/actions-runner-2" bash scripts/install.sh

# Manage individually
RUNNER_DIR="~/actions-runner-1" bash scripts/manage.sh start
RUNNER_DIR="~/actions-runner-2" bash scripts/manage.sh start
```

## Configuration

### Environment Variables

```bash
# Required
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"   # PAT with repo or admin:org scope

# Choose one:
export RUNNER_REPO="owner/repo"           # Repo-level runner
export RUNNER_ORG="my-org"                # Org-level runner

# Optional
export RUNNER_NAME="$(hostname)"          # Runner name (default: hostname)
export RUNNER_DIR="$HOME/actions-runner"  # Install directory
export RUNNER_LABELS=""                   # Comma-separated extra labels
export RUNNER_GROUP="default"             # Runner group (org-level only)
export RUNNER_WORK="_work"                # Work directory name
```

### Systemd Service

The installer creates a user-level systemd service:

```bash
# Service file location
~/.config/systemd/user/github-actions-runner.service

# Enable on boot (optional)
loginctl enable-linger $USER
systemctl --user enable github-actions-runner
```

## Troubleshooting

### Issue: "Registration failed — 401 Unauthorized"

**Fix:** Your token needs `repo` scope (for repo runners) or `admin:org` scope (for org runners).

```bash
# Verify token works
curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | jq .login
```

### Issue: Runner shows offline in GitHub

**Check:**
1. Service running: `bash scripts/manage.sh status`
2. Logs for errors: `bash scripts/manage.sh logs`
3. Network: `curl -s https://api.github.com` returns valid JSON

### Issue: "Must not run with sudo"

**Fix:** The runner intentionally refuses root. Run as a regular user:
```bash
su - myuser -c "bash scripts/install.sh"
```

### Issue: Runner can't find Docker

**Fix:** Add the runner user to the docker group:
```bash
sudo usermod -aG docker $USER
# Then restart the runner
bash scripts/manage.sh restart
```

## Architecture Support

| Architecture | Supported | Binary |
|-------------|-----------|--------|
| x64 (amd64) | ✅ | actions-runner-linux-x64 |
| ARM64 (aarch64) | ✅ | actions-runner-linux-arm64 |
| ARM (armv7) | ❌ | Not supported by GitHub |

## Security Notes

1. **Token safety** — The registration token is single-use and expires in 1 hour. Your PAT is NOT stored after registration.
2. **Service isolation** — Runs as your user, not root.
3. **Work directory** — Job files are cleaned up after each run.
4. **Network** — Runner connects outbound to GitHub; no inbound ports needed.

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests)
- `jq` (JSON parsing)
- `tar`, `sha256sum` (extraction + verification)
- `systemd` (service management)
- Optional: `docker` (for container-based actions)
