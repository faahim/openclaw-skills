#!/bin/bash
# Vulnerability Check — Scan an SBOM with Grype for known CVEs
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <sbom-file> [--severity critical,high]"
  echo ""
  echo "Scans an SBOM file for known vulnerabilities using Grype."
  echo "Accepts syft-json, cyclonedx-json, or spdx-json format."
  exit 1
fi

SBOM_FILE="$1"
shift

SEVERITY_FILTER=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --severity) SEVERITY_FILTER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ ! -f "$SBOM_FILE" ]]; then
  echo "❌ SBOM file not found: $SBOM_FILE"
  exit 1
fi

# Check for Grype
if ! command -v grype &>/dev/null; then
  echo "❌ Grype not installed. Install with:"
  echo "   curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin"
  echo ""
  echo "Or run: bash scripts/install.sh (select 'y' for Grype)"
  exit 1
fi

echo "🔍 Scanning SBOM for vulnerabilities..."
echo ""

GRYPE_ARGS=("sbom:$SBOM_FILE")

if [[ -n "$SEVERITY_FILTER" ]]; then
  GRYPE_ARGS+=("--fail-on" "$SEVERITY_FILTER")
fi

grype "${GRYPE_ARGS[@]}" 2>/dev/null
EXIT_CODE=$?

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "✅ Vulnerability scan complete."
else
  echo "⚠️  Vulnerabilities found at or above severity threshold."
fi

exit $EXIT_CODE
