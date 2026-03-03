#!/bin/bash
# Generate a Logwatch report on-demand
set -e

# Defaults
DETAIL="${LOGWATCH_DETAIL:-Med}"
RANGE="${LOGWATCH_RANGE:-yesterday}"
FORMAT="${LOGWATCH_FORMAT:-text}"
OUTPUT="stdout"
EMAIL="${LOGWATCH_EMAIL:-}"
FILENAME=""
SERVICES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --detail)    DETAIL="$2"; shift 2 ;;
    --range)     RANGE="$2"; shift 2 ;;
    --format)    FORMAT="$2"; shift 2 ;;
    --email)     EMAIL="$2"; OUTPUT="mail"; shift 2 ;;
    --output)    FILENAME="$2"; OUTPUT="file"; shift 2 ;;
    --service)   SERVICES+=("$2"); shift 2 ;;
    --help|-h)
      echo "Usage: report.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --detail  LOW|MED|HIGH    Detail level (default: Med)"
      echo "  --range   RANGE           Date range (default: yesterday)"
      echo "                            Examples: today, yesterday,"
      echo "                            'between -7 days and today'"
      echo "  --format  text|html       Output format (default: text)"
      echo "  --email   ADDRESS         Email the report"
      echo "  --output  FILE            Save to file"
      echo "  --service NAME            Filter to specific service(s)"
      echo "                            (can be specified multiple times)"
      echo ""
      echo "Examples:"
      echo "  report.sh                            # Quick report, yesterday"
      echo "  report.sh --detail high              # Detailed report"
      echo "  report.sh --range today              # Today's activity"
      echo "  report.sh --service sshd --detail high   # SSH only"
      echo "  report.sh --email admin@example.com  # Email report"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check logwatch is installed
if ! command -v logwatch &>/dev/null; then
  echo "❌ Logwatch not installed. Run: bash scripts/install.sh"
  exit 1
fi

# Build command
CMD=(sudo logwatch --detail "$DETAIL" --range "$RANGE" --format "$FORMAT")

# Add service filters
for svc in "${SERVICES[@]}"; do
  CMD+=(--service "$svc")
done

# Handle output
case $OUTPUT in
  mail)
    if [[ -z "$EMAIL" ]]; then
      echo "❌ Email address required for mail output"
      exit 1
    fi
    CMD+=(--output mail --mailto "$EMAIL")
    echo "📧 Sending report to $EMAIL..."
    ;;
  file)
    if [[ -z "$FILENAME" ]]; then
      FILENAME="/var/log/logwatch/report-$(date +%Y%m%d-%H%M%S).txt"
    fi
    CMD+=(--output file --filename "$FILENAME")
    echo "📄 Saving report to $FILENAME..."
    ;;
  stdout)
    CMD+=(--output stdout)
    ;;
esac

# Run logwatch
"${CMD[@]}"

# Report status
if [[ $OUTPUT == "file" ]]; then
  echo ""
  echo "✅ Report saved to: $FILENAME ($(wc -c < "$FILENAME") bytes)"
elif [[ $OUTPUT == "mail" ]]; then
  echo "✅ Report sent to $EMAIL"
fi
