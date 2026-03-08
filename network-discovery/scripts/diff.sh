#!/bin/bash
# Network Discovery — Compare last two scans
set -euo pipefail

DATA_DIR="${NETDISC_DATA_DIR:-$HOME/.network-discovery}"
SCANS_DIR="$DATA_DIR/scans"
KNOWN_FILE="$DATA_DIR/known-devices.json"

[[ -f "$KNOWN_FILE" ]] || echo '[]' > "$KNOWN_FILE"

# Get last two scans
LATEST=$(ls -1t "$SCANS_DIR"/*.json 2>/dev/null | head -1)
PREVIOUS=$(ls -1t "$SCANS_DIR"/*.json 2>/dev/null | sed -n '2p')

if [[ -z "$LATEST" ]]; then
  echo "❌ No scans found. Run scan.sh first."
  exit 1
fi

if [[ -z "$PREVIOUS" ]]; then
  echo "Only one scan available. Run scan.sh again to compare."
  exit 0
fi

echo "📊 Network Changes"
echo "   Previous: $(jq -r '.timestamp' "$PREVIOUS")"
echo "   Current:  $(jq -r '.timestamp' "$LATEST")"
echo ""

PREV_COUNT=$(jq '.device_count' "$PREVIOUS")
CUR_COUNT=$(jq '.device_count' "$LATEST")
echo "   Devices: $PREV_COUNT → $CUR_COUNT"
echo ""

# Find new devices
PREV_MACS=$(jq -r '.devices[].mac' "$PREVIOUS" | sort)
CUR_MACS=$(jq -r '.devices[].mac' "$LATEST" | sort)

NEW=$(comm -13 <(echo "$PREV_MACS") <(echo "$CUR_MACS"))
GONE=$(comm -23 <(echo "$PREV_MACS") <(echo "$CUR_MACS"))

if [[ -n "$NEW" ]]; then
  echo "➕ New devices:"
  echo "$NEW" | while read -r mac; do
    [[ -z "$mac" ]] && continue
    IP=$(jq -r --arg m "$mac" '.devices[] | select(.mac == $m) | .ip' "$LATEST")
    VENDOR=$(jq -r --arg m "$mac" '.devices[] | select(.mac == $m) | .vendor' "$LATEST")
    echo "   $IP — $mac ($VENDOR)"
  done
  echo ""
fi

if [[ -n "$GONE" ]]; then
  echo "➖ Departed devices:"
  echo "$GONE" | while read -r mac; do
    [[ -z "$mac" ]] && continue
    IP=$(jq -r --arg m "$mac" '.devices[] | select(.mac == $m) | .ip' "$PREVIOUS")
    NAME=$(jq -r --arg m "$mac" '.[] | select(.mac == $m) | .name // "(unknown)"' "$KNOWN_FILE")
    echo "   $IP — $mac ($NAME)"
  done
  echo ""
fi

if [[ -z "$NEW" && -z "$GONE" ]]; then
  echo "✅ No changes detected."
fi

# IP changes for same MAC
echo "$CUR_MACS" | while read -r mac; do
  [[ -z "$mac" ]] && continue
  CUR_IP=$(jq -r --arg m "$mac" '.devices[] | select(.mac == $m) | .ip' "$LATEST" 2>/dev/null)
  PREV_IP=$(jq -r --arg m "$mac" '.devices[] | select(.mac == $m) | .ip' "$PREVIOUS" 2>/dev/null)
  if [[ -n "$PREV_IP" && "$CUR_IP" != "$PREV_IP" ]]; then
    echo "🔄 IP changed: $mac — $PREV_IP → $CUR_IP"
  fi
done
