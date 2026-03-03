# Listing Copy: Mailpit Email Testing Server

## Metadata
- **Type:** Skill
- **Name:** mailpit-server
- **Display Name:** Mailpit Email Testing Server
- **Categories:** [dev-tools, communication]
- **Icon:** 📧
- **Dependencies:** [curl, bash]

## Tagline

"Local SMTP server for dev — capture, view, and debug emails without sending them"

## Description

Stop sending test emails to real inboxes. Mailpit is a lightweight local SMTP server that captures every outgoing email from your app during development. View them in a clean web UI with full HTML rendering, attachment support, and spam score checking.

**One command to install, one to start.** Point your app's SMTP config at `localhost:1025` and every email your app sends gets captured — never reaching real recipients. View them all at `http://localhost:8025`.

**What it does:**
- 📧 Captures all SMTP emails locally — no real delivery
- 🖥️ Clean web UI with HTML preview, source view, and headers
- 📎 Full attachment support — view and download
- 🔍 Search and filter captured messages
- 🔄 Optional SMTP relay — capture AND forward to real SMTP
- 🐳 Docker support — add to docker-compose in 3 lines
- 🔌 REST API — query captured emails in automated tests
- ⚡ Single binary — no runtime dependencies, instant start

**Perfect for:** Backend developers, full-stack teams, QA testers, anyone building apps that send email (signup flows, password resets, notifications, reports).

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Start
bash scripts/run.sh start
# ✅ SMTP: localhost:1025 | Web: http://localhost:8025

# Send test email
bash scripts/run.sh test
# ✅ Check http://localhost:8025 — your email is there!
```
