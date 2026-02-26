#!/bin/bash
# ClamAV Antivirus — Scan files and directories
set -e

SCAN_PATH=""
QUARANTINE=false
QUARANTINE_DIR="${CLAMAV_QUARANTINE_DIR:-/var/clamav/quarantine}"
SCAN_LOG="${CLAMAV_SCAN_LOG:-/var/log/clamav/scan.log}"
ALERT=""
EXCLUDE=""
EXCLUDE_EXT=""
NO_DAEMON=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) SCAN_PATH="$2"; shift 2 ;;
        --quarantine) QUARANTINE=true; shift ;;
        --alert) ALERT="$2"; shift 2 ;;
        --exclude) EXCLUDE="$2"; shift 2 ;;
        --exclude-ext) EXCLUDE_EXT="$2"; shift 2 ;;
        --no-daemon) NO_DAEMON=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --config) CONFIG="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SCAN_PATH" && -z "$CONFIG" ]]; then
    echo "Usage: bash scan.sh --path /directory [--quarantine] [--alert telegram] [--exclude dir1,dir2]"
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] 🔍 Scanning $SCAN_PATH ..."

# Build clamscan command
SCAN_CMD="clamscan"
if [[ "$NO_DAEMON" == false ]] && command -v clamdscan &>/dev/null && systemctl is-active clamav-daemon &>/dev/null 2>&1; then
    SCAN_CMD="clamdscan"
fi

SCAN_ARGS="-r --stdout"

if [[ "$QUARANTINE" == true ]]; then
    mkdir -p "$QUARANTINE_DIR"
    SCAN_ARGS="$SCAN_ARGS --move=$QUARANTINE_DIR"
fi

# Add excludes
if [[ -n "$EXCLUDE" ]]; then
    IFS=',' read -ra DIRS <<< "$EXCLUDE"
    for dir in "${DIRS[@]}"; do
        SCAN_ARGS="$SCAN_ARGS --exclude-dir=$dir"
    done
fi

if [[ -n "$EXCLUDE_EXT" ]]; then
    IFS=',' read -ra EXTS <<< "$EXCLUDE_EXT"
    for ext in "${EXTS[@]}"; do
        SCAN_ARGS="$SCAN_ARGS --exclude=\\.${ext}$"
    done
fi

# Run scan
TEMP_RESULT=$(mktemp)
START_TIME=$(date +%s)

$SCAN_CMD $SCAN_ARGS "$SCAN_PATH" > "$TEMP_RESULT" 2>&1 || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Parse results
INFECTED=$(grep -c "FOUND$" "$TEMP_RESULT" 2>/dev/null || echo "0")
SCANNED=$(grep -oP 'Scanned files: \K\d+' "$TEMP_RESULT" 2>/dev/null || grep -c "" "$TEMP_RESULT" 2>/dev/null || echo "0")
THREATS=$(grep "FOUND$" "$TEMP_RESULT" 2>/dev/null || true)

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [[ "$INFECTED" -gt 0 ]]; then
    echo "[$TIMESTAMP] ⚠️  THREATS DETECTED:"
    echo "$THREATS" | while IFS= read -r line; do
        FILE=$(echo "$line" | cut -d: -f1)
        VIRUS=$(echo "$line" | cut -d: -f2 | sed 's/ FOUND$//' | xargs)
        echo "  ⚠️  $FILE — $VIRUS"
        if [[ "$QUARANTINE" == true ]]; then
            echo "  📦 Quarantined → $QUARANTINE_DIR/$(basename "$FILE")"
        fi
    done

    # Send alert
    if [[ "$ALERT" == "telegram" && -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        HOSTNAME=$(hostname)
        ALERT_MSG="🚨 *ClamAV Alert*%0AHost: $HOSTNAME%0APath: $SCAN_PATH%0AThreats: $INFECTED%0A%0A$(echo "$THREATS" | head -5 | sed 's/ FOUND$//' | while read -r l; do echo "• $l%0A"; done)"
        
        curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${ALERT_MSG}" \
            -d "parse_mode=Markdown" > /dev/null 2>&1 || true
        echo "  📱 Alert sent to Telegram"
    fi
else
    echo "[$TIMESTAMP] ✅ Scan complete — no threats found"
fi

echo "[$TIMESTAMP] 📊 $SCANNED files scanned, $INFECTED threats, ${DURATION}s"

# Log results
mkdir -p "$(dirname "$SCAN_LOG")"
echo "$TIMESTAMP|$SCAN_PATH|$SCANNED|$INFECTED|${DURATION}s" >> "$SCAN_LOG" 2>/dev/null || true

# JSON output
if [[ "$JSON_OUTPUT" == true ]]; then
    echo "{\"timestamp\":\"$TIMESTAMP\",\"path\":\"$SCAN_PATH\",\"files\":$SCANNED,\"threats\":$INFECTED,\"duration\":$DURATION}"
fi

rm -f "$TEMP_RESULT"

[[ "$INFECTED" -gt 0 ]] && exit 1 || exit 0
