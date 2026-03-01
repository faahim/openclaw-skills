#!/bin/bash
# JupyterLab Notebook Manager — Create, list, backup, restore notebooks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
WORKSPACE="${JUPYTER_HOME:-$HOME/jupyter-workspace}"

cmd_create() {
  local template="blank" name="notebook.ipynb"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --template|-t) template="$2"; shift 2 ;;
      --name|-n) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local filepath="$WORKSPACE/$name"
  mkdir -p "$(dirname "$filepath")"

  case "$template" in
    blank)
      cat > "$filepath" << 'NBEOF'
{"cells":[{"cell_type":"markdown","metadata":{},"source":["# New Notebook\n"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":[]}],"metadata":{"kernelspec":{"display_name":"Python 3","language":"python","name":"python3"},"language_info":{"name":"python","version":"3.11.0"}},"nbformat":4,"nbformat_minor":5}
NBEOF
      ;;
    data-analysis)
      cat > "$filepath" << 'NBEOF'
{"cells":[{"cell_type":"markdown","metadata":{},"source":["# Data Analysis\n","## Setup"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["import pandas as pd\nimport numpy as np\nimport matplotlib.pyplot as plt\nimport seaborn as sns\n\n%matplotlib inline\nsns.set_style('whitegrid')\nplt.rcParams['figure.figsize'] = (12, 6)"]},{"cell_type":"markdown","metadata":{},"source":["## Load Data"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# df = pd.read_csv('data.csv')\n# df.head()"]},{"cell_type":"markdown","metadata":{},"source":["## Explore"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# df.describe()\n# df.info()"]},{"cell_type":"markdown","metadata":{},"source":["## Visualize"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# plt.figure()\n# sns.histplot(df['column'])\n# plt.title('Distribution')\n# plt.show()"]},{"cell_type":"markdown","metadata":{},"source":["## Conclusions\n","\n","- Finding 1\n","- Finding 2"]}],"metadata":{"kernelspec":{"display_name":"Python 3","language":"python","name":"python3"},"language_info":{"name":"python","version":"3.11.0"}},"nbformat":4,"nbformat_minor":5}
NBEOF
      ;;
    ml-starter)
      cat > "$filepath" << 'NBEOF'
{"cells":[{"cell_type":"markdown","metadata":{},"source":["# Machine Learning Starter\n"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["import pandas as pd\nimport numpy as np\nfrom sklearn.model_selection import train_test_split\nfrom sklearn.preprocessing import StandardScaler\nfrom sklearn.metrics import classification_report, confusion_matrix\nimport matplotlib.pyplot as plt\nimport seaborn as sns\n\n%matplotlib inline"]},{"cell_type":"markdown","metadata":{},"source":["## 1. Load & Explore Data"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# df = pd.read_csv('data.csv')\n# X = df.drop('target', axis=1)\n# y = df['target']\n# X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)"]},{"cell_type":"markdown","metadata":{},"source":["## 2. Preprocess"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# scaler = StandardScaler()\n# X_train_scaled = scaler.fit_transform(X_train)\n# X_test_scaled = scaler.transform(X_test)"]},{"cell_type":"markdown","metadata":{},"source":["## 3. Train Model"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# from sklearn.ensemble import RandomForestClassifier\n# model = RandomForestClassifier(n_estimators=100, random_state=42)\n# model.fit(X_train_scaled, y_train)"]},{"cell_type":"markdown","metadata":{},"source":["## 4. Evaluate"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# y_pred = model.predict(X_test_scaled)\n# print(classification_report(y_test, y_pred))\n# sns.heatmap(confusion_matrix(y_test, y_pred), annot=True, fmt='d')\n# plt.show()"]}],"metadata":{"kernelspec":{"display_name":"Python 3","language":"python","name":"python3"},"language_info":{"name":"python","version":"3.11.0"}},"nbformat":4,"nbformat_minor":5}
NBEOF
      ;;
    *)
      echo "Available templates: blank, data-analysis, ml-starter"
      exit 1
      ;;
  esac

  echo "✅ Created notebook: $filepath (template: $template)"
}

cmd_list() {
  echo "📋 Notebooks in $WORKSPACE"
  echo "=========================="
  find "$WORKSPACE" -name "*.ipynb" -not -path "*/.ipynb_checkpoints/*" 2>/dev/null | sort | while read -r f; do
    local size
    size=$(du -h "$f" | cut -f1)
    local modified
    modified=$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -d. -f1)
    echo "  📓 $(basename "$f") ($size, $modified)"
  done
  local count
  count=$(find "$WORKSPACE" -name "*.ipynb" -not -path "*/.ipynb_checkpoints/*" 2>/dev/null | wc -l)
  echo ""
  echo "Total: $count notebooks"
}

cmd_backup() {
  local output="${1:-$HOME/jupyter-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output|-o) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  tar -czf "$output" -C "$(dirname "$WORKSPACE")" "$(basename "$WORKSPACE")" \
    --exclude=".ipynb_checkpoints" 2>/dev/null
  local size
  size=$(du -h "$output" | cut -f1)
  echo "✅ Backup created: $output ($size)"
}

cmd_restore() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { echo "Usage: bash notebooks.sh restore --input <backup.tar.gz>"; exit 1; }
  [ ! -f "$input" ] && { echo "❌ File not found: $input"; exit 1; }

  tar -xzf "$input" -C "$(dirname "$WORKSPACE")"
  echo "✅ Restored from: $input"
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  create) cmd_create "$@" ;;
  list) cmd_list ;;
  backup) cmd_backup "$@" ;;
  restore) cmd_restore "$@" ;;
  *)
    echo "Jupyter Notebook Manager"
    echo ""
    echo "Commands:"
    echo "  create --template <name> --name <file.ipynb>"
    echo "  list"
    echo "  backup --output <file.tar.gz>"
    echo "  restore --input <file.tar.gz>"
    echo ""
    echo "Templates: blank, data-analysis, ml-starter"
    ;;
esac
