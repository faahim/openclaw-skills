---
name: system-migration
description: >-
  Export and import full system configuration — packages, services, crontabs, users, network settings, and dotfiles — for seamless server migration or disaster recovery.
categories: [automation, dev-tools]
dependencies: [bash, tar, dpkg, systemctl]
---

# System Migration Tool

## What This Does

Captures your entire server configuration into a portable migration bundle — installed packages, running services, crontab entries, user accounts, network config, sysctl tunables, and key dotfiles. Restore on a new machine in minutes instead of hours of manual setup.

**Example:** "Export my Ubuntu server config, spin up a fresh VPS, import everything — packages installed, services configured, cron jobs restored."

## Quick Start (5 minutes)

### 1. Export Current System

```bash
sudo bash scripts/export.sh --output /tmp/migration-bundle
```

**Output:**
```
[export] Collecting package list... 847 packages
[export] Collecting service states... 23 enabled services
[export] Collecting crontabs... 4 user crontabs
[export] Collecting network config...
[export] Collecting user accounts...
[export] Collecting dotfiles...
[export] Collecting sysctl settings...
[export] Compressing bundle...
✅ Migration bundle saved to /tmp/migration-bundle.tar.gz (142KB)
```

### 2. Transfer to New Machine

```bash
scp /tmp/migration-bundle.tar.gz user@new-server:/tmp/
```

### 3. Import on New Machine

```bash
sudo bash scripts/import.sh --bundle /tmp/migration-bundle.tar.gz --dry-run
# Review what will be installed/configured, then:
sudo bash scripts/import.sh --bundle /tmp/migration-bundle.tar.gz
```

## Core Workflows

### Workflow 1: Full System Export

**Use case:** Capture everything before migrating or rebuilding

```bash
sudo bash scripts/export.sh --output /tmp/migration-bundle
```

**Exports:**
- Package list (apt/yum/dnf/pacman)
- Enabled systemd services
- All user crontabs + system crontab
- `/etc/network/` or netplan config
- User accounts (non-system, UID ≥ 1000)
- SSH authorized_keys
- Key dotfiles (.bashrc, .profile, .ssh/config, .gitconfig)
- Sysctl settings (`/etc/sysctl.conf` + `/etc/sysctl.d/`)
- UFW/firewall rules
- Custom `/etc/` config files (optional)

### Workflow 2: Selective Export

**Use case:** Only export specific components

```bash
# Only packages and services
sudo bash scripts/export.sh --output /tmp/pkgs-only --include packages,services

# Everything except dotfiles
sudo bash scripts/export.sh --output /tmp/no-dots --exclude dotfiles
```

**Available components:** `packages`, `services`, `crontabs`, `network`, `users`, `dotfiles`, `sysctl`, `firewall`, `etc-configs`

### Workflow 3: Dry-Run Import

**Use case:** Preview changes before applying

```bash
sudo bash scripts/import.sh --bundle /tmp/migration-bundle.tar.gz --dry-run
```

**Output:**
```
[dry-run] Would install 47 missing packages:
  nginx, redis-server, postgresql, certbot, ...
[dry-run] Would enable 5 services:
  nginx, redis-server, postgresql, certbot.timer, ...
[dry-run] Would restore 3 crontabs:
  root, deploy, backup
[dry-run] Would apply 12 sysctl settings
[dry-run] Would restore UFW rules (22/tcp, 80/tcp, 443/tcp)
⚠️  No changes made. Remove --dry-run to apply.
```

### Workflow 4: Selective Import

**Use case:** Only restore certain components

```bash
# Only install packages
sudo bash scripts/import.sh --bundle /tmp/migration-bundle.tar.gz --include packages

# Restore everything except user accounts
sudo bash scripts/import.sh --bundle /tmp/migration-bundle.tar.gz --exclude users
```

### Workflow 5: Diff Two Systems

**Use case:** Compare current system against a migration bundle

```bash
bash scripts/diff.sh --bundle /tmp/migration-bundle.tar.gz
```

**Output:**
```
[diff] Packages:
  + 12 packages in bundle but not installed
  - 5 packages installed but not in bundle
[diff] Services:
  + 2 services enabled in bundle but not here
  ~ 1 service state differs (nginx: enabled vs disabled)
[diff] Crontabs:
  + 1 crontab in bundle but not present (backup)
[diff] Sysctl:
  ~ 3 values differ
```

## Configuration

### Export Config (Optional)

Create `config.yaml` to customize what gets exported:

```yaml
# config.yaml
export:
  # Extra directories to include (beyond defaults)
  extra_etc_dirs:
    - /etc/nginx
    - /etc/redis
    - /etc/postgresql

  # Extra dotfiles to capture
  extra_dotfiles:
    - .tmux.conf
    - .vimrc
    - .zshrc

  # Exclude specific packages from export
  exclude_packages:
    - linux-headers-*
    - linux-image-*

  # Include Docker container list
  include_docker: true
```

```bash
sudo bash scripts/export.sh --config config.yaml --output /tmp/migration-bundle
```

### Import Config (Optional)

```yaml
# import-config.yaml
import:
  # Skip these packages even if in bundle
  skip_packages:
    - mysql-server  # Using PostgreSQL on new server

  # Remap users (old-name -> new-name)
  user_remap:
    deploy: deployer
    app: webapp

  # Don't touch network config
  skip_components:
    - network
```

## Advanced Usage

### Scheduled Exports (Backup)

```bash
# Export system config weekly
0 2 * * 0 cd /path/to/skill && sudo bash scripts/export.sh --output /backups/system-$(date +\%Y\%m\%d) --quiet
```

### Compare Before Upgrade

```bash
# Snapshot before OS upgrade
sudo bash scripts/export.sh --output /tmp/pre-upgrade

# ... do upgrade ...

# Check what changed
bash scripts/diff.sh --bundle /tmp/pre-upgrade.tar.gz
```

### Multi-Machine Fleet

```bash
# Export from each server
for host in web1 web2 db1; do
  ssh $host 'sudo bash /opt/system-migration/scripts/export.sh --output /tmp/snapshot --quiet'
  scp $host:/tmp/snapshot.tar.gz backups/$host-$(date +%Y%m%d).tar.gz
done
```

## Troubleshooting

### Issue: "Permission denied" during export

**Fix:** Run with sudo — many system files require root access.
```bash
sudo bash scripts/export.sh --output /tmp/bundle
```

### Issue: Package manager not detected

**Fix:** The tool auto-detects apt, yum, dnf, and pacman. If using a different package manager, export will skip package collection and warn.

### Issue: Import fails on different distro

**Fix:** Package names may differ between distros (e.g., `nginx` is universal but `python3-dev` vs `python3-devel`). Use `--dry-run` first, then manually adjust the package list in the bundle:
```bash
tar xzf bundle.tar.gz
vi migration/packages.txt
tar czf bundle.tar.gz migration/
```

### Issue: SSH keys won't restore

**Fix:** Ensure `.ssh/` directory permissions are correct after import:
```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

## What Gets Captured

| Component | What's Saved | Restore Method |
|-----------|-------------|----------------|
| Packages | Package name list | `apt install` / `yum install` |
| Services | Enabled systemd units | `systemctl enable` |
| Crontabs | Per-user + system crontabs | `crontab -u <user>` |
| Network | Netplan/interfaces config | File copy to `/etc/` |
| Users | Username, UID, groups, shell | `useradd` with matching UID |
| Dotfiles | .bashrc, .profile, .ssh/config, .gitconfig | File copy to `$HOME` |
| Sysctl | Kernel parameters | `sysctl -p` |
| Firewall | UFW rules / iptables-save | `ufw` commands |
| SSH Keys | authorized_keys per user | File copy |
| Docker | Container list + compose files | `docker compose up` |

## Dependencies

- `bash` (4.0+)
- `tar` (bundling)
- `systemctl` (service detection)
- `crontab` (cron export)
- Package manager: `apt`, `yum`, `dnf`, or `pacman`
- Optional: `ufw` (firewall rules), `docker` (container list)
