---
name: ngrok-tunnel
description: >-
  Expose local services to the internet with ngrok — manage tunnels, inspect traffic, and configure custom domains from the terminal.
categories: [dev-tools, automation]
dependencies: [bash, curl, jq]
---

# Ngrok Tunnel Manager

## What This Does

Installs and manages ngrok tunnels to expose local services (web servers, APIs, databases) to the public internet. Start tunnels, list active sessions, inspect request/response traffic, configure auth and custom domains — all from the command line.

**Example:** "Expose my local dev server on port 3000 to the internet with HTTPS and basic auth."

## Quick Start (5 minutes)

### 1. Install ngrok

```bash
# Linux (amd64)
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok-v3-stable-linux-amd64.tgz | tar xz -C /usr/local/bin

# Linux (arm64)
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok-v3-stable-linux-arm64.tgz | tar xz -C /usr/local/bin

# Mac
brew install ngrok/ngrok/ngrok

# Verify
ngrok version
```

### 2. Authenticate

```bash
# Get your auth token from https://dashboard.ngrok.com/get-started/your-authtoken
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

### 3. Start Your First Tunnel

```bash
# Expose local port 3000
bash scripts/tunnel.sh start --port 3000

# Output:
# ✅ Tunnel started
# 🌐 Public URL: https://abc123.ngrok-free.app
# 📊 Inspector: http://127.0.0.1:4040
```

## Core Workflows

### Workflow 1: Expose a Local Web Server

**Use case:** Share your dev server with a teammate or test webhooks

```bash
bash scripts/tunnel.sh start --port 3000
```

**Output:**
```
✅ Tunnel started
🌐 https://abc123.ngrok-free.app → http://localhost:3000
📊 Inspect traffic at http://127.0.0.1:4040
```

### Workflow 2: Expose with Basic Auth

**Use case:** Protect your tunnel with a username/password

```bash
bash scripts/tunnel.sh start --port 8080 --auth "user:password"
```

### Workflow 3: TCP Tunnel (SSH, Database, etc.)

**Use case:** Expose SSH or a database port

```bash
bash scripts/tunnel.sh start --port 22 --proto tcp
```

**Output:**
```
✅ TCP tunnel started
🌐 tcp://0.tcp.ngrok.io:12345 → localhost:22
```

### Workflow 4: Custom Domain

**Use case:** Use your own domain instead of random ngrok URL

```bash
bash scripts/tunnel.sh start --port 3000 --domain myapp.ngrok-free.app
```

### Workflow 5: List Active Tunnels

```bash
bash scripts/tunnel.sh list
```

**Output:**
```
Active Tunnels:
  1. https://abc123.ngrok-free.app → localhost:3000 (http)
  2. tcp://0.tcp.ngrok.io:12345 → localhost:22 (tcp)
```

### Workflow 6: Inspect Traffic

**Use case:** Debug webhooks by viewing request/response payloads

```bash
# View last 20 requests
bash scripts/tunnel.sh inspect --limit 20

# Output:
# [12:00:01] POST /webhook 200 (23ms) — 1.2KB
# [12:00:05] GET /api/health 200 (5ms) — 48B
# [12:00:12] POST /webhook 500 (150ms) — 256B ⚠️
```

### Workflow 7: Stop Tunnels

```bash
# Stop all tunnels
bash scripts/tunnel.sh stop

# Stop specific tunnel
bash scripts/tunnel.sh stop --name myapp
```

### Workflow 8: Replay Requests

**Use case:** Re-send a failed webhook for debugging

```bash
bash scripts/tunnel.sh replay --id req_abc123
```

## Configuration

### Environment Variables

```bash
# Required
export NGROK_AUTHTOKEN="your-auth-token"

# Optional: default settings
export NGROK_DEFAULT_PORT="3000"
export NGROK_DEFAULT_REGION="us"   # us, eu, ap, au, sa, jp, in
```

### Config File (~/.config/ngrok/ngrok.yml)

```yaml
version: "3"
agent:
  authtoken: YOUR_TOKEN

tunnels:
  webapp:
    proto: http
    addr: 3000
    inspect: true

  api:
    proto: http
    addr: 8080
    basic_auth:
      - "admin:secret"

  ssh:
    proto: tcp
    addr: 22

  database:
    proto: tcp
    addr: 5432
```

### Start Named Tunnels from Config

```bash
# Start specific tunnel
bash scripts/tunnel.sh start --name webapp

# Start all tunnels from config
bash scripts/tunnel.sh start --all
```

## Advanced Usage

### Webhook Testing with Replay

```bash
# 1. Start tunnel
bash scripts/tunnel.sh start --port 3000

# 2. Send a webhook (from external service)

# 3. View captured requests
bash scripts/tunnel.sh inspect

# 4. Replay a specific request
bash scripts/tunnel.sh replay --id req_abc123
```

### Multiple Tunnels Simultaneously

```bash
# Start multiple tunnels
bash scripts/tunnel.sh start --port 3000 --name frontend &
bash scripts/tunnel.sh start --port 8080 --name api &

# List all
bash scripts/tunnel.sh list
```

### Run as Background Service

```bash
# Start in background
bash scripts/tunnel.sh start --port 3000 --background

# Check status
bash scripts/tunnel.sh status

# View logs
bash scripts/tunnel.sh logs
```

### IP Restriction

```bash
# Only allow specific IPs
bash scripts/tunnel.sh start --port 3000 --cidr-allow "1.2.3.4/32,10.0.0.0/8"
```

## Troubleshooting

### Issue: "ERR_NGROK_108 — authtoken not found"

**Fix:**
```bash
ngrok config add-authtoken YOUR_TOKEN
# Or set env var:
export NGROK_AUTHTOKEN="YOUR_TOKEN"
```

### Issue: "ERR_NGROK_8012 — tunnel session limit"

**Cause:** Free plan allows 1 agent session. You have another ngrok running.

**Fix:**
```bash
# Kill existing sessions
pkill ngrok
# Then start fresh
bash scripts/tunnel.sh start --port 3000
```

### Issue: "address already in use" on inspector port

**Fix:**
```bash
# Use a different inspect port
ngrok http 3000 --inspect=false
# Or kill existing ngrok processes
pkill ngrok
```

### Issue: Tunnel URL changes on restart

**Fix:** Use a static domain (requires paid plan or free static domain):
```bash
bash scripts/tunnel.sh start --port 3000 --domain your-app.ngrok-free.app
```

## Key Principles

1. **One command** — Start exposing in seconds
2. **Inspect everything** — See every request/response
3. **Replay requests** — Debug webhooks without re-triggering
4. **Secure by default** — HTTPS, auth, IP restrictions
5. **Background ready** — Run as a persistent service

## Dependencies

- `bash` (4.0+)
- `curl` (for install + API calls)
- `jq` (for JSON parsing)
- `ngrok` (installed by this skill)
