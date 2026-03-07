---
name: linux-user-manager
description: >-
  Create, manage, and audit Linux users, groups, and SSH keys from the command line.
categories: [security, automation]
dependencies: [bash, useradd, usermod, groupadd, chage]
---

# Linux User Manager

## What This Does

Manages Linux users, groups, SSH keys, and password policies through simple scripts. Automates the tedious parts of user administration — creating users with proper home dirs, managing group memberships, deploying SSH keys, enforcing password policies, and auditing user activity. Perfect for managing VPS/servers where you need consistent user setup.

**Example:** "Create a deploy user with SSH key, add to docker and www-data groups, set password expiry to 90 days, and audit all sudo usage."

## Quick Start (5 minutes)

### 1. Check Dependencies

```bash
# All required tools are built into Linux — no installation needed
which useradd usermod groupadd chage passwd 2>/dev/null && echo "✅ All tools available"
```

### 2. Create Your First User

```bash
# Create a user with home directory and bash shell
sudo bash scripts/user-manager.sh create --user deploy --shell /bin/bash --groups sudo,docker

# Output:
# ✅ User 'deploy' created
#    Home: /home/deploy
#    Shell: /bin/bash
#    Groups: deploy, sudo, docker
```

### 3. Deploy an SSH Key

```bash
# Add an SSH public key for the user
sudo bash scripts/user-manager.sh ssh-add --user deploy --key "ssh-ed25519 AAAAC3... user@laptop"

# Output:
# ✅ SSH key added for 'deploy'
#    Keys: 1 authorized key(s)
```

## Core Workflows

### Workflow 1: Create User with Full Setup

**Use case:** New team member or service account

```bash
sudo bash scripts/user-manager.sh create \
  --user alice \
  --shell /bin/bash \
  --groups sudo,docker,www-data \
  --expire-days 90 \
  --ssh-key "ssh-ed25519 AAAAC3..."
```

**Output:**
```
✅ User 'alice' created
   Home: /home/alice
   Shell: /bin/bash
   Groups: alice, sudo, docker, www-data
   Password expires: 90 days
   SSH key: installed
```

### Workflow 2: Audit Users

**Use case:** Security review — who has access?

```bash
sudo bash scripts/user-manager.sh audit
```

**Output:**
```
=== User Audit Report (2026-03-07) ===

HUMAN USERS (UID >= 1000):
  alice     | Groups: sudo,docker,www-data | Shell: /bin/bash | Last login: 2026-03-06 14:22
  deploy    | Groups: sudo,docker         | Shell: /bin/bash | Last login: 2026-03-07 01:15
  bob       | Groups: www-data            | Shell: /bin/bash | Last login: 2026-02-28 09:00 ⚠️ (7 days ago)

SUDO USERS:
  alice, deploy

SSH KEY STATUS:
  alice   : 2 authorized keys
  deploy  : 1 authorized key
  bob     : 0 authorized keys ⚠️ (password-only)

PASSWORD STATUS:
  alice   : expires in 67 days
  deploy  : expires in 82 days
  bob     : never expires ⚠️

LOCKED ACCOUNTS: none
SHELL: /usr/sbin/nologin ACCOUNTS: 24 (system accounts)
```

### Workflow 3: Lock/Unlock Users

**Use case:** Temporarily disable access

```bash
# Lock a user (disable login)
sudo bash scripts/user-manager.sh lock --user bob

# Unlock
sudo bash scripts/user-manager.sh unlock --user bob
```

### Workflow 4: Manage Groups

```bash
# Create a group
sudo bash scripts/user-manager.sh group-create --group developers

# Add user to group
sudo bash scripts/user-manager.sh group-add --user alice --group developers

# List group members
sudo bash scripts/user-manager.sh group-list --group developers
```

### Workflow 5: Set Password Policy

```bash
# Enforce password expiry
sudo bash scripts/user-manager.sh password-policy \
  --user alice \
  --max-days 90 \
  --min-days 7 \
  --warn-days 14
```

### Workflow 6: Remove User Safely

```bash
# Remove user but keep home dir (safe)
sudo bash scripts/user-manager.sh remove --user bob

# Remove user AND home dir
sudo bash scripts/user-manager.sh remove --user bob --purge
```

### Workflow 7: Bulk Create Users from File

```bash
# users.csv format: username,shell,groups,ssh_key
cat users.csv
# alice,/bin/bash,sudo;docker,ssh-ed25519 AAAA...
# bob,/bin/bash,www-data,ssh-ed25519 BBBB...

sudo bash scripts/user-manager.sh bulk-create --file users.csv
```

### Workflow 8: Check Sudo Activity

```bash
# Show recent sudo commands
sudo bash scripts/user-manager.sh sudo-log --lines 50
```

## Advanced Usage

### Run as Cron (Daily Audit)

```bash
# Daily user audit at 6am
echo "0 6 * * * root bash /path/to/scripts/user-manager.sh audit >> /var/log/user-audit.log 2>&1" | sudo tee /etc/cron.d/user-audit
```

### Expire Inactive Users

```bash
# Lock users who haven't logged in for 30+ days
sudo bash scripts/user-manager.sh expire-inactive --days 30
```

## Troubleshooting

### Issue: "useradd: Permission denied"

**Fix:** Run with `sudo`

### Issue: "user already exists"

**Fix:** Use `usermod` to modify, or `--force` flag to skip existing

### Issue: SSH key not working

**Check:**
1. Key format: `ssh-ed25519` or `ssh-rsa` prefix
2. Permissions: `~/.ssh` is 700, `authorized_keys` is 600
3. Owner: files owned by the user, not root

## Dependencies

- `bash` (4.0+)
- `useradd` / `usermod` / `userdel` (shadow-utils)
- `groupadd` / `groupmod` (shadow-utils)
- `chage` (password aging)
- `passwd` (password management)
- `last` / `lastlog` (login history)
- `grep` / `awk` / `cut` (text processing)
- All standard on any Linux distribution
