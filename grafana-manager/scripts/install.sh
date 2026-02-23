#!/bin/bash
# Grafana Dashboard Manager — Install Script
# Installs Grafana OSS on Debian/Ubuntu, RHEL/Fedora, or via Docker
set -euo pipefail

OS=""
DOCKER=false
PORT=3000
DATA_DIR="/opt/grafana-data"

usage() {
  echo "Usage: $0 [--os debian|rhel] [--docker] [--port PORT] [--data DIR]"
  echo ""
  echo "Options:"
  echo "  --os debian|rhel   Install natively on this OS family"
  echo "  --docker           Install via Docker instead"
  echo "  --port PORT        Grafana port (default: 3000)"
  echo "  --data DIR         Data directory for Docker (default: /opt/grafana-data)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --os) OS="$2"; shift 2 ;;
    --docker) DOCKER=true; shift ;;
    --port) PORT="$2"; shift 2 ;;
    --data) DATA_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

install_debian() {
  echo "📦 Installing Grafana OSS on Debian/Ubuntu..."
  sudo apt-get install -y apt-transport-https software-properties-common wget
  sudo mkdir -p /etc/apt/keyrings/
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
  sudo apt-get update
  sudo apt-get install -y grafana
  sudo systemctl daemon-reload
  sudo systemctl enable grafana-server
  sudo systemctl start grafana-server
  echo "✅ Grafana installed and running"
  echo "🔗 http://localhost:${PORT} (admin/admin)"
}

install_rhel() {
  echo "📦 Installing Grafana OSS on RHEL/CentOS/Fedora..."
  cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
  sudo yum install -y grafana || sudo dnf install -y grafana
  sudo systemctl daemon-reload
  sudo systemctl enable grafana-server
  sudo systemctl start grafana-server
  echo "✅ Grafana installed and running"
  echo "🔗 http://localhost:${PORT} (admin/admin)"
}

install_docker() {
  echo "🐳 Installing Grafana via Docker..."
  if ! command -v docker &>/dev/null; then
    echo "❌ Docker not found. Install Docker first."
    exit 1
  fi
  mkdir -p "$DATA_DIR"
  docker run -d \
    --name grafana \
    --restart unless-stopped \
    -p "${PORT}:3000" \
    -v "${DATA_DIR}:/var/lib/grafana" \
    -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
    grafana/grafana-oss:latest
  echo "✅ Grafana container started"
  echo "🔗 http://localhost:${PORT} (admin/admin)"
}

# Auto-detect OS if not specified
if [[ "$DOCKER" == "true" ]]; then
  install_docker
elif [[ -z "$OS" ]]; then
  if [[ -f /etc/debian_version ]]; then
    OS="debian"
  elif [[ -f /etc/redhat-release ]]; then
    OS="rhel"
  else
    echo "⚠️  Cannot detect OS. Use --os debian|rhel or --docker"
    exit 1
  fi
fi

case "$OS" in
  debian) install_debian ;;
  rhel) install_rhel ;;
  "") ;; # Docker already handled above
  *) echo "❌ Unknown OS: $OS. Use debian or rhel."; exit 1 ;;
esac
