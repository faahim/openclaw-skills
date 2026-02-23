#!/bin/bash
# Add a scrape target to Prometheus config
set -euo pipefail

TARGET="${1:?Usage: add-target.sh <host:port> [label]}"
LABEL="${2:-${TARGET%%:*}}"
CONFIG="/etc/prometheus/prometheus.yml"

# Check if target already exists
if grep -q "${TARGET}" "${CONFIG}" 2>/dev/null; then
  echo "⚠️  Target ${TARGET} already in config"
  exit 0
fi

# Add target under the 'node' job
# Uses python for safe YAML manipulation, falls back to sed
if command -v python3 &>/dev/null; then
  python3 << PYEOF
import yaml, sys

with open("${CONFIG}") as f:
    cfg = yaml.safe_load(f)

for job in cfg.get("scrape_configs", []):
    if job.get("job_name") == "node":
        for sc in job.get("static_configs", []):
            sc["targets"].append("${TARGET}")
            if "labels" not in sc:
                sc["labels"] = {}
        # Add as new static_config entry with label
        job["static_configs"].append({
            "targets": ["${TARGET}"],
            "labels": {"instance_name": "${LABEL}"}
        })
        break
else:
    cfg.setdefault("scrape_configs", []).append({
        "job_name": "node",
        "static_configs": [{"targets": ["${TARGET}"], "labels": {"instance_name": "${LABEL}"}}]
    })

with open("${CONFIG}", "w") as f:
    yaml.dump(cfg, f, default_flow_style=False)

print("✅ Added target ${TARGET} (${LABEL})")
PYEOF
else
  # Fallback: append to config
  cat >> "${CONFIG}" << YAML

  # Added $(date -u +%Y-%m-%dT%H:%M:%SZ)
  - job_name: 'node-${LABEL}'
    static_configs:
      - targets: ['${TARGET}']
        labels:
          instance_name: '${LABEL}'
YAML
  echo "✅ Added target ${TARGET} (${LABEL}) — verify YAML manually"
fi

# Validate config
if /usr/local/bin/promtool check config "${CONFIG}"; then
  echo "✅ Config valid"
  systemctl reload prometheus 2>/dev/null && echo "🔄 Prometheus reloaded" || echo "⚠️  Reload prometheus manually: systemctl reload prometheus"
else
  echo "❌ Config invalid — check ${CONFIG}"
  exit 1
fi
