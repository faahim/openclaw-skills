#!/bin/bash
# Show status of managed systemd services
set -euo pipefail

JSON=false
SERVICES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --all) shift ;;
    --json) JSON=true; shift ;;
    *) SERVICES+=("$1"); shift ;;
  esac
done

# If no specific services, find all custom services
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  mapfile -t SERVICES < <(
    grep -rl "managed service" /etc/systemd/system/*.service 2>/dev/null |
    xargs -I{} basename {} .service 2>/dev/null || true
  )
fi

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  echo "No managed services found."
  echo "Create one with: sudo bash scripts/create-service.sh --name myapp --exec '/path/to/app'"
  exit 0
fi

if [[ "$JSON" == true ]]; then
  echo "["
  first=true
  for svc in "${SERVICES[@]}"; do
    active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
    pid=$(systemctl show "$svc" --property=MainPID --value 2>/dev/null || echo "0")
    mem=$(systemctl show "$svc" --property=MemoryCurrent --value 2>/dev/null || echo "0")
    
    [[ "$first" == true ]] && first=false || echo ","
    printf '  {"name":"%s","active":"%s","enabled":"%s","pid":%s,"memory":%s}' \
      "$svc" "$active" "$enabled" "$pid" "$mem"
  done
  echo ""
  echo "]"
  exit 0
fi

# Table output
printf "%-24s %-12s %-8s %-10s %-20s %-10s\n" \
  "SERVICE" "STATUS" "CPU" "MEM" "UPTIME" "RESTARTS"
printf "%s\n" "$(printf '─%.0s' {1..90})"

for svc in "${SERVICES[@]}"; do
  active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
  
  case "$active" in
    active)   status="● running" ;;
    inactive) status="○ stopped" ;;
    failed)   status="✖ failed" ;;
    *)        status="? $active" ;;
  esac

  cpu="-"
  mem="-"
  uptime="-"
  restarts="-"

  if [[ "$active" == "active" ]]; then
    pid=$(systemctl show "$svc" --property=MainPID --value 2>/dev/null || echo "0")
    
    if [[ "$pid" != "0" && -d "/proc/$pid" ]]; then
      cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "-")
      cpu="${cpu}%"
      
      mem_bytes=$(systemctl show "$svc" --property=MemoryCurrent --value 2>/dev/null || echo "0")
      if [[ "$mem_bytes" =~ ^[0-9]+$ && "$mem_bytes" -gt 0 ]]; then
        mem_mb=$((mem_bytes / 1048576))
        mem="${mem_mb}MB"
      fi
    fi

    # Uptime
    active_enter=$(systemctl show "$svc" --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
    if [[ -n "$active_enter" && "$active_enter" != "n/a" ]]; then
      start_epoch=$(date -d "$active_enter" +%s 2>/dev/null || echo "0")
      now_epoch=$(date +%s)
      diff=$((now_epoch - start_epoch))
      days=$((diff / 86400))
      hours=$(( (diff % 86400) / 3600 ))
      mins=$(( (diff % 3600) / 60 ))
      if [[ $days -gt 0 ]]; then
        uptime="${days}d ${hours}h ${mins}m"
      elif [[ $hours -gt 0 ]]; then
        uptime="${hours}h ${mins}m"
      else
        uptime="${mins}m"
      fi
    fi

    # Restart count
    restarts=$(systemctl show "$svc" --property=NRestarts --value 2>/dev/null || echo "-")
  fi

  printf "%-24s %-12s %-8s %-10s %-20s %-10s\n" \
    "$svc" "$status" "$cpu" "$mem" "$uptime" "$restarts"
done
