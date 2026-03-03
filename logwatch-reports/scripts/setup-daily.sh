#!/bin/bash
# Set up scheduled Logwatch reports via cron
set -e

# Defaults
EMAIL=""
DETAIL="Med"
RANGE="yesterday"
FORMAT="text"
TIME="0 6 * * *"  # 6 AM daily
OUTPUT_TYPE="mail"
FILENAME=""
PROFILE="default"
SERVICES=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --email)     EMAIL="$2"; OUTPUT_TYPE="mail"; shift 2 ;;
    --detail)    DETAIL="$2"; shift 2 ;;
    --range)     RANGE="$2"; shift 2 ;;
    --format)    FORMAT="$2"; shift 2 ;;
    --time)      TIME="$2"; shift 2 ;;
    --output)    FILENAME="$2"; OUTPUT_TYPE="file"; shift 2 ;;
    --profile)   PROFILE="$2"; shift 2 ;;
    --service)   SERVICES="$SERVICES --service $2"; shift 2 ;;
    --help|-h)
      echo "Usage: setup-daily.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --email ADDRESS      Send report to this email"
      echo "  --output FILE        Save report to file instead"
      echo "  --detail LOW|MED|HIGH  Detail level (default: Med)"
      echo "  --range RANGE        Date range (default: yesterday)"
      echo "  --format text|html   Output format (default: text)"
      echo "  --time 'CRON_EXPR'   Cron schedule (default: '0 6 * * *')"
      echo "  --profile NAME       Profile name for multiple schedules"
      echo "  --service NAME       Filter services (repeatable)"
      echo ""
      echo "Examples:"
      echo "  setup-daily.sh --email admin@example.com"
      echo "  setup-daily.sh --output /var/log/logwatch/daily.txt"
      echo "  setup-daily.sh --email sec@co.com --profile security --service sshd --service sudo --detail high"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [[ "$OUTPUT_TYPE" == "mail" && -z "$EMAIL" ]]; then
  echo "❌ Either --email or --output is required"
  exit 1
fi

# Build logwatch command for cron
LW_CMD="logwatch --detail $DETAIL --range \"$RANGE\" --format $FORMAT"

if [[ "$OUTPUT_TYPE" == "mail" ]]; then
  LW_CMD="$LW_CMD --output mail --mailto $EMAIL"
elif [[ "$OUTPUT_TYPE" == "file" ]]; then
  LW_CMD="$LW_CMD --output file --filename $FILENAME"
fi

if [[ -n "$SERVICES" ]]; then
  LW_CMD="$LW_CMD $SERVICES"
fi

# Cron job identifier
CRON_ID="# logwatch-report-$PROFILE"

# Remove existing cron for this profile
(crontab -l 2>/dev/null | grep -v "$CRON_ID" | grep -v "logwatch.*# $PROFILE") | crontab - 2>/dev/null || true

# Add new cron job
(crontab -l 2>/dev/null; echo "$TIME $LW_CMD $CRON_ID") | crontab -

echo "✅ Scheduled Logwatch report!"
echo ""
echo "  Profile:  $PROFILE"
echo "  Schedule: $TIME"
echo "  Detail:   $DETAIL"
echo "  Range:    $RANGE"
echo "  Format:   $FORMAT"
if [[ "$OUTPUT_TYPE" == "mail" ]]; then
  echo "  Email:    $EMAIL"
else
  echo "  Output:   $FILENAME"
fi
if [[ -n "$SERVICES" ]]; then
  echo "  Services: $SERVICES"
fi
echo ""
echo "To view cron entry: crontab -l | grep logwatch"
echo "To remove: crontab -l | grep -v 'logwatch-report-$PROFILE' | crontab -"
