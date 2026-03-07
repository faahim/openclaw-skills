---
name: stripe-cli
description: >-
  Install and manage the Stripe CLI for payment testing, webhook forwarding, and event monitoring.
categories: [dev-tools, finance]
dependencies: [bash, curl]
---

# Stripe CLI Manager

## What This Does

Installs the Stripe CLI, manages webhook forwarding to local dev servers, triggers test events, tails logs, and monitors payment activity — all from the terminal. Essential for any developer building Stripe payment integrations.

**Example:** "Forward Stripe webhooks to localhost:3000, trigger a test checkout.session.completed event, tail payment logs in real-time."

## Quick Start (5 minutes)

### 1. Install Stripe CLI

```bash
bash scripts/install.sh
```

### 2. Login to Stripe

```bash
stripe login
# Opens browser for authentication
# Or use API key:
stripe login --api-key sk_test_YOUR_KEY
```

### 3. Forward Webhooks to Local Server

```bash
bash scripts/webhook-forward.sh --port 3000
# Output:
# ✅ Webhook forwarding active
# 🔗 Forwarding to: http://localhost:3000/api/webhooks/stripe
# 🔑 Webhook signing secret: whsec_abc123...
# Ready. Listening for events...
```

## Core Workflows

### Workflow 1: Webhook Forwarding

**Use case:** Forward live Stripe events to your local development server

```bash
# Basic forwarding
bash scripts/webhook-forward.sh --port 3000

# Custom endpoint path
bash scripts/webhook-forward.sh --port 3000 --path /api/stripe/webhook

# Filter specific events only
bash scripts/webhook-forward.sh --port 3000 --events "checkout.session.completed,payment_intent.succeeded"
```

**Output:**
```
[2026-03-07 12:00:00] --> checkout.session.completed [evt_1abc...]
[2026-03-07 12:00:00]     POST http://localhost:3000/api/stripe/webhook [200 OK]
```

### Workflow 2: Trigger Test Events

**Use case:** Simulate Stripe events for testing

```bash
# Trigger a specific event
stripe trigger checkout.session.completed

# Trigger payment intent flow
stripe trigger payment_intent.succeeded

# Trigger subscription lifecycle
stripe trigger customer.subscription.created

# List all available triggers
stripe trigger --list
```

### Workflow 3: Tail Logs

**Use case:** Monitor Stripe API activity in real-time

```bash
# Tail all API requests
stripe logs tail

# Filter by HTTP method
stripe logs tail --filter-http-method POST

# Filter by status
stripe logs tail --filter-status-code 400

# Filter by API path
stripe logs tail --filter-request-path "/v1/charges"
```

### Workflow 4: Resource Management

**Use case:** List, create, and inspect Stripe resources

```bash
# List recent charges
stripe charges list --limit 10

# List customers
stripe customers list --limit 5

# Get a specific resource
stripe charges retrieve ch_1abc123

# Create a test customer
stripe customers create --name "Test User" --email "test@example.com"

# Create a payment intent
stripe payment_intents create --amount 2000 --currency usd
```

### Workflow 5: Fixture-Based Testing

**Use case:** Run complex multi-step test scenarios

```bash
# Run a fixture file
stripe fixtures examples/subscription-flow.json

# Create custom fixture
cat > my-fixture.json << 'EOF'
{
  "_meta": { "template_version": 0 },
  "fixtures": [
    {
      "name": "customer",
      "path": "/v1/customers",
      "method": "post",
      "params": {
        "name": "Test Customer",
        "email": "test@example.com"
      }
    },
    {
      "name": "payment_method",
      "path": "/v1/payment_methods",
      "method": "post",
      "params": {
        "type": "card",
        "card": {
          "token": "tok_visa"
        }
      }
    }
  ]
}
EOF
stripe fixtures my-fixture.json
```

### Workflow 6: Monitor Webhook Health

**Use case:** Check webhook endpoint status and recent deliveries

```bash
# List webhook endpoints
stripe webhook_endpoints list

# Check recent events
stripe events list --limit 20

# Get event details
stripe events retrieve evt_1abc123

# Resend a failed event
stripe events resend evt_1abc123
```

## Configuration

### Environment Variables

```bash
# Use test mode key (recommended for development)
export STRIPE_API_KEY="sk_test_YOUR_KEY"

# Use specific Stripe account (for Connect platforms)
export STRIPE_ACCOUNT="acct_123"

# Set default device name
export STRIPE_DEVICE_NAME="my-dev-machine"
```

### Config File

The Stripe CLI stores config at `~/.config/stripe/config.toml`:

```toml
[default]
device_name = "dev-laptop"
# API key is stored securely after `stripe login`
```

## Advanced Usage

### Testing Stripe Connect

```bash
# Forward with Connect account
bash scripts/webhook-forward.sh --port 3000 --connect

# Trigger Connect events
stripe trigger account.updated
stripe trigger transfer.created
```

### Custom Webhook Forwarding

```bash
# Forward to multiple endpoints
stripe listen \
  --forward-to localhost:3000/webhooks \
  --forward-connect-to localhost:3000/connect-webhooks
```

### CI/CD Integration

```bash
# Non-interactive login for CI
export STRIPE_API_KEY="sk_test_..."
stripe charges list --limit 1  # Verify connection

# Run test fixtures in CI
stripe fixtures tests/stripe-fixtures.json
```

### Idempotency Testing

```bash
# Send request with idempotency key
stripe charges create \
  --amount 2000 \
  --currency usd \
  --source tok_visa \
  -i "unique-key-123"
```

## Troubleshooting

### Issue: "stripe: command not found"

**Fix:**
```bash
# Re-run installer
bash scripts/install.sh

# Or add to PATH manually
export PATH="$PATH:$HOME/.local/bin"
```

### Issue: "Not authenticated"

**Fix:**
```bash
# Login again
stripe login

# Or set API key directly
stripe login --api-key sk_test_YOUR_KEY
```

### Issue: Webhook forwarding drops events

**Fix:**
- Check your server is running and responding within 30s
- Use `--skip-verify` if using self-signed SSL locally
- Check `stripe logs tail` for failed deliveries

### Issue: "Account has been deactivated"

**Fix:** You're using a revoked key. Generate a new one at dashboard.stripe.com/apikeys

## Scripts Reference

### scripts/install.sh
Installs the Stripe CLI for your platform (Linux/macOS). Handles apt, brew, or direct binary download.

### scripts/webhook-forward.sh
Starts webhook forwarding with sensible defaults. Logs events to `~/.stripe/webhook.log`.

### scripts/health-check.sh
Checks Stripe CLI installation, authentication status, and API connectivity.

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- Internet connection (Stripe CLI talks to Stripe API)
- Stripe account (free to create at stripe.com)

## Key Principles

1. **Test mode first** — Always use `sk_test_` keys for development
2. **Webhook secrets** — Store `whsec_` signing secrets securely
3. **Event replay** — Use `stripe events resend` to replay failed webhooks
4. **Fixtures** — Use fixture files for reproducible test scenarios
5. **Log monitoring** — `stripe logs tail` is your friend for debugging
