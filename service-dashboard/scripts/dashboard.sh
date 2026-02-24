#!/usr/bin/env bash
# Service Health Dashboard — Generate a status page from service checks
# Usage: bash dashboard.sh --config config.yaml --output status.html
set -euo pipefail

# --- Defaults ---
CONFIG=""
OUTPUT="/tmp/service-dashboard.html"
FORMAT="html"
HISTORY_FILE="${SERVICE_DASHBOARD_HISTORY:-$HOME/.service-dashboard-history.jsonl}"
REPORT_DAYS=""
ALERT_STATE_FILE="${SERVICE_DASHBOARD_STATE:-$HOME/.service-dashboard-state.json}"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --report) REPORT_DAYS="$2"; shift 2 ;;
    -h|--help) echo "Usage: dashboard.sh --config <yaml> [--output <path>] [--format html|json] [--report 7d]"; exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$CONFIG" ]] && { echo "Error: --config required"; exit 1; }
[[ ! -f "$CONFIG" ]] && { echo "Error: Config not found: $CONFIG"; exit 1; }

# --- Simple YAML parser (handles our flat config) ---
parse_yaml_checks() {
  python3 -c "
import yaml, json, sys
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
print(json.dumps(data))
" 2>/dev/null || parse_yaml_fallback
}

parse_yaml_fallback() {
  # Fallback: parse with simple awk for systems without PyYAML
  python3 -c "
import json, re, sys

checks = []
current = {}
in_checks = False
in_alerts = False
meta = {}

with open('$CONFIG') as f:
    for line in f:
        line = line.rstrip()
        stripped = line.lstrip()

        if stripped.startswith('title:'):
            meta['title'] = stripped.split(':', 1)[1].strip().strip('\"')
        elif stripped.startswith('theme:'):
            meta['theme'] = stripped.split(':', 1)[1].strip()
        elif stripped.startswith('refresh:'):
            meta['refresh'] = int(stripped.split(':', 1)[1].strip())
        elif stripped == 'checks:':
            in_checks = True
            in_alerts = False
            continue
        elif stripped == 'alerts:':
            in_checks = False
            in_alerts = True
            continue

        if in_checks:
            if stripped.startswith('- name:'):
                if current:
                    checks.append(current)
                current = {'name': stripped.split(':', 1)[1].strip().strip('\"')}
            elif ':' in stripped and not stripped.startswith('-') and not stripped.startswith('#'):
                key, val = stripped.split(':', 1)
                key = key.strip()
                val = val.strip().strip('\"')
                if key in ('port', 'timeout', 'expect_status'):
                    try: val = int(val)
                    except: pass
                if key in ('enabled',):
                    val = val.lower() == 'true'
                current[key] = val

if current:
    checks.append(current)

result = {**meta, 'checks': checks}
print(json.dumps(result))
"
}

CONFIG_JSON=$(parse_yaml_checks)

TITLE=$(echo "$CONFIG_JSON" | jq -r '.title // "Service Status"')
THEME=$(echo "$CONFIG_JSON" | jq -r '.theme // "dark"')
REFRESH=$(echo "$CONFIG_JSON" | jq -r '.refresh // 60')
NUM_CHECKS=$(echo "$CONFIG_JSON" | jq '.checks | length')

# --- Alert helpers ---
send_telegram() {
  local msg="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -sf "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      -d "chat_id=$TELEGRAM_CHAT_ID" \
      -d "text=$msg" \
      -d "parse_mode=HTML" > /dev/null 2>&1 || true
  fi
}

send_webhook() {
  local url="$1" msg="$2"
  curl -sf -X POST "$url" -H "Content-Type: application/json" \
    -d "{\"text\":\"$msg\"}" > /dev/null 2>&1 || true
}

load_previous_state() {
  if [[ -f "$ALERT_STATE_FILE" ]]; then
    cat "$ALERT_STATE_FILE"
  else
    echo "{}"
  fi
}

PREV_STATE=$(load_previous_state)

# --- Check functions ---
check_http() {
  local url="$1" expect_status="${2:-200}" expect_body="${3:-}" timeout="${4:-10}" method="${5:-GET}"
  local start=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  
  local response
  response=$(curl -sf -o /tmp/sd_body.txt -w "%{http_code}" \
    -X "$method" --max-time "$timeout" --connect-timeout 5 "$url" 2>/dev/null) || response="000"
  
  local end=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local elapsed=$(( end - start ))
  
  local status="up" error=""
  if [[ "$response" != "$expect_status" ]]; then
    status="down"
    error="HTTP $response (expected $expect_status)"
  fi
  
  if [[ "$status" == "up" && -n "$expect_body" ]]; then
    if ! grep -q "$expect_body" /tmp/sd_body.txt 2>/dev/null; then
      status="down"
      error="Body missing: $expect_body"
    fi
  fi
  
  echo "{\"status\":\"$status\",\"response_ms\":$elapsed,\"error\":\"$error\"}"
}

check_tcp() {
  local host="$1" port="$2" timeout="${3:-5}"
  local start=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  
  local status="up" error=""
  if ! nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
    if ! timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
      status="down"
      error="Connection refused ($host:$port)"
    fi
  fi
  
  local end=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local elapsed=$(( end - start ))
  
  echo "{\"status\":\"$status\",\"response_ms\":$elapsed,\"error\":\"$error\"}"
}

check_dns() {
  local domain="$1" record="${2:-A}" expect="${3:-}" nameserver="${4:-}"
  local start=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  
  local status="up" error="" result=""
  if command -v dig &>/dev/null; then
    local ns_arg=""
    [[ -n "$nameserver" ]] && ns_arg="@$nameserver"
    result=$(dig +short $ns_arg "$domain" "$record" 2>/dev/null)
  elif command -v nslookup &>/dev/null; then
    result=$(nslookup -type="$record" "$domain" ${nameserver:-} 2>/dev/null | grep -A1 "answer" | tail -1)
  else
    status="down"
    error="No DNS tool (dig/nslookup) found"
  fi
  
  if [[ -z "$result" && "$status" != "down" ]]; then
    status="down"
    error="DNS lookup failed for $domain ($record)"
  fi
  
  if [[ "$status" == "up" && -n "$expect" ]]; then
    if ! echo "$result" | grep -q "$expect"; then
      status="down"
      error="DNS mismatch: got $result, expected $expect"
    fi
  fi
  
  local end=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local elapsed=$(( end - start ))
  
  echo "{\"status\":\"$status\",\"response_ms\":$elapsed,\"error\":\"$error\"}"
}

check_docker() {
  local container="$1"
  local start=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  
  local status="up" error=""
  if ! command -v docker &>/dev/null; then
    status="down"
    error="Docker CLI not found"
  else
    local state
    state=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null) || state="not_found"
    if [[ "$state" != "running" ]]; then
      status="down"
      error="Container $container: $state"
    else
      local health
      health=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null) || health=""
      if [[ "$health" == "unhealthy" ]]; then
        status="down"
        error="Container unhealthy"
      fi
    fi
  fi
  
  local end=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local elapsed=$(( end - start ))
  
  echo "{\"status\":\"$status\",\"response_ms\":$elapsed,\"error\":\"$error\"}"
}

check_command() {
  local cmd="$1"
  local start=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  
  local status="up" error=""
  if ! eval "$cmd" > /dev/null 2>&1; then
    status="down"
    error="Command failed: $cmd"
  fi
  
  local end=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local elapsed=$(( end - start ))
  
  echo "{\"status\":\"$status\",\"response_ms\":$elapsed,\"error\":\"$error\"}"
}

# --- Run all checks ---
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULTS="[]"

for i in $(seq 0 $((NUM_CHECKS - 1))); do
  check=$(echo "$CONFIG_JSON" | jq -c ".checks[$i]")
  name=$(echo "$check" | jq -r '.name')
  type=$(echo "$check" | jq -r '.type')
  
  case "$type" in
    http)
      url=$(echo "$check" | jq -r '.url')
      expect_status=$(echo "$check" | jq -r '.expect_status // 200')
      expect_body=$(echo "$check" | jq -r '.expect_body // ""')
      timeout=$(echo "$check" | jq -r '.timeout // 10')
      method=$(echo "$check" | jq -r '.method // "GET"')
      result=$(check_http "$url" "$expect_status" "$expect_body" "$timeout" "$method")
      ;;
    tcp)
      host=$(echo "$check" | jq -r '.host')
      port=$(echo "$check" | jq -r '.port')
      timeout=$(echo "$check" | jq -r '.timeout // 5')
      result=$(check_tcp "$host" "$port" "$timeout")
      ;;
    dns)
      domain=$(echo "$check" | jq -r '.domain')
      record=$(echo "$check" | jq -r '.record // "A"')
      expect=$(echo "$check" | jq -r '.expect // ""')
      nameserver=$(echo "$check" | jq -r '.nameserver // ""')
      result=$(check_dns "$domain" "$record" "$expect" "$nameserver")
      ;;
    docker)
      container=$(echo "$check" | jq -r '.container')
      result=$(check_docker "$container")
      ;;
    command)
      cmd=$(echo "$check" | jq -r '.cmd')
      result=$(check_command "$cmd")
      ;;
    *)
      result='{"status":"down","response_ms":0,"error":"Unknown check type: '"$type"'"}'
      ;;
  esac
  
  # Add name to result
  result=$(echo "$result" | jq --arg name "$name" --arg type "$type" '. + {name: $name, type: $type}')
  RESULTS=$(echo "$RESULTS" | jq --argjson r "$result" '. += [$r]')
  
  # Log to history
  echo "$result" | jq -c --arg ts "$NOW" '. + {checked_at: $ts}' >> "$HISTORY_FILE"
  
  # Alerting
  svc_status=$(echo "$result" | jq -r '.status')
  prev_status=$(echo "$PREV_STATE" | jq -r --arg n "$name" '.[$n] // "unknown"')
  
  if [[ "$svc_status" == "down" && "$prev_status" != "down" ]]; then
    svc_error=$(echo "$result" | jq -r '.error')
    alert_msg="🔴 <b>DOWN:</b> $name — $svc_error"
    
    tg_enabled=$(echo "$CONFIG_JSON" | jq -r '.alerts.telegram.enabled // false')
    [[ "$tg_enabled" == "true" ]] && send_telegram "$alert_msg"
    
    wh_url=$(echo "$CONFIG_JSON" | jq -r '.alerts.webhook.url // ""')
    [[ -n "$wh_url" && "$wh_url" != "null" ]] && send_webhook "$wh_url" "DOWN: $name — $svc_error"
  elif [[ "$svc_status" == "up" && "$prev_status" == "down" ]]; then
    alert_msg="🟢 <b>RECOVERED:</b> $name is back up"
    
    tg_enabled=$(echo "$CONFIG_JSON" | jq -r '.alerts.telegram.enabled // false')
    [[ "$tg_enabled" == "true" ]] && send_telegram "$alert_msg"
    
    wh_url=$(echo "$CONFIG_JSON" | jq -r '.alerts.webhook.url // ""')
    [[ -n "$wh_url" && "$wh_url" != "null" ]] && send_webhook "$wh_url" "RECOVERED: $name"
  fi
  
  # Update state
  PREV_STATE=$(echo "$PREV_STATE" | jq --arg n "$name" --arg s "$svc_status" '.[$n] = $s')
done

# Save alert state
echo "$PREV_STATE" > "$ALERT_STATE_FILE"

# --- Calculate overall status ---
DOWN_COUNT=$(echo "$RESULTS" | jq '[.[] | select(.status == "down")] | length')
TOTAL_COUNT=$(echo "$RESULTS" | jq 'length')
if [[ "$DOWN_COUNT" -eq 0 ]]; then
  OVERALL="operational"
elif [[ "$DOWN_COUNT" -lt "$TOTAL_COUNT" ]]; then
  OVERALL="degraded"
else
  OVERALL="outage"
fi

# --- Calculate 24h uptime from history ---
calc_uptime() {
  local name="$1"
  local cutoff=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  [[ -z "$cutoff" ]] && { echo "N/A"; return; }
  [[ ! -f "$HISTORY_FILE" ]] && { echo "N/A"; return; }
  
  local total up
  total=$(grep "\"name\":\"$name\"" "$HISTORY_FILE" | jq -r --arg c "$cutoff" 'select(.checked_at >= $c)' 2>/dev/null | wc -l)
  up=$(grep "\"name\":\"$name\"" "$HISTORY_FILE" | jq -r --arg c "$cutoff" 'select(.checked_at >= $c and .status == "up")' 2>/dev/null | wc -l)
  
  if [[ "$total" -gt 0 ]]; then
    python3 -c "print(f'{($up/$total)*100:.1f}%')" 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

# --- JSON output ---
if [[ "$FORMAT" == "json" ]]; then
  JSON_OUT=$(jq -n \
    --arg ts "$NOW" \
    --arg overall "$OVERALL" \
    --argjson services "$RESULTS" \
    '{generated_at: $ts, overall: $overall, services: $services}')
  
  if [[ "$OUTPUT" == "-" ]]; then
    echo "$JSON_OUT" | jq .
  else
    mkdir -p "$(dirname "$OUTPUT")"
    echo "$JSON_OUT" | jq . > "$OUTPUT"
    echo "✅ JSON dashboard written to $OUTPUT"
  fi
  exit 0
fi

# --- HTML output ---
generate_html() {
  local bg_color text_color card_bg border_color
  if [[ "$THEME" == "dark" ]]; then
    bg_color="#0d1117"; text_color="#e6edf3"; card_bg="#161b22"; border_color="#30363d"
  else
    bg_color="#ffffff"; text_color="#1f2328"; card_bg="#f6f8fa"; border_color="#d0d7de"
  fi
  
  local overall_color overall_text overall_icon
  case "$OVERALL" in
    operational) overall_color="#3fb950"; overall_text="All Systems Operational"; overall_icon="✅" ;;
    degraded) overall_color="#d29922"; overall_text="Partial Outage"; overall_icon="⚠️" ;;
    outage) overall_color="#f85149"; overall_text="Major Outage"; overall_icon="🔴" ;;
  esac
  
  cat << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="$REFRESH">
<title>$TITLE</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: $bg_color; color: $text_color; padding: 2rem; }
  .container { max-width: 800px; margin: 0 auto; }
  h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
  .overall { padding: 1rem; border-radius: 8px; margin-bottom: 2rem; text-align: center; font-size: 1.2rem; font-weight: 600; background: ${overall_color}22; border: 1px solid ${overall_color}55; color: $overall_color; }
  .service { display: flex; align-items: center; justify-content: space-between; padding: 0.75rem 1rem; background: $card_bg; border: 1px solid $border_color; border-radius: 6px; margin-bottom: 0.5rem; }
  .service-left { display: flex; align-items: center; gap: 0.75rem; }
  .service-right { display: flex; align-items: center; gap: 1.5rem; font-size: 0.85rem; opacity: 0.7; }
  .dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .dot-up { background: #3fb950; }
  .dot-down { background: #f85149; }
  .name { font-weight: 500; }
  .error { color: #f85149; font-size: 0.8rem; margin-left: 0.5rem; }
  .type-badge { font-size: 0.7rem; padding: 2px 6px; border-radius: 3px; background: ${border_color}; text-transform: uppercase; letter-spacing: 0.5px; }
  .footer { margin-top: 2rem; text-align: center; font-size: 0.8rem; opacity: 0.5; }
</style>
</head>
<body>
<div class="container">
  <h1>$TITLE</h1>
  <p style="margin-bottom:1rem;opacity:0.6;font-size:0.85rem;">Last checked: $NOW</p>
  <div class="overall">$overall_icon $overall_text</div>
HTMLEOF

  for i in $(seq 0 $((NUM_CHECKS - 1))); do
    local svc=$(echo "$RESULTS" | jq -c ".[$i]")
    local name=$(echo "$svc" | jq -r '.name')
    local stype=$(echo "$svc" | jq -r '.type')
    local status=$(echo "$svc" | jq -r '.status')
    local ms=$(echo "$svc" | jq -r '.response_ms')
    local err=$(echo "$svc" | jq -r '.error // ""')
    local uptime=$(calc_uptime "$name")
    
    local dot_class="dot-up"
    [[ "$status" == "down" ]] && dot_class="dot-down"
    
    local err_html=""
    [[ -n "$err" && "$err" != "" ]] && err_html="<span class=\"error\">$err</span>"
    
    cat << SVCEOF
  <div class="service">
    <div class="service-left">
      <div class="dot $dot_class"></div>
      <span class="name">$name</span>
      <span class="type-badge">$stype</span>
      $err_html
    </div>
    <div class="service-right">
      <span>${ms}ms</span>
      <span>$uptime</span>
    </div>
  </div>
SVCEOF
  done

  cat << FOOTEOF
  <div class="footer">
    Powered by Service Dashboard • Auto-refreshes every ${REFRESH}s
  </div>
</div>
</body>
</html>
FOOTEOF
}

mkdir -p "$(dirname "$OUTPUT")"
generate_html > "$OUTPUT"
echo "✅ Dashboard written to $OUTPUT ($TOTAL_COUNT services, $DOWN_COUNT down)"
