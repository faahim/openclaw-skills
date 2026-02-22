#!/usr/bin/env bash
# API Monitor — Lightweight endpoint monitoring with alerts
# Usage: bash monitor.sh --config monitors.json [--loop --interval 120]
#        bash monitor.sh --url https://example.com/api [--expect-status 200] [--alert telegram]
set -euo pipefail

# --- Defaults ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${API_MONITOR_STATE_DIR:-$(dirname "$SCRIPT_DIR")/state}"
LOG_DIR="${API_MONITOR_LOG_DIR:-$(dirname "$SCRIPT_DIR")/logs}"
CONFIG=""
SINGLE_URL=""
EXPECT_STATUS="200"
EXPECT_JSON=""
EXPECT_JSON_PATH=""
TIMEOUT=5
MAX_LATENCY=0
METHOD="GET"
BODY=""
CONTENT_TYPE=""
HEADERS=()
ALERT_CHANNELS=()
LOOP=false
INTERVAL=120
CHECK_SSL=false
SSL_WARN_DAYS=30
SHOW_STATS=false
STATS_HOURS=24
RETRIES=2
RETRY_DELAY=5
ALERT_COOLDOWN=300
NOTIFY_RECOVERY=true

mkdir -p "$STATE_DIR" "$LOG_DIR"

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG="$2"; shift 2 ;;
    --url) SINGLE_URL="$2"; shift 2 ;;
    --expect-status) EXPECT_STATUS="$2"; shift 2 ;;
    --expect-json) EXPECT_JSON="$2"; shift 2 ;;
    --expect-json-path) EXPECT_JSON_PATH="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --max-latency) MAX_LATENCY="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --content-type) CONTENT_TYPE="$2"; shift 2 ;;
    --header) HEADERS+=("$2"); shift 2 ;;
    --alert) ALERT_CHANNELS+=("$2"); shift 2 ;;
    --loop) LOOP=true; shift ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --check-ssl) CHECK_SSL=true; shift ;;
    --ssl-warn-days) SSL_WARN_DAYS="$2"; shift 2 ;;
    --stats) SHOW_STATS=true; shift ;;
    --hours) STATS_HOURS="$2"; shift 2 ;;
    --retries) RETRIES="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Logging ---
log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $*"
  echo "[$ts] $*" >> "$LOG_DIR/monitor.log"
}

# --- Alert Functions ---
send_telegram() {
  local msg="$1" token="${API_MONITOR_TELEGRAM_TOKEN:-}" chat_id="${API_MONITOR_TELEGRAM_CHAT_ID:-}"
  [[ -z "$token" || -z "$chat_id" ]] && return 1
  curl -sf -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d "chat_id=${chat_id}" -d "text=${msg}" -d "parse_mode=Markdown" \
    -o /dev/null 2>/dev/null || true
}

send_slack() {
  local msg="$1" webhook="${API_MONITOR_SLACK_WEBHOOK:-}"
  [[ -z "$webhook" ]] && return 1
  curl -sf -X POST "$webhook" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"${msg}\"}" \
    -o /dev/null 2>/dev/null || true
}

send_alert() {
  local msg="$1" name="$2"
  shift 2
  local channels=("$@")

  # Check cooldown
  local cooldown_file="$STATE_DIR/${name//[^a-zA-Z0-9_-]/_}.cooldown"
  if [[ -f "$cooldown_file" ]]; then
    local last_alert
    last_alert=$(cat "$cooldown_file")
    local now
    now=$(date +%s)
    if (( now - last_alert < ALERT_COOLDOWN )); then
      return 0
    fi
  fi
  date +%s > "$cooldown_file"

  for ch in "${channels[@]}"; do
    case "$ch" in
      telegram) send_telegram "$msg" ;;
      slack) send_slack "$msg" ;;
      *) log "  ⚠️  Unknown alert channel: $ch" ;;
    esac
  done
}

send_recovery() {
  local name="$1" down_since="$2"
  shift 2
  local channels=("$@")
  local now
  now=$(date +%s)
  local down_duration=$(( now - down_since ))
  local mins=$(( down_duration / 60 ))
  local msg="✅ *${name}* is back UP (was down for ${mins} min)"

  # Clear cooldown
  local cooldown_file="$STATE_DIR/${name//[^a-zA-Z0-9_-]/_}.cooldown"
  rm -f "$cooldown_file"

  for ch in "${channels[@]}"; do
    case "$ch" in
      telegram) send_telegram "$msg" ;;
      slack) send_slack "$msg" ;;
    esac
  done
}

# --- SSL Check ---
check_ssl_cert() {
  local url="$1" warn_days="$2"
  local host
  host=$(echo "$url" | sed -E 's|https?://([^/:]+).*|\1|')
  local expiry
  expiry=$(echo | openssl s_client -servername "$host" -connect "${host}:443" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [[ -z "$expiry" ]]; then
    echo "SSL_ERROR"
    return 1
  fi
  local expiry_epoch
  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
  local now_epoch
  now_epoch=$(date +%s)
  local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
  if (( days_left < warn_days )); then
    echo "SSL_WARN:${days_left}:${expiry}"
  else
    echo "SSL_OK:${days_left}:${expiry}"
  fi
}

# --- Core: Check Single Endpoint ---
check_endpoint() {
  local url="$1" method="$2" expect_status="$3" timeout="$4"
  local body="${5:-}" content_type="${6:-}" expect_json="${7:-}" expect_json_path="${8:-}"
  local max_lat="${9:-0}"
  shift 9 || true
  local header_args=()
  
  # Build curl args
  local curl_args=(-s -o /tmp/api_monitor_body -w '%{http_code}\n%{time_total}' --max-time "$timeout")
  curl_args+=(-X "$method")
  [[ -n "$content_type" ]] && curl_args+=(-H "Content-Type: $content_type")
  [[ -n "$body" ]] && curl_args+=(-d "$body")

  # Execute with retries
  local attempt=0 http_code="" elapsed_ms=0 response_body=""
  while (( attempt <= RETRIES )); do
    local output
    output=$(curl "${curl_args[@]}" "$url" 2>/dev/null) || output="000
0"
    http_code=$(echo "$output" | head -1)
    local elapsed
    elapsed=$(echo "$output" | tail -1)
    elapsed_ms=$(echo "$elapsed" | awk '{printf "%d", $1 * 1000}')
    response_body=$(cat /tmp/api_monitor_body 2>/dev/null || echo "")

    # Check if status matches
    local status_ok=false
    if echo "$expect_status" | grep -q ','; then
      # Multiple expected statuses
      for s in $(echo "$expect_status" | tr ',' ' '); do
        [[ "$http_code" == "$s" ]] && status_ok=true
      done
    else
      [[ "$http_code" == "$expect_status" ]] && status_ok=true
    fi

    if $status_ok; then
      break
    fi

    (( attempt++ ))
    if (( attempt <= RETRIES )); then
      sleep "$RETRY_DELAY"
    fi
  done

  # Build result
  local result="OK"
  local details=""

  # Status check
  local status_ok=false
  if echo "$expect_status" | grep -q ','; then
    for s in $(echo "$expect_status" | tr ',' ' '); do
      [[ "$http_code" == "$s" ]] && status_ok=true
    done
  else
    [[ "$http_code" == "$expect_status" ]] && status_ok=true
  fi

  if ! $status_ok; then
    result="FAIL"
    details="HTTP $http_code (expected $expect_status)"
  fi

  # JSON validation
  if [[ "$result" == "OK" && -n "$expect_json" ]]; then
    if ! echo "$response_body" | jq -e ". == $expect_json" > /dev/null 2>&1; then
      # Try partial match
      if ! echo "$response_body" | jq -e "contains($expect_json)" > /dev/null 2>&1; then
        result="FAIL"
        details="JSON mismatch"
      fi
    fi
  fi

  # JSON path check
  if [[ "$result" == "OK" && -n "$expect_json_path" ]]; then
    local path_result
    path_result=$(echo "$response_body" | jq -r "$expect_json_path" 2>/dev/null)
    if [[ -z "$path_result" || "$path_result" == "null" ]]; then
      result="FAIL"
      details="JSON path '$expect_json_path' not found"
    fi
  fi

  # Latency check
  if [[ "$result" == "OK" && "$max_lat" -gt 0 && "$elapsed_ms" -gt "$max_lat" ]]; then
    result="SLOW"
    details="Latency ${elapsed_ms}ms exceeds ${max_lat}ms threshold"
  fi

  echo "${result}|${http_code}|${elapsed_ms}|${details}"
}

# --- Record latency for stats ---
record_latency() {
  local name="$1" latency="$2" status="$3"
  local ts
  ts=$(date +%s)
  echo "${ts}|${latency}|${status}" >> "$STATE_DIR/${name//[^a-zA-Z0-9_-]/_}.latency"
}

# --- Show stats ---
show_stats() {
  local hours="$1"
  local cutoff
  cutoff=$(( $(date +%s) - hours * 3600 ))
  
  echo "=== API Monitor Stats (last ${hours}h) ==="
  echo ""
  printf "%-30s %8s %8s %8s %8s\n" "Endpoint" "Avg" "P95" "P99" "Checks"
  printf "%-30s %8s %8s %8s %8s\n" "--------" "---" "---" "---" "------"
  
  for f in "$STATE_DIR"/*.latency; do
    [[ -f "$f" ]] || continue
    local name
    name=$(basename "$f" .latency)
    local data
    data=$(awk -F'|' -v cutoff="$cutoff" '$1 >= cutoff {print $2}' "$f" | sort -n)
    local count
    count=$(echo "$data" | wc -l | tr -d ' ')
    [[ "$count" -eq 0 ]] && continue
    local avg
    avg=$(echo "$data" | awk '{sum+=$1} END {printf "%d", sum/NR}')
    local p95_idx=$(( count * 95 / 100 ))
    local p99_idx=$(( count * 99 / 100 ))
    [[ "$p95_idx" -lt 1 ]] && p95_idx=1
    [[ "$p99_idx" -lt 1 ]] && p99_idx=1
    local p95
    p95=$(echo "$data" | sed -n "${p95_idx}p")
    local p99
    p99=$(echo "$data" | sed -n "${p99_idx}p")
    printf "%-30s %6sms %6sms %6sms %8s\n" "$name" "$avg" "$p95" "$p99" "$count"
  done
}

# --- Process Config File ---
run_config() {
  local config_file="$1"
  
  if ! jq empty "$config_file" 2>/dev/null; then
    log "❌ Invalid JSON in $config_file"
    return 1
  fi
  
  local defaults_timeout defaults_max_latency
  defaults_timeout=$(jq -r '.defaults.timeout // 5' "$config_file")
  defaults_max_latency=$(jq -r '.defaults.max_latency // 0' "$config_file")
  RETRIES=$(jq -r '.defaults.retries // 2' "$config_file")
  RETRY_DELAY=$(jq -r '.defaults.retry_delay // 5' "$config_file")
  ALERT_COOLDOWN=$(jq -r '.defaults.alert_cooldown // 300' "$config_file")
  
  local monitor_count
  monitor_count=$(jq '.monitors | length' "$config_file")
  
  for (( i=0; i<monitor_count; i++ )); do
    local name url method expect_status timeout max_lat body ct expect_json expect_json_path
    name=$(jq -r ".monitors[$i].name // \"Monitor-$i\"" "$config_file")
    url=$(jq -r ".monitors[$i].url" "$config_file")
    method=$(jq -r ".monitors[$i].method // \"GET\"" "$config_file")
    expect_status=$(jq -r '(.monitors['"$i"'].expect_status // 200) | if type == "array" then join(",") else tostring end' "$config_file")
    timeout=$(jq -r ".monitors[$i].timeout // $defaults_timeout" "$config_file")
    max_lat=$(jq -r ".monitors[$i].max_latency // $defaults_max_latency" "$config_file")
    body=$(jq -r ".monitors[$i].body // \"\"" "$config_file")
    ct=$(jq -r '.monitors['"$i"'].headers["Content-Type"] // ""' "$config_file")
    expect_json=$(jq -c ".monitors[$i].expect_json // empty" "$config_file" 2>/dev/null || echo "")
    expect_json_path=$(jq -r ".monitors[$i].expect_json_path // \"\"" "$config_file")
    
    local alerts_json
    alerts_json=$(jq -r ".monitors[$i].alerts // [] | .[]" "$config_file")
    local alert_arr=()
    while IFS= read -r ch; do
      [[ -n "$ch" ]] && alert_arr+=("$ch")
    done <<< "$alerts_json"
    
    # Run check
    local result
    result=$(check_endpoint "$url" "$method" "$expect_status" "$timeout" "$body" "$ct" "$expect_json" "$expect_json_path" "$max_lat")
    
    local status http_code elapsed details
    IFS='|' read -r status http_code elapsed details <<< "$result"
    
    # Track state for recovery notifications
    local state_file="$STATE_DIR/${name//[^a-zA-Z0-9_-]/_}.state"
    
    case "$status" in
      OK)
        log "✅ ${name} — ${http_code} OK (${elapsed}ms)"
        # Check for recovery
        if [[ -f "$state_file" ]]; then
          local down_since
          down_since=$(cat "$state_file")
          if $NOTIFY_RECOVERY && [[ ${#alert_arr[@]} -gt 0 ]]; then
            send_recovery "$name" "$down_since" "${alert_arr[@]}"
          fi
          rm -f "$state_file"
        fi
        ;;
      SLOW)
        log "⚠️  ${name} — ${http_code} SLOW (${elapsed}ms) — ${details}"
        if [[ ${#alert_arr[@]} -gt 0 ]]; then
          send_alert "⚠️ *${name}* is SLOW: ${details}" "$name" "${alert_arr[@]}"
        fi
        ;;
      FAIL)
        log "❌ ${name} — ${details} (${elapsed}ms)"
        # Record down state
        if [[ ! -f "$state_file" ]]; then
          date +%s > "$state_file"
        fi
        if [[ ${#alert_arr[@]} -gt 0 ]]; then
          send_alert "🚨 *${name}* is DOWN: ${details}" "$name" "${alert_arr[@]}"
        fi
        ;;
    esac
    
    record_latency "$name" "$elapsed" "$status"
  done
}

# --- Single URL Mode ---
run_single() {
  local result
  result=$(check_endpoint "$SINGLE_URL" "$METHOD" "$EXPECT_STATUS" "$TIMEOUT" "$BODY" "$CONTENT_TYPE" "$EXPECT_JSON" "$EXPECT_JSON_PATH" "$MAX_LATENCY")
  
  local status http_code elapsed details
  IFS='|' read -r status http_code elapsed details <<< "$result"
  
  local name
  name=$(echo "$SINGLE_URL" | sed -E 's|https?://||; s|/.*||')
  
  case "$status" in
    OK) log "✅ ${SINGLE_URL} — ${http_code} OK (${elapsed}ms)" ;;
    SLOW) log "⚠️  ${SINGLE_URL} — ${http_code} SLOW (${elapsed}ms) — ${details}" ;;
    FAIL) log "❌ ${SINGLE_URL} — ${details} (${elapsed}ms)" ;;
  esac
  
  if [[ "$status" != "OK" && ${#ALERT_CHANNELS[@]} -gt 0 ]]; then
    send_alert "🚨 *${name}* — ${details}" "$name" "${ALERT_CHANNELS[@]}"
  fi
  
  # SSL check
  if $CHECK_SSL; then
    local ssl_result
    ssl_result=$(check_ssl_cert "$SINGLE_URL" "$SSL_WARN_DAYS")
    case "$ssl_result" in
      SSL_OK:*)
        local days
        days=$(echo "$ssl_result" | cut -d: -f2)
        log "🔒 SSL valid ($days days remaining)"
        ;;
      SSL_WARN:*)
        local days expiry
        days=$(echo "$ssl_result" | cut -d: -f2)
        expiry=$(echo "$ssl_result" | cut -d: -f3-)
        log "⚠️  SSL expires in $days days ($expiry)"
        if [[ ${#ALERT_CHANNELS[@]} -gt 0 ]]; then
          send_alert "⚠️ *${name}* SSL cert expires in ${days} days!" "$name" "${ALERT_CHANNELS[@]}"
        fi
        ;;
      SSL_ERROR)
        log "❌ SSL check failed"
        ;;
    esac
  fi
  
  record_latency "$name" "$elapsed" "$status"
}

# --- Main ---
if $SHOW_STATS; then
  show_stats "$STATS_HOURS"
  exit 0
fi

if [[ -z "$CONFIG" && -z "$SINGLE_URL" ]]; then
  echo "Usage: $0 --config monitors.json [--loop --interval 120]"
  echo "       $0 --url https://example.com/api [--expect-status 200] [--alert telegram]"
  exit 1
fi

if $LOOP; then
  log "🔄 Starting continuous monitoring (interval: ${INTERVAL}s)"
  while true; do
    if [[ -n "$CONFIG" ]]; then
      run_config "$CONFIG"
    else
      run_single
    fi
    sleep "$INTERVAL"
  done
else
  if [[ -n "$CONFIG" ]]; then
    run_config "$CONFIG"
  else
    run_single
  fi
fi
