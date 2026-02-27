#!/bin/bash
# Install and configure Eclipse Mosquitto MQTT broker
set -euo pipefail

DOCKER_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --docker) DOCKER_MODE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if $DOCKER_MODE; then
  echo "🐳 Setting up Mosquitto via Docker..."
  
  mkdir -p mosquitto/{config,data,log}
  
  cat > mosquitto/config/mosquitto.conf << 'CONF'
listener 1883
protocol mqtt
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_type all
CONF

  cat > docker-compose.yml << 'COMPOSE'
version: '3.8'
services:
  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "1883:1883"
      - "8883:8883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
COMPOSE

  docker compose up -d
  echo "✅ Mosquitto running in Docker on port 1883"
  echo "   Config: ./mosquitto/config/mosquitto.conf"
  echo "   Logs:   ./mosquitto/log/mosquitto.log"
  exit 0
fi

echo "📦 Installing Mosquitto MQTT broker..."

# Detect OS
if [ -f /etc/debian_version ]; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq mosquitto mosquitto-clients
elif [ -f /etc/redhat-release ]; then
  sudo yum install -y epel-release
  sudo yum install -y mosquitto mosquitto-clients
elif [ -f /etc/arch-release ]; then
  sudo pacman -Sy --noconfirm mosquitto
elif command -v brew &>/dev/null; then
  brew install mosquitto
else
  echo "❌ Unsupported OS. Install mosquitto manually."
  exit 1
fi

# Create default config
sudo tee /etc/mosquitto/conf.d/default.conf > /dev/null << 'CONF'
# MQTT Broker - Default Configuration
listener 1883
protocol mqtt

# Start with anonymous access for testing
# Run 'bash scripts/configure.sh --auth' to enable authentication
allow_anonymous true

# Logging
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information

# Persistence
persistence true
persistence_location /var/lib/mosquitto/
CONF

# Ensure log directory exists
sudo mkdir -p /var/log/mosquitto
sudo chown mosquitto:mosquitto /var/log/mosquitto 2>/dev/null || true

# Enable and start
sudo systemctl enable mosquitto
sudo systemctl restart mosquitto

echo "✅ Mosquitto installed and running on port 1883"
echo ""
echo "Quick test:"
echo "  mosquitto_sub -t 'test/#' -v &"
echo "  mosquitto_pub -t 'test/hello' -m 'It works!'"
echo ""
echo "Next steps:"
echo "  bash scripts/manage-users.sh add <user> <pass>  # Add authentication"
echo "  bash scripts/configure.sh --auth                 # Enable auth requirement"
echo "  bash scripts/setup-tls.sh --domain <your-domain> # Enable TLS"
