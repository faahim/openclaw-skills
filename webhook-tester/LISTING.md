# Listing Copy: Webhook Tester

## Metadata
- **Type:** Skill
- **Name:** webhook-tester
- **Display Name:** Webhook Tester
- **Categories:** [dev-tools, automation]
- **Price:** $10
- **Dependencies:** [python3, curl, jq]

## Tagline

Capture, inspect, and replay incoming webhooks — debug integrations in seconds

## Description

Debugging webhooks from Stripe, GitHub, Slack, or Twilio is painful. You change an endpoint, trigger an event, wait, check logs, realize the payload format changed, and do it all again. You need a way to see exactly what's coming in.

Webhook Tester spins up a zero-dependency HTTP server (Python stdlib only) that captures every incoming webhook to disk as structured JSON. Inspect headers and payloads, diff two webhooks, replay any captured request against your dev server, verify Stripe and GitHub signatures, and export as curl commands for your teammates.

**What it does:**
- 🔗 Capture webhooks on any port — all HTTP methods supported
- 📁 Auto-save every payload as structured JSON
- 🔍 Inspect, filter, diff, and search captured webhooks
- 🔄 Replay any webhook against any URL with one command
- 🔐 Verify Stripe and GitHub webhook signatures
- 📋 Export as curl commands for sharing
- ⚡ Route-specific responses (different status codes per path)
- ⏱️ Simulate slow responses to test timeout handling
- 🚀 Daemon mode with auto-rotation
- 🌐 CORS-ready for browser testing

## Quick Start Preview

```bash
python3 scripts/server.py --port 9876
# → 🔗 Webhook Tester listening on http://0.0.0.0:9876

bash scripts/inspect.sh show latest
# → Full headers + pretty-printed body

bash scripts/replay.sh 1 http://localhost:3000/api/webhooks
# → 🔄 Replaying webhook #1 → Response: 200 OK (45ms)
```

## Dependencies
- `python3` (3.8+ — stdlib only, no pip packages)
- `curl` (for replay)
- `jq` (for JSON display)

## Installation Time
**2 minutes** — No installation needed, just run the Python server
