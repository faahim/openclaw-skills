---
name: tmate-session-sharing
description: >-
  Share terminal sessions instantly for pair programming, debugging, and remote support using tmate.
categories: [dev-tools, communication]
dependencies: [tmate, tmux]
---

# tmate Session Sharing

## What This Does

Share your terminal with anyone via a secure SSH connection — no port forwarding, no firewall config. Uses [tmate](https://tmate.io/) (a fork of tmux) to create instant, shareable terminal sessions with read-only or read-write access.

**Example:** "Start a shared terminal, send the SSH link to a colleague, debug together in real-time."

## Quick Start (2 minutes)

### 1. Install tmate

```bash
bash scripts/install.sh
```

### 2. Start a Shared Session

```bash
bash scripts/run.sh start
```

**Output:**
```
🔗 tmate session started!

Read-Write (full access):
  SSH:  ssh <random>@nyc1.tmate.io
  Web:  https://tmate.io/t/<token>

Read-Only (view only):
  SSH:  ssh ro-<random>@nyc1.tmate.io
  Web:  https://tmate.io/t/<ro-token>

Share the appropriate link with your collaborator.
Session log: /tmp/tmate-session.log
```

### 3. Share the Link

Send the SSH or web URL to whoever needs access. They connect instantly — no setup needed on their end.

### 4. End the Session

```bash
bash scripts/run.sh stop
```

## Core Workflows

### Workflow 1: Quick Pair Programming Session

**Use case:** Share your terminal for live coding

```bash
# Start session
bash scripts/run.sh start

# Copy the read-write SSH link and send to your pair
# They run: ssh <session-id>@nyc1.tmate.io
# Both of you see the same terminal, can type commands

# When done
bash scripts/run.sh stop
```

### Workflow 2: Read-Only Demo/Support

**Use case:** Let someone watch your terminal without giving control

```bash
# Start session
bash scripts/run.sh start

# Share ONLY the read-only link
# Viewer can see everything but cannot type

bash scripts/run.sh stop
```

### Workflow 3: Named Session with API Key

**Use case:** Persistent, named sessions (requires tmate.io API key or self-hosted server)

```bash
# Set up named session
export TMATE_API_KEY="your-api-key"
bash scripts/run.sh start --name "debug-session-42"

# Others connect via the named session
# ssh <name>@nyc1.tmate.io
```

### Workflow 4: Auto-Expiring Session

**Use case:** Session that closes after a timeout

```bash
# Start session that expires in 30 minutes
bash scripts/run.sh start --timeout 30

# Session auto-terminates after 30 min
```

### Workflow 5: Session with Notification

**Use case:** Get a Telegram alert with session links

```bash
# Start session and notify via Telegram
bash scripts/run.sh start --notify telegram

# Bot sends you the session links
```

### Workflow 6: Check Session Status

```bash
bash scripts/run.sh status

# Output:
# ✅ tmate session active (PID: 12345)
# Started: 2026-03-02 07:30:00
# Duration: 15 minutes
# Read-Write: ssh abc123@nyc1.tmate.io
# Read-Only:  ssh ro-abc123@nyc1.tmate.io
```

## Configuration

### Environment Variables

```bash
# Optional: Telegram alerts for session links
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Optional: Custom tmate server (self-hosted)
export TMATE_SERVER_HOST="tmate.example.com"
export TMATE_SERVER_PORT="22"
export TMATE_SERVER_RSA_FINGERPRINT="SHA256:..."
export TMATE_SERVER_ED25519_FINGERPRINT="SHA256:..."

# Optional: tmate API key for named sessions
export TMATE_API_KEY="<your-key>"
```

### Custom tmate.conf

```bash
# Create ~/.tmate.conf for persistent settings
cat > ~/.tmate.conf << 'EOF'
# Use custom server
set -g tmate-server-host "tmate.example.com"
set -g tmate-server-port 22

# Set display name
set -g tmate-display-name "my-session"

# Auto-start in detached mode
set -g tmate-foreground-restart 0
EOF
```

## Advanced Usage

### Self-Hosted tmate Server (Docker)

For full control, run your own tmate server:

```bash
bash scripts/self-host.sh setup

# This runs:
# docker run -d --name tmate-server \
#   -p 2222:2222 \
#   -v tmate-keys:/etc/tmate-ssh-server-keys \
#   tmate/tmate-ssh-server
```

### Run Command in Shared Session

```bash
# Start session and run a specific command
bash scripts/run.sh start --cmd "htop"

# Viewers see htop running
```

### List All Active Sessions

```bash
bash scripts/run.sh list

# Output:
# PID    Started              Session ID
# 12345  2026-03-02 07:30:00  abc123
# 12346  2026-03-02 08:00:00  def456
```

## Troubleshooting

### Issue: "tmate: command not found"

**Fix:** Run the install script:
```bash
bash scripts/install.sh
```

### Issue: Session starts but no links shown

**Fix:** Wait 2-3 seconds for tmate to connect. Check:
```bash
cat /tmp/tmate-session.log
```

### Issue: Connection refused on custom server

**Fix:** Check server fingerprints in `~/.tmate.conf` match your server's actual keys:
```bash
ssh-keygen -lf /path/to/tmate-ssh-server-keys/ssh_host_rsa_key.pub
```

### Issue: tmux conflicts

**Fix:** tmate uses its own socket, shouldn't conflict. If it does:
```bash
# Kill existing tmux sessions first
tmux kill-server
# Then start tmate
bash scripts/run.sh start
```

## Dependencies

- `tmate` (installed by scripts/install.sh)
- `tmux` (usually pre-installed, tmate depends on it)
- `curl` (for Telegram notifications, optional)
- `docker` (for self-hosted server, optional)

## Key Principles

1. **Instant sharing** — One command to start, share a link, done
2. **Secure by default** — SSH encrypted, unique session IDs
3. **Read-only option** — Share without giving control
4. **No port forwarding** — Works through NAT/firewalls
5. **Self-hostable** — Run your own server for full control
