#!/bin/bash
# Home Assistant CLI Manager
# Controls HA devices, reads states, triggers automations via REST API

set -euo pipefail

# --- Configuration ---
HA_URL="${HA_URL:-}"
HA_TOKEN="${HA_TOKEN:-}"
HA_TIMEOUT="${HA_TIMEOUT:-10}"
HA_INSECURE="${HA_INSECURE:-false}"
HA_DASHBOARD_ENTITIES="${HA_DASHBOARD_ENTITIES:-light,sensor,lock,climate,switch,binary_sensor}"

CURL_OPTS=(-s --max-time "$HA_TIMEOUT")
if [[ "$HA_INSECURE" == "true" ]]; then
  CURL_OPTS+=(-k)
fi

# --- Helpers ---
die() { echo "❌ $*" >&2; exit 1; }

check_config() {
  [[ -n "$HA_URL" ]] || die "HA_URL not set. Export HA_URL=http://homeassistant.local:8123"
  [[ -n "$HA_TOKEN" ]] || die "HA_TOKEN not set. Export HA_TOKEN=your_long_lived_access_token"
}

ha_api() {
  local method="${1:-GET}"
  local endpoint="$2"
  shift 2
  local data="${1:-}"

  local args=("${CURL_OPTS[@]}" -X "$method" \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    "${HA_URL}/api${endpoint}")

  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi

  local response
  response=$(curl "${args[@]}" 2>/dev/null) || die "Failed to connect to Home Assistant at $HA_URL"

  if echo "$response" | jq -e '.message' >/dev/null 2>&1; then
    local msg
    msg=$(echo "$response" | jq -r '.message // empty')
    if [[ -n "$msg" && "$msg" != "null" ]]; then
      die "HA API error: $msg"
    fi
  fi

  echo "$response"
}

# --- Commands ---

cmd_status() {
  check_config
  local resp
  resp=$(ha_api GET "/")
  local version location
  version=$(echo "$resp" | jq -r '.version // "unknown"')
  location=$(echo "$resp" | jq -r '.location_name // "unknown"')

  local states
  states=$(ha_api GET "/states")
  local entity_count domain_count
  entity_count=$(echo "$states" | jq 'length')
  domain_count=$(echo "$states" | jq '[.[].entity_id | split(".")[0]] | unique | length')

  echo "✅ Home Assistant $version connected"
  echo "Location: $location"
  echo "Entities: $domain_count domains, $entity_count entities"
}

cmd_entities() {
  check_config
  local domain_filter="${1:-}"
  local json_mode="${2:-}"
  local states
  states=$(ha_api GET "/states")

  if [[ -n "$domain_filter" ]]; then
    states=$(echo "$states" | jq --arg d "$domain_filter" '[.[] | select(.entity_id | startswith($d + "."))]')
  fi

  if [[ "$json_mode" == "--json" ]]; then
    echo "$states" | jq .
    return
  fi

  echo "$states" | jq -r '.[] | {id: .entity_id, state: .state, attrs: .attributes} |
    (if (.id | startswith("light")) then "💡"
     elif (.id | startswith("sensor")) then "🌡️"
     elif (.id | startswith("lock")) then "🔒"
     elif (.id | startswith("switch")) then "🔌"
     elif (.id | startswith("climate")) then "🌡️"
     elif (.id | startswith("camera")) then "📷"
     elif (.id | startswith("binary_sensor")) then "👁️"
     elif (.id | startswith("automation")) then "🤖"
     else "•" end) + " " + .id + " — " + .state +
    (if .attrs.brightness then " (brightness: " + ((.attrs.brightness / 2.55 | floor | tostring)) + "%)" else "" end) +
    (if .attrs.temperature then " (" + (.attrs.temperature | tostring) + "°)" else "" end) +
    (if .attrs.unit_of_measurement then " " + .attrs.unit_of_measurement else "" end)
  ' 2>/dev/null || echo "$states" | jq -r '.[] | .entity_id + " — " + .state'
}

cmd_state() {
  check_config
  local entity_id="$1"
  local json_mode="${2:-}"
  [[ -n "$entity_id" ]] || die "Usage: ha.sh state <entity_id> [--json]"

  local resp
  resp=$(ha_api GET "/states/$entity_id")

  if [[ "$json_mode" == "--json" ]]; then
    echo "$resp" | jq .
    return
  fi

  local state
  state=$(echo "$resp" | jq -r '.state')
  local attrs
  attrs=$(echo "$resp" | jq -r '.attributes | to_entries | map(.key + ": " + (.value | tostring)) | join(", ")')
  local last_changed
  last_changed=$(echo "$resp" | jq -r '.last_changed')

  echo "$state"
  [[ -n "$attrs" && "$attrs" != "null" ]] && echo "  Attributes: $attrs"
  echo "  Last changed: $last_changed"
}

cmd_states() {
  check_config
  local domain="$1"
  [[ -n "$domain" ]] || die "Usage: ha.sh states <domain> (e.g., light, sensor, switch)"
  cmd_entities "$domain"
}

cmd_call() {
  check_config
  local service="$1"
  local entity_id="${2:-}"
  shift 2 || true

  [[ -n "$service" ]] || die "Usage: ha.sh call <domain.service> [entity_id] [key=value ...]"

  local domain="${service%%.*}"
  local svc="${service##*.}"

  # Build service data JSON
  local data="{}"
  if [[ -n "$entity_id" && "$entity_id" != "all" ]]; then
    data=$(echo "$data" | jq --arg eid "$entity_id" '. + {entity_id: $eid}')
  fi

  # Parse key=value pairs
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv##*=}"
    # Try to parse as number
    if [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]]; then
      data=$(echo "$data" | jq --arg k "$key" --argjson v "$val" '. + {($k): $v}')
    else
      data=$(echo "$data" | jq --arg k "$key" --arg v "$val" '. + {($k): $v}')
    fi
  done

  local resp
  resp=$(ha_api POST "/services/$domain/$svc" "$data")
  echo "✅ Called $service"
  if [[ -n "$entity_id" && "$entity_id" != "all" ]]; then
    echo "   Entity: $entity_id"
  fi
  echo "   Response: $(echo "$resp" | jq -r 'if type == "array" then (length | tostring) + " entities affected" else tostring end' 2>/dev/null || echo "$resp")"
}

cmd_automations() {
  check_config
  cmd_entities "automation"
}

cmd_dashboard() {
  check_config
  local states
  states=$(ha_api GET "/states")
  local now
  now=$(date '+%Y-%m-%d %H:%M %Z')

  echo "🏠 Home Dashboard — $now"
  echo "─────────────────────────────────────────"

  # Lights
  local lights_on lights_total
  lights_on=$(echo "$states" | jq '[.[] | select(.entity_id | startswith("light.")) | select(.state == "on")] | length')
  lights_total=$(echo "$states" | jq '[.[] | select(.entity_id | startswith("light."))] | length')
  echo "💡 Lights: $lights_on/$lights_total on"
  echo "$states" | jq -r '[.[] | select(.entity_id | startswith("light.")) | select(.state == "on")] | .[] |
    "   • " + (.entity_id | split(".")[1] | gsub("_"; " ")) +
    (if .attributes.brightness then " (" + ((.attributes.brightness / 2.55 | floor | tostring)) + "%)" else "" end)
  ' 2>/dev/null

  # Climate
  local temp_sensors
  temp_sensors=$(echo "$states" | jq -r '[.[] | select(.entity_id | test("sensor.*temp")) | select(.state != "unavailable")] | .[] |
    "   • " + (.entity_id | split(".")[1] | gsub("_"; " ")) + ": " + .state + (.attributes.unit_of_measurement // "")
  ' 2>/dev/null)
  if [[ -n "$temp_sensors" ]]; then
    echo "🌡️ Climate:"
    echo "$temp_sensors"
  fi

  # Security
  local locks_unlocked
  locks_unlocked=$(echo "$states" | jq '[.[] | select(.entity_id | startswith("lock.")) | select(.state == "unlocked")] | length')
  local locks_total
  locks_total=$(echo "$states" | jq '[.[] | select(.entity_id | startswith("lock."))] | length')
  if [[ "$locks_total" -gt 0 ]]; then
    if [[ "$locks_unlocked" -eq 0 ]]; then
      echo "🔒 Security: All locked ✅ ($locks_total locks)"
    else
      echo "🔒 Security: ⚠️ $locks_unlocked/$locks_total UNLOCKED"
      echo "$states" | jq -r '[.[] | select(.entity_id | startswith("lock.")) | select(.state == "unlocked")] | .[] |
        "   ⚠️ " + (.entity_id | split(".")[1] | gsub("_"; " ")) + " — UNLOCKED"
      ' 2>/dev/null
    fi
  fi

  # Automations
  local auto_on auto_total
  auto_on=$(echo "$states" | jq '[.[] | select(.entity_id | startswith("automation.")) | select(.state == "on")] | length')
  auto_total=$(echo "$states" | jq '[.[] | select(.entity_id | startswith("automation."))] | length')
  echo "🤖 Automations: $auto_on active, $((auto_total - auto_on)) disabled"
}

cmd_history() {
  check_config
  local entity_id="$1"
  local period="${2:-24h}"
  [[ -n "$entity_id" ]] || die "Usage: ha.sh history <entity_id> [period: 1h|24h|7d]"

  # Convert period to timestamp
  local hours=24
  case "$period" in
    *h) hours="${period%h}" ;;
    *d) hours=$(( ${period%d} * 24 )) ;;
    *) hours=24 ;;
  esac

  local start_time
  start_time=$(date -u -d "-${hours} hours" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -v-${hours}H '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "")

  local endpoint="/history/period"
  if [[ -n "$start_time" ]]; then
    endpoint="/history/period/${start_time}?filter_entity_id=${entity_id}&minimal_response"
  else
    endpoint="/history/period?filter_entity_id=${entity_id}&minimal_response"
  fi

  local resp
  resp=$(ha_api GET "$endpoint")

  echo "$entity_id — Last $period"
  echo "$resp" | jq -r '.[0] // [] | .[] |
    "[" + (.last_changed | split("T")[1] | split(".")[0] | .[0:5]) + "] " + .state
  ' 2>/dev/null | head -50

  # Summary stats for numeric sensors
  local stats
  stats=$(echo "$resp" | jq -r '.[0] // [] | [.[] | .state | select(. != "unavailable" and . != "unknown") | tonumber] |
    if length > 0 then "Avg: " + (add / length * 10 | floor / 10 | tostring) + "  Min: " + (min | tostring) + "  Max: " + (max | tostring)
    else empty end
  ' 2>/dev/null)
  [[ -n "$stats" ]] && echo "$stats"
}

cmd_logs() {
  check_config
  local limit="${1:-20}"
  local resp
  resp=$(ha_api GET "/logbook")
  echo "$resp" | jq -r '.[:'"$limit"'] | .[] |
    "[" + (.when | split("T")[1] | split(".")[0] | .[0:5]) + "] " + .name + " " + (.message // "")
  ' 2>/dev/null
}

cmd_batch() {
  check_config
  for cmd_str in "$@"; do
    echo "→ $cmd_str"
    eval "cmd_${cmd_str%% *} ${cmd_str#* }" 2>/dev/null || eval "$0 $cmd_str"
    echo
  done
}

cmd_monitor() {
  check_config
  local config="${1:-}"
  # Simple monitor: check for critical states
  local states
  states=$(ha_api GET "/states")

  # Check for leak sensors
  local leaks
  leaks=$(echo "$states" | jq -r '[.[] | select(.entity_id | test("leak|water")) | select(.state == "on")] | .[] | .entity_id' 2>/dev/null)
  if [[ -n "$leaks" ]]; then
    echo "🚨 ALERT: Water leak detected!"
    echo "$leaks"
  fi

  # Check for unlocked doors (>30 min)
  local unlocked
  unlocked=$(echo "$states" | jq -r '[.[] | select(.entity_id | startswith("lock.")) | select(.state == "unlocked")] | .[] | .entity_id' 2>/dev/null)
  if [[ -n "$unlocked" ]]; then
    echo "⚠️ WARNING: Unlocked doors:"
    echo "$unlocked"
  fi

  # Check for unavailable entities
  local unavail_count
  unavail_count=$(echo "$states" | jq '[.[] | select(.state == "unavailable")] | length')
  if [[ "$unavail_count" -gt 0 ]]; then
    echo "⚠️ $unavail_count entities unavailable"
  fi

  [[ -z "$leaks" && -z "$unlocked" && "$unavail_count" -eq 0 ]] && echo "✅ All clear — $(date '+%H:%M')"
}

# --- Main Router ---
cmd="${1:-help}"
shift || true

case "$cmd" in
  status)       cmd_status "$@" ;;
  entities)     cmd_entities "$@" ;;
  state)        cmd_state "$@" ;;
  states)       cmd_states "$@" ;;
  call)         cmd_call "$@" ;;
  automations)  cmd_automations "$@" ;;
  dashboard)    cmd_dashboard "$@" ;;
  history)      cmd_history "$@" ;;
  logs)         cmd_logs "$@" ;;
  batch)        cmd_batch "$@" ;;
  monitor)      cmd_monitor "$@" ;;
  help|*)
    echo "Home Assistant Manager"
    echo ""
    echo "Usage: ha.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  status                          Check HA connection"
    echo "  entities [domain] [--json]      List all entities"
    echo "  state <entity_id> [--json]      Get entity state"
    echo "  states <domain>                 List entities by domain"
    echo "  call <service> [entity] [k=v]   Call a service"
    echo "  automations                     List automations"
    echo "  dashboard                       Home summary dashboard"
    echo "  history <entity> [period]       Entity history (1h|24h|7d)"
    echo "  logs [limit]                    Recent logbook entries"
    echo "  batch <cmd1> <cmd2> ...         Run multiple commands"
    echo "  monitor                         Check for alerts"
    echo ""
    echo "Environment:"
    echo "  HA_URL      Home Assistant URL (required)"
    echo "  HA_TOKEN    Long-lived access token (required)"
    echo "  HA_TIMEOUT  API timeout seconds (default: 10)"
    echo "  HA_INSECURE Allow self-signed SSL (default: false)"
    ;;
esac
