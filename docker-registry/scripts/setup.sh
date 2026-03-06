#!/bin/bash
# Private Docker Registry — Setup Script
# Deploys a Docker registry with auth, TLS, and optional S3 storage

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REGISTRY_DATA_DIR="${REGISTRY_DATA_DIR:-$HOME/.docker-registry}"
REGISTRY_DOMAIN="${REGISTRY_DOMAIN:-localhost}"
REGISTRY_USER="${REGISTRY_USER:-admin}"
REGISTRY_PASS="${REGISTRY_PASS:-$(openssl rand -base64 16)}"
REGISTRY_CONTAINER_NAME="docker-registry"
REGISTRY_S3_BUCKET="${REGISTRY_S3_BUCKET:-}"
REGISTRY_S3_REGION="${REGISTRY_S3_REGION:-us-east-1}"
MIRROR_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --mirror) MIRROR_MODE=true; shift ;;
    --storage)
      if [[ "$2" == "s3" ]]; then
        if [[ -z "$REGISTRY_S3_BUCKET" ]]; then
          echo "❌ Set REGISTRY_S3_BUCKET environment variable first"
          exit 1
        fi
      fi
      STORAGE_BACKEND="$2"; shift 2 ;;
    --port) REGISTRY_PORT="$2"; shift 2 ;;
    --domain) REGISTRY_DOMAIN="$2"; shift 2 ;;
    --data-dir) REGISTRY_DATA_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: setup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --mirror        Configure as Docker Hub pull-through cache"
      echo "  --storage s3    Use S3 backend storage"
      echo "  --port PORT     Registry port (default: 5000)"
      echo "  --domain DOMAIN Domain for TLS cert (default: localhost)"
      echo "  --data-dir DIR  Data directory (default: ~/.docker-registry)"
      echo "  -h, --help      Show this help"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

STORAGE_BACKEND="${STORAGE_BACKEND:-filesystem}"

echo "🐳 Private Docker Registry Setup"
echo "═══════════════════════════════════"
echo "  Domain:   $REGISTRY_DOMAIN"
echo "  Port:     $REGISTRY_PORT"
echo "  Data:     $REGISTRY_DATA_DIR"
echo "  Storage:  $STORAGE_BACKEND"
echo "  Mirror:   $MIRROR_MODE"
echo "═══════════════════════════════════"
echo ""

# ── Prerequisites ────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "❌ Docker is not installed. Install it first:"
  echo "   https://docs.docker.com/engine/install/"
  exit 1
fi

# ── Create directories ──────────────────────────────────────────────
echo "📁 Creating directories..."
mkdir -p "$REGISTRY_DATA_DIR"/{data,certs,auth,config}

# ── Generate TLS certificates (self-signed if not provided) ─────────
REGISTRY_TLS_CERT="${REGISTRY_TLS_CERT:-}"
REGISTRY_TLS_KEY="${REGISTRY_TLS_KEY:-}"

if [[ -z "$REGISTRY_TLS_CERT" ]]; then
  echo "🔐 Generating self-signed TLS certificate..."
  
  # Generate CA
  openssl genrsa -out "$REGISTRY_DATA_DIR/certs/ca.key" 4096 2>/dev/null
  openssl req -new -x509 -days 3650 -key "$REGISTRY_DATA_DIR/certs/ca.key" \
    -out "$REGISTRY_DATA_DIR/certs/ca.crt" \
    -subj "/CN=Docker Registry CA" 2>/dev/null
  
  # Generate server cert
  openssl genrsa -out "$REGISTRY_DATA_DIR/certs/server.key" 4096 2>/dev/null
  
  cat > "$REGISTRY_DATA_DIR/certs/san.cnf" <<SANEOF
[req]
distinguished_name = req_dn
req_extensions = v3_req
[req_dn]
CN = $REGISTRY_DOMAIN
[v3_req]
subjectAltName = DNS:$REGISTRY_DOMAIN,DNS:localhost,IP:127.0.0.1
SANEOF

  openssl req -new -key "$REGISTRY_DATA_DIR/certs/server.key" \
    -out "$REGISTRY_DATA_DIR/certs/server.csr" \
    -config "$REGISTRY_DATA_DIR/certs/san.cnf" \
    -subj "/CN=$REGISTRY_DOMAIN" 2>/dev/null

  openssl x509 -req -days 3650 \
    -in "$REGISTRY_DATA_DIR/certs/server.csr" \
    -CA "$REGISTRY_DATA_DIR/certs/ca.crt" \
    -CAkey "$REGISTRY_DATA_DIR/certs/ca.key" \
    -CAcreateserial \
    -out "$REGISTRY_DATA_DIR/certs/server.crt" \
    -extensions v3_req \
    -extfile "$REGISTRY_DATA_DIR/certs/san.cnf" 2>/dev/null

  REGISTRY_TLS_CERT="$REGISTRY_DATA_DIR/certs/server.crt"
  REGISTRY_TLS_KEY="$REGISTRY_DATA_DIR/certs/server.key"
  
  echo "   ✅ Self-signed cert generated (valid 10 years)"
  echo "   📄 CA cert: $REGISTRY_DATA_DIR/certs/ca.crt"
else
  echo "🔐 Using provided TLS certificate"
  # Copy provided certs to registry dir
  cp "$REGISTRY_TLS_CERT" "$REGISTRY_DATA_DIR/certs/server.crt"
  cp "$REGISTRY_TLS_KEY" "$REGISTRY_DATA_DIR/certs/server.key"
  REGISTRY_TLS_CERT="$REGISTRY_DATA_DIR/certs/server.crt"
  REGISTRY_TLS_KEY="$REGISTRY_DATA_DIR/certs/server.key"
fi

# ── Create authentication ───────────────────────────────────────────
echo "🔑 Setting up authentication..."

if command -v htpasswd &>/dev/null; then
  htpasswd -Bbn "$REGISTRY_USER" "$REGISTRY_PASS" > "$REGISTRY_DATA_DIR/auth/htpasswd"
else
  # Fallback: use Docker to generate htpasswd
  docker run --rm --entrypoint htpasswd httpd:2 -Bbn "$REGISTRY_USER" "$REGISTRY_PASS" \
    > "$REGISTRY_DATA_DIR/auth/htpasswd"
fi

echo "   ✅ Admin user created: $REGISTRY_USER"

# ── Generate registry config ────────────────────────────────────────
echo "📝 Generating configuration..."

cat > "$REGISTRY_DATA_DIR/config/config.yml" <<EOF
version: 0.1
log:
  level: info
  fields:
    service: registry

storage:
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
EOF

if [[ "$STORAGE_BACKEND" == "s3" ]]; then
  cat >> "$REGISTRY_DATA_DIR/config/config.yml" <<EOF
  s3:
    region: $REGISTRY_S3_REGION
    bucket: $REGISTRY_S3_BUCKET
    encrypt: true
    secure: true
    v4auth: true
EOF
else
  cat >> "$REGISTRY_DATA_DIR/config/config.yml" <<EOF
  filesystem:
    rootdirectory: /var/lib/registry
    maxthreads: 100
EOF
fi

cat >> "$REGISTRY_DATA_DIR/config/config.yml" <<EOF

http:
  addr: :5000
  tls:
    certificate: /certs/server.crt
    key: /certs/server.key
  headers:
    X-Content-Type-Options: [nosniff]

auth:
  htpasswd:
    realm: "Docker Registry"
    path: /auth/htpasswd

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF

if [[ "$MIRROR_MODE" == "true" ]]; then
  cat >> "$REGISTRY_DATA_DIR/config/config.yml" <<EOF

proxy:
  remoteurl: https://registry-1.docker.io
EOF
  echo "   ✅ Pull-through cache mode enabled"
fi

# ── Stop existing registry ──────────────────────────────────────────
if docker ps -q -f name="$REGISTRY_CONTAINER_NAME" 2>/dev/null | grep -q .; then
  echo "🔄 Stopping existing registry..."
  docker stop "$REGISTRY_CONTAINER_NAME" >/dev/null 2>&1
  docker rm "$REGISTRY_CONTAINER_NAME" >/dev/null 2>&1
fi

# ── Deploy registry container ───────────────────────────────────────
echo "🚀 Deploying registry..."

DOCKER_ARGS=(
  --name "$REGISTRY_CONTAINER_NAME"
  --restart always
  -p "$REGISTRY_PORT:5000"
  -v "$REGISTRY_DATA_DIR/data:/var/lib/registry"
  -v "$REGISTRY_DATA_DIR/certs:/certs:ro"
  -v "$REGISTRY_DATA_DIR/auth:/auth:ro"
  -v "$REGISTRY_DATA_DIR/config/config.yml:/etc/docker/registry/config.yml:ro"
)

if [[ "$STORAGE_BACKEND" == "s3" ]]; then
  DOCKER_ARGS+=(
    -e "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}"
    -e "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}"
  )
fi

docker run -d "${DOCKER_ARGS[@]}" registry:2 >/dev/null

# ── Wait for registry to be ready ───────────────────────────────────
echo "⏳ Waiting for registry..."
for i in {1..30}; do
  if curl -sk "https://localhost:$REGISTRY_PORT/v2/" -o /dev/null 2>/dev/null; then
    break
  fi
  sleep 1
done

# ── Verify ──────────────────────────────────────────────────────────
if curl -sk -u "$REGISTRY_USER:$REGISTRY_PASS" "https://localhost:$REGISTRY_PORT/v2/_catalog" >/dev/null 2>&1; then
  echo ""
  echo "════════════════════════════════════════════"
  echo "✅ Registry is running!"
  echo ""
  echo "  URL:      https://$REGISTRY_DOMAIN:$REGISTRY_PORT"
  echo "  Username: $REGISTRY_USER"
  echo "  Password: $REGISTRY_PASS"
  echo "  Data:     $REGISTRY_DATA_DIR"
  echo ""
  echo "  Quick test:"
  echo "    docker login $REGISTRY_DOMAIN:$REGISTRY_PORT"
  echo "    docker tag alpine $REGISTRY_DOMAIN:$REGISTRY_PORT/alpine"
  echo "    docker push $REGISTRY_DOMAIN:$REGISTRY_PORT/alpine"
  echo ""
  if [[ -f "$REGISTRY_DATA_DIR/certs/ca.crt" ]]; then
    echo "  ⚠️  Self-signed cert: trust the CA on Docker clients:"
    echo "    sudo mkdir -p /etc/docker/certs.d/$REGISTRY_DOMAIN:$REGISTRY_PORT"
    echo "    sudo cp $REGISTRY_DATA_DIR/certs/ca.crt /etc/docker/certs.d/$REGISTRY_DOMAIN:$REGISTRY_PORT/ca.crt"
    echo "    sudo systemctl restart docker"
  fi
  echo "════════════════════════════════════════════"
  
  # Save credentials for manage.sh
  cat > "$REGISTRY_DATA_DIR/.env" <<EOF
REGISTRY_PORT=$REGISTRY_PORT
REGISTRY_DOMAIN=$REGISTRY_DOMAIN
REGISTRY_USER=$REGISTRY_USER
REGISTRY_PASS=$REGISTRY_PASS
REGISTRY_DATA_DIR=$REGISTRY_DATA_DIR
REGISTRY_CONTAINER_NAME=$REGISTRY_CONTAINER_NAME
EOF

else
  echo "❌ Registry failed to start. Check logs:"
  echo "   docker logs $REGISTRY_CONTAINER_NAME"
  exit 1
fi
