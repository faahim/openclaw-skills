#!/bin/bash
# QR Code Generator — Main Script
# Requires: qrencode
set -e

# Defaults
TEXT=""
OUTPUT=""
FORMAT="png"
TERMINAL=false
SIZE=8
LEVEL="M"
FG="000000"
BG="FFFFFF"
WIFI=false
SSID=""
PASSWORD=""
ENCRYPTION="WPA"
VCARD=false
VNAME=""
VPHONE=""
VEMAIL=""
VURL=""
BATCH=""
OUTPUT_DIR="./qr-output"
STDIN=false

usage() {
  cat <<EOF
Usage: bash run.sh [OPTIONS]

QR Code Generator — Create QR codes from text, URLs, WiFi, vCards.

Options:
  --text TEXT         Text/URL to encode
  --output FILE       Output file (default: stdout for terminal)
  --format FORMAT     png, svg, terminal (default: png)
  --terminal          Display as UTF-8 art in terminal
  --size N            Module pixel size for PNG (default: 8)
  --level L|M|Q|H     Error correction level (default: M)
  --foreground HEX    Foreground color, 6-digit hex (default: 000000)
  --background HEX    Background color, 6-digit hex (default: FFFFFF)
  --wifi              Generate WiFi QR code
  --ssid NAME         WiFi SSID
  --password PASS     WiFi password
  --encryption TYPE   WPA, WEP, or nopass (default: WPA)
  --vcard             Generate vCard QR code
  --name NAME         vCard full name
  --phone PHONE       vCard phone
  --email EMAIL       vCard email
  --url URL           vCard website
  --batch FILE        Batch file (one text per line)
  --output-dir DIR    Batch output directory (default: ./qr-output)
  --stdin             Read text from stdin
  -h, --help          Show this help

Examples:
  bash run.sh --text "https://example.com" --output qr.png
  bash run.sh --text "Hello" --terminal
  bash run.sh --wifi --ssid "MyWiFi" --password "pass123" --output wifi.png
  bash run.sh --vcard --name "John" --email "j@x.com" --output contact.png
  bash run.sh --batch urls.txt --output-dir ./codes/
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --text) TEXT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --terminal) TERMINAL=true; shift ;;
    --size) SIZE="$2"; shift 2 ;;
    --level) LEVEL="$2"; shift 2 ;;
    --foreground) FG="$2"; shift 2 ;;
    --background) BG="$2"; shift 2 ;;
    --wifi) WIFI=true; shift ;;
    --ssid) SSID="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --encryption) ENCRYPTION="$2"; shift 2 ;;
    --vcard) VCARD=true; shift ;;
    --name) VNAME="$2"; shift 2 ;;
    --phone) VPHONE="$2"; shift 2 ;;
    --email) VEMAIL="$2"; shift 2 ;;
    --url) VURL="$2"; shift 2 ;;
    --batch) BATCH="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --stdin) STDIN=true; shift ;;
    -h|--help) usage ;;
    *) echo "❌ Unknown option: $1"; echo "Run with --help for usage."; exit 1 ;;
  esac
done

# Check qrencode is installed
if ! command -v qrencode &>/dev/null; then
  echo "❌ qrencode not found. Run: bash scripts/install.sh"
  exit 1
fi

# Build WiFi string
if $WIFI; then
  if [ -z "$SSID" ]; then
    echo "❌ --ssid is required for WiFi QR codes"; exit 1
  fi
  # Escape special chars in SSID and password
  ESCAPED_SSID=$(echo "$SSID" | sed 's/[\\;,:]/\\&/g')
  ESCAPED_PASS=$(echo "$PASSWORD" | sed 's/[\\;,:]/\\&/g')
  TEXT="WIFI:T:${ENCRYPTION};S:${ESCAPED_SSID};P:${ESCAPED_PASS};;"
fi

# Build vCard string
if $VCARD; then
  if [ -z "$VNAME" ]; then
    echo "❌ --name is required for vCard QR codes"; exit 1
  fi
  TEXT="BEGIN:VCARD
VERSION:3.0
FN:${VNAME}"
  [ -n "$VPHONE" ] && TEXT="${TEXT}
TEL:${VPHONE}"
  [ -n "$VEMAIL" ] && TEXT="${TEXT}
EMAIL:${VEMAIL}"
  [ -n "$VURL" ] && TEXT="${TEXT}
URL:${VURL}"
  TEXT="${TEXT}
END:VCARD"
fi

# Read from stdin
if $STDIN; then
  TEXT=$(cat)
fi

# Batch mode
if [ -n "$BATCH" ]; then
  if [ ! -f "$BATCH" ]; then
    echo "❌ Batch file not found: $BATCH"; exit 1
  fi
  mkdir -p "$OUTPUT_DIR"
  COUNT=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    COUNT=$((COUNT + 1))
    SLUG=$(echo "$line" | sed 's/[^a-zA-Z0-9]/-/g' | head -c 50)
    OUTFILE="${OUTPUT_DIR}/${COUNT}-${SLUG}.png"
    qrencode -o "$OUTFILE" -s "$SIZE" -l "$LEVEL" \
      --foreground="$FG" --background="$BG" "$line"
    echo "✅ [$COUNT] $OUTFILE — $line"
  done < "$BATCH"
  echo ""
  echo "📁 Generated $COUNT QR codes in $OUTPUT_DIR/"
  exit 0
fi

# Validate text
if [ -z "$TEXT" ]; then
  echo "❌ No text to encode. Use --text, --wifi, --vcard, --stdin, or --batch."
  echo "Run with --help for usage."
  exit 1
fi

# Terminal mode
if $TERMINAL; then
  qrencode -t UTF8 -l "$LEVEL" "$TEXT"
  exit 0
fi

# SVG mode
if [ "$FORMAT" = "svg" ]; then
  if [ -z "$OUTPUT" ]; then
    qrencode -t SVG -l "$LEVEL" "$TEXT"
  else
    qrencode -t SVG -l "$LEVEL" -o "$OUTPUT" "$TEXT"
    echo "✅ SVG saved: $OUTPUT"
  fi
  exit 0
fi

# PNG mode (default)
if [ -z "$OUTPUT" ]; then
  qrencode -t PNG -s "$SIZE" -l "$LEVEL" \
    --foreground="$FG" --background="$BG" "$TEXT"
else
  qrencode -t PNG -s "$SIZE" -l "$LEVEL" \
    --foreground="$FG" --background="$BG" -o "$OUTPUT" "$TEXT"
  # Get file size
  FSIZE=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null || echo "?")
  echo "✅ PNG saved: $OUTPUT (${FSIZE} bytes, module size: ${SIZE}px, EC level: ${LEVEL})"
fi
