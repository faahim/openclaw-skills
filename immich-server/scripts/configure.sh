#!/bin/bash
# Immich Server — Configuration Manager
set -euo pipefail

INSTALL_DIR="${IMMICH_DIR:-/opt/immich}"
cd "$INSTALL_DIR"

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --port)
      PORT="$2"; shift 2
      sed -i "s|[0-9]*:2283|$PORT:2283|g" docker-compose.yml
      log "✅ Port changed to $PORT. Restart with: docker compose up -d"
      ;;
    --upload-dir)
      DIR="$2"; shift 2
      mkdir -p "$DIR"
      sed -i "s|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=$DIR|" .env
      log "✅ Upload directory changed to $DIR. Restart with: docker compose up -d"
      ;;
    --gpu)
      GPU="$2"; shift 2
      case "$GPU" in
        nvidia)
          log "🎮 Enabling NVIDIA GPU acceleration..."
          # Add NVIDIA runtime to ML container
          if ! grep -q "runtime: nvidia" docker-compose.yml; then
            sed -i '/immich-machine-learning:/,/^  [a-z]/{/image:/a\    runtime: nvidia\n    environment:\n      - NVIDIA_VISIBLE_DEVICES=all}' docker-compose.yml
          fi
          ;;
        intel)
          log "🎮 Enabling Intel GPU (OpenVINO)..."
          if ! grep -q "/dev/dri" docker-compose.yml; then
            sed -i '/immich-machine-learning:/,/^  [a-z]/{/image:/a\    devices:\n      - /dev/dri:/dev/dri}' docker-compose.yml
          fi
          ;;
        off)
          log "Disabling GPU acceleration..."
          sed -i '/runtime: nvidia/d' docker-compose.yml
          ;;
        *) echo "Unknown GPU type: $GPU (use nvidia/intel/off)"; exit 1 ;;
      esac
      log "Restart with: docker compose up -d"
      ;;
    --no-ml)
      shift
      echo "IMMICH_MACHINE_LEARNING_ENABLED=false" >> .env
      log "✅ Machine learning disabled. Restart with: docker compose up -d"
      ;;
    --ml-model)
      MODEL="$2"; shift 2
      case "$MODEL" in
        small) echo "MACHINE_LEARNING_CLIP_MODEL=ViT-B-16__openai" >> .env ;;
        large) echo "MACHINE_LEARNING_CLIP_MODEL=ViT-L-14__openai" >> .env ;;
        *) echo "Unknown model size: $MODEL (use small/large)"; exit 1 ;;
      esac
      log "✅ ML model set to $MODEL. Restart with: docker compose up -d"
      ;;
    *)
      echo "Usage: configure.sh [OPTIONS]"
      echo "  --port PORT          Change server port"
      echo "  --upload-dir DIR     Change photo upload directory"
      echo "  --gpu TYPE           Enable GPU (nvidia/intel/off)"
      echo "  --no-ml              Disable machine learning"
      echo "  --ml-model SIZE      Set ML model (small/large)"
      exit 0 ;;
  esac
done
