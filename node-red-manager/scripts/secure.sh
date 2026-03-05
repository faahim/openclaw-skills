#!/bin/bash
# Node-RED Manager — Security Setup
set -euo pipefail

NR_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
SETTINGS="$NR_DIR/settings.js"
USERNAME=""
PASSWORD=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --user) USERNAME="$2"; shift 2 ;;
    --pass) PASSWORD="$2"; shift 2 ;;
    *) echo "Usage: bash scripts/secure.sh --user <username> --pass <password>"; exit 1 ;;
  esac
done

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: bash scripts/secure.sh --user <username> --pass <password>"
  exit 1
fi

echo "🔐 Securing Node-RED..."

# Generate bcrypt hash
if command -v node &>/dev/null; then
  HASH=$(node -e "
    const bcrypt = require('bcryptjs');
    console.log(bcrypt.hashSync('$PASSWORD', 8));
  " 2>/dev/null || node -e "
    try {
      const bcrypt = require('bcryptjs');
      console.log(bcrypt.hashSync('$PASSWORD', 8));
    } catch(e) {
      // Install bcryptjs if needed
      require('child_process').execSync('npm install -g bcryptjs', {stdio:'pipe'});
      const bcrypt = require('bcryptjs');
      console.log(bcrypt.hashSync('$PASSWORD', 8));
    }
  " 2>/dev/null)

  if [ -z "$HASH" ]; then
    # Try installing bcryptjs in user dir
    echo "📦 Installing bcryptjs..."
    cd "$NR_DIR" && npm install bcryptjs 2>/dev/null
    HASH=$(node -e "const bcrypt = require('$NR_DIR/node_modules/bcryptjs'); console.log(bcrypt.hashSync('$PASSWORD', 8));")
  fi
else
  echo "❌ Node.js required for password hashing"
  exit 1
fi

if [ -z "$HASH" ]; then
  echo "❌ Failed to generate password hash"
  exit 1
fi

# Create or update settings.js
if [ ! -f "$SETTINGS" ]; then
  # Start Node-RED briefly to generate default settings
  echo "📝 Generating default settings..."
  cat > "$SETTINGS" <<EOF
module.exports = {
    uiPort: process.env.PORT || ${NODE_RED_PORT:-1880},
    adminAuth: {
        type: "credentials",
        users: [{
            username: "$USERNAME",
            password: "$HASH",
            permissions: "*"
        }]
    },
    functionGlobalContext: {},
    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    }
};
EOF
  echo "✅ Settings created with authentication"
else
  # Check if adminAuth already exists
  if grep -q "adminAuth" "$SETTINGS"; then
    echo "⚠️  adminAuth already configured in settings.js"
    echo "   Updating credentials..."
    # Create a temp node script to update settings
    node -e "
      const fs = require('fs');
      let content = fs.readFileSync('$SETTINGS', 'utf8');
      // Replace the adminAuth block
      const authBlock = \`adminAuth: {
        type: \"credentials\",
        users: [{
            username: \"$USERNAME\",
            password: \"$HASH\",
            permissions: \"*\"
        }]
    }\`;
      content = content.replace(/adminAuth\s*:\s*\{[\s\S]*?\}\s*\]\s*\}/m, authBlock);
      fs.writeFileSync('$SETTINGS', content);
    " 2>/dev/null && echo "✅ Credentials updated" || echo "⚠️  Auto-update failed. Edit $SETTINGS manually."
  else
    # Append adminAuth to settings
    # Insert before the closing module.exports
    node -e "
      const fs = require('fs');
      let content = fs.readFileSync('$SETTINGS', 'utf8');
      const authConfig = \",\\n    adminAuth: {\\n        type: \\\"credentials\\\",\\n        users: [{\\n            username: \\\"$USERNAME\\\",\\n            password: \\\"$HASH\\\",\\n            permissions: \\\"*\\\"\\n        }]\\n    }\";
      // Insert before last closing brace
      const lastBrace = content.lastIndexOf('}');
      if (lastBrace > -1) {
        content = content.slice(0, lastBrace) + authConfig + '\\n' + content.slice(lastBrace);
      }
      fs.writeFileSync('$SETTINGS', content);
    " 2>/dev/null
    echo "✅ Authentication added to settings.js"
  fi
fi

echo ""
echo "🔐 Auth configured:"
echo "   Username: $USERNAME"
echo "   Password: (hidden)"
echo ""
echo "Restart Node-RED to apply: bash scripts/manage.sh restart"
