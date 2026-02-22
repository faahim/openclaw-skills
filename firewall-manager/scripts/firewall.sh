#!/bin/bash
# Firewall Manager — UFW/firewalld management script
# Requires sudo access

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
SSH_PORT="${FW_SSH_PORT:-22}"
TRUSTED_NETWORK="${FW_TRUSTED_NETWORK:-}"
LOG_LEVEL="${FW_LOG_LEVEL:-low}"

# Detect firewall backend
detect_backend() {
  if command -v ufw &>/dev/null; then
    echo "ufw"
  elif command -v firewall-cmd &>/dev/null; then
    echo "firewalld"
  else
    echo "none"
  fi
}

BACKEND=$(detect_backend)

# ─── Helper Functions ───────────────────────────────────────────────

log_info()  { echo -e "${GREEN}✅${NC} $*"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
log_error() { echo -e "${RED}❌${NC} $*"; }
log_step()  { echo -e "${BLUE}→${NC} $*"; }

require_sudo() {
  if [[ $EUID -ne 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      log_error "This command requires sudo access."
      exit 1
    fi
  fi
}

# ─── UFW Functions ──────────────────────────────────────────────────

ufw_install() {
  require_sudo
  log_step "Installing UFW..."
  
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq ufw
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y -q ufw
  elif command -v yum &>/dev/null; then
    sudo yum install -y -q ufw
  else
    log_error "Package manager not found. Install UFW manually."
    exit 1
  fi
  
  log_step "Setting default policies..."
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  
  log_step "Allowing SSH on port $SSH_PORT (safety first)..."
  sudo ufw allow "$SSH_PORT/tcp" comment "SSH"
  
  log_step "Enabling UFW..."
  echo "y" | sudo ufw enable
  
  log_info "UFW installed and enabled. SSH allowed on port $SSH_PORT."
  echo ""
  sudo ufw status verbose
}

ufw_status() {
  local numbered="${1:-}"
  echo -e "🔥 ${BLUE}Firewall Status${NC}"
  echo "==============================="
  if [[ "$numbered" == "numbered" ]]; then
    sudo ufw status numbered
  else
    sudo ufw status verbose
  fi
}

ufw_allow() {
  local port="$1"
  require_sudo
  sudo ufw allow "$port" comment "Allowed by firewall-manager"
  log_info "Allowed port $port"
}

ufw_allow_from() {
  local ip="$1"
  local port="$2"
  require_sudo
  sudo ufw allow from "$ip" to any port "$port" comment "Allowed from $ip"
  log_info "Allowed $ip → port $port"
}

ufw_block() {
  local target="$1"
  require_sudo
  sudo ufw deny from "$target"
  log_info "Blocked $target"
}

ufw_limit() {
  local port="$1"
  require_sudo
  sudo ufw limit "$port" comment "Rate limited"
  log_info "Rate limited $port (6 connections per 30s)"
}

ufw_delete() {
  local rule_num="$1"
  require_sudo
  echo "y" | sudo ufw delete "$rule_num"
  log_info "Deleted rule #$rule_num"
}

ufw_reset() {
  require_sudo
  log_warn "Resetting all firewall rules..."
  echo "y" | sudo ufw reset
  log_info "All rules reset. UFW is now inactive."
  log_warn "Run 'bash firewall.sh install' to set up again."
}

ufw_logging() {
  local level="${1:-$LOG_LEVEL}"
  require_sudo
  sudo ufw logging "$level"
  log_info "Logging set to $level"
}

ufw_logs() {
  if [[ -f /var/log/ufw.log ]]; then
    sudo grep -i "ufw" /var/log/ufw.log 2>/dev/null || \
    sudo grep -i "ufw" /var/log/syslog 2>/dev/null || \
    log_warn "No UFW log entries found."
  else
    sudo grep -i "ufw" /var/log/syslog 2>/dev/null || \
    log_warn "No UFW log entries found."
  fi
}

ufw_export() {
  if [[ -f /etc/ufw/user.rules ]]; then
    cat /etc/ufw/user.rules
  else
    sudo ufw status numbered
  fi
}

ufw_import() {
  local file="$1"
  require_sudo
  if [[ ! -f "$file" ]]; then
    log_error "File not found: $file"
    exit 1
  fi
  sudo cp "$file" /etc/ufw/user.rules
  sudo ufw reload
  log_info "Rules imported from $file"
}

ufw_app_list() {
  sudo ufw app list
}

ufw_app_allow() {
  local app="$1"
  require_sudo
  sudo ufw allow "$app"
  log_info "Allowed application profile: $app"
}

# ─── Presets ────────────────────────────────────────────────────────

preset_web_server() {
  require_sudo
  log_step "Applying web-server preset..."
  sudo ufw allow 80/tcp comment "HTTP"
  sudo ufw allow 443/tcp comment "HTTPS"
  sudo ufw limit "$SSH_PORT/tcp" comment "SSH rate-limited"
  log_info "Web server preset applied (HTTP + HTTPS + SSH rate-limited)"
}

preset_db_server() {
  local network="${1:-$TRUSTED_NETWORK}"
  require_sudo
  
  if [[ -z "$network" ]]; then
    log_error "Specify trusted network: --network 10.0.0.0/24 or set FW_TRUSTED_NETWORK"
    exit 1
  fi
  
  log_step "Applying db-server preset (trusted: $network)..."
  sudo ufw allow from "$network" to any port 5432 comment "PostgreSQL from trusted"
  sudo ufw allow from "$network" to any port 3306 comment "MySQL from trusted"
  sudo ufw allow from "$network" to any port 27017 comment "MongoDB from trusted"
  sudo ufw allow from "$network" to any port 6379 comment "Redis from trusted"
  sudo ufw limit "$SSH_PORT/tcp" comment "SSH rate-limited"
  log_info "DB server preset applied (Postgres/MySQL/Mongo/Redis from $network)"
}

preset_docker_host() {
  require_sudo
  log_step "Applying docker-host preset..."
  sudo ufw allow 2376/tcp comment "Docker TLS"
  sudo ufw allow 2377/tcp comment "Docker Swarm"
  sudo ufw allow 7946/tcp comment "Docker overlay TCP"
  sudo ufw allow 7946/udp comment "Docker overlay UDP"
  sudo ufw allow 4789/udp comment "Docker overlay VXLAN"
  sudo ufw limit "$SSH_PORT/tcp" comment "SSH rate-limited"
  log_info "Docker host preset applied"
}

preset_minimal() {
  require_sudo
  log_step "Applying minimal preset (SSH only)..."
  echo "y" | sudo ufw reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw limit "$SSH_PORT/tcp" comment "SSH rate-limited"
  echo "y" | sudo ufw enable
  log_info "Minimal preset applied — SSH only, everything else blocked"
}

# ─── Docker Fix ─────────────────────────────────────────────────────

docker_fix() {
  require_sudo
  log_step "Fixing Docker/UFW conflict..."
  
  # Create/update Docker daemon config
  local daemon_json="/etc/docker/daemon.json"
  if [[ -f "$daemon_json" ]]; then
    # Merge iptables: false
    if command -v jq &>/dev/null; then
      sudo jq '. + {"iptables": false}' "$daemon_json" > /tmp/daemon.json.tmp
      sudo mv /tmp/daemon.json.tmp "$daemon_json"
    else
      log_warn "jq not found — manually add '\"iptables\": false' to $daemon_json"
    fi
  else
    echo '{"iptables": false}' | sudo tee "$daemon_json" >/dev/null
  fi
  
  # Add DOCKER-USER chain rules
  local after_rules="/etc/ufw/after.rules"
  if ! grep -q "DOCKER-USER" "$after_rules" 2>/dev/null; then
    cat <<'EOF' | sudo tee -a "$after_rules" >/dev/null

# Docker UFW fix — route Docker traffic through UFW
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -j RETURN
COMMIT
EOF
  fi
  
  sudo systemctl restart docker 2>/dev/null || true
  sudo ufw reload
  log_info "Docker/UFW conflict fixed. Docker containers now respect UFW rules."
}

# ─── Audit ──────────────────────────────────────────────────────────

audit() {
  echo -e "🔍 ${BLUE}Firewall Security Audit${NC} — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "========================================"
  echo ""
  
  local score=10
  local warnings=()
  
  # Check if active
  local fw_status
  fw_status=$(sudo ufw status 2>/dev/null | head -1)
  if echo "$fw_status" | grep -qi "active"; then
    echo -e "Status: ${GREEN}✅ Active${NC}"
  else
    echo -e "Status: ${RED}❌ INACTIVE${NC}"
    score=$((score - 5))
    warnings+=("Firewall is INACTIVE — your server is unprotected!")
  fi
  
  # Check defaults
  local defaults
  defaults=$(sudo ufw status verbose 2>/dev/null | grep "Default:")
  if echo "$defaults" | grep -qi "deny (incoming)"; then
    echo -e "Default incoming: ${GREEN}✅ DENY${NC}"
  else
    echo -e "Default incoming: ${RED}❌ NOT DENY${NC}"
    score=$((score - 3))
    warnings+=("Default incoming policy is not DENY — change with: ufw default deny incoming")
  fi
  
  if echo "$defaults" | grep -qi "allow (outgoing)"; then
    echo -e "Default outgoing: ${GREEN}✅ ALLOW${NC}"
  fi
  
  echo ""
  echo "Open Ports:"
  
  # Parse rules
  local ssh_limited=false
  local high_ports=()
  
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*\[ ]]; then
      local port rule_detail
      port=$(echo "$line" | awk '{print $2}')
      rule_detail=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //')
      
      # Check if SSH is rate limited
      if [[ "$port" == "${SSH_PORT}/tcp" ]] || [[ "$port" == "${SSH_PORT}" ]]; then
        if echo "$line" | grep -qi "limit"; then
          ssh_limited=true
          echo -e "  $port — SSH (rate limited ${GREEN}✅${NC})"
        else
          echo -e "  $port — SSH (${YELLOW}not rate limited${NC})"
        fi
      else
        echo "  $port — $rule_detail"
      fi
      
      # Check for high/unusual ports
      local port_num
      port_num=$(echo "$port" | grep -oP '^\d+' || echo "0")
      if [[ "$port_num" -gt 10000 ]]; then
        high_ports+=("$port")
      fi
    fi
  done < <(sudo ufw status numbered 2>/dev/null | tail -n +4)
  
  echo ""
  
  # SSH rate limiting check
  if ! $ssh_limited; then
    score=$((score - 1))
    warnings+=("SSH is not rate-limited — run: bash firewall.sh limit ${SSH_PORT}/tcp")
  fi
  
  # High port check
  if [[ ${#high_ports[@]} -gt 0 ]]; then
    score=$((score - 1))
    warnings+=("High ports open: ${high_ports[*]} — verify these are intentional")
  fi
  
  # IPv6 check
  if grep -q "IPV6=yes" /etc/default/ufw 2>/dev/null; then
    echo -e "IPv6: ${GREEN}✅ Enabled${NC}"
  else
    warnings+=("IPv6 rules may not be active — check /etc/default/ufw")
  fi
  
  # Print warnings
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  Warnings:${NC}"
    for w in "${warnings[@]}"; do
      echo "  - $w"
    done
  fi
  
  echo ""
  
  # Score
  local color=$GREEN
  if [[ $score -lt 7 ]]; then color=$RED
  elif [[ $score -lt 9 ]]; then color=$YELLOW
  fi
  
  local rating="Excellent"
  if [[ $score -lt 5 ]]; then rating="Poor"
  elif [[ $score -lt 7 ]]; then rating="Needs Work"
  elif [[ $score -lt 9 ]]; then rating="Good"
  fi
  
  echo -e "Score: ${color}${score}/10${NC} — ${rating}"
}

# ─── Web Server Shortcut ───────────────────────────────────────────

web_server() {
  preset_web_server
}

# ─── Main Command Router ───────────────────────────────────────────

usage() {
  echo "Firewall Manager — UFW/firewalld management"
  echo ""
  echo "Usage: bash firewall.sh <command> [args]"
  echo ""
  echo "Commands:"
  echo "  install                    Install & enable UFW with safe defaults"
  echo "  status [numbered]          Show firewall status"
  echo "  allow <port>[/proto]       Allow a port (e.g., 80, 443/tcp)"
  echo "  allow-from <ip> <port>     Allow port from specific IP/subnet"
  echo "  block <ip|subnet>          Block an IP or subnet"
  echo "  limit <port>[/proto]       Rate-limit a port"
  echo "  delete <rule-number>       Delete a rule by number"
  echo "  reset                      Reset all rules (dangerous!)"
  echo "  audit                      Run security audit"
  echo "  logging <level>            Set log level (off|low|medium|high|full)"
  echo "  logs                       View firewall logs"
  echo "  export                     Export current rules"
  echo "  import <file>              Import rules from file"
  echo "  app-list                   List available app profiles"
  echo "  app-allow <name>           Allow an application profile"
  echo "  web-server                 Apply web server preset"
  echo "  preset <name> [--network]  Apply a preset (web-server|db-server|docker-host|minimal)"
  echo "  docker-fix                 Fix Docker/UFW conflict"
  echo ""
}

CMD="${1:-help}"
shift || true

case "$CMD" in
  install)     ufw_install ;;
  status)      ufw_status "${1:-}" ;;
  allow)       ufw_allow "$1" ;;
  allow-from)  ufw_allow_from "$1" "$2" ;;
  block)       ufw_block "$1" ;;
  limit)       ufw_limit "$1" ;;
  delete)      ufw_delete "$1" ;;
  reset)       ufw_reset ;;
  audit)       audit ;;
  logging)     ufw_logging "${1:-$LOG_LEVEL}" ;;
  logs)        ufw_logs ;;
  export)      ufw_export ;;
  import)      ufw_import "$1" ;;
  app-list)    ufw_app_list ;;
  app-allow)   ufw_app_allow "$1" ;;
  web-server)  web_server ;;
  preset)
    preset_name="${1:-}"
    network_arg=""
    shift || true
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --network) network_arg="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    case "$preset_name" in
      web-server)    preset_web_server ;;
      db-server)     preset_db_server "$network_arg" ;;
      docker-host)   preset_docker_host ;;
      minimal)       preset_minimal ;;
      *)             log_error "Unknown preset: $preset_name"; exit 1 ;;
    esac
    ;;
  docker-fix)  docker_fix ;;
  help|--help|-h) usage ;;
  *)           log_error "Unknown command: $CMD"; usage; exit 1 ;;
esac
