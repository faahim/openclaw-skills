#!/bin/bash
# Ghost Blog Manager — Complete Removal
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

NAME="${1:-ghost}"
DEPLOY_DIR="$HOME/ghost-deployments/$NAME"

[ ! -d "$DEPLOY_DIR" ] && { echo "Not found: $DEPLOY_DIR"; exit 1; }

echo -e "${RED}⚠️  This will permanently delete:${NC}"
echo "  - All Ghost containers for '$NAME'"
echo "  - All Docker volumes (database, content, SSL certs)"
echo "  - Deploy directory: $DEPLOY_DIR"
echo ""
read -p "Type 'destroy' to confirm: " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
    echo "Aborted."
    exit 0
fi

cd "$DEPLOY_DIR"
echo -e "${YELLOW}Stopping and removing...${NC}"
docker compose down -v 2>/dev/null || docker-compose down -v
cd "$HOME"
rm -rf "$DEPLOY_DIR"

echo -e "${GREEN}✅ Ghost '$NAME' completely removed.${NC}"
