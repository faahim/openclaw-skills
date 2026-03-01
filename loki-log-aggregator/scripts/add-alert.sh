#!/bin/bash
# Loki Log Aggregator — Add Alert Rule
# Configure Loki ruler to alert on log patterns

set -euo pipefail

LOKI_CONFIG="/etc/loki/config.yaml"
RULES_DIR="/etc/loki/rules/default"
ALERT_NAME=""
QUERY=""
THRESHOLD=1
WINDOW="5m"
WEBHOOK=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) ALERT_NAME="$2"; shift 2 ;;
    --query) QUERY="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --window) WINDOW="$2"; shift 2 ;;
    --webhook) WEBHOOK="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: add-alert.sh --name <name> --query '<LogQL>' --threshold <N> --window <dur> [--webhook <url>]"
      echo ""
      echo "Example:"
      echo "  add-alert.sh --name high-errors --query '{job=\"nginx\"} |= \"500\"' --threshold 10 --window 5m"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$ALERT_NAME" ] || [ -z "$QUERY" ]; then
  echo "❌ --name and --query are required"
  exit 1
fi

# Create rules directory
sudo mkdir -p "$RULES_DIR"

# Write rule file
RULE_FILE="${RULES_DIR}/${ALERT_NAME}.yaml"

cat > /tmp/loki-rule.yaml <<YAML
groups:
  - name: ${ALERT_NAME}
    rules:
      - alert: ${ALERT_NAME}
        expr: |
          sum(rate(${QUERY}[${WINDOW}])) > ${THRESHOLD}
        for: ${WINDOW}
        labels:
          severity: warning
        annotations:
          summary: "Alert: ${ALERT_NAME}"
          description: "Log pattern matched > ${THRESHOLD} times in ${WINDOW}"
YAML

sudo mv /tmp/loki-rule.yaml "$RULE_FILE"
sudo chown loki:loki "$RULE_FILE"

# Ensure ruler is enabled in Loki config
if ! grep -q "ruler:" "$LOKI_CONFIG" 2>/dev/null; then
  cat >> /tmp/loki-ruler-append.yaml <<YAML

ruler:
  storage:
    type: local
    local:
      directory: /etc/loki/rules
  rule_path: /var/lib/loki/rules-temp
  ring:
    kvstore:
      store: inmemory
  enable_api: true
  alertmanager_url: ""
YAML
  sudo bash -c "cat /tmp/loki-ruler-append.yaml >> $LOKI_CONFIG"
  rm -f /tmp/loki-ruler-append.yaml
fi

echo "✅ Alert rule '${ALERT_NAME}' created at ${RULE_FILE}"
echo ""
echo "Restart Loki to load the rule:"
echo "  bash scripts/manage.sh restart loki"

if [ -n "$WEBHOOK" ]; then
  echo ""
  echo "⚠️  To send alerts to ${WEBHOOK}, configure an Alertmanager instance"
  echo "   and set alertmanager_url in ${LOKI_CONFIG}"
fi
