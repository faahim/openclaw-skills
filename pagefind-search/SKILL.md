---
name: pagefind-search
description: >-
  Add instant client-side search to any static site. Indexes HTML, generates a search UI — no server required.
categories: [dev-tools, writing]
dependencies: [bash, curl, tar]
---

# Pagefind Static Site Search

## What This Does

Installs [Pagefind](https://pagefind.app), indexes your static site's HTML files, and generates a fast client-side search widget. Works with Hugo, MkDocs, Jekyll, Astro, Eleventy, or any folder of HTML files. Zero server-side infrastructure — everything runs in the browser.

**Example:** "Index 500 HTML pages, get a search bar that finds results in <50ms with fuzzy matching."

## Quick Start (5 minutes)

### 1. Install Pagefind

```bash
bash scripts/install.sh
```

This downloads the latest Pagefind binary to `~/.local/bin/pagefind`. Supports Linux (x86_64, aarch64) and macOS.

### 2. Index Your Site

```bash
# Point at your static site's build output
pagefind --site ./public

# Or specify a different output directory
pagefind --site ./dist --output-subdir _search
```

**Output:**
```
Running Pagefind v1.3.0
Running from: /home/user/my-site
Indexed 247 pages
Indexed 18432 words
Indexed 0 filters
Indexed 0 sorts
Created 12 index chunks
```

### 3. Add Search to Your Site

Add this snippet to any HTML page:

```html
<link href="/_pagefind/pagefind-ui.css" rel="stylesheet">
<script src="/_pagefind/pagefind-ui.js"></script>
<div id="search"></div>
<script>
  window.addEventListener('DOMContentLoaded', () => {
    new PagefindUI({ element: "#search", showSubResults: true });
  });
</script>
```

Rebuild/serve your site and search just works.

## Core Workflows

### Workflow 1: Index a Hugo Site

```bash
# Build Hugo
hugo --minify

# Index the output
pagefind --site ./public

# Serve locally to test
python3 -m http.server -d public 8080
# Visit http://localhost:8080 and search
```

### Workflow 2: Index MkDocs

```bash
# Build MkDocs
mkdocs build

# Index
pagefind --site ./site

# The search UI replaces MkDocs' built-in search
```

### Workflow 3: Selective Indexing

Control what gets indexed using `data-pagefind-body` attributes:

```html
<!-- Only index content inside this div -->
<div data-pagefind-body>
  <h1>My Article</h1>
  <p>This content will be searchable.</p>
</div>

<!-- This sidebar won't be indexed -->
<nav>...</nav>
```

Or exclude elements:

```html
<div data-pagefind-body>
  <p>This is indexed.</p>
  <div data-pagefind-ignore>This is NOT indexed.</div>
</div>
```

### Workflow 4: Filtered Search (Tags, Categories)

Add filter attributes to your HTML:

```html
<article>
  <span data-pagefind-filter="category">Tutorial</span>
  <span data-pagefind-filter="tag">JavaScript</span>
  <h1 data-pagefind-meta="title">Getting Started</h1>
  <p>Content here...</p>
</article>
```

Then in the UI:

```html
<script>
  new PagefindUI({
    element: "#search",
    showSubResults: true,
    showEmptyFilters: false
  });
</script>
```

Users can filter search results by category/tag.

### Workflow 5: CI/CD Integration

Add to your build pipeline (GitHub Actions example):

```yaml
- name: Build site
  run: hugo --minify

- name: Index with Pagefind
  run: |
    curl -sL https://github.com/CloudCannon/pagefind/releases/latest/download/pagefind-v1.3.0-x86_64-unknown-linux-musl.tar.gz | tar xz
    ./pagefind --site ./public

- name: Deploy
  uses: peaceiris/actions-gh-pages@v3
  with:
    publish_dir: ./public
```

## Configuration

### CLI Options

```bash
# Basic indexing
pagefind --site ./public

# Custom output directory
pagefind --site ./public --output-subdir _search

# Serve with live reloading (dev mode)
pagefind --site ./public --serve

# Verbose output
pagefind --site ./public --verbose

# Exclude paths from indexing
pagefind --site ./public --glob "**/*.html" --exclude-selectors "nav,footer,.sidebar"
```

### Config File (pagefind.yml)

```yaml
# pagefind.yml — place in project root
site: public
output_subdir: _pagefind
glob: "**/*.html"
exclude_selectors:
  - nav
  - footer
  - .sidebar
  - "[data-pagefind-ignore]"
root_selector: body
force_language: en
```

Run with: `pagefind` (auto-detects config file)

### UI Customization

```javascript
new PagefindUI({
  element: "#search",
  showSubResults: true,        // Show sub-headings in results
  showImages: true,             // Show page images in results
  excerptLength: 15,            // Words per excerpt
  resetStyles: false,           // Keep default Pagefind CSS
  bundlePath: "/_pagefind/",   // Path to index files
  debounceTimeoutMs: 300,       // Search input debounce
  translations: {
    placeholder: "Search docs...",
    zero_results: "No results for [SEARCH_TERM]"
  }
});
```

### Custom CSS Theming

```css
:root {
  --pagefind-ui-scale: 1;
  --pagefind-ui-primary: #034ad8;
  --pagefind-ui-text: #393939;
  --pagefind-ui-background: #ffffff;
  --pagefind-ui-border: #eeeeee;
  --pagefind-ui-tag: #eeeeee;
  --pagefind-ui-border-width: 2px;
  --pagefind-ui-border-radius: 8px;
  --pagefind-ui-font: sans-serif;
}
```

## Advanced Usage

### JavaScript API (Headless Search)

Build a custom search UI:

```javascript
const pagefind = await import("/_pagefind/pagefind.js");
await pagefind.init();

const search = await pagefind.search("tutorial");
console.log(`${search.results.length} results`);

// Load full data for first 5 results
const results = await Promise.all(
  search.results.slice(0, 5).map(r => r.data())
);

results.forEach(r => {
  console.log(r.url, r.meta.title, r.excerpt);
});
```

### Multilingual Sites

```bash
# Pagefind auto-detects language from <html lang="...">
# For multi-language sites, index each language separately:
pagefind --site ./public/en --output-subdir ../_pagefind_en
pagefind --site ./public/fr --output-subdir ../_pagefind_fr
```

### Rebuild on File Changes (Watch Mode)

```bash
# Use with a file watcher
while inotifywait -r -e modify ./content/; do
  hugo --minify && pagefind --site ./public
done
```

## Troubleshooting

### Issue: "pagefind: command not found"

```bash
# Ensure ~/.local/bin is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: "No pages found to index"

- Check `--site` points to a directory with `.html` files
- Ensure HTML files have a `<body>` tag
- Try `--verbose` to see what Pagefind is scanning

### Issue: Search returns no results

- Verify `/_pagefind/` directory exists in your site output
- Check browser console for 404 errors on pagefind files
- Ensure `bundlePath` in PagefindUI matches the output location

### Issue: Indexing is slow

- Use `--glob` to limit which files are scanned
- Exclude large pages with `data-pagefind-ignore`
- Typical: 1000 pages indexes in <5 seconds

## Dependencies

- `bash` (4.0+)
- `curl` (for downloading Pagefind)
- `tar` (for extracting)
- A static site with HTML files
