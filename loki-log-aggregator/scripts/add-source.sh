#!/bin/bash
# Loki Log Aggregator — Add Log Source
# Add a new log file source to Promtail config

set -euo pipefail

PROMTAIL_CONFIG="/etc/promtail/config.yaml"
JOB_NAME=""
LOG_PATH=""
LABELS=""
DOCKER=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --job) JOB_NAME="$2"; shift 2 ;;
    --path) LOG_PATH="$2"; shift 2 ;;
    --labels) LABELS="$2"; shift 2 ;;
    --docker) DOCKER=true; shift ;;
    -h|--help)
      echo "Usage: add-source.sh --job <name> --path <log-path> [--labels 'key=val'] [--docker]"
      echo ""
      echo "Examples:"
      echo "  add-source.sh --job nginx --path '/var/log/nginx/*.log'"
      echo "  add-source.sh --job myapp --path '/opt/app/logs/*.log' --labels 'env=\"prod\"'"
      echo "  add-source.sh --job docker --path '/var/lib/docker/containers/**/*-json.log' --docker"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$JOB_NAME" ] || [ -z "$LOG_PATH" ]; then
  echo "❌ --job and --path are required"
  echo "   Run: add-source.sh --help"
  exit 1
fi

# Build the scrape config block
echo ""
echo "📝 Adding log source: ${JOB_NAME}"
echo "   Path: ${LOG_PATH}"

ENTRY="
  - job_name: ${JOB_NAME}
    static_configs:
      - targets: [localhost]
        labels:
          job: ${JOB_NAME}
          __path__: ${LOG_PATH}"

# Add extra labels
if [ -n "$LABELS" ]; then
  ENTRY="${ENTRY}
          ${LABELS}"
fi

# For Docker logs, add JSON pipeline stage
if $DOCKER; then
  ENTRY="${ENTRY}
    pipeline_stages:
      - docker: {}
      - json:
          expressions:
            stream: stream
            time: time
            log: log
      - output:
          source: log"
fi

# Append to Promtail config
echo "$ENTRY" | sudo tee -a "$PROMTAIL_CONFIG" > /dev/null

echo ""
echo "✅ Source '${JOB_NAME}' added to ${PROMTAIL_CONFIG}"
echo ""
echo "Restart Promtail to apply:"
echo "  bash scripts/manage.sh restart promtail"
echo ""
echo "Then query with:"
echo "  bash scripts/query.sh '{job=\"${JOB_NAME}\"}'"
