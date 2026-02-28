---
name: svg-optimizer
description: >-
  Batch-optimize SVG files — strip metadata, minify paths, reduce file size by 30-80% with zero quality loss.
categories: [design, automation]
dependencies: [node, npm]
---

# SVG Optimizer

## What This Does

Installs and runs [SVGO](https://github.com/svg/svgo) to optimize SVG files in bulk. Strips editor metadata (Inkscape, Illustrator), minifies path data, removes hidden elements, collapses groups, and converts shapes to shorter paths. Typical savings: 30-80% file size reduction with zero visual difference.

**Example:** "Optimize all SVGs in `./icons/` — shrink 2.4 MB to 680 KB, output to `./icons-optimized/`."

## Quick Start (2 minutes)

### 1. Install SVGO

```bash
bash scripts/install.sh
```

### 2. Optimize a Single SVG

```bash
bash scripts/run.sh --input logo.svg --output logo.min.svg
```

### 3. Batch Optimize a Directory

```bash
bash scripts/run.sh --input ./icons/ --output ./icons-optimized/
```

## Core Workflows

### Workflow 1: Optimize Single File

```bash
bash scripts/run.sh --input hero.svg --output hero.min.svg

# Output:
# ✅ hero.svg: 48.2 KB → 12.7 KB (73.6% reduction)
```

### Workflow 2: Batch Optimize Directory

```bash
bash scripts/run.sh --input ./assets/svg/ --output ./assets/svg-optimized/

# Output:
# ✅ icon-home.svg: 3.1 KB → 1.2 KB (61.3%)
# ✅ icon-user.svg: 4.8 KB → 1.5 KB (68.7%)
# ✅ logo.svg: 22.4 KB → 6.1 KB (72.8%)
# ─────────────────────────────────
# Total: 30.3 KB → 8.8 KB (71.0% reduction, 3 files)
```

### Workflow 3: In-Place Optimization

```bash
bash scripts/run.sh --input ./icons/ --inplace

# Output:
# ⚠️  In-place mode: originals will be overwritten
# ✅ 12 files optimized (avg 64.2% reduction)
```

### Workflow 4: Aggressive Mode (Maximum Compression)

```bash
bash scripts/run.sh --input ./svg/ --output ./svg-min/ --aggressive

# Enables extra plugins: convertShapeToPath, removeViewBox removal disabled,
# mergePaths, removeOffCanvasPaths
```

### Workflow 5: Web-Safe Mode (Preserves Accessibility)

```bash
bash scripts/run.sh --input ./svg/ --output ./svg-web/ --web-safe

# Keeps: title, desc, aria attributes, role attributes
# Removes: editor metadata, comments, hidden elements
```

### Workflow 6: Compare Before/After

```bash
bash scripts/run.sh --input ./icons/ --output ./icons-min/ --report

# Generates: optimization-report.csv
# file,original_bytes,optimized_bytes,reduction_pct
# icon-home.svg,3174,1223,61.5
# icon-user.svg,4812,1498,68.9
```

## Configuration

### Custom SVGO Config

Create `svgo.config.mjs` for fine-grained control:

```javascript
// svgo.config.mjs
export default {
  multipass: true,
  plugins: [
    'preset-default',
    'removeDimensions',
    'sortAttrs',
    {
      name: 'removeAttrs',
      params: { attrs: '(data-.*)' }
    }
  ]
};
```

Use with:
```bash
bash scripts/run.sh --input ./svg/ --output ./svg-min/ --config svgo.config.mjs
```

### Preset Configs

The skill ships with presets in `scripts/presets/`:

- **default.mjs** — Balanced optimization (recommended)
- **aggressive.mjs** — Maximum compression, may alter rendering edge cases
- **web-safe.mjs** — Preserves accessibility attributes (title, desc, aria-*)
- **icon.mjs** — Optimized for icon sets (removes dimensions, adds viewBox)

## Advanced Usage

### Watch Mode (Auto-Optimize on Change)

```bash
bash scripts/run.sh --input ./src/svg/ --output ./dist/svg/ --watch

# Watches for new/changed SVGs and optimizes automatically
```

### Pipe from stdin

```bash
cat raw.svg | npx svgo --input - --output - > optimized.svg
```

### Integrate with Build Pipeline

```bash
# In package.json scripts:
# "optimize-svg": "bash path/to/scripts/run.sh --input ./src/svg --output ./public/svg --report"

# Or in Makefile:
# svg: bash scripts/run.sh --input src/svg --output dist/svg
```

## Troubleshooting

### Issue: "svgo: command not found"

```bash
# Re-run install
bash scripts/install.sh

# Or install globally
npm install -g svgo
```

### Issue: SVG looks different after optimization

Use web-safe mode or create a custom config excluding problematic plugins:

```javascript
// svgo.config.mjs
export default {
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          convertPathData: false,    // Keep original path data
          mergePaths: false,         // Don't merge paths
          convertShapeToPath: false  // Keep shapes as-is
        }
      }
    }
  ]
};
```

### Issue: Animated SVGs break

Add `--web-safe` flag — it preserves SMIL animations and CSS animations.

## Dependencies

- `node` (16+)
- `npm` (comes with node)
- `svgo` (installed by `scripts/install.sh`)

## Key Principles

1. **Non-destructive by default** — Output to separate directory unless `--inplace`
2. **Multipass** — Runs multiple optimization passes for best results
3. **Preset-based** — Ship sensible defaults, allow full customization
4. **Batch-friendly** — Process hundreds of files in seconds
5. **Report generation** — CSV reports for tracking optimization gains
