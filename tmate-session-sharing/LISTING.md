# Listing Copy: tmate Session Sharing

## Metadata
- **Type:** Skill
- **Name:** tmate-session-sharing
- **Display Name:** tmate Session Sharing
- **Categories:** [dev-tools, communication]
- **Price:** $8
- **Icon:** 🖥️
- **Dependencies:** [tmate, tmux]

## Tagline

Share terminal sessions instantly — pair program, debug, and demo in real-time

## Description

Sharing your terminal with a colleague shouldn't require VPNs, port forwarding, or screen-sharing tools that add lag. It should be one command.

tmate Session Sharing installs and manages [tmate](https://tmate.io/) — a secure, instant terminal sharing tool built on tmux. Start a session, get an SSH link, share it. Your collaborator connects in seconds from anywhere, through any NAT or firewall.

**What it does:**
- 🚀 One-command session start with shareable SSH/web links
- 🔒 Read-only mode for demos and support (viewer can't type)
- ⏱️ Auto-expiring sessions with configurable timeouts
- 📱 Telegram notifications with session links
- 🐳 Self-hosted server option via Docker for full control
- 📋 Session management — start, stop, status, list active sessions

Perfect for developers who pair program, sysadmins doing remote debugging, or anyone who needs to share their terminal without the overhead of a video call.

## Quick Start Preview

```bash
# Install tmate
bash scripts/install.sh

# Start a shared session
bash scripts/run.sh start

# Output:
# 🔗 tmate session started!
# Read-Write:  ssh abc123@nyc1.tmate.io
# Read-Only:   ssh ro-abc123@nyc1.tmate.io
```

## Core Capabilities

1. Instant session sharing — One command, get SSH link, share it
2. Read-write access — Full collaborative terminal control
3. Read-only access — Safe viewing for demos and support
4. Web access — Browser-based terminal view (no SSH client needed)
5. Auto-timeout — Sessions expire after configurable duration
6. Telegram alerts — Get session links sent to your phone
7. Self-hosted server — Run your own tmate server via Docker
8. Named sessions — Persistent session names with API keys
9. Session management — Start, stop, status, list commands
10. Cross-platform — Works on Linux, macOS, any SSH client connects

## Dependencies
- `tmate` (auto-installed by install.sh)
- `tmux` (tmate dependency)
- `curl` (optional, for Telegram alerts)
- `docker` (optional, for self-hosted server)

## Installation Time
**2 minutes** — Run install script, start sharing

## Pricing Justification
**Why $8:** Simple utility, low complexity, high convenience. Comparable to free tmate but adds session management, notifications, self-hosting automation, and OpenClaw-native integration.
