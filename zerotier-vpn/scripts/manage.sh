#!/bin/bash
# ZeroTier VPN — Network Management Script
# Create, join, manage, and monitor ZeroTier networks

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[ZT]${NC} $*"; }
warn() { echo -e "${YELLOW}[ZT]${NC} $*"; }
err()  { echo -e "${RED}[ZT]${NC} $*" >&2; }
info() { echo -e "${BLUE}[ZT]${NC} $*"; }

API_BASE="https://api.zerotier.com/api/v1"

# Check prerequisites
check_prereqs() {
  if [[ -z "${ZT_API_TOKEN:-}" ]]; then
    err "ZT_API_TOKEN not set. Get one from https://my.zerotier.com/account"
    exit 1
  fi
  
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      err "Required: $cmd — install it first"
      exit 1
    fi
  done
}

# API call helper
zt_api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "$method" "${API_BASE}${endpoint}" \
    -H "Authorization: token ${ZT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

# Commands

cmd_status() {
  log "Local ZeroTier Status"
  echo ""
  
  if ! command -v zerotier-cli &>/dev/null; then
    err "ZeroTier not installed. Run: bash scripts/install.sh"
    exit 1
  fi
  
  sudo zerotier-cli info
  echo ""
  
  log "Joined Networks:"
  sudo zerotier-cli listnetworks
  echo ""
  
  log "Connected Peers:"
  sudo zerotier-cli peers | head -20
}

cmd_create() {
  check_prereqs
  local name="${1:-my-network}"
  local cidr="${2:-10.147.17.0/24}"
  
  # Parse CIDR to IP range
  local base_ip range_start range_end
  base_ip=$(echo "$cidr" | cut -d'/' -f1)
  range_start=$(echo "$base_ip" | sed 's/\.[0-9]*$/.1/')
  range_end=$(echo "$base_ip" | sed 's/\.[0-9]*$/.254/')
  
  log "Creating network: $name ($cidr)"
  
  local result
  result=$(zt_api POST "/network" -d "{
    \"config\": {
      \"name\": \"$name\",
      \"private\": true,
      \"ipAssignmentPools\": [{\"ipRangeStart\": \"$range_start\", \"ipRangeEnd\": \"$range_end\"}],
      \"routes\": [{\"target\": \"$cidr\"}],
      \"v4AssignMode\": {\"zt\": true}
    }
  }")
  
  local network_id
  network_id=$(echo "$result" | jq -r '.id')
  
  log "✅ Network created!"
  log "   Network ID: $network_id"
  log "   Name:       $name"
  log "   IP Range:   $range_start - $range_end"
  log "   Route:      $cidr"
  log "   Private:    true (members must be authorized)"
  echo ""
  log "Join from any device:"
  log "   sudo zerotier-cli join $network_id"
}

cmd_join() {
  local network_id="${1:?Usage: manage.sh join <network-id>}"
  
  if ! command -v zerotier-cli &>/dev/null; then
    err "ZeroTier not installed. Run: bash scripts/install.sh"
    exit 1
  fi
  
  log "Joining network $network_id..."
  sudo zerotier-cli join "$network_id"
  
  log "✅ Join request sent."
  log "   Network admin must authorize this device."
  log "   Check status: sudo zerotier-cli listnetworks"
}

cmd_leave() {
  local network_id="${1:?Usage: manage.sh leave <network-id>}"
  
  log "Leaving network $network_id..."
  sudo zerotier-cli leave "$network_id"
  log "✅ Left network."
}

cmd_members() {
  check_prereqs
  local network_id="${1:?Usage: manage.sh members <network-id>}"
  local online_only="${2:-}"
  
  log "Members of network $network_id:"
  echo ""
  
  local members
  members=$(zt_api GET "/network/$network_id/member")
  
  printf "%-12s %-18s %-10s %-12s %s\n" "NODE ID" "IP" "AUTH" "STATUS" "NAME"
  printf "%-12s %-18s %-10s %-12s %s\n" "-------" "--" "----" "------" "----"
  
  echo "$members" | jq -r '.[] | [
    .nodeId,
    (.config.ipAssignments // [] | if length > 0 then .[0] else "unassigned" end),
    (if .config.authorized then "✅" else "❌" end),
    (if .lastOnline > 0 then
      (if (now - (.lastOnline / 1000)) < 300 then "🟢 online" else "🔴 offline" end)
    else "⚪ never" end),
    (.name // "-")
  ] | @tsv' | while IFS=$'\t' read -r nid ip auth status name; do
    if [[ -n "$online_only" && "$status" == *"offline"* ]]; then
      continue
    fi
    printf "%-12s %-18s %-10s %-12s %s\n" "$nid" "$ip" "$auth" "$status" "$name"
  done
}

cmd_authorize() {
  check_prereqs
  local network_id="${1:?Usage: manage.sh authorize <network-id> <member-id>}"
  local member_id="${2:?Usage: manage.sh authorize <network-id> <member-id>}"
  
  zt_api POST "/network/$network_id/member/$member_id" \
    -d '{"config": {"authorized": true}}' >/dev/null
  
  log "✅ Member $member_id authorized on network $network_id"
}

cmd_deauthorize() {
  check_prereqs
  local network_id="${1:?Usage: manage.sh deauthorize <network-id> <member-id>}"
  local member_id="${2:?Usage: manage.sh deauthorize <network-id> <member-id>}"
  
  zt_api POST "/network/$network_id/member/$member_id" \
    -d '{"config": {"authorized": false}}' >/dev/null
  
  log "✅ Member $member_id deauthorized from network $network_id"
}

cmd_overview() {
  check_prereqs
  local network_id="${1:?Usage: manage.sh overview <network-id>}"
  
  local network
  network=$(zt_api GET "/network/$network_id")
  
  local name cidr member_count
  name=$(echo "$network" | jq -r '.config.name // "unnamed"')
  cidr=$(echo "$network" | jq -r '.config.routes[0].target // "none"')
  
  local members
  members=$(zt_api GET "/network/$network_id/member")
  
  local total auth online
  total=$(echo "$members" | jq 'length')
  auth=$(echo "$members" | jq '[.[] | select(.config.authorized)] | length')
  online=$(echo "$members" | jq "[.[] | select(.lastOnline > 0 and (now - (.lastOnline / 1000)) < 300)] | length")
  local pending=$((total - auth))
  
  echo ""
  log "Network Overview"
  echo "  Name:       $name"
  echo "  ID:         $network_id"
  echo "  Subnet:     $cidr"
  echo "  Members:    $auth authorized, $pending pending"
  echo "  Online:     $online / $auth"
  echo ""
}

cmd_peers() {
  log "ZeroTier Peers:"
  echo ""
  sudo zerotier-cli peers
}

cmd_networks() {
  check_prereqs
  
  log "Your ZeroTier Networks:"
  echo ""
  
  local networks
  networks=$(zt_api GET "/network")
  
  printf "%-18s %-20s %-18s %-8s\n" "NETWORK ID" "NAME" "SUBNET" "MEMBERS"
  printf "%-18s %-20s %-18s %-8s\n" "----------" "----" "------" "-------"
  
  echo "$networks" | jq -r '.[] | [
    .id,
    (.config.name // "unnamed"),
    (.config.routes[0].target // "none"),
    (.totalMemberCount // 0 | tostring)
  ] | @tsv' | while IFS=$'\t' read -r id name subnet members; do
    printf "%-18s %-20s %-18s %-8s\n" "$id" "$name" "$subnet" "$members"
  done
}

cmd_delete() {
  check_prereqs
  local network_id="${1:?Usage: manage.sh delete <network-id>}"
  
  warn "Deleting network $network_id..."
  zt_api DELETE "/network/$network_id" >/dev/null
  log "✅ Network $network_id deleted."
}

cmd_health_check() {
  check_prereqs
  local network_id="${1:?Usage: manage.sh health-check <network-id>}"
  
  local members
  members=$(zt_api GET "/network/$network_id/member")
  
  local issues=0
  
  # Check for offline authorized members
  local offline
  offline=$(echo "$members" | jq -r '[.[] | select(.config.authorized and .lastOnline > 0 and (now - (.lastOnline / 1000)) > 600)] | length')
  if [[ "$offline" -gt 0 ]]; then
    warn "⚠️  $offline authorized member(s) offline >10 min"
    echo "$members" | jq -r '.[] | select(.config.authorized and .lastOnline > 0 and (now - (.lastOnline / 1000)) > 600) | "  - " + .nodeId + " (" + (.name // "unnamed") + ") — last seen " + ((.lastOnline / 1000) | strftime("%Y-%m-%d %H:%M UTC"))'
    issues=$((issues + 1))
  fi
  
  # Check for pending (unauthorized) members
  local pending
  pending=$(echo "$members" | jq '[.[] | select(.config.authorized | not)] | length')
  if [[ "$pending" -gt 0 ]]; then
    warn "⚠️  $pending pending member(s) awaiting authorization"
    echo "$members" | jq -r '.[] | select(.config.authorized | not) | "  - " + .nodeId'
    issues=$((issues + 1))
  fi
  
  # Check local peer connections for relay
  if command -v zerotier-cli &>/dev/null; then
    local relayed
    relayed=$(sudo zerotier-cli peers 2>/dev/null | grep -c "RELAY" || true)
    if [[ "$relayed" -gt 0 ]]; then
      warn "⚠️  $relayed peer(s) using RELAY (not direct). Check UDP port 9993."
      issues=$((issues + 1))
    fi
  fi
  
  if [[ "$issues" -eq 0 ]]; then
    log "✅ Network $network_id: All healthy"
  else
    warn "Found $issues issue(s)"
  fi
  
  return "$issues"
}

# Usage
usage() {
  echo "ZeroTier VPN Manager"
  echo ""
  echo "Usage: manage.sh <command> [args]"
  echo ""
  echo "Local Commands (no API token needed):"
  echo "  status                     Show local ZeroTier status"
  echo "  join <network-id>          Join a network"
  echo "  leave <network-id>         Leave a network"
  echo "  peers                      Show connected peers"
  echo ""
  echo "API Commands (requires ZT_API_TOKEN):"
  echo "  create [name] [cidr]       Create a new network"
  echo "  delete <network-id>        Delete a network"
  echo "  networks                   List all your networks"
  echo "  overview <network-id>      Network overview & stats"
  echo "  members <network-id>       List network members"
  echo "  authorize <net> <member>   Authorize a member"
  echo "  deauthorize <net> <member> Deauthorize a member"
  echo "  health-check <network-id>  Check network health"
  echo ""
  echo "Environment:"
  echo "  ZT_API_TOKEN    API token from https://my.zerotier.com/account"
}

# Main dispatcher
case "${1:-}" in
  status)       cmd_status ;;
  create)       shift; cmd_create "${@:-}" ;;
  join)         shift; cmd_join "$@" ;;
  leave)        shift; cmd_leave "$@" ;;
  members)      shift; cmd_members "$@" ;;
  authorize)    shift; cmd_authorize "$@" ;;
  deauthorize)  shift; cmd_deauthorize "$@" ;;
  overview)     shift; cmd_overview "$@" ;;
  peers)        cmd_peers ;;
  networks)     cmd_networks ;;
  delete)       shift; cmd_delete "$@" ;;
  health-check) shift; cmd_health_check "$@" ;;
  help|--help|-h|"") usage ;;
  *)            err "Unknown command: $1"; usage; exit 1 ;;
esac
