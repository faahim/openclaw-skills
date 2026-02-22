#!/bin/bash
# Install AWS CLI v2 if not present
set -euo pipefail

if command -v aws &>/dev/null; then
  echo "✅ AWS CLI already installed: $(aws --version)"
  exit 0
fi

echo "Installing AWS CLI v2..."

ARCH=$(uname -m)
OS=$(uname -s)

if [[ "$OS" == "Linux" ]]; then
  if [[ "$ARCH" == "x86_64" ]]; then
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  elif [[ "$ARCH" == "aarch64" ]]; then
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip
  else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
  fi
  cd /tmp && unzip -qo awscliv2.zip
  sudo ./aws/install || ./aws/install --install-dir "$HOME/.local/aws-cli" --bin-dir "$HOME/.local/bin"
  rm -rf /tmp/awscliv2.zip /tmp/aws
elif [[ "$OS" == "Darwin" ]]; then
  curl -sL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o /tmp/AWSCLIV2.pkg
  sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
  rm /tmp/AWSCLIV2.pkg
else
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

echo "✅ AWS CLI installed: $(aws --version)"

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "⚠️  jq not found. Installing..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq
  elif command -v brew &>/dev/null; then
    brew install jq
  elif command -v yum &>/dev/null; then
    sudo yum install -y jq
  else
    echo "❌ Please install jq manually"
  fi
fi

echo ""
echo "Next: Configure credentials with 'aws configure' or set AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY"
