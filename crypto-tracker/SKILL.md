---
name: crypto-tracker
description: >-
  Monitor cryptocurrency prices, track your portfolio value, and get instant alerts when prices hit your targets.
categories: [finance, automation]
dependencies: [bash, curl, jq, bc]
---

# Crypto Tracker

## What This Does

Monitors cryptocurrency prices using the free CoinGecko API, tracks your portfolio value over time, and sends alerts (Telegram, email, or webhook) when prices cross your thresholds. Logs historical data for trend analysis.

**Example:** "Track BTC, ETH, SOL — alert me when BTC drops below $60k or ETH crosses $4k. Show my portfolio value daily."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# These are standard on most Linux/Mac systems
which curl jq bc || echo "Install: sudo apt-get install curl jq bc"

# Optional: Telegram alerts
export CRYPTO_TELEGRAM_BOT_TOKEN="<your-bot-token>"
export CRYPTO_TELEGRAM_CHAT_ID="<your-chat-id>"
```

### 2. Check a Price

```bash
bash scripts/crypto.sh price bitcoin
# Output: [2026-03-03 16:00:00] BTC: $97,432.15 (24h: +2.3%)

bash scripts/crypto.sh price ethereum solana cardano
# Output:
# [2026-03-03 16:00:00] ETH: $3,847.22 (24h: -0.8%)
# [2026-03-03 16:00:00] SOL: $187.55 (24h: +5.1%)
# [2026-03-03 16:00:00] ADA: $0.72 (24h: +1.2%)
```

### 3. Set Up Portfolio

```bash
# Add holdings
bash scripts/crypto.sh portfolio add bitcoin 0.5
bash scripts/crypto.sh portfolio add ethereum 3.2
bash scripts/crypto.sh portfolio add solana 50

# Check portfolio value
bash scripts/crypto.sh portfolio show
# Output:
# ┌─────────┬────────┬───────────┬───────────┐
# │ Coin    │ Amount │ Price     │ Value     │
# ├─────────┼────────┼───────────┼───────────┤
# │ BTC     │ 0.5    │ $97,432   │ $48,716   │
# │ ETH     │ 3.2    │ $3,847    │ $12,311   │
# │ SOL     │ 50     │ $187.55   │ $9,377    │
# ├─────────┼────────┼───────────┼───────────┤
# │ TOTAL   │        │           │ $70,404   │
# └─────────┴────────┴───────────┴───────────┘
```

### 4. Set Price Alerts

```bash
# Alert when BTC drops below $60,000
bash scripts/crypto.sh alert add bitcoin below 60000

# Alert when ETH goes above $4,000
bash scripts/crypto.sh alert add ethereum above 4000

# Alert when SOL changes more than 10% in 24h
bash scripts/crypto.sh alert add solana change 10

# List active alerts
bash scripts/crypto.sh alert list
```

## Core Workflows

### Workflow 1: Price Check (Single or Multiple)

```bash
# Single coin
bash scripts/crypto.sh price bitcoin

# Multiple coins
bash scripts/crypto.sh price bitcoin ethereum solana

# Top N coins by market cap
bash scripts/crypto.sh top 10

# Search for a coin
bash scripts/crypto.sh search "polygon"
```

### Workflow 2: Portfolio Tracking

```bash
# Add/remove holdings
bash scripts/crypto.sh portfolio add bitcoin 0.5
bash scripts/crypto.sh portfolio remove solana

# Update amount
bash scripts/crypto.sh portfolio set ethereum 5.0

# Show portfolio with 24h change
bash scripts/crypto.sh portfolio show

# Portfolio history (if logging enabled)
bash scripts/crypto.sh portfolio history 7  # last 7 days
```

### Workflow 3: Price Alerts

```bash
# Price threshold alerts
bash scripts/crypto.sh alert add bitcoin below 60000
bash scripts/crypto.sh alert add ethereum above 4000

# Percentage change alerts (24h)
bash scripts/crypto.sh alert add solana change 10

# Remove an alert
bash scripts/crypto.sh alert remove 1

# Check alerts now (triggers any that match)
bash scripts/crypto.sh alert check
```

### Workflow 4: Automated Monitoring (Cron)

```bash
# Check prices and trigger alerts every 15 minutes
bash scripts/crypto.sh monitor

# Run as cron job
# */15 * * * * cd /path/to/crypto-tracker && bash scripts/crypto.sh monitor >> logs/monitor.log 2>&1

# Daily portfolio snapshot
# 0 9 * * * cd /path/to/crypto-tracker && bash scripts/crypto.sh portfolio snapshot >> logs/portfolio.log 2>&1
```

### Workflow 5: Historical Data

```bash
# Log current prices to CSV
bash scripts/crypto.sh log

# View price history
bash scripts/crypto.sh history bitcoin 30  # last 30 data points

# Export to CSV
bash scripts/crypto.sh export bitcoin > bitcoin-prices.csv
```

## Configuration

### Environment Variables

```bash
# Telegram alerts (optional)
export CRYPTO_TELEGRAM_BOT_TOKEN="<token>"
export CRYPTO_TELEGRAM_CHAT_ID="<chat-id>"

# Email alerts via SMTP (optional)
export CRYPTO_SMTP_HOST="smtp.gmail.com"
export CRYPTO_SMTP_PORT="587"
export CRYPTO_SMTP_USER="<email>"
export CRYPTO_SMTP_PASS="<password>"
export CRYPTO_ALERT_EMAIL="<recipient>"

# Webhook alerts (optional)
export CRYPTO_WEBHOOK_URL="https://hooks.slack.com/..."

# Data directory (default: ./data)
export CRYPTO_DATA_DIR="./data"

# Currency (default: usd)
export CRYPTO_CURRENCY="usd"
```

### Config File (optional)

```yaml
# config.yaml
currency: usd
alert_method: telegram  # telegram, email, webhook, stdout
portfolio:
  bitcoin: 0.5
  ethereum: 3.2
  solana: 50
alerts:
  - coin: bitcoin
    type: below
    value: 60000
  - coin: ethereum
    type: above
    value: 4000
  - coin: solana
    type: change
    value: 10
```

## Advanced Usage

### Run as OpenClaw Cron Job

```bash
# In your OpenClaw config, add a cron job:
# Schedule: every 15 minutes
# Command: bash /path/to/crypto-tracker/scripts/crypto.sh monitor
```

### Custom Alert Scripts

```bash
# Run custom command on alert
bash scripts/crypto.sh alert add bitcoin below 60000 \
  --on-trigger 'echo "BTC CRASH" | wall'
```

### Multiple Currencies

```bash
# Check price in EUR
CRYPTO_CURRENCY=eur bash scripts/crypto.sh price bitcoin

# Check price in multiple currencies
bash scripts/crypto.sh price bitcoin --currencies usd,eur,gbp
```

## Troubleshooting

### Issue: "rate limit exceeded"

CoinGecko free API allows ~30 requests/minute. Space out calls.

**Fix:** Use `monitor` command (batches requests) instead of individual `price` calls.

### Issue: Coin not found

**Fix:** Use the CoinGecko ID (not ticker). Search first:
```bash
bash scripts/crypto.sh search "shiba"
# → shiba-inu (SHIB)
```

### Issue: Telegram alerts not working

**Check:**
```bash
# Test Telegram
curl -s "https://api.telegram.org/bot$CRYPTO_TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$CRYPTO_TELEGRAM_CHAT_ID&text=Test"
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to CoinGecko API)
- `jq` (JSON parsing)
- `bc` (decimal math for portfolio calculations)
- Optional: `cron` (scheduled monitoring)

## API

Uses the free [CoinGecko API](https://api.coingecko.com/api/v3/) — no API key required.

- Rate limit: ~30 requests/minute (free tier)
- Data: Real-time prices, 24h change, market cap, volume
- Supported coins: 10,000+
- Supported currencies: 50+ fiat currencies
