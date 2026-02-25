#!/bin/bash
# Set up scheduled GoAccess report generation via cron
set -euo pipefail

LOG_FILE=""
LOG_FORMAT="COMBINED"
OUTPUT_DIR=""
SCHEDULE="daily"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --log) LOG_FILE="$2"; shift 2 ;;
        --format) LOG_FORMAT="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --schedule) SCHEDULE="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [[ -z "$LOG_FILE" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: bash setup-cron.sh --log <path> --output-dir <path> [--format COMBINED] [--schedule daily|hourly|weekly]"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Create the report generation script
REPORT_SCRIPT="$OUTPUT_DIR/generate-report.sh"
cat > "$REPORT_SCRIPT" <<SCRIPT
#!/bin/bash
# Auto-generated GoAccess report script
DATE=\$(date +%Y-%m-%d)
HOUR=\$(date +%H)
bash "$SCRIPT_DIR/analyze.sh" \\
    --log "$LOG_FILE" \\
    --format "$LOG_FORMAT" \\
    --html "$OUTPUT_DIR/analytics-\${DATE}.html"

# Keep latest as index
cp "$OUTPUT_DIR/analytics-\${DATE}.html" "$OUTPUT_DIR/index.html" 2>/dev/null || true

# Clean reports older than 30 days
find "$OUTPUT_DIR" -name "analytics-*.html" -mtime +30 -delete 2>/dev/null || true
SCRIPT
chmod +x "$REPORT_SCRIPT"

# Set cron schedule
case $SCHEDULE in
    hourly)  CRON_EXPR="0 * * * *" ;;
    daily)   CRON_EXPR="0 2 * * *" ;;  # 2 AM
    weekly)  CRON_EXPR="0 2 * * 0" ;;  # Sunday 2 AM
    *)       echo "Unknown schedule: $SCHEDULE (use: hourly, daily, weekly)"; exit 1 ;;
esac

# Add to crontab (idempotent)
CRON_LINE="$CRON_EXPR bash $REPORT_SCRIPT >> $OUTPUT_DIR/cron.log 2>&1"
CRON_TAG="# goaccess-analytics"

(crontab -l 2>/dev/null | grep -v "$CRON_TAG" || true; echo "$CRON_LINE $CRON_TAG") | crontab -

echo "✅ Cron job added ($SCHEDULE at $CRON_EXPR)"
echo "   Reports: $OUTPUT_DIR/analytics-YYYY-MM-DD.html"
echo "   Latest:  $OUTPUT_DIR/index.html"
echo "   Logs:    $OUTPUT_DIR/cron.log"
echo ""
echo "   To remove: crontab -e (delete the goaccess-analytics line)"
