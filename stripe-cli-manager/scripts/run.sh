#!/bin/bash
# Stripe CLI Manager — Unified command interface
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.stripe-manager"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure stripe CLI exists
check_stripe() {
  if ! command -v stripe &>/dev/null; then
    echo -e "${RED}❌ Stripe CLI not found. Run: bash scripts/install.sh${NC}"
    exit 1
  fi
}

# Ensure jq exists
check_jq() {
  if ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ jq not found. Install: sudo apt-get install jq${NC}"
    exit 1
  fi
}

# Get API key
get_api_key() {
  if [ -n "${STRIPE_API_KEY:-}" ]; then
    echo "$STRIPE_API_KEY"
  else
    echo -e "${YELLOW}⚠️ STRIPE_API_KEY not set. Using stripe CLI default authentication.${NC}" >&2
    echo ""
  fi
}

# ── Commands ──────────────────────────────────────────

cmd_status() {
  check_stripe
  echo -e "${BLUE}Stripe CLI Status${NC}"
  echo "────────────────────"
  echo "Version: $(stripe version 2>/dev/null || echo 'unknown')"
  echo "API Key: ${STRIPE_API_KEY:+set (${STRIPE_API_KEY:0:12}...)}${STRIPE_API_KEY:-not set (using stripe login)}"
  
  # Test connectivity
  if stripe config --list &>/dev/null 2>&1; then
    echo -e "Auth: ${GREEN}✅ Authenticated${NC}"
  else
    echo -e "Auth: ${YELLOW}⚠️ Not authenticated — run 'stripe login'${NC}"
  fi
}

cmd_webhook_forward() {
  check_stripe
  local url="${1:-${STRIPE_WEBHOOK_URL:-http://localhost:3000/api/webhooks/stripe}}"
  
  echo -e "${GREEN}✅ Webhook forwarding active${NC}"
  echo "→ Forwarding to: $url"
  echo "Ready. Listening for events..."
  echo ""
  
  local api_key_flag=""
  [ -n "${STRIPE_API_KEY:-}" ] && api_key_flag="--api-key $STRIPE_API_KEY"
  
  stripe listen --forward-to "$url" $api_key_flag
}

cmd_events() {
  check_stripe
  check_jq
  local live=false
  local types=""
  local limit=25
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --live) live=true; shift ;;
      --types) types="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [ "$live" = true ]; then
    echo -e "${BLUE}Live Event Stream${NC} (Ctrl+C to stop)"
    echo "────────────────────"
    
    local type_filter=""
    [ -n "$types" ] && type_filter="--events $types"
    
    stripe listen --print-json $type_filter 2>/dev/null | while IFS= read -r line; do
      if echo "$line" | jq -e '.type' &>/dev/null 2>&1; then
        local evt_type=$(echo "$line" | jq -r '.type')
        local evt_id=$(echo "$line" | jq -r '.id // "unknown"')
        local created=$(echo "$line" | jq -r '.created // 0')
        local ts=$(date -d "@$created" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$created" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$created")
        echo -e "[${ts}] ${GREEN}${evt_type}${NC} — ${evt_id}"
      fi
    done
  else
    echo -e "${BLUE}Recent Events (last ${limit})${NC}"
    echo "────────────────────"
    stripe events list --limit "$limit" 2>/dev/null | head -50
  fi
}

cmd_product_create() {
  check_stripe
  local name="" description=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [ -z "$name" ]; then
    echo -e "${RED}❌ --name is required${NC}"
    exit 1
  fi
  
  local desc_flag=""
  [ -n "$description" ] && desc_flag="-d description=\"$description\""
  
  echo "Creating product: $name..."
  stripe products create -d "name=$name" $desc_flag 2>/dev/null
  echo -e "${GREEN}✅ Product created${NC}"
}

cmd_price_create() {
  check_stripe
  local product="" amount="" currency="usd" interval=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --product) product="$2"; shift 2 ;;
      --amount) amount="$2"; shift 2 ;;
      --currency) currency="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [ -z "$product" ] || [ -z "$amount" ]; then
    echo -e "${RED}❌ --product and --amount are required${NC}"
    exit 1
  fi
  
  local args="-d product=$product -d unit_amount=$amount -d currency=$currency"
  if [ -n "$interval" ]; then
    args="$args -d recurring[interval]=$interval"
  fi
  
  echo "Creating price: $amount ($currency) for $product..."
  stripe prices create $args 2>/dev/null
  echo -e "${GREEN}✅ Price created${NC}"
}

cmd_products() {
  check_stripe
  check_jq
  echo -e "${BLUE}Products${NC}"
  echo "────────────────────────────────────────────────────────────────"
  printf "%-18s | %-20s | %-6s | %s\n" "ID" "Name" "Active" "Prices"
  echo "────────────────────────────────────────────────────────────────"
  
  stripe products list --limit 20 -d "expand[]=data.default_price" 2>/dev/null | \
    jq -r '.data[] | [.id, .name, (if .active then "✅" else "❌" end), (.default_price.unit_amount // 0 | . / 100 | tostring)] | @tsv' 2>/dev/null | \
    while IFS=$'\t' read -r id name active price; do
      printf "%-18s | %-20s | %-6s | $%s\n" "$id" "${name:0:20}" "$active" "$price"
    done
}

cmd_payments() {
  check_stripe
  check_jq
  local limit=10
  [ -n "${1:-}" ] && limit="$1"
  
  echo -e "${BLUE}Recent Payments (last ${limit})${NC}"
  echo "──────────────────────────────────────────────────────────────────────────"
  printf "%-18s | %-8s | %-10s | %-15s | %s\n" "Date" "Amount" "Status" "Customer" "Description"
  echo "──────────────────────────────────────────────────────────────────────────"
  
  stripe payment_intents list --limit "$limit" 2>/dev/null | \
    jq -r '.data[] | [
      (.created | todate | split("T")[0]),
      ((.amount // 0) / 100 | tostring),
      .status,
      (.customer // "none"),
      (.description // "-")
    ] | @tsv' 2>/dev/null | \
    while IFS=$'\t' read -r date amount status customer desc; do
      local status_color="$NC"
      case "$status" in
        succeeded) status_color="$GREEN" ;;
        failed|canceled) status_color="$RED" ;;
        *) status_color="$YELLOW" ;;
      esac
      printf "%-18s | \$%-7s | ${status_color}%-10s${NC} | %-15s | %s\n" "$date" "$amount" "$status" "${customer:0:15}" "${desc:0:30}"
    done
}

cmd_customers() {
  check_stripe
  check_jq
  local limit=10
  [ -n "${1:-}" ] && limit="$1"
  
  echo -e "${BLUE}Recent Customers (last ${limit})${NC}"
  echo "──────────────────────────────────────────────────────────────"
  printf "%-18s | %-30s | %s\n" "ID" "Email" "Created"
  echo "──────────────────────────────────────────────────────────────"
  
  stripe customers list --limit "$limit" 2>/dev/null | \
    jq -r '.data[] | [.id, (.email // "no email"), (.created | todate | split("T")[0])] | @tsv' 2>/dev/null | \
    while IFS=$'\t' read -r id email created; do
      printf "%-18s | %-30s | %s\n" "$id" "${email:0:30}" "$created"
    done
}

cmd_customer() {
  check_stripe
  check_jq
  local id=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [ -z "$id" ]; then
    echo -e "${RED}❌ --id is required${NC}"
    exit 1
  fi
  
  stripe customers retrieve "$id" 2>/dev/null | jq '{
    id: .id,
    email: .email,
    name: .name,
    created: (.created | todate),
    currency: .currency,
    balance: (.balance // 0),
    default_source: .default_source
  }'
}

cmd_trigger() {
  check_stripe
  local event="${1:-}"
  shift || true
  
  if [ -z "$event" ]; then
    echo -e "${RED}❌ Event type required${NC}"
    echo "Examples: payment_intent.succeeded, customer.subscription.deleted"
    echo "Full list: stripe trigger --list"
    exit 1
  fi
  
  echo "Triggering: $event..."
  stripe trigger "$event" "$@" 2>/dev/null
  echo -e "${GREEN}✅ Event triggered${NC}"
}

cmd_revenue() {
  check_stripe
  check_jq
  local period="${1:-month}"
  
  local since=""
  case "$period" in
    day) since=$(date -d "1 day ago" +%s 2>/dev/null || date -v-1d +%s) ;;
    week) since=$(date -d "7 days ago" +%s 2>/dev/null || date -v-7d +%s) ;;
    month) since=$(date -d "30 days ago" +%s 2>/dev/null || date -v-30d +%s) ;;
    year) since=$(date -d "365 days ago" +%s 2>/dev/null || date -v-365d +%s) ;;
    *) since=$(date -d "30 days ago" +%s 2>/dev/null || date -v-30d +%s) ;;
  esac
  
  echo -e "${BLUE}Revenue Summary (last ${period})${NC}"
  echo "─────────────────────────────"
  
  # Get charges
  local charges_json=$(stripe charges list --limit 100 -d "created[gte]=$since" 2>/dev/null)
  
  local gross=$(echo "$charges_json" | jq '[.data[] | select(.status == "succeeded") | .amount] | add // 0' 2>/dev/null)
  local refunded=$(echo "$charges_json" | jq '[.data[] | .amount_refunded] | add // 0' 2>/dev/null)
  local net=$(( (gross - refunded) ))
  local total=$(echo "$charges_json" | jq '.data | length' 2>/dev/null)
  local failed=$(echo "$charges_json" | jq '[.data[] | select(.status == "failed")] | length' 2>/dev/null)
  
  printf "Gross:    \$%s\n" "$(echo "scale=2; $gross / 100" | bc)"
  printf "Refunds:  -\$%s\n" "$(echo "scale=2; $refunded / 100" | bc)"
  printf "Net:      \$%s\n" "$(echo "scale=2; $net / 100" | bc)"
  printf "Txns:     %s\n" "$total"
  printf "Failed:   %s\n" "$failed"
}

cmd_monitor() {
  check_stripe
  local alert_failures=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --alert-failures) alert_failures=true; shift ;;
      *) shift ;;
    esac
  done
  
  echo -e "${BLUE}Payment Monitor${NC} (Ctrl+C to stop)"
  echo "────────────────────"
  
  stripe listen --print-json 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | jq -e '.type' &>/dev/null 2>&1; then
      local evt_type=$(echo "$line" | jq -r '.type')
      local ts=$(date '+%Y-%m-%d %H:%M:%S')
      
      case "$evt_type" in
        payment_intent.succeeded)
          local amount=$(echo "$line" | jq -r '.data.object.amount // 0')
          local customer=$(echo "$line" | jq -r '.data.object.customer // "unknown"')
          echo -e "[${ts}] ${GREEN}✅ Payment succeeded${NC} — \$$(echo "scale=2; $amount / 100" | bc) — $customer"
          ;;
        payment_intent.payment_failed)
          local amount=$(echo "$line" | jq -r '.data.object.amount // 0')
          local customer=$(echo "$line" | jq -r '.data.object.customer // "unknown"')
          local error=$(echo "$line" | jq -r '.data.object.last_payment_error.code // "unknown"')
          echo -e "[${ts}] ${RED}❌ Payment failed${NC} — \$$(echo "scale=2; $amount / 100" | bc) — $customer — $error"
          
          # Send Telegram alert if configured
          if [ "$alert_failures" = true ] && [ -n "${STRIPE_ALERT_CHAT_ID:-}" ] && [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
            local msg="🚨 *Payment Failed*%0ACustomer: ${customer}%0AAmount: \$$(echo "scale=2; $amount / 100" | bc)%0AReason: ${error}%0ATime: ${ts}"
            curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${STRIPE_ALERT_CHAT_ID}&text=${msg}&parse_mode=Markdown" >/dev/null 2>&1
          fi
          ;;
        charge.refunded)
          local amount=$(echo "$line" | jq -r '.data.object.amount_refunded // 0')
          echo -e "[${ts}] ${YELLOW}↩️ Refund${NC} — \$$(echo "scale=2; $amount / 100" | bc)"
          ;;
        customer.subscription.*)
          local action="${evt_type##*.}"
          local sub_id=$(echo "$line" | jq -r '.data.object.id // "unknown"')
          echo -e "[${ts}] ${BLUE}📋 Subscription ${action}${NC} — $sub_id"
          ;;
        charge.dispute.created)
          local amount=$(echo "$line" | jq -r '.data.object.amount // 0')
          echo -e "[${ts}] ${RED}⚠️ Dispute created${NC} — \$$(echo "scale=2; $amount / 100" | bc)"
          ;;
        *)
          echo -e "[${ts}] ${NC}${evt_type}${NC}"
          ;;
      esac
    fi
  done
}

cmd_export() {
  check_stripe
  check_jq
  local from="" to="" output="stripe-export.csv"
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --from) from="$2"; shift 2 ;;
      --to) to="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local args="--limit 100"
  [ -n "$from" ] && args="$args -d created[gte]=$(date -d "$from" +%s 2>/dev/null || date -j -f '%Y-%m-%d' "$from" +%s)"
  [ -n "$to" ] && args="$args -d created[lte]=$(date -d "$to" +%s 2>/dev/null || date -j -f '%Y-%m-%d' "$to" +%s)"
  
  echo "date,amount,currency,status,customer,description" > "$output"
  
  stripe charges list $args 2>/dev/null | \
    jq -r '.data[] | [
      (.created | todate),
      ((.amount // 0) / 100),
      .currency,
      .status,
      (.customer // ""),
      (.description // "")
    ] | @csv' >> "$output" 2>/dev/null
  
  local count=$(wc -l < "$output")
  echo -e "${GREEN}✅ Exported $((count - 1)) transactions to $output${NC}"
}

cmd_import_products() {
  check_stripe
  local file=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo -e "${RED}❌ --file is required and must exist${NC}"
    exit 1
  fi
  
  local count=0
  tail -n +2 "$file" | while IFS=, read -r name description price_cents currency interval; do
    name=$(echo "$name" | tr -d '"')
    description=$(echo "$description" | tr -d '"')
    
    echo "Creating product: $name..."
    local product_id=$(stripe products create -d "name=$name" -d "description=$description" 2>/dev/null | jq -r '.id')
    
    local price_args="-d product=$product_id -d unit_amount=$price_cents -d currency=$currency"
    [ -n "$interval" ] && interval=$(echo "$interval" | tr -d '"' | xargs) && [ "$interval" != "" ] && price_args="$price_args -d recurring[interval]=$interval"
    
    stripe prices create $price_args 2>/dev/null >/dev/null
    echo -e "  ${GREEN}✅ Created: $name — \$$(echo "scale=2; $price_cents / 100" | bc)${NC}"
    count=$((count + 1))
  done
  
  echo -e "\n${GREEN}✅ Import complete${NC}"
}

# ── Help ──────────────────────────────────────────────

cmd_help() {
  echo "Stripe CLI Manager"
  echo ""
  echo "Usage: bash scripts/run.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  status              Show Stripe CLI status and auth info"
  echo "  webhook-forward     Forward webhooks to local URL"
  echo "  events              List or stream events"
  echo "  products            List all products"
  echo "  product-create      Create a new product"
  echo "  price-create        Create a price for a product"
  echo "  payments            List recent payments"
  echo "  customers           List recent customers"
  echo "  customer            Get customer details"
  echo "  trigger             Trigger a test event"
  echo "  revenue             Show revenue summary"
  echo "  monitor             Real-time payment monitor with alerts"
  echo "  export              Export transactions to CSV"
  echo "  import-products     Import products from CSV"
  echo "  help                Show this help"
  echo ""
  echo "Environment:"
  echo "  STRIPE_API_KEY         Stripe secret key (sk_test_... or sk_live_...)"
  echo "  STRIPE_WEBHOOK_URL     Default webhook forwarding URL"
  echo "  STRIPE_ALERT_CHAT_ID   Telegram chat ID for failure alerts"
  echo "  TELEGRAM_BOT_TOKEN     Telegram bot token for alerts"
}

# ── Main ──────────────────────────────────────────────

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  status)           cmd_status ;;
  webhook-forward)  cmd_webhook_forward "$@" ;;
  events)           cmd_events "$@" ;;
  products)         cmd_products ;;
  product-create)   cmd_product_create "$@" ;;
  price-create)     cmd_price_create "$@" ;;
  payments)         cmd_payments "$@" ;;
  customers)        cmd_customers "$@" ;;
  customer)         cmd_customer "$@" ;;
  trigger)          cmd_trigger "$@" ;;
  revenue)          cmd_revenue "$@" ;;
  monitor)          cmd_monitor "$@" ;;
  export)           cmd_export "$@" ;;
  import-products)  cmd_import_products "$@" ;;
  help|--help|-h)   cmd_help ;;
  *)
    echo -e "${RED}Unknown command: $COMMAND${NC}"
    cmd_help
    exit 1
    ;;
esac
