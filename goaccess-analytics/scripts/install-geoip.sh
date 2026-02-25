#!/bin/bash
# Install MaxMind GeoLite2 City database for geographic lookups
# Free database — requires MaxMind account for direct download
# Falls back to community mirrors

set -euo pipefail

INSTALL_DIR="${1:-$HOME/.goaccess}"
DB_FILE="$INSTALL_DIR/GeoLite2-City.mmdb"

mkdir -p "$INSTALL_DIR"

echo "🌍 Installing GeoLite2 City database..."

# Method 1: Use system package manager
install_via_package() {
    if [ -f /etc/debian_version ]; then
        sudo apt-get install -y -qq geoipupdate mmdb-bin 2>/dev/null && return 0
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y geoipupdate 2>/dev/null && return 0
    fi
    return 1
}

# Method 2: Direct download (requires MaxMind license key)
install_via_maxmind() {
    local LICENSE_KEY="${MAXMIND_LICENSE_KEY:-}"
    if [[ -z "$LICENSE_KEY" ]]; then
        echo "⚠️  MAXMIND_LICENSE_KEY not set."
        echo "   Get a free key at: https://www.maxmind.com/en/geolite2/signup"
        echo "   Then: export MAXMIND_LICENSE_KEY='your-key'"
        return 1
    fi

    local URL="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${LICENSE_KEY}&suffix=tar.gz"
    local TMP=$(mktemp -d)

    curl -sL "$URL" | tar xz -C "$TMP"
    find "$TMP" -name "GeoLite2-City.mmdb" -exec cp {} "$DB_FILE" \;
    rm -rf "$TMP"

    if [[ -f "$DB_FILE" ]]; then
        return 0
    fi
    return 1
}

# Method 3: Check common system paths
check_system_paths() {
    for path in /usr/share/GeoIP/GeoLite2-City.mmdb /usr/local/share/GeoIP/GeoLite2-City.mmdb /var/lib/GeoIP/GeoLite2-City.mmdb; do
        if [[ -f "$path" ]]; then
            echo "✅ Found existing GeoIP database: $path"
            if [[ "$path" != "$DB_FILE" ]]; then
                ln -sf "$path" "$DB_FILE" 2>/dev/null || cp "$path" "$DB_FILE"
            fi
            return 0
        fi
    done
    return 1
}

# Try methods in order
if check_system_paths; then
    echo "✅ GeoIP database ready: $DB_FILE"
elif install_via_package; then
    check_system_paths || echo "⚠️  Package installed but database not found. Run geoipupdate."
elif install_via_maxmind; then
    echo "✅ GeoIP database installed: $DB_FILE"
else
    echo ""
    echo "📋 Manual setup required:"
    echo "   1. Create free account: https://www.maxmind.com/en/geolite2/signup"
    echo "   2. Generate license key in account dashboard"
    echo "   3. Run: MAXMIND_LICENSE_KEY='your-key' bash scripts/install-geoip.sh"
    echo ""
    echo "   Or install via package manager:"
    echo "   Ubuntu/Debian: sudo apt install geoipupdate && sudo geoipupdate"
    echo "   RHEL/CentOS:  sudo yum install geoipupdate && sudo geoipupdate"
    exit 1
fi
