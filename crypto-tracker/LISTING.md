# Listing Copy: Crypto Tracker

## Metadata
- **Type:** Skill
- **Name:** crypto-tracker
- **Display Name:** Crypto Tracker
- **Categories:** [finance, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, jq, bc]

## Tagline

Monitor crypto prices, track your portfolio, and get instant alerts when prices move

## Description

Checking crypto prices across multiple sites is tedious. Manually calculating your portfolio value every day wastes time. And by the time you notice a big price move, you've already missed your entry or exit point.

Crypto Tracker monitors cryptocurrency prices using the free CoinGecko API (10,000+ coins supported), tracks your portfolio value in real-time, and sends instant alerts via Telegram, email, or webhook when prices cross your targets. All data stays local — no accounts, no third-party tracking.

**What it does:**
- 💰 Check prices for any cryptocurrency instantly
- 📊 Track portfolio value with 24h change percentages
- 🚨 Set price alerts (above/below thresholds, % change)
- 📈 Log price history to CSV for trend analysis
- ⏰ Run automated monitoring via cron (every 5-60 min)
- 🔔 Multi-channel alerts: Telegram, email, Slack webhook
- 🔍 Search 10,000+ coins by name or ticker

Perfect for crypto investors, traders, and curious holders who want reliable price monitoring without trusting third-party portfolio apps with their holdings data.

## Quick Start Preview

```bash
# Check prices
bash scripts/crypto.sh price bitcoin ethereum solana

# Track portfolio
bash scripts/crypto.sh portfolio add btc 0.5
bash scripts/crypto.sh portfolio show

# Set alerts
bash scripts/crypto.sh alert add bitcoin below 60000
```

## Core Capabilities

1. Real-time prices — Fetch current price + 24h change for any coin
2. Portfolio tracking — Add holdings, see total value, daily snapshots
3. Price alerts — Trigger on above/below thresholds or % change
4. Top coins view — Market cap rankings with key metrics
5. Coin search — Find any of 10,000+ coins by name or ticker
6. Multi-channel alerts — Telegram, email, Slack/Discord webhook
7. Price history logging — CSV export for analysis
8. Cron-ready monitoring — Automated checks on any schedule
9. Ticker shortcuts — Use BTC/ETH/SOL instead of full names
10. Zero API keys — Uses free CoinGecko API, no signup needed
11. Local data — Portfolio and history stored on your machine
12. Multi-currency — Check prices in USD, EUR, GBP, or 50+ fiat currencies

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- `bc`

## Installation Time
**3 minutes** — No API keys needed, just run the script
