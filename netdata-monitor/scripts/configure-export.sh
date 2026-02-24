#!/bin/bash
# Configure Netdata metric exports
set -e

METHOD="${1:-}"

[ -z "$METHOD" ] && {
    echo "Usage: bash scripts/configure-export.sh <method>"
    echo ""
    echo "Methods:"
    echo "  prometheus  - Export at /api/v1/allmetrics?format=prometheus"
    echo "  graphite    - Export to Graphite/Carbon"
    echo "  json        - Export at /api/v1/allmetrics?format=json"
    exit 0
}

case "$METHOD" in
    prometheus)
        echo "✅ Prometheus metrics are available by default at:"
        echo "   http://localhost:19999/api/v1/allmetrics?format=prometheus"
        echo ""
        echo "Add to prometheus.yml:"
        echo "  scrape_configs:"
        echo "    - job_name: 'netdata'"
        echo "      metrics_path: '/api/v1/allmetrics'"
        echo "      params:"
        echo "        format: [prometheus]"
        echo "      static_configs:"
        echo "        - targets: ['localhost:19999']"
        ;;
    json)
        echo "✅ JSON metrics available at:"
        echo "   http://localhost:19999/api/v1/allmetrics?format=json"
        ;;
    *)
        echo "❌ Unknown method: $METHOD"
        exit 1
        ;;
esac
