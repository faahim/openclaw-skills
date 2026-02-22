#!/bin/bash
# Health check for a systemd service
set -euo pipefail

SERVICE="${1:?Usage: bash health.sh <service-name>}"

echo "Service: $SERVICE"

# Status
active=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "unknown")
case "$active" in
  active)   echo "Status:  ● active (running)" ;;
  inactive) echo "Status:  ○ inactive (stopped)" ;;
  failed)   echo "Status:  ✖ failed" ;;
  *)        echo "Status:  ? $active" ;;
esac

# PID
pid=$(systemctl show "$SERVICE" --property=MainPID --value 2>/dev/null || echo "0")
echo "PID:     $pid"

# Memory
mem_bytes=$(systemctl show "$SERVICE" --property=MemoryCurrent --value 2>/dev/null || echo "0")
mem_limit=$(systemctl show "$SERVICE" --property=MemoryMax --value 2>/dev/null || echo "infinity")
if [[ "$mem_bytes" =~ ^[0-9]+$ && "$mem_bytes" -gt 0 ]]; then
  mem_mb=$(awk "BEGIN {printf \"%.1f\", $mem_bytes / 1048576}")
  if [[ "$mem_limit" != "infinity" && "$mem_limit" =~ ^[0-9]+$ ]]; then
    limit_mb=$(awk "BEGIN {printf \"%.0f\", $mem_limit / 1048576}")
    echo "Memory:  ${mem_mb} MB (limit: ${limit_mb}MB)"
  else
    echo "Memory:  ${mem_mb} MB"
  fi
else
  echo "Memory:  -"
fi

# CPU
if [[ "$pid" != "0" && -d "/proc/$pid" ]]; then
  cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "-")
  echo "CPU:     ${cpu}%"
else
  echo "CPU:     -"
fi

# Uptime
active_enter=$(systemctl show "$SERVICE" --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
if [[ -n "$active_enter" && "$active_enter" != "n/a" ]]; then
  start_epoch=$(date -d "$active_enter" +%s 2>/dev/null || echo "0")
  now_epoch=$(date +%s)
  diff=$((now_epoch - start_epoch))
  days=$((diff / 86400))
  hours=$(( (diff % 86400) / 3600 ))
  mins=$(( (diff % 3600) / 60 ))
  if [[ $days -gt 0 ]]; then
    echo "Uptime:  ${days} days, ${hours} hours"
  elif [[ $hours -gt 0 ]]; then
    echo "Uptime:  ${hours} hours, ${mins} minutes"
  else
    echo "Uptime:  ${mins} minutes"
  fi
fi

# Restarts
restarts=$(systemctl show "$SERVICE" --property=NRestarts --value 2>/dev/null || echo "-")
echo "Restarts: $restarts"

# Recent errors
echo ""
echo "Recent errors:"
errors=$(journalctl -u "$SERVICE" -p err --no-pager -n 5 --output=short-iso 2>/dev/null || true)
if [[ -z "$errors" ]]; then
  echo "  none"
else
  echo "$errors" | sed 's/^/  /'
fi

# Check listening ports
if [[ "$pid" != "0" && -d "/proc/$pid" ]]; then
  ports=$(ss -tlnp 2>/dev/null | grep "pid=$pid" | awk '{print $4}' | rev | cut -d: -f1 | rev | sort -un | tr '\n' ',' | sed 's/,$//' || true)
  if [[ -n "$ports" ]]; then
    echo "Ports:   $ports (listening)"
  fi
fi
