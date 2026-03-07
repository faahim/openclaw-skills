# Listing Copy: User Manager

## Metadata
- **Type:** Skill
- **Name:** user-manager
- **Display Name:** User Manager
- **Categories:** [security, automation]
- **Icon:** 👤
- **Price:** $10
- **Dependencies:** [bash, useradd, usermod, groupadd, ssh-keygen]

## Tagline
Manage Linux users, groups, SSH keys, and sudo access from one tool

## Description

Managing Linux users properly is tedious — creating accounts, setting up SSH keys, configuring groups, granting sudo access, fixing permissions. One wrong chmod and SSH breaks. One forgotten sudoers entry and you're locked out.

User Manager handles the entire lifecycle of Linux user accounts through a single script. Create users with SSH-key-only login by default, manage group memberships, grant or revoke sudo with proper sudoers.d entries, bulk-create from CSV, and run security audits to catch misconfigurations.

**What it does:**
- 👤 Create users with proper SSH setup in one command
- 🔑 Manage SSH authorized keys (add, remove, list)
- 🛡️ Grant/revoke sudo access with proper sudoers.d files
- 📋 Security audit — find empty passwords, rogue shells, stale accounts
- 🔒 Lock/unlock accounts without deleting data
- 📦 Bulk create users from CSV
- 📊 Export user lists as JSON or CSV
- ⏱️ Password expiry policies and enforcement

**Perfect for sysadmins, DevOps engineers, and anyone managing Linux servers** who wants consistent, auditable user management without remembering a dozen different commands and their flags.

## Quick Start Preview

```bash
# Create a deploy user with SSH key, no sudo
sudo bash scripts/run.sh create --username deploy --groups docker --ssh-key "ssh-ed25519 AAAA..."

# Audit all users
sudo bash scripts/run.sh audit

# Grant sudo
sudo bash scripts/run.sh sudo --username deploy --grant
```

## Core Capabilities

1. User creation — One command creates user, home dir, groups, SSH key, disables password
2. SSH key management — Add, remove, list authorized keys with proper permissions
3. Sudo management — Clean sudoers.d entries, supports NOPASSWD for automation accounts
4. Security audit — Scans for empty passwords, system users with shells, stale logins
5. Account locking — Disable accounts without deleting data
6. Bulk operations — Create dozens of users from a CSV file
7. Group management — Create groups, add/remove members
8. Export — Dump user list as JSON or CSV for documentation
9. Password policies — Set expiry, warn days, force rotation
10. Audit logging — All operations logged to /var/log/user-manager.log
