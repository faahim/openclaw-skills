# Listing Copy: Vikunja Manager

## Metadata
- **Type:** Skill
- **Name:** vikunja-manager
- **Display Name:** Vikunja Task Manager
- **Categories:** [productivity, automation]
- **Icon:** ✅
- **Price:** $12
- **Dependencies:** [docker, curl, jq]

## Tagline

Deploy a self-hosted task manager — Kanban boards, CalDAV sync, and full API control

## Description

Manually tracking tasks across scattered apps is chaotic. You lose context switching between Trello, Todoist, and sticky notes — and you're paying monthly for features you barely use.

**Vikunja Manager** deploys a full-featured, self-hosted Vikunja instance in 5 minutes. Get Kanban boards, list views, Gantt charts, CalDAV calendar sync, file attachments, labels, priorities, and team collaboration — all on your own server with zero monthly fees.

**What it does:**
- 🚀 One-command deploy (Docker) with SQLite or PostgreSQL
- 📋 Kanban boards, lists, Gantt charts, and calendar views
- 📅 CalDAV sync with any calendar app (Thunderbird, Apple Calendar, DAVx5)
- 🔌 Full REST API for automation (create projects, tasks, labels via CLI)
- 💾 Automated backup & restore scripts
- 🔄 Easy updates (pull latest image, restart)
- 🔐 OpenID Connect / SSO support
- 📧 Email notifications (SMTP)

Perfect for developers, teams, and anyone who wants powerful task management without vendor lock-in.

## Quick Start Preview

```bash
# Deploy Vikunja
bash scripts/install.sh

# Manage
bash scripts/manage.sh status
bash scripts/manage.sh health
bash scripts/manage.sh update

# Backup
bash scripts/backup.sh
```

## Core Capabilities

1. One-command deployment — Docker Compose with SQLite or PostgreSQL
2. Kanban boards — Drag-and-drop task management
3. CalDAV sync — Bidirectional calendar sync with any CalDAV client
4. REST API — Full CRUD for projects, tasks, labels, teams
5. Automated backups — Scheduled backup with retention cleanup
6. Container management — Status, logs, update, restart commands
7. Email notifications — SMTP integration for task reminders
8. SSO support — OpenID Connect authentication
9. File attachments — Attach files to tasks
10. Multi-user — Team collaboration with shared projects

## Dependencies
- `docker` (with compose plugin)
- `curl`
- `jq`
- `openssl`

## Installation Time
**5 minutes**
