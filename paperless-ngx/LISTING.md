# Listing Copy: Paperless-ngx Document Manager

## Metadata
- **Type:** Skill
- **Name:** paperless-ngx
- **Display Name:** Paperless-ngx Document Manager
- **Categories:** [data, productivity]
- **Price:** $15
- **Dependencies:** [docker, docker-compose, curl, jq]
- **Icon:** 📄

## Tagline

Deploy and manage Paperless-ngx — self-hosted OCR document management with full-text search

## Description

Tired of losing documents in folder hierarchies or trusting sensitive files to cloud services? Paperless-ngx is the most popular self-hosted document management system (19k+ GitHub stars), and this skill automates everything from deployment to daily management.

**One command deploys a full Paperless-ngx stack** — PostgreSQL, Redis, OCR engine, and web UI — via Docker Compose. Then manage your entire document library through the CLI: upload files, search by content, auto-tag with rules, manage correspondents, and schedule nightly backups.

**What it does:**
- 🚀 One-command Docker deployment with sensible defaults
- 📄 Upload and OCR documents (PDF, PNG, JPG, DOCX, and more)
- 🔍 Full-text search across all documents
- 🏷️ Auto-tagging rules (regex, fuzzy match, exact)
- 👥 Multi-user support with permissions
- 💾 Automated backups with configurable retention
- 📊 Health monitoring and queue management
- 🔄 One-command updates to latest version

**Perfect for** developers, sysadmins, and privacy-conscious users who want Google Drive-level document search on their own hardware.

## Core Capabilities

1. Docker deployment — Full stack (Postgres + Redis + Paperless) in one command
2. OCR processing — Automatic text extraction from scans in 100+ languages
3. Document search — Full-text search across all uploaded documents
4. Auto-tagging — Create rules to automatically categorize incoming documents
5. API management — Search, tag, download, and organize via CLI
6. Backup automation — Scheduled backups with retention policies
7. Health monitoring — Check container status, queue depth, disk usage
8. Bulk import — Drop a folder of documents for batch processing
9. Multi-user — Add users with granular permissions
10. Self-hosted — Everything runs locally, zero cloud dependency

## Installation Time
**10 minutes** — Run install script, start using immediately
