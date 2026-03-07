#!/usr/bin/env bash
# Compare two system inventory JSON files and show differences
# Usage: bash diff.sh baseline.json current.json

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <baseline.json> <current.json>"
  exit 1
fi

BASELINE="$1"
CURRENT="$2"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required for diff. Install with: sudo apt-get install jq" >&2
  exit 1
fi

echo "# System Inventory Diff"
echo "**Baseline:** $BASELINE"
echo "**Current:** $CURRENT"
echo "**Compared at:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ── System changes ────────────────────────────────────────────────────────────
echo "## System"
b_kernel="$(jq -r '.system.kernel // ""' "$BASELINE" 2>/dev/null)"
c_kernel="$(jq -r '.system.kernel // ""' "$CURRENT" 2>/dev/null)"
if [[ "$b_kernel" != "$c_kernel" ]]; then
  echo "~ Kernel: $b_kernel → $c_kernel"
else
  echo "No changes."
fi
echo ""

# ── Memory changes ────────────────────────────────────────────────────────────
echo "## Memory"
b_mem="$(jq -r '.memory.total_mb // 0' "$BASELINE" 2>/dev/null)"
c_mem="$(jq -r '.memory.total_mb // 0' "$CURRENT" 2>/dev/null)"
if [[ "$b_mem" != "$c_mem" ]]; then
  echo "~ Total RAM: ${b_mem}MB → ${c_mem}MB"
else
  echo "No changes (${c_mem}MB)."
fi
echo ""

# ── Package changes ───────────────────────────────────────────────────────────
echo "## Package Changes"
b_count="$(jq -r '.packages.total_packages // 0' "$BASELINE" 2>/dev/null)"
c_count="$(jq -r '.packages.total_packages // 0' "$CURRENT" 2>/dev/null)"
echo "Package count: $b_count → $c_count ($(( c_count - b_count )) change)"
echo ""

# ── Service changes ───────────────────────────────────────────────────────────
echo "## Service Changes"
b_services="$(jq -r '[.services[]?.unit] | sort | .[]' "$BASELINE" 2>/dev/null)"
c_services="$(jq -r '[.services[]?.unit] | sort | .[]' "$CURRENT" 2>/dev/null)"

new_services="$(comm -13 <(echo "$b_services") <(echo "$c_services") 2>/dev/null || true)"
removed_services="$(comm -23 <(echo "$b_services") <(echo "$c_services") 2>/dev/null || true)"

if [[ -n "$new_services" ]]; then
  while IFS= read -r svc; do
    [[ -n "$svc" ]] && echo "+ $svc (new)"
  done <<< "$new_services"
fi
if [[ -n "$removed_services" ]]; then
  while IFS= read -r svc; do
    [[ -n "$svc" ]] && echo "- $svc (removed)"
  done <<< "$removed_services"
fi
[[ -z "$new_services" && -z "$removed_services" ]] && echo "No changes."
echo ""

# ── Port changes ──────────────────────────────────────────────────────────────
echo "## Port Changes"
b_ports="$(jq -r '[.ports[]?.address] | sort | .[]' "$BASELINE" 2>/dev/null)"
c_ports="$(jq -r '[.ports[]?.address] | sort | .[]' "$CURRENT" 2>/dev/null)"

new_ports="$(comm -13 <(echo "$b_ports") <(echo "$c_ports") 2>/dev/null || true)"
removed_ports="$(comm -23 <(echo "$b_ports") <(echo "$c_ports") 2>/dev/null || true)"

if [[ -n "$new_ports" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] && echo "+ $p (new listener)"
  done <<< "$new_ports"
fi
if [[ -n "$removed_ports" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] && echo "- $p (no longer listening)"
  done <<< "$removed_ports"
fi
[[ -z "$new_ports" && -z "$removed_ports" ]] && echo "No changes."
echo ""

# ── Storage changes ───────────────────────────────────────────────────────────
echo "## Storage"
b_fs="$(jq -r '.storage.filesystems[]? | "\(.mount): \(.use_percent)"' "$BASELINE" 2>/dev/null || true)"
c_fs="$(jq -r '.storage.filesystems[]? | "\(.mount): \(.use_percent)"' "$CURRENT" 2>/dev/null || true)"
if [[ "$b_fs" != "$c_fs" ]]; then
  echo "Filesystem usage changed:"
  diff <(echo "$b_fs") <(echo "$c_fs") || true
else
  echo "No changes."
fi
echo ""

echo "---"
echo "End of diff report."
