#!/bin/bash
# Network Discovery — Manage Known Devices
set -euo pipefail

DATA_DIR="${NETDISC_DATA_DIR:-$HOME/.network-discovery}"
KNOWN_FILE="$DATA_DIR/known-devices.json"

mkdir -p "$DATA_DIR"
[[ -f "$KNOWN_FILE" ]] || echo '[]' > "$KNOWN_FILE"

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  add)
    MAC="${1:?Usage: manage.sh add <mac> <name>}"
    NAME="${2:?Usage: manage.sh add <mac> <name>}"
    MAC=$(echo "$MAC" | tr '[:upper:]' '[:lower:]')

    # Check if already exists
    EXISTS=$(jq --arg m "$MAC" '[.[] | select(.mac == $m)] | length' "$KNOWN_FILE")
    if [[ "$EXISTS" -gt 0 ]]; then
      echo "⚠️  Device $MAC already in known list. Updating name."
      jq --arg m "$MAC" --arg n "$NAME" 'map(if .mac == $m then .name = $n else . end)' "$KNOWN_FILE" > "${KNOWN_FILE}.tmp"
    else
      jq --arg m "$MAC" --arg n "$NAME" --arg d "$(date -u +%Y-%m-%d)" \
        '. += [{"mac": $m, "name": $n, "added": $d}]' "$KNOWN_FILE" > "${KNOWN_FILE}.tmp"
    fi
    mv "${KNOWN_FILE}.tmp" "$KNOWN_FILE"
    echo "✅ Added: $MAC → $NAME"
    ;;

  remove)
    MAC="${1:?Usage: manage.sh remove <mac>}"
    MAC=$(echo "$MAC" | tr '[:upper:]' '[:lower:]')
    jq --arg m "$MAC" 'map(select(.mac != $m))' "$KNOWN_FILE" > "${KNOWN_FILE}.tmp"
    mv "${KNOWN_FILE}.tmp" "$KNOWN_FILE"
    echo "🗑️  Removed: $MAC"
    ;;

  list)
    COUNT=$(jq 'length' "$KNOWN_FILE")
    echo "📋 Known devices ($COUNT):"
    echo ""
    printf "%-20s %-30s %s\n" "MAC Address" "Name" "Added"
    printf "%-20s %-30s %s\n" "-----------" "----" "-----"
    jq -r '.[] | [.mac, .name, .added] | @tsv' "$KNOWN_FILE" | while IFS=$'\t' read -r mac name added; do
      printf "%-20s %-30s %s\n" "$mac" "$name" "$added"
    done
    ;;

  import)
    # Auto-import all devices from the latest scan as "known"
    LATEST=$(ls -1t "$DATA_DIR/scans/"*.json 2>/dev/null | head -1)
    if [[ -z "$LATEST" ]]; then
      echo "❌ No scan results found. Run scan.sh first."
      exit 1
    fi
    IMPORTED=0
    jq -r '.devices[] | [.mac, .vendor] | @tsv' "$LATEST" | while IFS=$'\t' read -r mac vendor; do
      EXISTS=$(jq --arg m "$mac" '[.[] | select(.mac == $m)] | length' "$KNOWN_FILE")
      if [[ "$EXISTS" == "0" ]]; then
        jq --arg m "$mac" --arg n "$vendor" --arg d "$(date -u +%Y-%m-%d)" \
          '. += [{"mac": $m, "name": $n, "added": $d}]' "$KNOWN_FILE" > "${KNOWN_FILE}.tmp"
        mv "${KNOWN_FILE}.tmp" "$KNOWN_FILE"
        echo "  ✅ $mac → $vendor"
        IMPORTED=$((IMPORTED + 1))
      fi
    done
    echo "Done. Imported devices from latest scan."
    ;;

  help|*)
    echo "Network Discovery — Device Manager"
    echo ""
    echo "Usage:"
    echo "  manage.sh add <mac> <name>     Add device to known list"
    echo "  manage.sh remove <mac>         Remove device from known list"
    echo "  manage.sh list                 List all known devices"
    echo "  manage.sh import               Import all devices from latest scan"
    ;;
esac
