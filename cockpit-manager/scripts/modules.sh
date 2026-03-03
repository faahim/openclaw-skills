#!/bin/bash
# Cockpit Web Console — Module Manager

set -euo pipefail

ACTION="${1:-list}"
MODULE="${2:-}"

# Detect package manager
detect_pkg_mgr() {
  if command -v apt-get &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v yum &>/dev/null; then echo "yum"
  elif command -v pacman &>/dev/null; then echo "pacman"
  elif command -v zypper &>/dev/null; then echo "zypper"
  else echo "unknown"; fi
}

PKG_MGR=$(detect_pkg_mgr)

# Known modules with descriptions
declare -A MODULE_DESC=(
  ["cockpit-machines"]="Virtual machine management (libvirt/KVM)"
  ["cockpit-podman"]="Podman container management"
  ["cockpit-storaged"]="Storage & disk management"
  ["cockpit-networkmanager"]="Network configuration"
  ["cockpit-packagekit"]="Software updates"
  ["cockpit-pcp"]="Performance Co-Pilot metrics (detailed graphs)"
  ["cockpit-session-recording"]="Session recording & playback"
  ["cockpit-sosreport"]="System diagnostic reports"
  ["cockpit-kdump"]="Kernel crash dump configuration"
  ["cockpit-selinux"]="SELinux policy management"
)

ALL_MODULES="cockpit-machines cockpit-podman cockpit-storaged cockpit-networkmanager cockpit-packagekit cockpit-pcp"

is_installed() {
  local pkg=$1
  case "$PKG_MGR" in
    apt) dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' ;;
    dnf|yum) rpm -q "$pkg" &>/dev/null ;;
    pacman) pacman -Qs "^${pkg}$" &>/dev/null ;;
    zypper) rpm -q "$pkg" &>/dev/null ;;
    *) return 1 ;;
  esac
}

install_pkg() {
  local pkg=$1
  case "$PKG_MGR" in
    apt) sudo apt-get install -y "$pkg" ;;
    dnf) sudo dnf install -y "$pkg" ;;
    yum) sudo yum install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    zypper) sudo zypper install -y "$pkg" ;;
    *) echo "❌ Unknown package manager"; exit 1 ;;
  esac
}

remove_pkg() {
  local pkg=$1
  case "$PKG_MGR" in
    apt) sudo apt-get remove -y "$pkg" ;;
    dnf) sudo dnf remove -y "$pkg" ;;
    yum) sudo yum remove -y "$pkg" ;;
    pacman) sudo pacman -R --noconfirm "$pkg" ;;
    zypper) sudo zypper remove -y "$pkg" ;;
    *) echo "❌ Unknown package manager"; exit 1 ;;
  esac
}

case "$ACTION" in
  list)
    echo "Cockpit Modules"
    echo "════════════════"
    for mod in "${!MODULE_DESC[@]}"; do
      if is_installed "$mod"; then
        STATUS="✅ Installed"
      else
        STATUS="❌ Not installed"
      fi
      printf "  %-30s %-18s %s\n" "$mod" "$STATUS" "${MODULE_DESC[$mod]}"
    done | sort
    ;;

  install)
    if [ -z "$MODULE" ]; then
      echo "Usage: modules.sh install <module|all>"
      exit 1
    fi
    
    if [ "$MODULE" = "all" ]; then
      echo "📦 Installing all modules..."
      for mod in $ALL_MODULES; do
        if is_installed "$mod"; then
          echo "  ✅ $mod (already installed)"
        else
          echo "  📦 Installing $mod..."
          install_pkg "$mod" 2>/dev/null && echo "  ✅ $mod installed" || echo "  ⚠️ $mod unavailable"
        fi
      done
    else
      PKG="cockpit-${MODULE}"
      # If user passed full package name
      [[ "$MODULE" == cockpit-* ]] && PKG="$MODULE"
      
      if is_installed "$PKG"; then
        echo "✅ $PKG is already installed"
      else
        echo "📦 Installing $PKG..."
        install_pkg "$PKG"
        echo "✅ $PKG installed"
      fi
    fi
    
    echo ""
    echo "🔄 Restart Cockpit to load new modules:"
    echo "   sudo systemctl restart cockpit.socket"
    ;;

  remove)
    if [ -z "$MODULE" ]; then
      echo "Usage: modules.sh remove <module>"
      exit 1
    fi
    
    PKG="cockpit-${MODULE}"
    [[ "$MODULE" == cockpit-* ]] && PKG="$MODULE"
    
    if ! is_installed "$PKG"; then
      echo "❌ $PKG is not installed"
    else
      echo "🗑️ Removing $PKG..."
      remove_pkg "$PKG"
      echo "✅ $PKG removed"
    fi
    ;;

  *)
    echo "Usage: modules.sh <list|install|remove> [module|all]"
    echo ""
    echo "Examples:"
    echo "  modules.sh list              # List all modules"
    echo "  modules.sh install machines  # Install VM management"
    echo "  modules.sh install all       # Install all modules"
    echo "  modules.sh remove pcp        # Remove PCP metrics"
    exit 1
    ;;
esac
