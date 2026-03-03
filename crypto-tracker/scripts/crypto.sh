#!/bin/bash
# Crypto Tracker — Monitor prices, track portfolio, get alerts
# Uses CoinGecko free API (no key required)

set -euo pipefail

# Config
DATA_DIR="${CRYPTO_DATA_DIR:-$(dirname "$0")/../data}"
CURRENCY="${CRYPTO_CURRENCY:-usd}"
CURRENCY_SYMBOL="${CRYPTO_CURRENCY_SYMBOL:-\$}"
API_BASE="https://api.coingecko.com/api/v3"
PORTFOLIO_FILE="$DATA_DIR/portfolio.json"
ALERTS_FILE="$DATA_DIR/alerts.json"
HISTORY_DIR="$DATA_DIR/history"
LOG_FILE="$DATA_DIR/price-log.csv"

# Ensure data dirs
mkdir -p "$DATA_DIR" "$HISTORY_DIR"

# Init files if missing
[ -f "$PORTFOLIO_FILE" ] || echo '{}' > "$PORTFOLIO_FILE"
[ -f "$ALERTS_FILE" ] || echo '[]' > "$ALERTS_FILE"
[ -f "$LOG_FILE" ] || echo "timestamp,coin,price_usd,change_24h" > "$LOG_FILE"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# ─── NOTIFICATIONS ───

send_alert() {
  local msg="$1"
  
  # Telegram
  if [ -n "${CRYPTO_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${CRYPTO_TELEGRAM_CHAT_ID:-}" ]; then
    curl -sf "https://api.telegram.org/bot${CRYPTO_TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="$CRYPTO_TELEGRAM_CHAT_ID" \
      -d text="$msg" \
      -d parse_mode="Markdown" > /dev/null 2>&1 || true
  fi
  
  # Webhook
  if [ -n "${CRYPTO_WEBHOOK_URL:-}" ]; then
    curl -sf -X POST "$CRYPTO_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"$msg\"}" > /dev/null 2>&1 || true
  fi
  
  # Email
  if [ -n "${CRYPTO_SMTP_HOST:-}" ] && [ -n "${CRYPTO_ALERT_EMAIL:-}" ]; then
    echo "$msg" | mail -s "🪙 Crypto Alert" "$CRYPTO_ALERT_EMAIL" 2>/dev/null || true
  fi
  
  echo "$msg"
}

# ─── API CALLS ───

fetch_prices() {
  local coins="$1"
  curl -sf "${API_BASE}/simple/price?ids=${coins}&vs_currencies=${CURRENCY}&include_24hr_change=true&include_market_cap=true" 2>/dev/null
}

fetch_top() {
  local limit="${1:-10}"
  curl -sf "${API_BASE}/coins/markets?vs_currency=${CURRENCY}&order=market_cap_desc&per_page=${limit}&page=1&sparkline=false" 2>/dev/null
}

search_coin() {
  local query="$1"
  curl -sf "${API_BASE}/search?query=${query}" 2>/dev/null
}

# ─── COIN ID MAPPING ───

# Common ticker → coingecko ID mappings
resolve_coin() {
  local input="${1,,}"  # lowercase
  case "$input" in
    btc|bitcoin) echo "bitcoin" ;;
    eth|ethereum) echo "ethereum" ;;
    sol|solana) echo "solana" ;;
    ada|cardano) echo "cardano" ;;
    dot|polkadot) echo "polkadot" ;;
    avax|avalanche) echo "avalanche-2" ;;
    matic|polygon) echo "matic-network" ;;
    link|chainlink) echo "chainlink" ;;
    doge|dogecoin) echo "dogecoin" ;;
    shib|shiba*) echo "shiba-inu" ;;
    xrp|ripple) echo "ripple" ;;
    bnb) echo "binancecoin" ;;
    uni|uniswap) echo "uniswap" ;;
    atom|cosmos) echo "cosmos" ;;
    near) echo "near" ;;
    arb|arbitrum) echo "arbitrum" ;;
    op|optimism) echo "optimism" ;;
    sui) echo "sui" ;;
    apt|aptos) echo "aptos" ;;
    ton|toncoin) echo "the-open-network" ;;
    *) echo "$input" ;;
  esac
}

format_price() {
  local price="$1"
  if (( $(echo "$price >= 1" | bc -l) )); then
    printf "%'.2f" "$price"
  elif (( $(echo "$price >= 0.01" | bc -l) )); then
    printf "%.4f" "$price"
  else
    printf "%.8f" "$price"
  fi
}

# ─── COMMANDS ───

cmd_price() {
  if [ $# -eq 0 ]; then
    echo "Usage: crypto.sh price <coin1> [coin2] ..."
    exit 1
  fi
  
  local ids=""
  for coin in "$@"; do
    local resolved=$(resolve_coin "$coin")
    [ -n "$ids" ] && ids="${ids},"
    ids="${ids}${resolved}"
  done
  
  local data
  data=$(fetch_prices "$ids")
  if [ -z "$data" ] || [ "$data" = "{}" ]; then
    echo "Error: Could not fetch prices. Check coin names or API rate limit."
    exit 1
  fi
  
  echo "$data" | jq -r --arg ts "$(timestamp)" --arg cur "$CURRENCY" '
    to_entries[] |
    "[\($ts)] \(.key | ascii_upcase | .[0:5]): $\(.value["\($cur)"] | tostring) (24h: \(
      if .value["\($cur)_24h_change"] then
        (.value["\($cur)_24h_change"] | . * 100 | round | . / 100 | tostring) + "%"
      else "N/A"
      end
    ))"
  '
}

cmd_top() {
  local limit="${1:-10}"
  local data
  data=$(fetch_top "$limit")
  
  printf "%-4s %-15s %-12s %-10s %-15s\n" "#" "Coin" "Price" "24h %" "Market Cap"
  printf "%-4s %-15s %-12s %-10s %-15s\n" "---" "---------------" "------------" "----------" "---------------"
  
  echo "$data" | jq -r '.[] | [.market_cap_rank, .name, .current_price, .price_change_percentage_24h, .market_cap] | @tsv' | \
  while IFS=$'\t' read -r rank name price change mcap; do
    local fmt_price=$(format_price "$price")
    local fmt_change=$(printf "%.1f%%" "$change" 2>/dev/null || echo "N/A")
    local fmt_mcap=""
    if [ -n "$mcap" ] && [ "$mcap" != "null" ]; then
      local mcap_b=$(echo "scale=1; $mcap / 1000000000" | bc -l 2>/dev/null || echo "?")
      fmt_mcap="\$${mcap_b}B"
    fi
    printf "%-4s %-15s \$%-11s %-10s %-15s\n" "$rank" "$name" "$fmt_price" "$fmt_change" "$fmt_mcap"
  done
}

cmd_search() {
  if [ $# -eq 0 ]; then
    echo "Usage: crypto.sh search <query>"
    exit 1
  fi
  
  local data
  data=$(search_coin "$1")
  echo "$data" | jq -r '.coins[:10][] | "  \(.id) (\(.symbol | ascii_upcase)) — \(.name)"'
}

cmd_portfolio() {
  local action="${1:-show}"
  shift 2>/dev/null || true
  
  case "$action" in
    add|set)
      local coin=$(resolve_coin "${1:?Usage: portfolio add <coin> <amount>}")
      local amount="${2:?Usage: portfolio add <coin> <amount>}"
      jq --arg coin "$coin" --arg amt "$amount" '.[$coin] = ($amt | tonumber)' "$PORTFOLIO_FILE" > "${PORTFOLIO_FILE}.tmp"
      mv "${PORTFOLIO_FILE}.tmp" "$PORTFOLIO_FILE"
      echo "✅ Set $coin = $amount"
      ;;
    remove)
      local coin=$(resolve_coin "${1:?Usage: portfolio remove <coin>}")
      jq --arg coin "$coin" 'del(.[$coin])' "$PORTFOLIO_FILE" > "${PORTFOLIO_FILE}.tmp"
      mv "${PORTFOLIO_FILE}.tmp" "$PORTFOLIO_FILE"
      echo "✅ Removed $coin"
      ;;
    show)
      local coins
      coins=$(jq -r 'keys | join(",")' "$PORTFOLIO_FILE")
      if [ -z "$coins" ] || [ "$coins" = "" ]; then
        echo "Portfolio is empty. Add coins: crypto.sh portfolio add bitcoin 0.5"
        return
      fi
      
      local prices
      prices=$(fetch_prices "$coins")
      
      local total=0
      printf "\n%-12s %-10s %-12s %-12s %-8s\n" "Coin" "Amount" "Price" "Value" "24h%"
      printf "%-12s %-10s %-12s %-12s %-8s\n" "────────────" "──────────" "────────────" "────────────" "────────"
      
      while IFS='=' read -r coin amount; do
        local price=$(echo "$prices" | jq -r --arg c "$coin" --arg cur "$CURRENCY" '.[$c][$cur] // 0')
        local change=$(echo "$prices" | jq -r --arg c "$coin" --arg cur "$CURRENCY" '.[$c]["\($cur)_24h_change"] // 0')
        local value=$(echo "scale=2; $amount * $price" | bc -l 2>/dev/null || echo "0")
        total=$(echo "scale=2; $total + $value" | bc -l 2>/dev/null || echo "$total")
        
        local fmt_price=$(format_price "$price")
        local fmt_change=$(printf "%.1f%%" "$change" 2>/dev/null || echo "N/A")
        printf "%-12s %-10s \$%-11s \$%-11s %-8s\n" \
          "$(echo "$coin" | cut -c1-12)" "$amount" "$fmt_price" "$(format_price "$value")" "$fmt_change"
      done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$PORTFOLIO_FILE")
      
      printf "%-12s %-10s %-12s %-12s\n" "────────────" "──────────" "────────────" "────────────"
      printf "%-12s %-10s %-12s \$%-11s\n" "TOTAL" "" "" "$(format_price "$total")"
      echo ""
      ;;
    snapshot)
      cmd_portfolio show
      echo "[$(timestamp)] Portfolio snapshot logged" >> "$DATA_DIR/snapshots.log"
      ;;
    *)
      echo "Usage: crypto.sh portfolio [add|remove|set|show|snapshot] [args]"
      ;;
  esac
}

cmd_alert() {
  local action="${1:-list}"
  shift 2>/dev/null || true
  
  case "$action" in
    add)
      local coin=$(resolve_coin "${1:?Usage: alert add <coin> <below|above|change> <value>}")
      local type="${2:?Usage: alert add <coin> <below|above|change> <value>}"
      local value="${3:?Usage: alert add <coin> <below|above|change> <value>}"
      
      jq --arg coin "$coin" --arg type "$type" --arg val "$value" \
        '. += [{"coin": $coin, "type": $type, "value": ($val | tonumber), "active": true, "triggered": false}]' \
        "$ALERTS_FILE" > "${ALERTS_FILE}.tmp"
      mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
      echo "✅ Alert: $coin $type $value"
      ;;
    remove)
      local idx="${1:?Usage: alert remove <index>}"
      jq --argjson idx "$idx" 'del(.[$idx])' "$ALERTS_FILE" > "${ALERTS_FILE}.tmp"
      mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
      echo "✅ Alert #$idx removed"
      ;;
    list)
      echo "Active Alerts:"
      jq -r 'to_entries[] | "  [\(.key)] \(.value.coin) \(.value.type) \(.value.value) (triggered: \(.value.triggered))"' "$ALERTS_FILE"
      ;;
    check)
      cmd_alert_check
      ;;
    reset)
      jq '[.[] | .triggered = false]' "$ALERTS_FILE" > "${ALERTS_FILE}.tmp"
      mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
      echo "✅ All alerts reset"
      ;;
    *)
      echo "Usage: crypto.sh alert [add|remove|list|check|reset] [args]"
      ;;
  esac
}

cmd_alert_check() {
  local alerts
  alerts=$(cat "$ALERTS_FILE")
  local count=$(echo "$alerts" | jq 'length')
  
  if [ "$count" -eq 0 ]; then
    return
  fi
  
  # Gather unique coins
  local coins
  coins=$(echo "$alerts" | jq -r '[.[] | select(.active == true and .triggered == false) | .coin] | unique | join(",")')
  [ -z "$coins" ] && return
  
  local prices
  prices=$(fetch_prices "$coins")
  
  local updated="$alerts"
  local i=0
  while [ $i -lt "$count" ]; do
    local alert=$(echo "$alerts" | jq ".[$i]")
    local active=$(echo "$alert" | jq -r '.active')
    local triggered=$(echo "$alert" | jq -r '.triggered')
    
    if [ "$active" = "true" ] && [ "$triggered" = "false" ]; then
      local coin=$(echo "$alert" | jq -r '.coin')
      local type=$(echo "$alert" | jq -r '.type')
      local threshold=$(echo "$alert" | jq -r '.value')
      local price=$(echo "$prices" | jq -r --arg c "$coin" --arg cur "$CURRENCY" '.[$c][$cur] // 0')
      local change=$(echo "$prices" | jq -r --arg c "$coin" --arg cur "$CURRENCY" '.[$c]["\($cur)_24h_change"] // 0')
      
      local fire=false
      case "$type" in
        below)
          (( $(echo "$price < $threshold" | bc -l) )) && fire=true
          ;;
        above)
          (( $(echo "$price > $threshold" | bc -l) )) && fire=true
          ;;
        change)
          local abs_change=$(echo "$change" | tr -d '-')
          (( $(echo "$abs_change > $threshold" | bc -l) )) && fire=true
          ;;
      esac
      
      if [ "$fire" = "true" ]; then
        local msg="🚨 *Crypto Alert*: $(echo "$coin" | tr '[:lower:]' '[:upper:]') is \$$(format_price "$price") — triggered $type $threshold"
        send_alert "$msg"
        updated=$(echo "$updated" | jq ".[$i].triggered = true")
      fi
    fi
    i=$((i + 1))
  done
  
  echo "$updated" | jq '.' > "$ALERTS_FILE"
}

cmd_log() {
  local coins
  coins=$(jq -r 'keys | join(",")' "$PORTFOLIO_FILE" 2>/dev/null)
  [ -z "$coins" ] && coins="bitcoin,ethereum,solana"
  
  local prices
  prices=$(fetch_prices "$coins")
  
  echo "$prices" | jq -r --arg ts "$(timestamp)" --arg cur "$CURRENCY" '
    to_entries[] |
    "\($ts),\(.key),\(.value[$cur]),\(.value["\($cur)_24h_change"] // 0)"
  ' >> "$LOG_FILE"
  
  echo "[$(timestamp)] Prices logged to $LOG_FILE"
}

cmd_history() {
  local coin=$(resolve_coin "${1:-bitcoin}")
  local lines="${2:-20}"
  echo "Price history for $coin (last $lines entries):"
  grep ",$coin," "$LOG_FILE" 2>/dev/null | tail -n "$lines" | \
    while IFS=',' read -r ts c price change; do
      printf "  %s  \$%s  (%s%%)\n" "$ts" "$(format_price "$price")" "$change"
    done
}

cmd_export() {
  local coin=$(resolve_coin "${1:-bitcoin}")
  grep ",$coin," "$LOG_FILE" 2>/dev/null || echo "No data for $coin"
}

cmd_monitor() {
  echo "[$(timestamp)] Running monitor cycle..."
  cmd_log
  cmd_alert_check
  echo "[$(timestamp)] Monitor cycle complete."
}

# ─── MAIN ───

case "${1:-help}" in
  price)    shift; cmd_price "$@" ;;
  top)      shift; cmd_top "$@" ;;
  search)   shift; cmd_search "$@" ;;
  portfolio) shift; cmd_portfolio "$@" ;;
  alert)    shift; cmd_alert "$@" ;;
  log)      cmd_log ;;
  history)  shift; cmd_history "$@" ;;
  export)   shift; cmd_export "$@" ;;
  monitor)  cmd_monitor ;;
  help|*)
    cat <<EOF
🪙 Crypto Tracker — Monitor prices, track portfolio, get alerts

Usage: crypto.sh <command> [args]

Commands:
  price <coin> [coin2...]   Check current prices
  top [N]                   Top N coins by market cap
  search <query>            Search for a coin
  portfolio add <coin> <N>  Add coin to portfolio
  portfolio show            Show portfolio value
  portfolio snapshot        Log portfolio snapshot
  alert add <coin> <type> <value>  Set price alert
  alert list                List active alerts
  alert check               Check and trigger alerts
  monitor                   Run full monitoring cycle (for cron)
  log                       Log prices to CSV
  history <coin> [N]        View price history
  export <coin>             Export price data as CSV

Examples:
  crypto.sh price bitcoin ethereum
  crypto.sh top 20
  crypto.sh portfolio add btc 0.5
  crypto.sh alert add eth above 4000
  crypto.sh monitor

Environment:
  CRYPTO_TELEGRAM_BOT_TOKEN  Telegram bot token for alerts
  CRYPTO_TELEGRAM_CHAT_ID    Telegram chat ID for alerts
  CRYPTO_WEBHOOK_URL         Webhook URL for alerts
  CRYPTO_CURRENCY            Fiat currency (default: usd)
  CRYPTO_DATA_DIR            Data directory (default: ./data)
EOF
    ;;
esac
