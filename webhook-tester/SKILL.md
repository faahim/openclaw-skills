---
name: webhook-tester
description: >-
  Capture, inspect, and replay incoming webhooks with a lightweight local HTTP server.
categories: [dev-tools, automation]
dependencies: [python3, curl, jq]
---

# Webhook Tester

## What This Does

Spins up a lightweight HTTP server that captures incoming webhook payloads, logs headers and body, and lets you replay them. Perfect for debugging integrations with Stripe, GitHub, Slack, Twilio, or any service that sends webhooks.

**Example:** "Start a webhook endpoint on port 9876, send a test Stripe event to it, inspect the payload, then replay it against your local dev server."

## Quick Start (2 minutes)

### 1. Start Capturing Webhooks

```bash
# Start the webhook capture server on port 9876
python3 scripts/server.py --port 9876

# Output:
# 🔗 Webhook Tester listening on http://0.0.0.0:9876
# 📁 Payloads saved to ./webhooks/
# Press Ctrl+C to stop
```

### 2. Send a Test Webhook

```bash
# From another terminal — simulate a webhook
curl -X POST http://localhost:9876/stripe/payment \
  -H "Content-Type: application/json" \
  -H "X-Stripe-Signature: t=123,v1=abc" \
  -d '{"type":"payment_intent.succeeded","data":{"amount":2000}}'

# Server output:
# [2026-02-22 12:00:00] POST /stripe/payment — 200 (application/json, 68 bytes)
#   Headers: X-Stripe-Signature: t=123,v1=abc
#   Body: {"type":"payment_intent.succeeded","data":{"amount":2000}}
#   Saved: webhooks/001_stripe_payment_20260222_120000.json
```

### 3. Inspect Captured Webhooks

```bash
# List all captured webhooks
bash scripts/inspect.sh list

# Output:
# #  | Time                | Method | Path             | Size   | Content-Type
# 1  | 2026-02-22 12:00:00 | POST   | /stripe/payment  | 68 B   | application/json
# 2  | 2026-02-22 12:01:00 | POST   | /github/push     | 1.2 KB | application/json

# View a specific webhook
bash scripts/inspect.sh show 1

# Outputs full headers + pretty-printed body
```

### 4. Replay a Webhook

```bash
# Replay webhook #1 against your local dev server
bash scripts/replay.sh 1 http://localhost:3000/api/webhooks/stripe

# Output:
# 🔄 Replaying webhook #1 → http://localhost:3000/api/webhooks/stripe
# Response: 200 OK (45ms)
```

## Core Workflows

### Workflow 1: Debug Stripe Webhooks

```bash
# 1. Start capture server
python3 scripts/server.py --port 9876 &

# 2. Point Stripe CLI to your server
# stripe listen --forward-to http://localhost:9876/stripe

# 3. Trigger a test event
# stripe trigger payment_intent.succeeded

# 4. Inspect what Stripe sent
bash scripts/inspect.sh show latest
```

### Workflow 2: Compare Webhook Payloads

```bash
# Diff two captured webhooks (useful for debugging changes)
bash scripts/inspect.sh diff 1 2
```

### Workflow 3: Run as Background Daemon

```bash
# Start in background with auto-rotation (keeps last 500 webhooks)
python3 scripts/server.py --port 9876 --max-keep 500 --daemon

# Check status
bash scripts/inspect.sh status

# Stop daemon
bash scripts/inspect.sh stop
```

### Workflow 4: Filter by Path or Header

```bash
# List only Stripe webhooks
bash scripts/inspect.sh list --path "/stripe"

# List only webhooks with specific header
bash scripts/inspect.sh list --header "X-GitHub-Event"
```

### Workflow 5: Export for Sharing

```bash
# Export webhook as a curl command (for teammates)
bash scripts/inspect.sh export 1

# Output:
# curl -X POST http://localhost:9876/stripe/payment \
#   -H "Content-Type: application/json" \
#   -H "X-Stripe-Signature: t=123,v1=abc" \
#   -d '{"type":"payment_intent.succeeded","data":{"amount":2000}}'
```

## Configuration

### Environment Variables

```bash
# Default port (override with --port)
export WEBHOOK_TESTER_PORT=9876

# Storage directory (override with --dir)
export WEBHOOK_TESTER_DIR="./webhooks"

# Max webhooks to keep (override with --max-keep)
export WEBHOOK_TESTER_MAX_KEEP=1000

# Auto-respond with custom status code
export WEBHOOK_TESTER_RESPONSE_CODE=200
```

### Response Customization

```bash
# Return 201 instead of 200
python3 scripts/server.py --port 9876 --response-code 201

# Return custom body
python3 scripts/server.py --port 9876 --response-body '{"ok":true}'

# Simulate slow responses (test timeout handling)
python3 scripts/server.py --port 9876 --delay 3000
```

## Advanced Usage

### Route-Specific Responses

```bash
# Configure different responses per path
python3 scripts/server.py --port 9876 \
  --route "/stripe:200:ok" \
  --route "/github:202:accepted" \
  --route "/slack:200:{\"challenge\":\"test\"}"
```

### Webhook Validation

```bash
# Verify Stripe webhook signatures
bash scripts/inspect.sh verify-stripe 1 --secret whsec_xxx

# Verify GitHub webhook signatures
bash scripts/inspect.sh verify-github 1 --secret ghsec_xxx
```

### Expose via Tunnel (for remote testing)

```bash
# If you have Tailscale or ngrok:
# ngrok http 9876
# Then use the public URL as your webhook endpoint
```

## Troubleshooting

### Issue: "Address already in use"

```bash
# Find what's using the port
lsof -i :9876
# Kill it or use a different port
python3 scripts/server.py --port 9877
```

### Issue: Webhooks not arriving

1. Check firewall: `sudo ufw status`
2. Check server is running: `bash scripts/inspect.sh status`
3. Test locally: `curl -X POST http://localhost:9876/test -d "hello"`

### Issue: Large payloads truncated in logs

```bash
# Increase log truncation limit
python3 scripts/server.py --port 9876 --max-log-body 50000
```

## Dependencies

- `python3` (3.8+ — uses only stdlib: http.server, json, os, sys)
- `curl` (for replay)
- `jq` (for pretty-printing JSON)
- No pip packages required

## Key Principles

1. **Zero dependencies** — Python stdlib only, no pip install needed
2. **Everything saved** — Every webhook persisted to disk as JSON
3. **Replayable** — Any captured webhook can be replayed anywhere
4. **Non-destructive** — Always responds 200 OK (configurable) so webhooks aren't retried
