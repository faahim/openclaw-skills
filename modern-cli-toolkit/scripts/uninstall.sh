#!/bin/bash
# Modern CLI Toolkit — Uninstall
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ONLY="${1:-}"

echo -e "${BLUE}Modern CLI Toolkit — Uninstaller${NC}"
echo ""

# Remove shell config
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [[ -f "$rc" ]] && grep -q "Modern CLI Toolkit" "$rc"; then
    sed -i '/# >>> Modern CLI Toolkit >>>/,/# <<< Modern CLI Toolkit <<</d' "$rc"
    echo -e "${GREEN}✅ Removed aliases from $rc${NC}"
  fi
done

# Remove ripgrep config
if [[ -f "$HOME/.ripgreprc" ]]; then
  rm "$HOME/.ripgreprc"
  echo -e "${GREEN}✅ Removed ~/.ripgreprc${NC}"
fi

# Remove git delta config
if git config --global --get core.pager 2>/dev/null | grep -q delta; then
  git config --global --unset core.pager 2>/dev/null || true
  git config --global --unset interactive.diffFilter 2>/dev/null || true
  git config --global --remove-section delta 2>/dev/null || true
  echo -e "${GREEN}✅ Removed delta from git config${NC}"
fi

echo ""
echo -e "${BLUE}Aliases and configs removed. Tools themselves remain installed.${NC}"
echo -e "${BLUE}To remove tools, use your package manager (brew uninstall / apt remove).${NC}"
