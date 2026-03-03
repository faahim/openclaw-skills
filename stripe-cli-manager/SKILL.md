---
name: stripe-cli-manager
description: >-
  Install, configure, and manage Stripe from the command line — webhooks, payments, products, and event monitoring.
categories: [finance, dev-tools]
dependencies: [bash, curl, jq]
---

# Stripe CLI Manager

## What This Does

Automates Stripe payment infrastructure management from your terminal. Install the Stripe CLI, forward webhooks to your local dev server, manage products and prices, monitor payment events in real-time, and trigger test payments — all without touching the Stripe dashboard.

**Example:** "Install Stripe CLI, forward webhooks to localhost:3000, create a $29/mo subscription product, and monitor for failed payments."

## Quick Start (5 minutes)

### 1. Install Stripe CLI

```bash
bash scripts/install.sh
```

This detects your OS and installs the Stripe CLI via the appropriate package manager.

### 2. Authenticate

```bash
stripe login
# Or use API key directly:
export STRIPE_API_KEY="sk_test_..."
```

### 3. Verify Installation

```bash
bash scripts/run.sh status
```

## Core Workflows

### Workflow 1: Forward Webhooks to Local Dev Server

**Use case:** Test Stripe webhooks against your local application during development.

```bash
bash scripts/run.sh webhook-forward --url http://localhost:3000/api/webhooks/stripe

# Output:
# ✅ Webhook forwarding active
# → Forwarding to: http://localhost:3000/api/webhooks/stripe
# → Webhook signing secret: whsec_abc123...
# Ready. Listening for events...
#
# 2026-03-03 18:30:00 → payment_intent.succeeded [evt_1abc...]
# 2026-03-03 18:30:05 → invoice.paid [evt_2def...]
```

### Workflow 2: Monitor Payment Events

**Use case:** Watch real-time Stripe events for debugging or alerting.

```bash
# Watch all events
bash scripts/run.sh events --live

# Watch specific event types
bash scripts/run.sh events --live --types "payment_intent.succeeded,payment_intent.payment_failed,charge.refunded"

# Output:
# [2026-03-03 18:30:00] payment_intent.succeeded — $29.00 — cus_abc123
# [2026-03-03 18:31:00] payment_intent.payment_failed — $49.00 — cus_def456 — card_declined
```

### Workflow 3: Manage Products & Prices

**Use case:** Create and manage your product catalog from the CLI.

```bash
# Create a product
bash scripts/run.sh product-create \
  --name "Pro Plan" \
  --description "Full access to all features"

# Add a price
bash scripts/run.sh price-create \
  --product prod_abc123 \
  --amount 2900 \
  --currency usd \
  --interval month

# List products
bash scripts/run.sh products

# Output:
# ID              | Name      | Active | Prices
# prod_abc123     | Pro Plan  | ✅     | $29.00/mo (price_xyz789)
# prod_def456     | Basic     | ✅     | $9.00/mo (price_uvw321)
```

### Workflow 4: Trigger Test Events

**Use case:** Simulate Stripe events for testing webhook handlers.

```bash
# Trigger a payment success event
bash scripts/run.sh trigger payment_intent.succeeded

# Trigger a subscription cancellation
bash scripts/run.sh trigger customer.subscription.deleted

# Trigger with specific fixtures
bash scripts/run.sh trigger invoice.payment_failed \
  --override "invoice:billing_reason=subscription_cycle"
```

### Workflow 5: Check Recent Payments

**Use case:** Quick overview of recent payment activity.

```bash
bash scripts/run.sh payments --limit 10

# Output:
# Date                | Amount  | Status    | Customer       | Description
# 2026-03-03 18:00   | $29.00  | succeeded | cus_abc123     | Pro Plan subscription
# 2026-03-03 17:45   | $9.00   | succeeded | cus_def456     | Basic Plan subscription
# 2026-03-03 17:30   | $49.00  | failed    | cus_ghi789     | card_declined
```

### Workflow 6: Manage Customers

```bash
# List recent customers
bash scripts/run.sh customers --limit 10

# Get customer details
bash scripts/run.sh customer --id cus_abc123

# Output:
# Customer: cus_abc123
# Email: user@example.com
# Created: 2026-02-15
# Subscriptions: 1 active (Pro Plan - $29.00/mo)
# Total spent: $87.00
# Default payment: Visa ending 4242
```

### Workflow 7: Revenue Summary

```bash
bash scripts/run.sh revenue --period month

# Output:
# Revenue Summary (March 2026)
# ─────────────────────────────
# Gross:    $4,230.00
# Refunds:  -$58.00
# Net:      $4,172.00
# Txns:     142
# MRR:      $3,890.00
# Failed:   7 (4.9%)
```

## Configuration

### Environment Variables

```bash
# Required: Stripe API key
export STRIPE_API_KEY="sk_test_..." # Test mode
# export STRIPE_API_KEY="sk_live_..." # Live mode (use with caution)

# Optional: Default webhook forward URL
export STRIPE_WEBHOOK_URL="http://localhost:3000/api/webhooks/stripe"

# Optional: Alert on failed payments (Telegram)
export STRIPE_ALERT_CHAT_ID="123456"
export TELEGRAM_BOT_TOKEN="bot123:abc..."
```

### Config File

```yaml
# ~/.stripe-manager/config.yaml
default_mode: test  # test or live
webhook_url: http://localhost:3000/api/webhooks/stripe
alert_on:
  - payment_intent.payment_failed
  - charge.dispute.created
  - customer.subscription.deleted
alert_channel: telegram  # telegram or webhook
products:
  - name: Pro Plan
    price: 2900
    currency: usd
    interval: month
```

## Advanced Usage

### Failed Payment Alerting

```bash
# Run as background monitor — alerts on failed payments
bash scripts/run.sh monitor --alert-failures

# Sends Telegram alert:
# 🚨 Payment Failed
# Customer: user@example.com (cus_abc123)
# Amount: $29.00
# Reason: card_declined
# Time: 2026-03-03 18:30:00
```

### Bulk Product Import

```bash
# Import products from CSV
bash scripts/run.sh import-products --file products.csv

# CSV format:
# name,description,price_cents,currency,interval
# "Pro Plan","Full access",2900,usd,month
# "Enterprise","Priority support",9900,usd,month
```

### Revenue Export

```bash
# Export transactions to CSV
bash scripts/run.sh export --from 2026-01-01 --to 2026-03-01 --output revenue.csv
```

## Troubleshooting

### Issue: "stripe: command not found"

**Fix:** Run the installer again:
```bash
bash scripts/install.sh
source ~/.bashrc  # or restart your shell
```

### Issue: Webhook forwarding shows "connection refused"

**Check:**
1. Your local server is running on the specified port
2. The URL is correct: `bash scripts/run.sh webhook-forward --url http://localhost:PORT/path`

### Issue: "Invalid API Key"

**Fix:**
1. Check key format: `echo $STRIPE_API_KEY` (should start with `sk_test_` or `sk_live_`)
2. Regenerate from Stripe Dashboard → Developers → API keys
3. Set it: `export STRIPE_API_KEY="sk_test_new_key_here"`

### Issue: Events not showing in live mode

**Check:** Ensure you're authenticated: `stripe login --api-key $STRIPE_API_KEY`

## Dependencies

- `bash` (4.0+)
- `curl` (for installation + API fallback)
- `jq` (JSON parsing)
- `stripe` CLI (installed by `scripts/install.sh`)
