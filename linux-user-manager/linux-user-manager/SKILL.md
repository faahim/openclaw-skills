---
name: linux-user-manager
description: >-
  Manage Linux users, groups, sudo access, SSH keys, and password policies from a single CLI tool.
categories: [security, automation]
dependencies: [bash, useradd, usermod, groupadd, chage, passwd]
---

# Linux User Manager

## What This Does

Automate Linux user account management — create users, manage groups, configure sudo access, deploy SSH keys, enforce password policies, and audit login activity. Saves hours of manual `useradd`/`usermod` commands and prevents configuration mistakes.

**Example:** "Create a deploy user with sudo access, SSH key, and 90-day password expiry — in one command."

## Quick Start (2 minutes)

### 1. Make Scripts Executable

```bash
chmod +x scripts/user-manager.sh
```

### 2. Create Your First User

```bash
sudo bash scripts/user-manager.sh create \
  --username deploy \
  --shell /bin/bash \
  --groups sudo,docker \
  --ssh-key "ssh-ed25519 AAAA... user@host" \
  --password-expire 90
```

### 3. List All Users

```bash
bash scripts/user-manager.sh list
```

**Output:**
```
USERNAME    UID   GROUPS              SHELL        LAST LOGIN         PWD EXPIRES
deploy      1001  sudo,docker         /bin/bash    2026-03-08 10:30   2026-06-06
www-data    33    www-data            /usr/sbin/nologin  Never        Never
```

## Core Workflows

### Workflow 1: Create User with Full Setup

```bash
sudo bash scripts/user-manager.sh create \
  --username alice \
  --fullname "Alice Smith" \
  --shell /bin/bash \
  --groups sudo,developers \
  --ssh-key "ssh-ed25519 AAAA..." \
  --password-expire 90 \
  --home /home/alice
```

**What it does:**
1. Creates user with home directory
2. Sets shell and full name
3. Adds to specified groups (creates groups if missing)
4. Installs SSH key to `~alice/.ssh/authorized_keys`
5. Sets password expiry policy
6. Locks password login (SSH-key-only by default)

### Workflow 2: Manage Sudo Access

```bash
# Grant sudo
sudo bash scripts/user-manager.sh sudo --username alice --grant

# Grant passwordless sudo
sudo bash scripts/user-manager.sh sudo --username alice --grant --nopasswd

# Revoke sudo
sudo bash scripts/user-manager.sh sudo --username alice --revoke

# List sudoers
bash scripts/user-manager.sh sudo --list
```

### Workflow 3: SSH Key Management

```bash
# Add SSH key
sudo bash scripts/user-manager.sh ssh-key --username alice \
  --add "ssh-ed25519 AAAA... alice@laptop"

# List keys
bash scripts/user-manager.sh ssh-key --username alice --list

# Remove key (by comment or fingerprint)
sudo bash scripts/user-manager.sh ssh-key --username alice \
  --remove "alice@laptop"

# Deploy key from file
sudo bash scripts/user-manager.sh ssh-key --username alice \
  --add-file /path/to/id_ed25519.pub
```

### Workflow 4: Password Policy

```bash
# Set password expiry (days)
sudo bash scripts/user-manager.sh password --username alice --max-age 90

# Set minimum password age
sudo bash scripts/user-manager.sh password --username alice --min-age 7

# Force password change on next login
sudo bash scripts/user-manager.sh password --username alice --force-change

# Lock account (disable login)
sudo bash scripts/user-manager.sh password --username alice --lock

# Unlock account
sudo bash scripts/user-manager.sh password --username alice --unlock

# Show password policy
bash scripts/user-manager.sh password --username alice --info
```

**Output:**
```
Password Policy for alice:
  Last changed:     2026-03-08
  Expires:          2026-06-06 (90 days)
  Min age:          7 days
  Warning:          7 days before expiry
  Inactive:         30 days after expiry
  Account locked:   No
```

### Workflow 5: Group Management

```bash
# Create group
sudo bash scripts/user-manager.sh group --create developers

# Add user to group
sudo bash scripts/user-manager.sh group --add alice --to developers

# Remove user from group
sudo bash scripts/user-manager.sh group --remove alice --from developers

# List group members
bash scripts/user-manager.sh group --members developers

# List all groups
bash scripts/user-manager.sh group --list
```

### Workflow 6: Audit & Reporting

```bash
# Show login history
bash scripts/user-manager.sh audit --logins

# Show failed login attempts
bash scripts/user-manager.sh audit --failed

# Show users with expiring passwords (next 30 days)
bash scripts/user-manager.sh audit --expiring 30

# Show users with no login in N days
bash scripts/user-manager.sh audit --inactive 90

# Show users with sudo access
bash scripts/user-manager.sh audit --sudoers

# Full security report
bash scripts/user-manager.sh audit --full
```

**Full report output:**
```
=== Linux User Security Audit ===
Date: 2026-03-08 12:53:00 UTC

TOTAL USERS: 5 (3 human, 2 system)
SUDO USERS: 2 (alice, deploy)
LOCKED ACCOUNTS: 0
EXPIRING PASSWORDS (30d): 1 (deploy — expires 2026-03-25)
INACTIVE >90 DAYS: 1 (olduser — last login 2025-11-01)
USERS WITH NO PASSWORD: 0
USERS WITH SSH KEYS: 3

RECOMMENDATIONS:
⚠️  deploy: Password expires in 17 days — renew or extend
⚠️  olduser: Inactive 128 days — consider disabling
✅  All accounts have passwords or are locked
✅  No users with empty passwords detected
```

### Workflow 7: Bulk Operations

```bash
# Create users from CSV
sudo bash scripts/user-manager.sh bulk-create --file users.csv

# CSV format: username,fullname,shell,groups,ssh_key
# alice,Alice Smith,/bin/bash,sudo;developers,ssh-ed25519 AAAA...
# bob,Bob Jones,/bin/bash,developers,ssh-ed25519 BBBB...
```

### Workflow 8: Delete User

```bash
# Delete user (keep home directory)
sudo bash scripts/user-manager.sh delete --username alice

# Delete user and home directory
sudo bash scripts/user-manager.sh delete --username alice --remove-home

# Delete user, home, and reassign files to root
sudo bash scripts/user-manager.sh delete --username alice --remove-home --reassign
```

## Troubleshooting

### Issue: "Permission denied"

Most operations require `sudo`. Run with `sudo bash scripts/user-manager.sh ...`

### Issue: "User already exists"

The script won't overwrite existing users. Use `modify` subcommand instead:
```bash
sudo bash scripts/user-manager.sh modify --username alice --add-groups docker
```

### Issue: SSH key not working

Check:
1. Permissions: `~user/.ssh` must be `700`, `authorized_keys` must be `600`
2. Ownership: Must be owned by the user
3. SELinux: Run `restorecon -Rv ~user/.ssh` if on RHEL/CentOS

The script sets correct permissions automatically.

### Issue: "chage: command not found"

Install shadow utilities:
```bash
# Debian/Ubuntu
sudo apt-get install passwd

# RHEL/CentOS
sudo yum install shadow-utils
```

## Dependencies

- `bash` (4.0+)
- `useradd` / `usermod` / `userdel` (shadow-utils / passwd package)
- `groupadd` / `groupmod` / `groupdel`
- `chage` (password aging)
- `last` / `lastb` (login auditing)
- `getent` (user/group lookups)
- Optional: `sudo` (for sudoers management)
- Optional: `jq` (for JSON output mode)

All dependencies are pre-installed on most Linux distributions.

## Key Principles

1. **Safe by default** — SSH-key-only auth, locked passwords unless explicitly set
2. **Idempotent** — Running the same command twice won't break anything
3. **Audit trail** — All changes logged to `/var/log/user-manager.log`
4. **No surprises** — Shows what will happen before doing it (use `--dry-run`)
