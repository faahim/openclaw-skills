#!/bin/bash
# Download and configure Vale style guides
set -euo pipefail

STYLES_DIR="${VALE_STYLES_DIR:-$HOME/.local/share/vale/styles}"
CONFIG_FILE="${VALE_CONFIG:-$HOME/.vale.ini}"

mkdir -p "$STYLES_DIR"

echo "📚 Setting up Vale style guides..."

# Style packages to install (name → GitHub release URL pattern)
declare -A STYLES=(
  ["Google"]="https://github.com/errata-ai/Google/releases/latest/download/Google.zip"
  ["Microsoft"]="https://github.com/errata-ai/Microsoft/releases/latest/download/Microsoft.zip"
  ["write-good"]="https://github.com/errata-ai/write-good/releases/latest/download/write-good.zip"
  ["proselint"]="https://github.com/errata-ai/proselint/releases/latest/download/proselint.zip"
  ["Joblint"]="https://github.com/errata-ai/Joblint/releases/latest/download/Joblint.zip"
)

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

for name in "${!STYLES[@]}"; do
  url="${STYLES[$name]}"
  if [[ -d "$STYLES_DIR/$name" ]]; then
    echo "  ✅ $name (already installed)"
    continue
  fi
  echo "  📥 Downloading $name..."
  curl -sL "$url" -o "$TMPDIR/$name.zip" 2>/dev/null
  if [[ -f "$TMPDIR/$name.zip" ]]; then
    unzip -qo "$TMPDIR/$name.zip" -d "$STYLES_DIR/" 2>/dev/null
    echo "  ✅ $name installed"
  else
    echo "  ⚠️  Failed to download $name (skipping)"
  fi
done

# Create global config if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "📝 Creating global config at $CONFIG_FILE..."
  cat > "$CONFIG_FILE" << 'EOF'
# Vale global configuration
# Override per-project with .vale.ini in project root

StylesPath = ${HOME}/.local/share/vale/styles

MinAlertLevel = suggestion

# Markdown files — full style checking
[*.md]
BasedOnStyles = Google, write-good, proselint

# Plain text — basic checks only
[*.txt]
BasedOnStyles = write-good, proselint

# HTML files
[*.html]
BasedOnStyles = Google, write-good

# reStructuredText
[*.rst]
BasedOnStyles = Google, write-good
EOF
  # Expand $HOME in config
  sed -i "s|\${HOME}|$HOME|g" "$CONFIG_FILE"
  echo "  ✅ Config created"
else
  echo "📝 Config already exists at $CONFIG_FILE"
fi

echo ""
echo "🎉 Vale styles ready! Installed to: $STYLES_DIR"
echo "   Config: $CONFIG_FILE"
echo ""
echo "   Try: vale README.md"
echo "   Or:  vale docs/"
