#!/bin/bash
# Check status of all Prometheus targets
set -euo pipefail

PROM_URL="${PROMETHEUS_URL:-http://localhost:9090}"

echo "📊 Prometheus Target Status"
echo "=========================="
echo ""

# Check Prometheus itself
if ! curl -sf "${PROM_URL}/-/healthy" &>/dev/null; then
  echo "❌ Prometheus is not running at ${PROM_URL}"
  exit 1
fi

# Get all targets
TARGETS=$(curl -sf "${PROM_URL}/api/v1/targets" 2>/dev/null)

if [ -z "$TARGETS" ]; then
  echo "❌ Failed to query targets"
  exit 1
fi

echo "$TARGETS" | jq -r '.data.activeTargets[] | 
  if .health == "up" then "✅" else "❌" end + 
  " " + .scrapePool + " | " + 
  .labels.instance + 
  (if .labels.instance_name then " (" + .labels.instance_name + ")" else "" end) +
  " — " + (.health | ascii_upcase) + 
  " — last scrape: " + .lastScrape'

echo ""

# Show active alerts
ALERTS=$(curl -sf "${PROM_URL}/api/v1/alerts" 2>/dev/null)
ALERT_COUNT=$(echo "$ALERTS" | jq '.data.alerts | length' 2>/dev/null || echo "0")

if [ "$ALERT_COUNT" -gt 0 ]; then
  echo "🔔 Active Alerts (${ALERT_COUNT}):"
  echo "$ALERTS" | jq -r '.data.alerts[] | "  " + 
    (if .state == "firing" then "🔴" else "🟡" end) + " " +
    .labels.alertname + " — " + .annotations.summary'
else
  echo "✅ No active alerts"
fi

echo ""

# Quick system stats via PromQL
echo "📈 Quick Stats (local):"
CPU=$(curl -sf "${PROM_URL}/api/v1/query?query=100-(avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))*100)" 2>/dev/null | jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null)
MEM=$(curl -sf "${PROM_URL}/api/v1/query?query=100*(1-node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes)" 2>/dev/null | jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null)
DISK=$(curl -sf "${PROM_URL}/api/v1/query?query=100*(1-node_filesystem_avail_bytes{mountpoint=\"/\"}/node_filesystem_size_bytes{mountpoint=\"/\"})" 2>/dev/null | jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null)

printf "  CPU:  %s%%\n" "$(echo "$CPU" | head -c 5)"
printf "  MEM:  %s%%\n" "$(echo "$MEM" | head -c 5)"
printf "  DISK: %s%%\n" "$(echo "$DISK" | head -c 5)"
