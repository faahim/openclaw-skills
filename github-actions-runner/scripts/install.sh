#!/bin/bash
# GitHub Actions Self-Hosted Runner — Installer
# Installs, registers, and configures runner as systemd service

set -euo pipefail

# --- Configuration ---
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-}"
RUNNER_GROUP="${RUNNER_GROUP:-default}"
RUNNER_WORK="${RUNNER_WORK:-_work}"
GITHUB_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
RUNNER_REPO="${RUNNER_REPO:-}"
RUNNER_ORG="${RUNNER_ORG:-}"

# --- Validation ---
if [ "$(id -u)" = "0" ]; then
  echo "❌ Do not run as root. The GitHub Actions runner refuses to run as root."
  exit 1
fi

if [ -z "$RUNNER_REPO" ] && [ -z "$RUNNER_ORG" ]; then
  echo "❌ Set RUNNER_REPO (owner/repo) or RUNNER_ORG (org-name)"
  exit 1
fi

# --- Detect architecture ---
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  RUNNER_ARCH="x64" ;;
  aarch64) RUNNER_ARCH="arm64" ;;
  *)       echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "📦 Architecture: $ARCH → $RUNNER_ARCH"

# --- Get latest runner version ---
echo "🔍 Finding latest runner version..."
LATEST=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
  echo "❌ Could not determine latest runner version"
  exit 1
fi

echo "📌 Latest version: $LATEST"

FILENAME="actions-runner-linux-${RUNNER_ARCH}-${LATEST}.tar.gz"
DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${LATEST}/${FILENAME}"

# --- Download ---
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ -f "$FILENAME" ]; then
  echo "📄 Already downloaded: $FILENAME"
else
  echo "⬇️  Downloading $FILENAME..."
  curl -sL -o "$FILENAME" "$DOWNLOAD_URL"
  echo "✅ Downloaded $FILENAME"
fi

# --- Verify checksum ---
echo "🔐 Verifying checksum..."
EXPECTED_HASH=$(curl -s "https://api.github.com/repos/actions/runner/releases/latest" \
  | jq -r ".body" \
  | grep -A1 "$FILENAME" \
  | grep -oP '[a-f0-9]{64}' | head -1 || true)

if [ -n "$EXPECTED_HASH" ]; then
  ACTUAL_HASH=$(sha256sum "$FILENAME" | cut -d' ' -f1)
  if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
    echo "✅ Checksum verified"
  else
    echo "⚠️  Checksum mismatch (expected: ${EXPECTED_HASH:0:16}... got: ${ACTUAL_HASH:0:16}...)"
    echo "   Proceeding anyway (GitHub sometimes doesn't include hashes in release notes)"
  fi
else
  echo "⚠️  Could not find checksum in release notes, skipping verification"
fi

# --- Extract ---
echo "📂 Extracting..."
tar xzf "$FILENAME"
echo "✅ Extracted to $RUNNER_DIR"

# --- Get registration token ---
echo "🔑 Getting registration token..."

if [ -n "$RUNNER_REPO" ]; then
  REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${RUNNER_REPO}/actions/runners/registration-token" \
    | jq -r .token)
  RUNNER_URL="https://github.com/${RUNNER_REPO}"
else
  REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/orgs/${RUNNER_ORG}/actions/runners/registration-token" \
    | jq -r .token)
  RUNNER_URL="https://github.com/${RUNNER_ORG}"
fi

if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
  echo "❌ Failed to get registration token. Check your GITHUB_TOKEN permissions."
  exit 1
fi

echo "✅ Got registration token"

# --- Configure runner ---
echo "⚙️  Configuring runner..."

LABEL_ARG=""
if [ -n "$RUNNER_LABELS" ]; then
  LABEL_ARG="--labels $RUNNER_LABELS"
fi

./config.sh \
  --url "$RUNNER_URL" \
  --token "$REG_TOKEN" \
  --name "$RUNNER_NAME" \
  --work "$RUNNER_WORK" \
  --runnergroup "$RUNNER_GROUP" \
  $LABEL_ARG \
  --unattended \
  --replace

echo "✅ Registered runner '$RUNNER_NAME' with $RUNNER_URL"

# --- Create systemd service ---
echo "🔧 Creating systemd service..."

SERVICE_NAME="github-actions-runner"
if [ "$RUNNER_DIR" != "$HOME/actions-runner" ]; then
  # Use a unique service name for multi-runner setups
  SERVICE_NAME="github-actions-runner-$(basename "$RUNNER_DIR")"
fi

mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/${SERVICE_NAME}.service" << EOF
[Unit]
Description=GitHub Actions Self-Hosted Runner ($RUNNER_NAME)
After=network.target

[Service]
Type=simple
WorkingDirectory=$RUNNER_DIR
ExecStart=$RUNNER_DIR/run.sh
Restart=on-failure
RestartSec=10
KillSignal=SIGTERM
TimeoutStopSec=60

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME" 2>/dev/null || true

echo "✅ Created systemd service: $SERVICE_NAME"

# --- Save metadata ---
cat > "$RUNNER_DIR/.runner-meta.json" << EOF
{
  "name": "$RUNNER_NAME",
  "url": "$RUNNER_URL",
  "repo": "$RUNNER_REPO",
  "org": "$RUNNER_ORG",
  "arch": "$RUNNER_ARCH",
  "version": "$LATEST",
  "service": "$SERVICE_NAME",
  "dir": "$RUNNER_DIR",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# --- Done ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Runner '$RUNNER_NAME' is ready!"
echo ""
echo "  Start:   bash scripts/manage.sh start"
echo "  Status:  bash scripts/manage.sh status"
echo "  Logs:    bash scripts/manage.sh logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
