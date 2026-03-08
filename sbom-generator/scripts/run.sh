#!/bin/bash
# SBOM Generator — Generate Software Bill of Materials using Syft
set -euo pipefail

# Defaults
SYFT_BIN="${SYFT_BIN:-syft}"
FORMAT="${SBOM_DEFAULT_FORMAT:-table}"
OUTPUT=""
PATH_TARGET=""
IMAGE_TARGET=""
OUTPUT_DIR="${SBOM_OUTPUT_DIR:-.}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate a Software Bill of Materials (SBOM) for a project or container image.

Options:
  --path PATH        Scan a local directory or file
  --image IMAGE      Scan a container image (e.g., node:20-alpine)
  --format FORMAT    Output format (default: table)
                     Options: table, spdx-json, spdx-tag-value,
                              cyclonedx-json, cyclonedx-xml, syft-json
  --output FILE      Write output to file (default: stdout)
  --help             Show this help

Examples:
  $(basename "$0") --path .
  $(basename "$0") --image nginx:latest --format cyclonedx-json --output sbom.json
  $(basename "$0") --path ./my-app --format spdx-json --output my-app-sbom.json
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --path)    PATH_TARGET="$2"; shift 2 ;;
    --image)   IMAGE_TARGET="$2"; shift 2 ;;
    --format)  FORMAT="$2"; shift 2 ;;
    --output)  OUTPUT="$2"; shift 2 ;;
    --help|-h) usage ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
  esac
done

# Validate
if ! command -v "$SYFT_BIN" &>/dev/null; then
  echo "❌ Syft not found. Install it with: bash scripts/install.sh"
  exit 1
fi

if [[ -z "$PATH_TARGET" && -z "$IMAGE_TARGET" ]]; then
  echo "❌ Specify --path or --image to scan."
  echo "Run with --help for usage."
  exit 1
fi

# Build syft command
SYFT_ARGS=()

if [[ -n "$PATH_TARGET" ]]; then
  if [[ ! -e "$PATH_TARGET" ]]; then
    echo "❌ Path not found: $PATH_TARGET"
    exit 1
  fi
  SYFT_ARGS+=("dir:$PATH_TARGET")
elif [[ -n "$IMAGE_TARGET" ]]; then
  SYFT_ARGS+=("$IMAGE_TARGET")
fi

SYFT_ARGS+=("--output" "$FORMAT")

# Execute
echo "🔍 Scanning with Syft (format: $FORMAT)..."
echo ""

if [[ -n "$OUTPUT" ]]; then
  # Ensure output directory exists
  mkdir -p "$(dirname "$OUTPUT")"
  
  "$SYFT_BIN" "${SYFT_ARGS[@]}" > "$OUTPUT" 2>/dev/null
  
  # Count packages
  if [[ "$FORMAT" == "table" ]]; then
    PKG_COUNT=$(wc -l < "$OUTPUT")
    PKG_COUNT=$((PKG_COUNT - 1))  # subtract header
  elif [[ "$FORMAT" == *"json"* ]] && command -v jq &>/dev/null; then
    if [[ "$FORMAT" == "cyclonedx-json" ]]; then
      PKG_COUNT=$(jq '.components | length' "$OUTPUT" 2>/dev/null || echo "?")
    elif [[ "$FORMAT" == "spdx-json" ]]; then
      PKG_COUNT=$(jq '.packages | length' "$OUTPUT" 2>/dev/null || echo "?")
    elif [[ "$FORMAT" == "syft-json" ]]; then
      PKG_COUNT=$(jq '.artifacts | length' "$OUTPUT" 2>/dev/null || echo "?")
    else
      PKG_COUNT="?"
    fi
  else
    PKG_COUNT="?"
  fi
  
  FILE_SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "✅ SBOM saved to: $OUTPUT ($FILE_SIZE, $PKG_COUNT packages)"
else
  "$SYFT_BIN" "${SYFT_ARGS[@]}" 2>/dev/null
  echo ""
  echo "✅ Scan complete."
fi
