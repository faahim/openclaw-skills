#!/bin/bash
# Dnsmasq Manager — Management Script
# Add/remove hosts, manage ad blocking, service control, logging

set -euo pipefail

CUSTOM_HOSTS="/etc/dnsmasq.d/custom.hosts"
ADBLOCK_HOSTS="/etc/dnsmasq.d/adblock.hosts"
WHITELIST_FILE="/etc/dnsmasq.d/whitelist.txt"
STATIC_LEASES="/etc/dnsmasq.d/static-leases.conf"
CONFIG_FILE="/etc/dnsmasq.d/openclaw.conf"
ADBLOCK_URL="${DNSMASQ_ADBLOCK_URL:-https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts}"
LOG_FILE="${DNSMASQ_LOG_DIR:-/var/log}/dnsmasq.log"
BACKUP_DIR="/etc/dnsmasq.d/backups"

ACTION="${1:-help}"
shift 2>/dev/null || true

reload_dnsmasq() {
  if command -v systemctl &>/dev/null && systemctl is-active dnsmasq &>/dev/null; then
    sudo systemctl reload dnsmasq 2>/dev/null || sudo systemctl restart dnsmasq
  elif [[ -f /var/run/dnsmasq.pid ]]; then
    sudo kill -HUP "$(cat /var/run/dnsmasq.pid)" 2>/dev/null || true
  fi
}

case "$ACTION" in

  # === Host Management ===

  add-host)
    HOSTNAME="${1:?Usage: manage.sh add-host <hostname> <ip>}"
    IP="${2:?Usage: manage.sh add-host <hostname> <ip>}"
    # Remove existing entry for this hostname
    sudo sed -i "/\s${HOSTNAME}$/d" "$CUSTOM_HOSTS" 2>/dev/null || true
    echo "${IP} ${HOSTNAME}" | sudo tee -a "$CUSTOM_HOSTS" > /dev/null
    reload_dnsmasq
    echo "✅ Added: ${HOSTNAME} → ${IP}"
    ;;

  remove-host)
    HOSTNAME="${1:?Usage: manage.sh remove-host <hostname>}"
    sudo sed -i "/\s${HOSTNAME}$/d" "$CUSTOM_HOSTS"
    reload_dnsmasq
    echo "✅ Removed: ${HOSTNAME}"
    ;;

  add-wildcard)
    DOMAIN="${1:?Usage: manage.sh add-wildcard <domain> <ip>}"
    IP="${2:?Usage: manage.sh add-wildcard <domain> <ip>}"
    # Add wildcard via dnsmasq address directive
    echo "address=/${DOMAIN}/${IP}" | sudo tee -a /etc/dnsmasq.d/wildcards.conf > /dev/null
    reload_dnsmasq
    echo "✅ Wildcard added: *.${DOMAIN} → ${IP}"
    ;;

  list-hosts)
    echo "📋 Custom Host Entries:"
    echo "─────────────────────────────────"
    if [[ -f "$CUSTOM_HOSTS" ]] && [[ -s "$CUSTOM_HOSTS" ]]; then
      cat "$CUSTOM_HOSTS" | while read -r ip host; do
        [[ -z "$ip" || "$ip" == "#"* ]] && continue
        printf "  %-30s → %s\n" "$host" "$ip"
      done
    else
      echo "  (none)"
    fi
    if [[ -f /etc/dnsmasq.d/wildcards.conf ]]; then
      echo ""
      echo "🌐 Wildcard Entries:"
      echo "─────────────────────────────────"
      grep "^address=" /etc/dnsmasq.d/wildcards.conf 2>/dev/null | while IFS='/' read -r _ domain ip; do
        printf "  *.%-27s → %s\n" "$domain" "$ip"
      done
    fi
    ;;

  # === DHCP Management ===

  add-lease)
    MAC="${1:?Usage: manage.sh add-lease <mac> <ip> [hostname]}"
    IP="${2:?Usage: manage.sh add-lease <mac> <ip> [hostname]}"
    HOSTNAME="${3:-}"
    sudo touch "$STATIC_LEASES"
    # Remove existing entry for this MAC
    sudo sed -i "/^dhcp-host=${MAC}/d" "$STATIC_LEASES" 2>/dev/null || true
    if [[ -n "$HOSTNAME" ]]; then
      echo "dhcp-host=${MAC},${IP},${HOSTNAME}" | sudo tee -a "$STATIC_LEASES" > /dev/null
      echo "✅ Static lease: ${MAC} → ${IP} (${HOSTNAME})"
    else
      echo "dhcp-host=${MAC},${IP}" | sudo tee -a "$STATIC_LEASES" > /dev/null
      echo "✅ Static lease: ${MAC} → ${IP}"
    fi
    reload_dnsmasq
    ;;

  list-leases)
    echo "📋 DHCP Leases:"
    echo "─────────────────────────────────"
    if [[ -f /var/lib/misc/dnsmasq.leases ]]; then
      cat /var/lib/misc/dnsmasq.leases | while read -r ts mac ip host _; do
        printf "  %-18s %-16s %s\n" "$mac" "$ip" "$host"
      done
    elif [[ -f /var/lib/dnsmasq/dnsmasq.leases ]]; then
      cat /var/lib/dnsmasq/dnsmasq.leases | while read -r ts mac ip host _; do
        printf "  %-18s %-16s %s\n" "$mac" "$ip" "$host"
      done
    else
      echo "  No lease file found"
    fi
    ;;

  check-dhcp)
    echo "🔍 Checking for existing DHCP servers on the network..."
    if command -v nmap &>/dev/null; then
      sudo nmap --script broadcast-dhcp-discover 2>/dev/null || echo "  Could not detect DHCP servers"
    else
      echo "  Install nmap for DHCP server detection: sudo apt install nmap"
    fi
    ;;

  # === Ad Blocking ===

  enable-adblock)
    URL="$ADBLOCK_URL"
    while [[ $# -gt 0 ]]; do
      case $1 in
        --url) URL="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    echo "📥 Downloading blocklist from: ${URL}"
    TEMP=$(mktemp)
    curl -sL "$URL" -o "$TEMP"
    # Convert hosts file format: keep 0.0.0.0 lines, strip comments
    grep "^0\.0\.0\.0\|^127\.0\.0\.1" "$TEMP" \
      | sed 's/^127\.0\.0\.1/0.0.0.0/' \
      | grep -v "localhost" \
      | sort -u > "${TEMP}.clean"
    BLOCKED=$(wc -l < "${TEMP}.clean")
    # Apply whitelist
    if [[ -f "$WHITELIST_FILE" ]]; then
      while read -r domain; do
        [[ -z "$domain" || "$domain" == "#"* ]] && continue
        sed -i "/ ${domain}$/d" "${TEMP}.clean"
      done < "$WHITELIST_FILE"
    fi
    sudo mv "${TEMP}.clean" "$ADBLOCK_HOSTS"
    rm -f "$TEMP"
    # Ensure config references adblock hosts
    if ! grep -q "addn-hosts=${ADBLOCK_HOSTS}" "$CONFIG_FILE" 2>/dev/null; then
      echo "addn-hosts=${ADBLOCK_HOSTS}" | sudo tee -a "$CONFIG_FILE" > /dev/null
    fi
    reload_dnsmasq
    echo "✅ Ad blocking enabled — ${BLOCKED} domains blocked"
    ;;

  update-adblock)
    echo "🔄 Updating ad blocklist..."
    bash "$0" enable-adblock "$@"
    ;;

  disable-adblock)
    sudo rm -f "$ADBLOCK_HOSTS"
    sudo sed -i "/addn-hosts=.*adblock/d" "$CONFIG_FILE" 2>/dev/null || true
    reload_dnsmasq
    echo "✅ Ad blocking disabled"
    ;;

  adblock-stats)
    if [[ -f "$ADBLOCK_HOSTS" ]]; then
      BLOCKED=$(wc -l < "$ADBLOCK_HOSTS")
      MODIFIED=$(stat -c %y "$ADBLOCK_HOSTS" 2>/dev/null || stat -f %Sm "$ADBLOCK_HOSTS" 2>/dev/null)
      echo "📊 Ad Blocking Stats:"
      echo "   Blocked domains: ${BLOCKED}"
      echo "   Last updated: ${MODIFIED}"
      echo "   Source: ${ADBLOCK_URL}"
    else
      echo "❌ Ad blocking not enabled"
    fi
    ;;

  whitelist)
    DOMAIN="${1:?Usage: manage.sh whitelist <domain>}"
    sudo touch "$WHITELIST_FILE"
    echo "$DOMAIN" | sudo tee -a "$WHITELIST_FILE" > /dev/null
    # Remove from adblock hosts
    if [[ -f "$ADBLOCK_HOSTS" ]]; then
      sudo sed -i "/ ${DOMAIN}$/d" "$ADBLOCK_HOSTS"
      reload_dnsmasq
    fi
    echo "✅ Whitelisted: ${DOMAIN}"
    ;;

  list-whitelist)
    echo "📋 Whitelisted Domains:"
    if [[ -f "$WHITELIST_FILE" ]]; then
      cat "$WHITELIST_FILE" | grep -v "^#" | grep -v "^$" | while read -r d; do
        echo "  ✅ $d"
      done
    else
      echo "  (none)"
    fi
    ;;

  # === DNS Forwarding ===

  add-forward)
    DOMAIN="${1:?Usage: manage.sh add-forward <domain> <dns-server>}"
    SERVER="${2:?Usage: manage.sh add-forward <domain> <dns-server>}"
    echo "server=/${DOMAIN}/${SERVER}" | sudo tee -a /etc/dnsmasq.d/forwards.conf > /dev/null
    reload_dnsmasq
    echo "✅ Forward: ${DOMAIN} → ${SERVER}"
    ;;

  # === Logging ===

  enable-logging)
    if ! grep -q "^log-queries" "$CONFIG_FILE" 2>/dev/null; then
      echo -e "\nlog-queries\nlog-facility=${LOG_FILE}" | sudo tee -a "$CONFIG_FILE" > /dev/null
      reload_dnsmasq
    fi
    echo "✅ Query logging enabled → ${LOG_FILE}"
    ;;

  query-log)
    LINES=50
    MODE="all"
    TOP=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --last) LINES="$2"; shift 2 ;;
        --top) TOP="$2"; shift 2 ;;
        --blocked) MODE="blocked"; shift ;;
        *) shift ;;
      esac
    done
    if [[ ! -f "$LOG_FILE" ]]; then
      echo "❌ Log file not found: ${LOG_FILE}"
      echo "   Enable logging first: manage.sh enable-logging"
      exit 1
    fi
    if [[ -n "$TOP" ]]; then
      echo "📊 Top ${TOP} queried domains:"
      if [[ "$MODE" == "blocked" ]]; then
        grep "is 0.0.0.0" "$LOG_FILE" | awk '{print $6}' | sort | uniq -c | sort -rn | head -"$TOP"
      else
        grep "query\[" "$LOG_FILE" | awk '{print $6}' | sort | uniq -c | sort -rn | head -"$TOP"
      fi
    else
      echo "📋 Last ${LINES} DNS queries:"
      tail -"$LINES" "$LOG_FILE"
    fi
    ;;

  # === Service Management ===

  status)
    if command -v systemctl &>/dev/null; then
      systemctl status dnsmasq --no-pager 2>/dev/null || echo "❌ Dnsmasq not running"
    elif pgrep dnsmasq &>/dev/null; then
      echo "✅ Dnsmasq is running (PID: $(pgrep dnsmasq | head -1))"
    else
      echo "❌ Dnsmasq not running"
    fi
    ;;

  start)
    if command -v systemctl &>/dev/null; then
      sudo systemctl start dnsmasq
    else
      sudo dnsmasq
    fi
    echo "✅ Dnsmasq started"
    ;;

  stop)
    if command -v systemctl &>/dev/null; then
      sudo systemctl stop dnsmasq
    else
      sudo killall dnsmasq 2>/dev/null || true
    fi
    echo "✅ Dnsmasq stopped"
    ;;

  restart)
    if command -v systemctl &>/dev/null; then
      sudo systemctl restart dnsmasq
    else
      sudo killall dnsmasq 2>/dev/null || true
      sleep 1
      sudo dnsmasq
    fi
    echo "✅ Dnsmasq restarted"
    ;;

  backup)
    sudo mkdir -p "$BACKUP_DIR"
    BACKUP_NAME="dnsmasq-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    sudo tar czf "${BACKUP_DIR}/${BACKUP_NAME}" -C /etc/dnsmasq.d . 2>/dev/null
    echo "✅ Backup saved: ${BACKUP_DIR}/${BACKUP_NAME}"
    ;;

  restore)
    LATEST=$(ls -t "${BACKUP_DIR}"/dnsmasq-backup-*.tar.gz 2>/dev/null | head -1)
    if [[ -z "$LATEST" ]]; then
      echo "❌ No backups found in ${BACKUP_DIR}"
      exit 1
    fi
    echo "📦 Restoring from: ${LATEST}"
    sudo tar xzf "$LATEST" -C /etc/dnsmasq.d/
    reload_dnsmasq
    echo "✅ Restored and reloaded"
    ;;

  test-dns)
    DOMAIN="${1:-google.com}"
    echo "🔍 Testing DNS resolution for ${DOMAIN}..."
    if command -v dig &>/dev/null; then
      dig @127.0.0.1 "$DOMAIN" +short
    elif command -v nslookup &>/dev/null; then
      nslookup "$DOMAIN" 127.0.0.1
    else
      echo "❌ Install dig or nslookup for DNS testing"
    fi
    ;;

  uninstall)
    echo "⚠️  This will remove dnsmasq and all configuration"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      if command -v systemctl &>/dev/null; then
        sudo systemctl stop dnsmasq 2>/dev/null || true
        sudo systemctl disable dnsmasq 2>/dev/null || true
      fi
      sudo rm -rf /etc/dnsmasq.d/openclaw.conf /etc/dnsmasq.d/custom.hosts \
        /etc/dnsmasq.d/adblock.hosts /etc/dnsmasq.d/whitelist.txt \
        /etc/dnsmasq.d/wildcards.conf /etc/dnsmasq.d/forwards.conf \
        /etc/dnsmasq.d/static-leases.conf
      echo "✅ Dnsmasq configuration removed"
      echo "   To fully uninstall: sudo apt remove dnsmasq (or equivalent)"
    fi
    ;;

  help|*)
    echo "Dnsmasq Manager — Commands"
    echo ""
    echo "Host Management:"
    echo "  add-host <hostname> <ip>     Add custom DNS entry"
    echo "  remove-host <hostname>       Remove custom DNS entry"
    echo "  add-wildcard <domain> <ip>   Add wildcard domain"
    echo "  list-hosts                   List all custom entries"
    echo ""
    echo "DHCP Management:"
    echo "  add-lease <mac> <ip> [name]  Add static DHCP lease"
    echo "  list-leases                  List active DHCP leases"
    echo "  check-dhcp                   Check for existing DHCP servers"
    echo ""
    echo "Ad Blocking:"
    echo "  enable-adblock [--url URL]   Enable ad blocking"
    echo "  update-adblock               Update blocklist"
    echo "  disable-adblock              Disable ad blocking"
    echo "  adblock-stats                Show blocking stats"
    echo "  whitelist <domain>           Whitelist a domain"
    echo "  list-whitelist               List whitelisted domains"
    echo ""
    echo "DNS Forwarding:"
    echo "  add-forward <domain> <dns>   Forward domain to specific DNS"
    echo ""
    echo "Logging:"
    echo "  enable-logging               Enable query logging"
    echo "  query-log [--last N]         View recent queries"
    echo "  query-log --top N            Top queried domains"
    echo "  query-log --blocked --top N  Top blocked domains"
    echo ""
    echo "Service:"
    echo "  status                       Check dnsmasq status"
    echo "  start / stop / restart       Service control"
    echo "  backup / restore             Backup/restore config"
    echo "  test-dns [domain]            Test DNS resolution"
    echo "  uninstall                    Remove all config"
    ;;

esac
