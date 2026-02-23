#!/bin/bash
# Auto-Update Manager — Configure and manage automatic security updates
# For Debian/Ubuntu systems
set -euo pipefail

VERSION="1.0.0"
LOG_PREFIX="[auto-update]"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${LOG_PREFIX} $1"; }
log_ok() { echo -e "${LOG_PREFIX} ${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${LOG_PREFIX} ${YELLOW}⚠️  $1${NC}"; }
log_err() { echo -e "${LOG_PREFIX} ${RED}❌ $1${NC}"; }
log_info() { echo -e "${LOG_PREFIX} ${BLUE}ℹ️  $1${NC}"; }

# Check we're on Debian/Ubuntu
check_distro() {
    if [ ! -f /etc/os-release ]; then
        log_err "Cannot detect OS. This tool supports Debian/Ubuntu only."
        exit 1
    fi
    . /etc/os-release
    case "$ID" in
        ubuntu|debian|linuxmint) ;;
        *)
            log_err "Unsupported distro: $ID. This tool supports Debian/Ubuntu only."
            exit 1
            ;;
    esac
}

# Check if running as root (for write operations)
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_err "This command requires root. Run with sudo."
        exit 1
    fi
}

cmd_status() {
    local json_mode=false
    [[ "${1:-}" == "--json" ]] && json_mode=true

    check_distro
    . /etc/os-release

    local ua_installed=false
    local ua_enabled=false
    local pending_security=0
    local pending_regular=0
    local reboot_required=false
    local last_update="never"
    local last_packages=0
    local auto_reboot=false
    local blacklisted=""

    # Check if unattended-upgrades is installed
    if dpkg -l unattended-upgrades 2>/dev/null | grep -q "^ii"; then
        ua_installed=true
        # Check if enabled
        if systemctl is-enabled unattended-upgrades &>/dev/null; then
            ua_enabled=true
        fi
    fi

    # Count pending security updates
    if command -v apt-get &>/dev/null; then
        pending_security=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst.*security" || true)
        pending_security=${pending_security:-0}
        pending_regular=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || true)
        pending_regular=${pending_regular:-0}
        pending_regular=$((pending_regular - pending_security))
    fi

    # Check reboot required
    [ -f /var/run/reboot-required ] && reboot_required=true

    # Last update time
    if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
        last_update=$(grep "Packages that were upgraded" /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null | tail -1 | head -c 19 || echo "never")
        last_packages=$(grep "Packages that were upgraded" /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null | tail -1 | grep -oP '\d+ package' | grep -oP '\d+' || echo 0)
    fi

    # Check auto-reboot config
    if grep -q "Unattended-Upgrade::Automatic-Reboot \"true\"" /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null; then
        auto_reboot=true
    fi

    # Get blacklist
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        blacklisted=$(grep -A100 "Unattended-Upgrade::Package-Blacklist" /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null | grep '^\s*"' | tr -d '";' | tr -s ' ' | xargs || echo "")
    fi

    if $json_mode; then
        cat <<EOF
{
  "unattended_upgrades": $ua_enabled,
  "pending_security": $pending_security,
  "pending_regular": $pending_regular,
  "reboot_required": $reboot_required,
  "last_update": "$last_update",
  "last_update_packages": $last_packages,
  "auto_reboot": $auto_reboot,
  "blacklisted": [$(echo "$blacklisted" | sed 's/[^ ]*/\"&\"/g' | tr ' ' ',' | sed 's/^"",*//')]
}
EOF
    else
        log "System: $PRETTY_NAME"
        if $ua_installed; then
            if $ua_enabled; then
                log_ok "Unattended-upgrades: INSTALLED & ENABLED"
            else
                log_warn "Unattended-upgrades: installed but DISABLED"
            fi
        else
            log_err "Unattended-upgrades: NOT installed"
        fi
        log "Pending security updates: $pending_security"
        log "Pending regular updates: $pending_regular"
        log "Last auto-update: $last_update"
        if $reboot_required; then
            log_warn "Reboot required: YES"
        else
            log_ok "Reboot required: NO"
        fi
        if $auto_reboot; then
            log_ok "Auto-reboot: ENABLED"
        else
            log_info "Auto-reboot: disabled"
        fi
        if [ -n "$blacklisted" ]; then
            log "Blacklisted packages: $blacklisted"
        fi
    fi
}

cmd_setup() {
    check_root
    check_distro

    local auto_reboot=false
    local reboot_time="04:00"
    local email=""
    local security_only=true
    local blacklist_pkgs=""
    local no_reboot=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-reboot) auto_reboot=true; shift ;;
            --no-reboot) no_reboot=true; shift ;;
            --reboot-time) reboot_time="$2"; shift 2 ;;
            --email) email="$2"; shift 2 ;;
            --security-only) security_only=true; shift ;;
            --all-updates) security_only=false; shift ;;
            --blacklist) blacklist_pkgs="$2"; shift 2 ;;
            *) log_err "Unknown option: $1"; exit 1 ;;
        esac
    done

    if $no_reboot; then auto_reboot=false; fi

    log_info "Installing unattended-upgrades..."
    apt-get update -qq
    apt-get install -y -qq unattended-upgrades apt-listchanges > /dev/null 2>&1
    log_ok "unattended-upgrades installed"

    # Enable auto-updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF
    log_ok "Auto-update schedule configured (daily)"

    # Configure unattended-upgrades
    . /etc/os-release
    local origins=""
    if $security_only; then
        origins="        \"\${distro_id}:\${distro_codename}-security\";"
    else
        origins="        \"\${distro_id}:\${distro_codename}-security\";
        \"\${distro_id}:\${distro_codename}-updates\";"
    fi

    local reboot_config="Unattended-Upgrade::Automatic-Reboot \"false\";"
    if $auto_reboot; then
        reboot_config="Unattended-Upgrade::Automatic-Reboot \"true\";
Unattended-Upgrade::Automatic-Reboot-Time \"${reboot_time}\";"
    fi

    local email_config=""
    if [ -n "$email" ]; then
        email_config="Unattended-Upgrade::Mail \"${email}\";
Unattended-Upgrade::MailReport \"on-change\";"
    fi

    local blacklist_config=""
    if [ -n "$blacklist_pkgs" ]; then
        blacklist_config="Unattended-Upgrade::Package-Blacklist {\n"
        for pkg in $blacklist_pkgs; do
            blacklist_config+="        \"${pkg}\";\n"
        done
        blacklist_config+="};"
    else
        blacklist_config="Unattended-Upgrade::Package-Blacklist {\n};"
    fi

    cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
${origins}
};

$(echo -e "$blacklist_config")

${reboot_config}

${email_config}

Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::SyslogEnable "true";
EOF

    # Enable the service
    systemctl enable --now unattended-upgrades
    log_ok "Unattended-upgrades service enabled"

    if $security_only; then
        log_ok "Mode: security updates only"
    else
        log_ok "Mode: security + regular updates"
    fi

    if $auto_reboot; then
        log_ok "Auto-reboot: enabled at ${reboot_time}"
    else
        log_info "Auto-reboot: disabled"
    fi

    if [ -n "$email" ]; then
        log_ok "Email notifications: ${email}"
    fi

    if [ -n "$blacklist_pkgs" ]; then
        log_ok "Blacklisted: ${blacklist_pkgs}"
    fi

    log_ok "Setup complete! Security updates will be applied automatically."
}

cmd_pending() {
    check_distro

    log "Checking pending updates..."
    echo ""

    local sec_updates
    sec_updates=$(apt-get -s upgrade 2>/dev/null | grep "^Inst.*security" || true)

    if [ -n "$sec_updates" ]; then
        log_warn "Pending security updates:"
        echo "$sec_updates" | while read -r line; do
            local pkg ver_from ver_to
            pkg=$(echo "$line" | awk '{print $2}')
            ver_from=$(dpkg -l "$pkg" 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "?")
            ver_to=$(echo "$line" | grep -oP '\[.*?\]' | tr -d '[]' || echo "?")
            echo "  - ${pkg} ${ver_from} -> ${ver_to} (security)"
        done
    else
        log_ok "No pending security updates"
    fi

    echo ""
    local reg_updates
    reg_updates=$(apt-get -s upgrade 2>/dev/null | grep "^Inst" | grep -v "security" || true)
    local reg_count
    reg_count=$(echo "$reg_updates" | grep -c "^Inst" 2>/dev/null || echo 0)
    log "Pending regular updates: ${reg_count} packages"

    echo ""
    if [ -f /var/run/reboot-required ]; then
        log_warn "Reboot required: YES"
        if [ -f /var/run/reboot-required.pkgs ]; then
            log "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs | sed 's/^/  - /'
        fi
    else
        log_ok "Reboot required: NO"
    fi
}

cmd_apply_now() {
    check_root
    check_distro

    log_info "Applying pending security updates now..."
    unattended-upgrade -v
    log_ok "Done. Check /var/log/unattended-upgrades/ for details."
}

cmd_history() {
    local days=30
    while [[ $# -gt 0 ]]; do
        case $1 in
            --days) days="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    log "Updates in last ${days} days:"
    echo ""

    local logfile="/var/log/unattended-upgrades/unattended-upgrades.log"
    if [ ! -f "$logfile" ]; then
        log_warn "No update log found at ${logfile}"
        log_info "Try: /var/log/apt/history.log instead"

        if [ -f /var/log/apt/history.log ]; then
            local cutoff
            cutoff=$(date -d "${days} days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)
            grep -A5 "Start-Date: " /var/log/apt/history.log | grep -E "(Start-Date|Upgrade|Install)" | tail -40
        fi
        return
    fi

    local cutoff
    cutoff=$(date -d "${days} days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null || echo "1970-01-01")

    grep "Packages that were upgraded" "$logfile" 2>/dev/null | while read -r line; do
        local date_str="${line:0:10}"
        if [[ "$date_str" > "$cutoff" || "$date_str" == "$cutoff" ]]; then
            echo "$line"
        fi
    done

    echo ""
    local total
    total=$(grep -c "Packages that were upgraded" "$logfile" 2>/dev/null || echo 0)
    local failures
    failures=$(grep -c "WARNING\|ERROR" "$logfile" 2>/dev/null || echo 0)
    log "Total recorded upgrades: ${total}"
    log "Warnings/errors: ${failures}"
}

cmd_disable() {
    check_root

    log_info "Disabling unattended-upgrades..."

    cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "7";
EOF

    systemctl stop unattended-upgrades 2>/dev/null || true
    systemctl disable unattended-upgrades 2>/dev/null || true

    log_ok "Auto-updates disabled. Manual updates still work via apt."
}

cmd_show_config() {
    log "Current unattended-upgrades configuration:"
    echo ""

    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        cat /etc/apt/apt.conf.d/50unattended-upgrades
    else
        log_warn "No config found at /etc/apt/apt.conf.d/50unattended-upgrades"
    fi

    echo ""
    log "Auto-update schedule:"
    if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        cat /etc/apt/apt.conf.d/20auto-upgrades
    else
        log_warn "No schedule config found"
    fi
}

cmd_blacklist() {
    local action="${1:-list}"
    shift || true

    local config="/etc/apt/apt.conf.d/50unattended-upgrades"

    case "$action" in
        list)
            if [ -f "$config" ]; then
                log "Blacklisted packages:"
                grep -A100 "Package-Blacklist" "$config" | grep '^\s*"' | tr -d '";' | sed 's/^/  - /' || log_info "None"
            else
                log_warn "No config file found"
            fi
            ;;
        add)
            check_root
            local pkgs="$*"
            if [ -z "$pkgs" ]; then
                log_err "Usage: auto-update.sh blacklist add \"pkg1 pkg2\""
                exit 1
            fi
            for pkg in $pkgs; do
                if ! grep -q "\"${pkg}\"" "$config" 2>/dev/null; then
                    sed -i "/Package-Blacklist {/a\\        \"${pkg}\";" "$config"
                    log_ok "Blacklisted: ${pkg}"
                else
                    log_info "Already blacklisted: ${pkg}"
                fi
            done
            ;;
        remove)
            check_root
            local pkgs="$*"
            for pkg in $pkgs; do
                sed -i "/\"${pkg}\"/d" "$config" 2>/dev/null
                log_ok "Removed from blacklist: ${pkg}"
            done
            ;;
        *)
            log_err "Usage: auto-update.sh blacklist [list|add|remove] [packages]"
            exit 1
            ;;
    esac
}

cmd_reboot() {
    local enable=false
    local disable=false
    local time="04:00"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --enable) enable=true; shift ;;
            --disable) disable=true; shift ;;
            --time) time="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local config="/etc/apt/apt.conf.d/50unattended-upgrades"

    if $enable; then
        check_root
        sed -i 's/Automatic-Reboot "false"/Automatic-Reboot "true"/' "$config" 2>/dev/null
        sed -i "s/Automatic-Reboot-Time .*/Automatic-Reboot-Time \"${time}\";/" "$config" 2>/dev/null
        log_ok "Auto-reboot enabled at ${time}"
    elif $disable; then
        check_root
        sed -i 's/Automatic-Reboot "true"/Automatic-Reboot "false"/' "$config" 2>/dev/null
        log_ok "Auto-reboot disabled"
    fi
}

cmd_reboot_needed() {
    if [ -f /var/run/reboot-required ]; then
        log_warn "Reboot IS required"
        if [ -f /var/run/reboot-required.pkgs ]; then
            log "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs | sed 's/^/  - /'
        fi
        return 1
    else
        log_ok "No reboot needed"
        return 0
    fi
}

cmd_reset() {
    check_root
    log_info "Resetting to default configuration..."

    # Remove custom configs
    rm -f /etc/apt/apt.conf.d/20auto-upgrades
    rm -f /etc/apt/apt.conf.d/50unattended-upgrades

    # Reconfigure with defaults
    dpkg-reconfigure -plow unattended-upgrades 2>/dev/null || true

    log_ok "Reset to default configuration"
}

cmd_generate_config() {
    # Generate a standalone setup script for remote servers
    log_info "Generating standalone setup script..."

    cat <<'SCRIPT'
#!/bin/bash
# Auto-generated by Auto-Update Manager
set -euo pipefail
apt-get update -qq
apt-get install -y -qq unattended-upgrades apt-listchanges
SCRIPT

    # Include the current config
    if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        echo "cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'"
        cat /etc/apt/apt.conf.d/20auto-upgrades
        echo "EOF"
    fi

    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        echo "cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'"
        cat /etc/apt/apt.conf.d/50unattended-upgrades
        echo "EOF"
    fi

    echo "systemctl enable --now unattended-upgrades"
    echo "echo 'Auto-update configured successfully!'"
}

# Main command router
case "${1:-help}" in
    status)         shift; cmd_status "$@" ;;
    setup)          shift; cmd_setup "$@" ;;
    pending)        cmd_pending ;;
    apply-now)      cmd_apply_now ;;
    history)        shift; cmd_history "$@" ;;
    disable)        cmd_disable ;;
    show-config)    cmd_show_config ;;
    blacklist)      shift; cmd_blacklist "$@" ;;
    reboot)         shift; cmd_reboot "$@" ;;
    reboot-needed)  cmd_reboot_needed ;;
    reset)          cmd_reset ;;
    generate-config) cmd_generate_config ;;
    help|--help|-h)
        echo "Auto-Update Manager v${VERSION}"
        echo ""
        echo "Usage: auto-update.sh <command> [options]"
        echo ""
        echo "Commands:"
        echo "  status [--json]              Show current auto-update state"
        echo "  setup [options]              Install & configure auto-updates"
        echo "  pending                      List pending updates"
        echo "  apply-now                    Apply security updates immediately"
        echo "  history [--days N]           Show update history"
        echo "  disable                      Disable auto-updates"
        echo "  show-config                  Display current configuration"
        echo "  blacklist [list|add|remove]  Manage package blacklist"
        echo "  reboot [--enable|--disable]  Configure auto-reboot"
        echo "  reboot-needed                Check if reboot is required"
        echo "  reset                        Reset to default config"
        echo "  generate-config              Generate standalone setup script"
        echo ""
        echo "Setup options:"
        echo "  --auto-reboot               Enable auto-reboot when needed"
        echo "  --no-reboot                 Disable auto-reboot"
        echo "  --reboot-time HH:MM         Set reboot time (default: 04:00)"
        echo "  --email ADDRESS             Enable email notifications"
        echo "  --security-only             Only apply security updates (default)"
        echo "  --all-updates               Apply all updates"
        echo "  --blacklist \"pkg1 pkg2\"      Blacklist packages"
        ;;
    *)
        log_err "Unknown command: $1"
        echo "Run 'auto-update.sh help' for usage."
        exit 1
        ;;
esac
