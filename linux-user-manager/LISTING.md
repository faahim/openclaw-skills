# Listing Copy: Linux User Manager

## Metadata
- **Type:** Skill
- **Name:** linux-user-manager
- **Display Name:** Linux User Manager
- **Categories:** [security, automation]
- **Price:** $8
- **Dependencies:** [bash, useradd, usermod, groupadd, chage]
- **Icon:** 👤

## Tagline

Manage Linux users, groups, SSH keys, and password policies from one script

## Description

Managing users on Linux servers shouldn't mean memorizing a dozen commands and their flags. Every time you set up a new VPS, onboard a team member, or do a security audit, you're running the same tedious useradd/usermod/chage commands. Miss a step — like setting proper SSH key permissions — and you've got a security hole.

Linux User Manager wraps all user administration into a single script. Create users with home dirs, shells, group memberships, SSH keys, and password policies in one command. Run security audits that show who has sudo access, whose passwords never expire, and who hasn't logged in for weeks. Lock/unlock accounts, manage groups, bulk-create users from CSV, and track sudo activity.

**What it does:**
- 👤 Create/remove users with full setup (home, shell, groups, SSH, password policy)
- 🔑 Deploy and manage SSH authorized keys with correct permissions
- 🔍 Security audit: sudo users, password expiry, login history, locked accounts
- 👥 Group management: create, add/remove members, list
- 📋 Bulk user creation from CSV
- 🔒 Lock/unlock accounts, expire inactive users
- 📊 Sudo activity log viewer
- ⏰ Password aging policy enforcement

Zero external dependencies — uses only built-in Linux tools (shadow-utils, passwd, chage). Works on any Linux distribution.

## Core Capabilities

1. User creation — Full setup with home dir, shell, groups, SSH key in one command
2. SSH key management — Add/list/remove authorized keys with correct permissions
3. Security audit — Complete user access report with warnings for issues
4. Group management — Create groups, manage memberships
5. Password policy — Enforce expiry, minimum age, warning periods
6. Bulk operations — Create multiple users from CSV file
7. Account locking — Temporarily disable/enable user access
8. Inactive user expiry — Auto-lock users who haven't logged in for N days
9. Sudo activity — View recent sudo command history
10. User info — Detailed view of any user's status and configuration

## Installation Time
**2 minutes** — Copy script, run with sudo
