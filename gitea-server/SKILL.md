---
name: gitea-server
description: >-
  Install, configure, and manage a self-hosted Gitea Git server with automatic backups and repository management.
categories: [dev-tools, automation]
dependencies: [bash, curl, git, sqlite3]
---

# Gitea Server Manager

## What This Does

Install and manage a self-hosted Gitea Git server — a lightweight, self-hosted GitHub alternative. Handles binary installation, systemd service setup, admin user creation, repository management via API, and automated backups.

**Example:** "Install Gitea on this server, create an admin account, set up 3 repos, and schedule nightly backups."

## Quick Start (5 minutes)

### 1. Install Gitea

```bash
bash scripts/install.sh
```

This will:
- Download the latest Gitea binary for your architecture
- Create a `git` system user
- Set up directories (`/var/lib/gitea`, `/etc/gitea`)
- Install a systemd service
- Start Gitea on port 3000

### 2. Complete Initial Setup

```bash
# Check Gitea is running
bash scripts/manage.sh status

# Create admin user (interactive)
bash scripts/manage.sh create-admin --username admin --password '<your-password>' --email admin@example.com
```

### 3. Access Web UI

Open `http://<your-server>:3000` in a browser to access the Gitea web interface.

## Core Workflows

### Workflow 1: Full Installation

**Use case:** Fresh server, need a Git hosting solution

```bash
# Install Gitea with SQLite (simplest setup)
bash scripts/install.sh --db sqlite

# Install with PostgreSQL (production)
bash scripts/install.sh --db postgres --db-host localhost --db-name gitea --db-user gitea --db-pass '<password>'
```

### Workflow 2: Repository Management via API

**Use case:** Create and manage repos without the web UI

```bash
# Set API credentials
export GITEA_URL="http://localhost:3000"
export GITEA_TOKEN="<your-api-token>"

# Create a repository
bash scripts/manage.sh create-repo --name my-project --description "My new project" --private

# List all repositories
bash scripts/manage.sh list-repos

# Mirror a GitHub repository
bash scripts/manage.sh mirror-repo --source https://github.com/user/repo.git --name repo-mirror

# Delete a repository
bash scripts/manage.sh delete-repo --owner admin --name old-project
```

### Workflow 3: Automated Backups

**Use case:** Nightly backups of all repos + database

```bash
# One-time backup
bash scripts/backup.sh --output /backups/gitea

# Setup nightly backup cron (2 AM)
bash scripts/backup.sh --schedule --time "02:00" --output /backups/gitea --keep 7

# Restore from backup
bash scripts/backup.sh --restore --file /backups/gitea/gitea-backup-2026-02-25.zip
```

### Workflow 4: Update Gitea

**Use case:** Upgrade to latest version

```bash
# Check current version
bash scripts/manage.sh version

# Update to latest
bash scripts/manage.sh update

# Update to specific version
bash scripts/manage.sh update --version 1.22.0
```

### Workflow 5: Reverse Proxy Setup

**Use case:** Put Gitea behind Nginx with SSL

```bash
# Generate Nginx config for Gitea
bash scripts/manage.sh nginx-config --domain git.example.com --ssl

# Output: /etc/nginx/sites-available/gitea.conf
# Then: sudo ln -s /etc/nginx/sites-available/gitea.conf /etc/nginx/sites-enabled/
# Then: sudo nginx -t && sudo systemctl reload nginx
```

## Configuration

### Environment Variables

```bash
# Gitea API access
export GITEA_URL="http://localhost:3000"
export GITEA_TOKEN="<api-token>"  # Generate in Settings > Applications

# Backup settings
export GITEA_BACKUP_DIR="/backups/gitea"
export GITEA_BACKUP_KEEP=7  # Keep last 7 backups

# Installation settings
export GITEA_PORT=3000
export GITEA_DOMAIN="git.example.com"
```

### Gitea Config File

Located at `/etc/gitea/app.ini`:

```ini
[server]
DOMAIN           = git.example.com
HTTP_PORT        = 3000
ROOT_URL         = https://git.example.com/

[database]
DB_TYPE  = sqlite3
PATH     = /var/lib/gitea/data/gitea.db

[repository]
ROOT = /var/lib/gitea/repositories

[service]
DISABLE_REGISTRATION = true  # After creating admin
```

## Advanced Usage

### Mirror GitHub Repos Automatically

```bash
# Mirror multiple repos from a GitHub org
bash scripts/manage.sh mirror-org --github-org mycompany --interval 8h
```

### Webhook Management

```bash
# Add webhook to a repo
bash scripts/manage.sh add-webhook \
  --repo my-project \
  --url https://ci.example.com/webhook \
  --events push,pull_request

# List webhooks
bash scripts/manage.sh list-webhooks --repo my-project
```

### User Management

```bash
# Create user
bash scripts/manage.sh create-user --username dev1 --password '<pass>' --email dev1@example.com

# List users
bash scripts/manage.sh list-users

# Disable user
bash scripts/manage.sh disable-user --username dev1
```

## Troubleshooting

### Issue: Gitea won't start

**Check logs:**
```bash
sudo journalctl -u gitea -f
```

**Common fixes:**
- Port conflict: Change `HTTP_PORT` in `/etc/gitea/app.ini`
- Permission issue: `sudo chown -R git:git /var/lib/gitea /etc/gitea`

### Issue: Can't push large files

**Fix:** Edit `/etc/gitea/app.ini`:
```ini
[server]
LFS_START_SERVER = true

[repository.upload]
FILE_MAX_SIZE = 100  # MB
```

### Issue: Backup fails

**Check:**
1. Backup dir exists and is writable: `ls -la $GITEA_BACKUP_DIR`
2. Enough disk space: `df -h`
3. Gitea service user can write: `sudo -u git touch $GITEA_BACKUP_DIR/test`

## Dependencies

- `bash` (4.0+)
- `curl` (downloads, API calls)
- `git` (repository operations)
- `sqlite3` (default database) or PostgreSQL/MySQL
- `systemd` (service management)
- Root/sudo access (for installation)
