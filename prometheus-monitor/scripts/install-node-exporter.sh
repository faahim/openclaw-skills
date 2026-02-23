#!/bin/bash
# Standalone Node Exporter installer for remote targets
set -euo pipefail

NODE_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  GOARCH="amd64" ;;
  aarch64) GOARCH="arm64" ;;
  armv7l)  GOARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "📦 Installing Node Exporter ${NODE_VERSION} for linux/${GOARCH}"

if ! id -u prometheus &>/dev/null; then
  useradd --no-create-home --shell /bin/false prometheus
fi

cd /tmp
NODE_ARCHIVE="node_exporter-${NODE_VERSION}.linux-${GOARCH}.tar.gz"
curl -fsSL -o "${NODE_ARCHIVE}" \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/${NODE_ARCHIVE}"
tar xzf "${NODE_ARCHIVE}"
cp "node_exporter-${NODE_VERSION}.linux-${GOARCH}/node_exporter" /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter

echo "✅ Node Exporter running on port 9100"
echo "   Add this target on your Prometheus server:"
echo "   sudo bash scripts/add-target.sh $(hostname -I | awk '{print $1}'):9100 $(hostname)"

rm -f /tmp/${NODE_ARCHIVE}
rm -rf /tmp/node_exporter-${NODE_VERSION}.linux-${GOARCH}
