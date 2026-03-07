---
name: user-manager
description: >-
  Manage Linux users, groups, SSH keys, and sudo access from a single interface.
categories: [security, automation]
dependencies: [bash, useradd, usermod, groupadd, ssh-keygen]
---

# User Manager

## What This Does

Automates Linux user account management — create users, manage groups, configure SSH keys, set sudo permissions, audit accounts, and enforce security policies. Handles the tedious multi-step process of properly setting up and maintaining user accounts on Linux servers.

**Example:** "Create a deploy user with SSH key-only login, add to docker group, no sudo, locked-down home directory."

## Quick Start (2 minutes)

### 1. Check Prerequisites

```bash
# All tools are built into Linux — no installs needed
which useradd groupadd usermod ssh-keygen passwd 2>/dev/null && echo "Ready!"
```

### 2. Create Your First User

```bash
# Create a user with SSH key and group membership
sudo bash scripts/run.sh create \
  --username deploy \
  --groups docker,www-data \
  --shell /bin/bash \
  --ssh-key "ssh-ed25519 AAAA... user@host"
```

### 3. Audit Existing Users

```bash
# See all human users, their groups, sudo access, and last login
sudo bash scripts/run.sh audit
```

## Core Workflows

### Workflow 1: Create a New User

```bash
sudo bash scripts/run.sh create \
  --username john \
  --fullname "John Doe" \
  --groups developers,docker \
  --shell /bin/bash \
  --ssh-key "ssh-ed25519 AAAA..."
```

**Output:**
```
✅ User 'john' created (UID: 1003)
✅ Home directory: /home/john
✅ Groups: john, developers, docker
✅ SSH key added to /home/john/.ssh/authorized_keys
✅ Password login disabled (SSH key only)
```

### Workflow 2: Grant/Revoke Sudo Access

```bash
# Grant sudo with password required
sudo bash scripts/run.sh sudo --username john --grant

# Grant passwordless sudo (for automation accounts)
sudo bash scripts/run.sh sudo --username john --grant --nopasswd

# Revoke sudo
sudo bash scripts/run.sh sudo --username john --revoke
```

**Output:**
```
✅ Sudo granted to 'john' (password required)
   Rule: john ALL=(ALL:ALL) ALL
```

### Workflow 3: Manage SSH Keys

```bash
# Add an SSH key
sudo bash scripts/run.sh ssh-key --username john \
  --add "ssh-ed25519 AAAA... laptop@home"

# List SSH keys
sudo bash scripts/run.sh ssh-key --username john --list

# Remove an SSH key (by comment or fingerprint)
sudo bash scripts/run.sh ssh-key --username john \
  --remove "laptop@home"
```

**Output:**
```
SSH keys for 'john':
  1. ssh-ed25519 SHA256:abc123... user@work (added 2026-01-15)
  2. ssh-ed25519 SHA256:def456... laptop@home (added 2026-03-01)
```

### Workflow 4: Security Audit

```bash
sudo bash scripts/run.sh audit
```

**Output:**
```
=== User Account Audit ===
Date: 2026-03-07 17:53:00 UTC

Human Users (UID >= 1000):
  john      | Groups: developers, docker     | Sudo: yes  | Last login: 2h ago    | SSH keys: 2
  deploy    | Groups: docker, www-data       | Sudo: no   | Last login: 5d ago    | SSH keys: 1
  admin     | Groups: sudo, adm             | Sudo: yes  | Last login: 1h ago    | SSH keys: 3

⚠️  Warnings:
  - User 'deploy' has not logged in for 5 days
  - User 'admin' has 3 SSH keys (review recommended)
  - 2 users have passwordless sudo

System Users with Login Shell:
  (none — good!)

Users with Empty Passwords:
  (none — good!)
```

### Workflow 5: Disable/Lock a User

```bash
# Lock account (preserves data, prevents login)
sudo bash scripts/run.sh lock --username john

# Unlock account
sudo bash scripts/run.sh unlock --username john

# Fully remove user and home directory
sudo bash scripts/run.sh remove --username john --purge
```

### Workflow 6: Bulk Operations

```bash
# Create multiple users from a CSV file
sudo bash scripts/run.sh bulk-create --file users.csv

# CSV format: username,fullname,groups,shell,ssh_key
# john,John Doe,developers,/bin/bash,ssh-ed25519 AAAA...
# jane,Jane Smith,designers,/bin/bash,ssh-ed25519 BBBB...
```

### Workflow 7: Group Management

```bash
# Create a group
sudo bash scripts/run.sh group-create --name developers

# Add user to group
sudo bash scripts/run.sh group-add --username john --group developers

# Remove user from group
sudo bash scripts/run.sh group-remove --username john --group developers

# List group members
sudo bash scripts/run.sh group-list --name developers
```

## Configuration

### Environment Variables

```bash
# Default shell for new users (optional)
export USER_MGR_DEFAULT_SHELL="/bin/bash"

# Disable password login by default (SSH key only)
export USER_MGR_SSH_ONLY="true"

# Minimum UID for human users
export USER_MGR_MIN_UID="1000"

# Home directory base
export USER_MGR_HOME_BASE="/home"
```

## Advanced Usage

### Enforce SSH-Key-Only Login

```bash
# Disable password auth for a specific user
sudo bash scripts/run.sh enforce-ssh --username john

# This sets the password to '!' and ensures SSH key exists
```

### Set Password Expiry Policy

```bash
# Force password change every 90 days
sudo bash scripts/run.sh password-policy --username john \
  --max-days 90 --warn-days 14

# Check password status
sudo bash scripts/run.sh password-status --username john
```

### Export User List

```bash
# Export all users as JSON
sudo bash scripts/run.sh export --format json > users.json

# Export as CSV
sudo bash scripts/run.sh export --format csv > users.csv
```

## Troubleshooting

### Issue: "useradd: user already exists"

**Fix:** The username is taken. Check with:
```bash
id <username>
```

### Issue: "Permission denied"

**Fix:** Run with `sudo`. User management requires root privileges.

### Issue: SSH key not working after adding

**Check:**
```bash
# Verify permissions (must be strict)
ls -la /home/<user>/.ssh/
# authorized_keys should be 600, .ssh should be 700
```

The script automatically sets correct permissions, but if manually edited they may break.

### Issue: User can't sudo after granting

**Check:**
```bash
# Verify sudoers entry
sudo grep <username> /etc/sudoers /etc/sudoers.d/*
```

## Key Principles

1. **SSH-key-first** — Disable password login by default for security
2. **Audit trail** — Log all user operations to `/var/log/user-manager.log`
3. **Safe defaults** — Restricted permissions, no sudo by default
4. **Idempotent** — Running the same command twice won't break things
5. **Non-destructive** — Lock/disable preferred over delete

## Dependencies

- `bash` (4.0+)
- `useradd`, `usermod`, `userdel` (shadow-utils)
- `groupadd`, `groupmod` (shadow-utils)
- `ssh-keygen` (openssh)
- `chage` (password aging)
- `last` (login history)
- Root/sudo access required
