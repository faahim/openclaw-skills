#!/bin/bash
# Mosh installer — server and client setup with firewall configuration
set -euo pipefail

MODE=""
PORTS="60000-60010"
HOSTS_FILE=""

usage() {
  echo "Usage: $0 [--server|--client] [--ports RANGE] [--hosts FILE]"
  echo ""
  echo "Options:"
  echo "  --server       Install mosh-server and configure firewall"
  echo "  --client       Install mosh client only"
  echo "  --ports RANGE  UDP port range (default: 60000-60010)"
  echo "  --hosts FILE   Install on multiple remote hosts via SSH"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --server) MODE="server"; shift ;;
    --client) MODE="client"; shift ;;
    --ports) PORTS="$2"; shift 2 ;;
    --hosts) HOSTS_FILE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$MODE" ]] && { echo "❌ Specify --server or --client"; usage; }

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

detect_os_pretty() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$PRETTY_NAME"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
  else
    echo "Unknown OS"
  fi
}

install_mosh() {
  local os
  os=$(detect_os)
  local pretty
  pretty=$(detect_os_pretty)
  
  echo "[$(timestamp)] ✅ Detected: $pretty"
  
  if command -v mosh &>/dev/null && command -v mosh-server &>/dev/null; then
    local ver
    ver=$(mosh --version 2>&1 | head -1 | grep -oP '[\d.]+' || echo "unknown")
    echo "[$(timestamp)] ✅ Mosh already installed (v$ver)"
    return 0
  fi
  
  echo "[$(timestamp)] ✅ Installing mosh..."
  
  case "$os" in
    ubuntu|debian|pop|linuxmint|raspbian)
      sudo apt-get update -qq
      sudo apt-get install -y -qq mosh
      ;;
    fedora)
      sudo dnf install -y mosh
      ;;
    centos|rhel|rocky|almalinux|amzn)
      sudo yum install -y epel-release 2>/dev/null || true
      sudo yum install -y mosh
      ;;
    arch|manjaro|endeavouros)
      sudo pacman -S --noconfirm mosh
      ;;
    opensuse*|sles)
      sudo zypper install -y mosh
      ;;
    alpine)
      sudo apk add mosh
      ;;
    macos)
      if command -v brew &>/dev/null; then
        brew install mosh
      else
        echo "❌ Homebrew required. Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
      fi
      ;;
    *)
      echo "❌ Unsupported OS: $os. Install mosh manually."
      exit 1
      ;;
  esac
  
  local ver
  ver=$(mosh --version 2>&1 | head -1 | grep -oP '[\d.]+' || echo "unknown")
  echo "[$(timestamp)] ✅ Mosh $ver installed"
}

configure_firewall() {
  local port_start port_end
  port_start=$(echo "$PORTS" | cut -d- -f1)
  port_end=$(echo "$PORTS" | cut -d- -f2)
  
  if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "active"; then
    sudo ufw allow "${port_start}:${port_end}/udp" >/dev/null 2>&1
    echo "[$(timestamp)] ✅ Firewall (ufw): UDP ${port_start}:${port_end} ALLOW"
  elif command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
    sudo firewall-cmd --add-port="${port_start}-${port_end}/udp" --permanent >/dev/null 2>&1
    sudo firewall-cmd --reload >/dev/null 2>&1
    echo "[$(timestamp)] ✅ Firewall (firewalld): UDP ${port_start}-${port_end} ALLOW"
  elif command -v iptables &>/dev/null; then
    sudo iptables -C INPUT -p udp --dport "${port_start}:${port_end}" -j ACCEPT 2>/dev/null || \
      sudo iptables -A INPUT -p udp --dport "${port_start}:${port_end}" -j ACCEPT
    echo "[$(timestamp)] ✅ Firewall (iptables): UDP ${port_start}:${port_end} ALLOW"
    # Try to persist
    if command -v netfilter-persistent &>/dev/null; then
      sudo netfilter-persistent save 2>/dev/null || true
    fi
  else
    echo "[$(timestamp)] ⚠️  No firewall detected — ensure UDP ${port_start}-${port_end} is open"
  fi
}

ensure_locale() {
  if locale -a 2>/dev/null | grep -qi "en_us.utf-\?8"; then
    return 0
  fi
  
  if locale -a 2>/dev/null | grep -qi "c.utf-\?8"; then
    return 0
  fi
  
  echo "[$(timestamp)] ⚠️  UTF-8 locale not found. Generating..."
  if command -v locale-gen &>/dev/null; then
    sudo locale-gen en_US.UTF-8 2>/dev/null || true
  fi
}

# Multi-host installation
if [[ -n "$HOSTS_FILE" ]]; then
  if [[ ! -f "$HOSTS_FILE" ]]; then
    echo "❌ Hosts file not found: $HOSTS_FILE"
    exit 1
  fi
  
  total=$(wc -l < "$HOSTS_FILE" | tr -d ' ')
  i=0
  
  while IFS= read -r host; do
    [[ -z "$host" || "$host" == \#* ]] && continue
    i=$((i + 1))
    echo "[$i/$total] $host"
    
    # Copy install script and run remotely
    scp -q "$0" "${host}:/tmp/mosh-install.sh" 2>/dev/null
    ssh "$host" "bash /tmp/mosh-install.sh --server --ports $PORTS && rm /tmp/mosh-install.sh" 2>&1 | sed 's/^/  /'
    
    echo "[$i/$total] $host — ✅ Done"
  done < "$HOSTS_FILE"
  
  exit 0
fi

# Single-host installation
install_mosh

if [[ "$MODE" == "server" ]]; then
  configure_firewall
  ensure_locale
  
  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "this-host")
  mosh_server_path=$(command -v mosh-server 2>/dev/null || echo "/usr/bin/mosh-server")
  
  echo "[$(timestamp)] ✅ mosh-server binary: $mosh_server_path"
  echo "[$(timestamp)]"
  echo "Connect with:"
  echo "  mosh $(whoami)@${local_ip}"
  echo "  mosh --ssh=\"ssh -p 22 -i ~/.ssh/key\" $(whoami)@${local_ip}"
fi

echo "[$(timestamp)] ✅ Setup complete"
