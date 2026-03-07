# Listing Copy: Matrix Synapse Manager

## Metadata
- **Type:** Skill
- **Name:** matrix-synapse
- **Display Name:** Matrix Synapse Manager
- **Categories:** [communication, home]
- **Price:** $15
- **Dependencies:** [docker, curl, jq]
- **Icon:** 💬

## Tagline

Deploy and manage a self-hosted Matrix chat server — encrypted messaging you control

## Description

Running your own chat server shouldn't require a DevOps team. Matrix Synapse Manager lets your OpenClaw agent deploy, configure, and maintain a fully-featured Matrix homeserver with a single command.

Matrix is a decentralized, end-to-end encrypted communication protocol used by governments, enterprises, and privacy-conscious teams worldwide. With this skill, your agent handles the entire lifecycle: Docker deployment with PostgreSQL and Nginx, user registration and management, room creation, federation configuration, health monitoring, backups, and database maintenance.

**What it does:**
- 🚀 One-command deployment with Docker Compose (Synapse + PostgreSQL + Nginx)
- 👥 Full user management — register, deactivate, reset passwords, list users
- 💬 Room management — create public/private rooms, list, delete, purge history
- 🌐 Federation support — connect with the wider Matrix network, test federation health
- 📊 Built-in health monitoring — server status, memory, database size, uptime
- 💾 Automated backup & restore — full data + database dumps
- 🔧 Database maintenance — purge old messages, vacuum, compress state tables
- 🔐 E2E encryption enabled by default for all private communications

Perfect for homelab enthusiasts, privacy-focused teams, and anyone who wants Slack-like chat without giving up control of their data.

## Core Capabilities

1. Docker Compose deployment — Synapse + PostgreSQL + Nginx in one command
2. User lifecycle management — register, list, deactivate, password resets
3. Room administration — create, list, delete, configure visibility
4. Federation testing — verify DNS, .well-known, SRV records, connectivity
5. Health monitoring — version, uptime, memory, database size, federation status
6. Automated backups — full data export with PostgreSQL dump support
7. Message purging — clean old messages by age (days) across all rooms
8. Database optimization — vacuum SQLite, compress state tables
9. Nginx reverse proxy — auto-generated config with SSL termination
10. Bridge support — connect Telegram, Discord, IRC to your Matrix server

## Dependencies
- `docker` (20.10+) with `docker compose`
- `curl`
- `jq`

## Installation Time
**10 minutes** — generate config, start containers, register first user
