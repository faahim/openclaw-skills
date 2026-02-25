#!/bin/bash
# Ansible Playbook Runner — Installer
set -e

echo "🔧 Ansible Playbook Runner — Installation"
echo "==========================================="

# Check Python 3
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1)
  echo "✅ $PY_VER found"
else
  echo "❌ Python 3 not found. Installing..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip
  elif command -v yum &>/dev/null; then
    sudo yum install -y python3 python3-pip
  elif command -v brew &>/dev/null; then
    brew install python3
  else
    echo "❌ Cannot auto-install Python 3. Please install manually."
    exit 1
  fi
fi

# Check pip3
if ! command -v pip3 &>/dev/null; then
  echo "📦 Installing pip3..."
  python3 -m ensurepip --upgrade 2>/dev/null || {
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3
  }
fi

# Install Ansible
echo "📦 Installing Ansible..."
pip3 install --user --break-system-packages ansible 2>&1 | tail -3

# Add to PATH if needed
LOCAL_BIN="$HOME/.local/bin"
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
  export PATH="$LOCAL_BIN:$PATH"
  echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> ~/.bashrc
  echo "ℹ️  Added $LOCAL_BIN to PATH"
fi

# Verify installation
if command -v ansible &>/dev/null; then
  ANSIBLE_VER=$(ansible --version 2>&1 | head -1)
  echo "✅ $ANSIBLE_VER installed successfully"
else
  echo "❌ Ansible installation failed. Try: pip3 install ansible"
  exit 1
fi

# Install sshpass for password-based auth (optional)
if ! command -v sshpass &>/dev/null; then
  echo "📦 Installing sshpass (optional, for password auth)..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y sshpass 2>/dev/null || echo "⚠️  sshpass install failed (optional)"
  elif command -v yum &>/dev/null; then
    sudo yum install -y sshpass 2>/dev/null || echo "⚠️  sshpass install failed (optional)"
  fi
fi

# Create default ansible.cfg if it doesn't exist
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CFG_FILE="$SCRIPT_DIR/ansible.cfg"

if [ ! -f "$CFG_FILE" ]; then
  cat > "$CFG_FILE" << 'EOF'
[defaults]
inventory = ./inventory.ini
remote_user = deploy
host_key_checking = False
timeout = 30
forks = 10
retry_files_enabled = False
stdout_callback = yaml

[privilege_escalation]
become = True
become_method = sudo
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
EOF
  echo "✅ Created ansible.cfg at $CFG_FILE"
fi

# Create empty inventory if it doesn't exist
INV_FILE="$SCRIPT_DIR/inventory.ini"
if [ ! -f "$INV_FILE" ]; then
  cat > "$INV_FILE" << 'EOF'
# Ansible Inventory
# Add hosts with: bash scripts/inventory.sh add <name> <ip> --user <user>

[all]
EOF
  echo "✅ Created inventory.ini at $INV_FILE"
fi

echo ""
echo "🎉 Ansible is ready!"
echo "   Next: bash scripts/inventory.sh add myserver 10.0.0.1 --user root"
echo "   Then: bash scripts/run.sh ping"
