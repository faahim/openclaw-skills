# Listing Copy: Stripe CLI Manager

## Metadata
- **Type:** Skill
- **Name:** stripe-cli-manager
- **Display Name:** Stripe CLI Manager
- **Categories:** [finance, dev-tools]
- **Price:** $15
- **Dependencies:** [bash, curl, jq, stripe-cli]
- **Icon:** 💳

## Tagline

Manage Stripe payments, webhooks, and products from your terminal — no dashboard needed.

## Description

Checking the Stripe dashboard every time you need to debug a webhook, verify a payment, or create a product is slow and breaks your flow. You need a way to manage your entire payment infrastructure from the command line.

Stripe CLI Manager installs the Stripe CLI, then wraps it with powerful automation commands. Forward webhooks to your local dev server, monitor payments in real-time, create products and prices, export transactions to CSV, and get Telegram alerts on failed payments — all from your terminal or OpenClaw agent.

**What it does:**
- 🔗 Forward Stripe webhooks to any local URL for development
- 📊 Real-time payment event monitoring with colored output
- 💰 Revenue summaries (daily, weekly, monthly, yearly)
- 📦 Create and manage products and prices via CLI
- 🚨 Telegram alerts on failed payments and disputes
- 📋 List payments, customers, and subscriptions
- 🧪 Trigger test events for webhook testing
- 📤 Export transactions to CSV
- 📥 Bulk import products from CSV
- 🔧 Auto-installs Stripe CLI on Linux and macOS

Perfect for indie hackers, SaaS developers, and anyone running Stripe who wants faster payment management without context-switching to the dashboard.

## Quick Start Preview

```bash
# Install Stripe CLI
bash scripts/install.sh

# Forward webhooks to your local server
bash scripts/run.sh webhook-forward --url http://localhost:3000/webhooks

# Check recent payments
bash scripts/run.sh payments --limit 10

# Monitor payments with failure alerts
bash scripts/run.sh monitor --alert-failures
```

## Core Capabilities

1. Webhook forwarding — Route Stripe events to any local URL for development testing
2. Payment monitoring — Real-time colored event stream with amount, customer, and status
3. Revenue reports — Instant gross/net/refund summaries by period
4. Product management — Create products and prices without the dashboard
5. Customer lookup — View customer details, subscriptions, and payment history
6. Test event triggers — Simulate any Stripe event for webhook testing
7. Failed payment alerts — Telegram notifications on payment failures and disputes
8. Transaction export — Download charges to CSV for accounting
9. Bulk product import — Create products from a CSV file
10. Cross-platform install — Auto-detects OS and installs via apt, brew, or binary

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- `stripe` CLI (installed by included script)

## Installation Time
**5 minutes** — Run install script, set API key, start using
