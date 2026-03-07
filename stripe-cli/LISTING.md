# Listing Copy: Stripe CLI Manager

## Metadata
- **Type:** Skill
- **Name:** stripe-cli
- **Display Name:** Stripe CLI Manager
- **Categories:** [dev-tools, finance]
- **Price:** $10
- **Dependencies:** [bash, curl]

## Tagline

"Install & manage the Stripe CLI — webhook forwarding, event testing, and payment monitoring"

## Description

Setting up Stripe webhook testing locally is painful. You need to install the CLI, configure authentication, set up forwarding to the right port and endpoint, and remember the right commands for triggering test events. Every time you switch projects, you're back to the docs.

Stripe CLI Manager handles all of it. One script installs the CLI on any platform (Linux apt/yum, macOS Homebrew, or direct binary). The webhook forwarder wraps `stripe listen` with sensible defaults, event filtering, and automatic logging. Trigger test events, tail API logs, manage resources, and run fixture-based test scenarios — all through clear, copy-paste workflows.

**What it does:**
- 🔧 Cross-platform installation (Linux, macOS, ARM64)
- 🔗 Webhook forwarding with event filtering and logging
- ⚡ Test event triggering (checkout, payments, subscriptions)
- 📊 Real-time API log tailing with status/path filters
- 🧪 Fixture-based multi-step test scenarios
- 🔍 Health check for CLI, auth, and API connectivity
- 🔌 Stripe Connect webhook support

Perfect for developers building payment integrations, SaaS billing, or marketplace platforms with Stripe.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Forward webhooks to your dev server
bash scripts/webhook-forward.sh --port 3000

# Trigger a test event
stripe trigger checkout.session.completed
```

## Core Capabilities

1. Cross-platform install — Linux (apt, yum, binary), macOS (Homebrew, binary), ARM64 support
2. Webhook forwarding — Forward events to localhost with custom port and path
3. Event filtering — Only forward events you care about
4. Test triggers — Simulate any Stripe event for testing
5. Log tailing — Monitor API requests in real-time
6. Resource management — List, create, inspect Stripe objects
7. Fixture testing — Run multi-step test scenarios from JSON files
8. Connect support — Forward and test Connect platform events
9. Health check — Verify CLI installation, auth, and connectivity
10. CI/CD ready — Non-interactive auth via environment variables

## Dependencies
- `bash` (4.0+)
- `curl`
- Internet connection

## Installation Time
**3 minutes** — Run install script, login, start forwarding
