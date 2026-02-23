#!/bin/bash
# Invoice Generator — Generate professional PDF invoices
# Requires: wkhtmltopdf, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$HOME/.invoice-generator.conf"
LEDGER_FILE="${LEDGER_FILE:-$HOME/invoices/ledger.json}"

# Load config defaults
DEFAULT_CURRENCY="USD"
DEFAULT_TAX_RATE=0
DEFAULT_DUE_DAYS=30
DEFAULT_NOTES=""
DEFAULT_TERMS=""
DEFAULT_FROM_NAME=""
DEFAULT_FROM_ADDRESS=""
DEFAULT_FROM_EMAIL=""
AUTO_NUMBER=false
NUMBER_PREFIX="INV"
NUMBER_YEAR=true

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Parse arguments
JSON_FILE=""
TEMPLATE_FILE="$SKILL_DIR/templates/default.html"
OUTPUT_DIR="."
INV_NUMBER=""
FROM_NAME="$DEFAULT_FROM_NAME"
TO_NAME=""
ITEMS=()
TAX_RATE="$DEFAULT_TAX_RATE"
CURRENCY="$DEFAULT_CURRENCY"
DUE_DAYS="$DEFAULT_DUE_DAYS"
NOTES="$DEFAULT_NOTES"
TERMS="$DEFAULT_TERMS"

while [[ $# -gt 0 ]]; do
  case $1 in
    --json) JSON_FILE="$2"; shift 2 ;;
    --template) TEMPLATE_FILE="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --number) INV_NUMBER="$2"; shift 2 ;;
    --from) FROM_NAME="$2"; shift 2 ;;
    --to) TO_NAME="$2"; shift 2 ;;
    --item) ITEMS+=("$2"); shift 2 ;;
    --tax) TAX_RATE="$2"; shift 2 ;;
    --currency) CURRENCY="$2"; shift 2 ;;
    --due-days) DUE_DAYS="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    --terms) TERMS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: generate.sh [--json FILE | --number NUM --from NAME --to NAME --item 'DESC|QTY|RATE' ...]"
      echo "Options:"
      echo "  --json FILE        Invoice data as JSON"
      echo "  --template FILE    Custom HTML template"
      echo "  --output DIR       Output directory (default: .)"
      echo "  --number NUM       Invoice number"
      echo "  --from NAME        Sender name"
      echo "  --to NAME          Recipient name"
      echo "  --item 'D|Q|R'     Line item (description|quantity|rate)"
      echo "  --tax PERCENT      Tax rate (default: 0)"
      echo "  --currency CODE    Currency code (default: USD)"
      echo "  --due-days N       Days until due (default: 30)"
      echo "  --notes TEXT       Invoice notes"
      echo "  --terms TEXT       Payment terms"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Currency symbols
get_currency_symbol() {
  case "$1" in
    USD) echo '$' ;;
    EUR) echo '€' ;;
    GBP) echo '£' ;;
    BDT) echo '৳' ;;
    INR) echo '₹' ;;
    JPY) echo '¥' ;;
    CAD) echo 'CA$' ;;
    AUD) echo 'A$' ;;
    *) echo "$1 " ;;
  esac
}

# Auto-generate invoice number
generate_number() {
  local prefix="${NUMBER_PREFIX}"
  local year=""
  [[ "$NUMBER_YEAR" == "true" ]] && year="-$(date +%Y)"
  
  # Find next number from ledger
  local next=1
  if [[ -f "$LEDGER_FILE" ]]; then
    local last
    last=$(jq -r '[.invoices[].number] | map(split("-") | last | tonumber) | max // 0' "$LEDGER_FILE" 2>/dev/null || echo 0)
    next=$((last + 1))
  fi
  printf "%s%s-%03d" "$prefix" "$year" "$next"
}

# Build invoice data from CLI args
build_cli_data() {
  local date_now
  date_now=$(date +%Y-%m-%d)
  local due_date
  due_date=$(date -d "+${DUE_DAYS} days" +%Y-%m-%d 2>/dev/null || date -v+${DUE_DAYS}d +%Y-%m-%d 2>/dev/null || echo "$date_now")
  
  [[ -z "$INV_NUMBER" ]] && INV_NUMBER=$(generate_number)
  
  local items_json="["
  local first=true
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r desc qty rate <<< "$item"
    [[ "$first" == "true" ]] && first=false || items_json+=","
    items_json+="{\"description\":\"$desc\",\"quantity\":$qty,\"rate\":$rate}"
  done
  items_json+="]"
  
  cat << EOF
{
  "number": "$INV_NUMBER",
  "date": "$date_now",
  "due_date": "$due_date",
  "from": {"name": "$FROM_NAME", "address": "", "email": ""},
  "to": {"name": "$TO_NAME", "address": "", "email": ""},
  "items": $items_json,
  "currency": "$CURRENCY",
  "tax_rate": $TAX_RATE,
  "notes": "$NOTES",
  "terms": "$TERMS"
}
EOF
}

# Check dependencies
for cmd in wkhtmltopdf jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Missing dependency: $cmd"
    echo "Install: sudo apt-get install -y $cmd"
    exit 1
  fi
done

# Get invoice data
if [[ -n "$JSON_FILE" ]]; then
  if [[ ! -f "$JSON_FILE" ]]; then
    echo "❌ File not found: $JSON_FILE"
    exit 1
  fi
  DATA=$(cat "$JSON_FILE")
else
  if [[ ${#ITEMS[@]} -eq 0 ]]; then
    echo "❌ No items. Use --item 'Description|Quantity|Rate' or --json FILE"
    exit 1
  fi
  DATA=$(build_cli_data)
fi

# Extract fields
INV_NUMBER=$(echo "$DATA" | jq -r '.number')
DATE=$(echo "$DATA" | jq -r '.date')
DUE_DATE=$(echo "$DATA" | jq -r '.due_date')
FROM_NAME=$(echo "$DATA" | jq -r '.from.name // ""')
FROM_ADDR=$(echo "$DATA" | jq -r '.from.address // ""')
FROM_EMAIL=$(echo "$DATA" | jq -r '.from.email // ""')
TO_NAME=$(echo "$DATA" | jq -r '.to.name // ""')
TO_ADDR=$(echo "$DATA" | jq -r '.to.address // ""')
TO_EMAIL=$(echo "$DATA" | jq -r '.to.email // ""')
CURRENCY=$(echo "$DATA" | jq -r '.currency // "USD"')
TAX_RATE=$(echo "$DATA" | jq -r '.tax_rate // 0')
NOTES=$(echo "$DATA" | jq -r '.notes // ""')
TERMS=$(echo "$DATA" | jq -r '.terms // ""')

SYMBOL=$(get_currency_symbol "$CURRENCY")

# Build items table rows and calculate totals
SUBTOTAL=0
ITEMS_HTML=""
while IFS= read -r item; do
  desc=$(echo "$item" | jq -r '.description')
  qty=$(echo "$item" | jq -r '.quantity')
  rate=$(echo "$item" | jq -r '.rate')
  amount=$(echo "$qty * $rate" | bc -l)
  SUBTOTAL=$(echo "$SUBTOTAL + $amount" | bc -l)
  ITEMS_HTML+="<tr><td>${desc}</td><td style='text-align:center'>${qty}</td><td style='text-align:right'>${SYMBOL}$(printf '%.2f' "$rate")</td><td style='text-align:right'>${SYMBOL}$(printf '%.2f' "$amount")</td></tr>"
done < <(echo "$DATA" | jq -c '.items[]')

TAX_AMOUNT=$(echo "$SUBTOTAL * $TAX_RATE / 100" | bc -l)
TOTAL=$(echo "$SUBTOTAL + $TAX_AMOUNT" | bc -l)

SUBTOTAL_FMT=$(printf '%.2f' "$SUBTOTAL")
TAX_FMT=$(printf '%.2f' "$TAX_AMOUNT")
TOTAL_FMT=$(printf '%.2f' "$TOTAL")

# Read template
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "❌ Template not found: $TEMPLATE_FILE"
  exit 1
fi

HTML=$(cat "$TEMPLATE_FILE")

# Replace placeholders
HTML="${HTML//\{\{invoice_number\}\}/$INV_NUMBER}"
HTML="${HTML//\{\{date\}\}/$DATE}"
HTML="${HTML//\{\{due_date\}\}/$DUE_DATE}"
HTML="${HTML//\{\{from_name\}\}/$FROM_NAME}"
HTML="${HTML//\{\{from_address\}\}/$FROM_ADDR}"
HTML="${HTML//\{\{from_email\}\}/$FROM_EMAIL}"
HTML="${HTML//\{\{to_name\}\}/$TO_NAME}"
HTML="${HTML//\{\{to_address\}\}/$TO_ADDR}"
HTML="${HTML//\{\{to_email\}\}/$TO_EMAIL}"
HTML="${HTML//\{\{items_table\}\}/$ITEMS_HTML}"
HTML="${HTML//\{\{subtotal\}\}/${SYMBOL}${SUBTOTAL_FMT}}"
HTML="${HTML//\{\{tax\}\}/${SYMBOL}${TAX_FMT}}"
HTML="${HTML//\{\{tax_rate\}\}/${TAX_RATE}%}"
HTML="${HTML//\{\{total\}\}/${SYMBOL}${TOTAL_FMT}}"
HTML="${HTML//\{\{currency\}\}/$CURRENCY}"
HTML="${HTML//\{\{notes\}\}/$NOTES}"
HTML="${HTML//\{\{terms\}\}/$TERMS}"

# Generate PDF
mkdir -p "$OUTPUT_DIR"
TEMP_HTML=$(mktemp /tmp/invoice-XXXXXX.html)
echo "$HTML" > "$TEMP_HTML"

PDF_FILE="$OUTPUT_DIR/${INV_NUMBER}.pdf"

# Use xvfb-run if available and no display
WKHTML_CMD="wkhtmltopdf"
if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run &>/dev/null; then
  WKHTML_CMD="xvfb-run --auto-servernum wkhtmltopdf"
fi

$WKHTML_CMD --quiet --encoding utf-8 --page-size A4 --margin-top 15mm --margin-bottom 15mm --margin-left 15mm --margin-right 15mm "$TEMP_HTML" "$PDF_FILE" 2>/dev/null

rm -f "$TEMP_HTML"

# Update ledger
mkdir -p "$(dirname "$LEDGER_FILE")"
if [[ ! -f "$LEDGER_FILE" ]]; then
  echo '{"invoices":[]}' > "$LEDGER_FILE"
fi

jq --arg num "$INV_NUMBER" \
   --arg date "$DATE" \
   --arg due "$DUE_DATE" \
   --arg client "$TO_NAME" \
   --arg total "${SYMBOL}${TOTAL_FMT}" \
   --arg currency "$CURRENCY" \
   --arg file "$PDF_FILE" \
   '.invoices += [{"number":$num,"date":$date,"due_date":$due,"client":$client,"total":$total,"currency":$currency,"file":$file,"status":"pending","created_at":now|todate}]' \
   "$LEDGER_FILE" > "${LEDGER_FILE}.tmp" && mv "${LEDGER_FILE}.tmp" "$LEDGER_FILE"

echo "✅ Generated: $PDF_FILE"
echo "   Invoice: $INV_NUMBER | Client: $TO_NAME | Total: ${SYMBOL}${TOTAL_FMT}"
