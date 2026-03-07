#!/bin/bash
# Ghost Blog Manager — Theme Management
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[ghost-blog]${NC} $1"; }
err() { echo -e "${RED}[ghost-blog]${NC} $1" >&2; }

ACTION="${1:-}"
SOURCE="${2:-}"
NAME="${GHOST_DEPLOY_NAME:-ghost}"
DEPLOY_DIR="$HOME/ghost-deployments/$NAME"

usage() {
    echo "Usage: $0 <install|list|activate> [source/theme-name]"
    echo "  install https://github.com/User/theme  — Install from GitHub"
    echo "  install /path/to/theme.zip              — Install from zip"
    echo "  list                                    — List installed themes"
    echo "  activate casper                         — Activate a theme"
    exit 1
}

[ -z "$ACTION" ] && usage
cd "$DEPLOY_DIR"

CONTAINER=$(docker compose ps -q ghost 2>/dev/null || docker-compose ps -q ghost)

case "$ACTION" in
    install)
        [ -z "$SOURCE" ] && { err "Provide theme URL or path"; exit 1; }
        TMP=$(mktemp -d)
        
        if [[ "$SOURCE" == http* ]]; then
            # GitHub repo
            log "Cloning theme from $SOURCE..."
            git clone --depth 1 "$SOURCE" "$TMP/theme"
            THEME_NAME=$(basename "$SOURCE" | sed 's/\.git$//')
            
            # Build if package.json exists
            if [ -f "$TMP/theme/package.json" ]; then
                cd "$TMP/theme"
                npm install --production 2>/dev/null && npm run build 2>/dev/null || true
                cd "$DEPLOY_DIR"
            fi
            
            # Zip it
            cd "$TMP/theme"
            zip -r "$TMP/$THEME_NAME.zip" . -x '.git/*' 'node_modules/*' > /dev/null
            cd "$DEPLOY_DIR"
        elif [ -f "$SOURCE" ]; then
            cp "$SOURCE" "$TMP/"
            THEME_NAME=$(basename "$SOURCE" .zip)
        else
            err "Source not found: $SOURCE"
            exit 1
        fi
        
        # Copy to Ghost content/themes
        docker cp "$TMP/$THEME_NAME.zip" "$CONTAINER:/var/lib/ghost/content/themes/"
        docker exec "$CONTAINER" unzip -o "/var/lib/ghost/content/themes/$THEME_NAME.zip" -d "/var/lib/ghost/content/themes/$THEME_NAME" 2>/dev/null || true
        
        rm -rf "$TMP"
        log "✅ Theme '$THEME_NAME' installed"
        log "Activate: $0 activate $THEME_NAME"
        ;;
    
    list)
        log "Installed themes:"
        docker exec "$CONTAINER" ls /var/lib/ghost/content/themes/ 2>/dev/null
        ;;
    
    activate)
        [ -z "$SOURCE" ] && { err "Provide theme name"; exit 1; }
        log "Activating theme: $SOURCE"
        # Ghost Admin API would be ideal here, but for simplicity:
        docker exec "$CONTAINER" ghost config set activeTheme "$SOURCE" 2>/dev/null || true
        docker compose restart ghost 2>/dev/null || docker-compose restart ghost
        log "✅ Theme '$SOURCE' activated (restart in progress)"
        ;;
    
    *) usage ;;
esac
