#!/bin/bash
# Create a custom CrowdSec scenario
# Usage: bash create-scenario.sh --name <name> --filter <filter> --groupby <groupby> --threshold <n> --timewindow <duration> --ban-duration <duration>
set -euo pipefail

NAME=""
FILTER=""
GROUPBY="evt.Meta.source_ip"
THRESHOLD=5
TIMEWINDOW="60s"
BAN_DURATION="4h"

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) NAME="$2"; shift 2 ;;
        --filter) FILTER="$2"; shift 2 ;;
        --groupby) GROUPBY="$2"; shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --timewindow) TIMEWINDOW="$2"; shift 2 ;;
        --ban-duration) BAN_DURATION="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$NAME" ] || [ -z "$FILTER" ]; then
    echo "Usage: bash create-scenario.sh --name <name> --filter <filter> [options]"
    echo ""
    echo "Options:"
    echo "  --groupby <field>        Group events by (default: evt.Meta.source_ip)"
    echo "  --threshold <n>          Trigger after N events (default: 5)"
    echo "  --timewindow <duration>  Within time window (default: 60s)"
    echo "  --ban-duration <dur>     Ban duration (default: 4h)"
    exit 1
fi

SCENARIO_FILE="/etc/crowdsec/scenarios/${NAME//\//-}.yaml"

sudo tee "$SCENARIO_FILE" > /dev/null <<EOF
type: leaky
name: ${NAME}
description: "Custom scenario: ${NAME}"
filter: "${FILTER}"
groupby: "${GROUPBY}"
capacity: ${THRESHOLD}
leakspeed: "${TIMEWINDOW}"
blackhole: "5m"
labels:
  remediation: true
  type: custom
EOF

sudo systemctl reload crowdsec
echo "✅ Custom scenario created: $NAME"
echo "   File: $SCENARIO_FILE"
echo "   Trigger: ${THRESHOLD} events in ${TIMEWINDOW} → ban ${BAN_DURATION}"
