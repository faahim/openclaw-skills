---
name: git-lfs-manager
description: >-
  Install, configure, and manage Git Large File Storage (LFS) — track patterns, migrate history, monitor quota, and optimize storage.
categories: [dev-tools, data]
dependencies: [git, git-lfs, bash, du]
---

# Git LFS Manager

## What This Does

Manages Git Large File Storage (LFS) end-to-end: installation, pattern tracking, history migration, quota monitoring, and storage optimization. Handles the complexity of LFS so you don't accidentally commit 500MB binaries to your repo.

**Example:** "Install git-lfs, track all PSD/AI/MP4 files, migrate existing large files from history, monitor LFS quota usage."

## Quick Start (5 minutes)

### 1. Install Git LFS

```bash
bash scripts/install.sh
```

This detects your OS (Debian/Ubuntu, RHEL/Fedora, macOS, Arch) and installs git-lfs, then runs `git lfs install`.

### 2. Track File Patterns

```bash
# Track common binary formats
bash scripts/manage.sh track-defaults

# Track specific patterns
bash scripts/manage.sh track "*.psd" "*.ai" "*.mp4" "*.zip"
```

### 3. Check LFS Status

```bash
# Show tracked patterns, LFS objects, storage usage
bash scripts/manage.sh status
```

## Core Workflows

### Workflow 1: Set Up LFS in a New Repo

**Use case:** Starting a project that will have large assets

```bash
cd /path/to/your/repo

# Install and initialize
bash /path/to/scripts/install.sh

# Track common patterns (images, video, archives, design files)
bash /path/to/scripts/manage.sh track-defaults

# Verify
cat .gitattributes
git lfs track
```

**Output:**
```
Tracking "*.psd"
Tracking "*.ai"
Tracking "*.sketch"
Tracking "*.fig"
Tracking "*.mp4"
Tracking "*.mov"
Tracking "*.avi"
Tracking "*.zip"
Tracking "*.tar.gz"
Tracking "*.png" (files > 1MB)
```

### Workflow 2: Migrate Existing Large Files

**Use case:** Repo already has large files in git history bloating the repo

```bash
# Find large files in history
bash scripts/manage.sh find-large --min-size 5M

# Migrate specific file types to LFS (rewrites history!)
bash scripts/manage.sh migrate "*.mp4" "*.psd" "*.zip"

# Migrate everything over a size threshold
bash scripts/manage.sh migrate-by-size 10M
```

**Output:**
```
migrate: Sorting commits: ..., done.
migrate: Rewriting commits: 100% (234/234), done.
  master    abc1234..def5678
  *.mp4     3 files, 450 MB
  *.psd     12 files, 1.2 GB
  *.zip     5 files, 200 MB
```

### Workflow 3: Monitor LFS Storage & Quota

**Use case:** Check how much LFS storage you're using (GitHub has limits)

```bash
# Local LFS storage usage
bash scripts/manage.sh quota

# Detailed object listing
bash scripts/manage.sh objects
```

**Output:**
```
Git LFS Storage Report
━━━━━━━━━━━━━━━━━━━━━
Local LFS objects:   47 files
Local LFS size:      2.3 GB
Tracked patterns:    12

Top 5 largest LFS objects:
  1. assets/video/demo.mp4        450 MB
  2. design/mockup-v3.psd         180 MB
  3. assets/video/tutorial.mov    156 MB
  4. releases/build-v2.1.zip      98 MB
  5. design/brand-guide.ai        67 MB
```

### Workflow 4: Clean & Prune LFS

**Use case:** Reclaim disk space from old LFS objects

```bash
# Remove old LFS objects not on current branch
bash scripts/manage.sh prune

# Deep clean — remove unreferenced objects
bash scripts/manage.sh clean
```

### Workflow 5: Pre-commit Hook (Block Large Files)

**Use case:** Prevent accidental commits of large files without LFS

```bash
# Install pre-commit hook that blocks files >5MB not tracked by LFS
bash scripts/manage.sh install-hook --max-size 5M
```

The hook checks every commit and rejects files over the threshold that aren't tracked by LFS.

## Configuration

### Default Track Patterns

The `track-defaults` command adds these patterns:

```
# Design files
*.psd, *.ai, *.sketch, *.fig, *.xd

# Video
*.mp4, *.mov, *.avi, *.mkv, *.webm

# Audio
*.wav, *.mp3, *.flac, *.aac

# Archives
*.zip, *.tar.gz, *.tar.bz2, *.7z, *.rar

# 3D / CAD
*.fbx, *.obj, *.blend, *.stl

# Documents (large)
*.pdf (>5MB), *.docx, *.pptx, *.xlsx

# Compiled / binary
*.dll, *.so, *.dylib, *.exe
```

### Custom Config

Create `lfs-config.yaml` in your repo root to customize:

```yaml
# lfs-config.yaml
track:
  - "*.psd"
  - "*.mp4"
  - "assets/**/*.png"
  
ignore:
  - "*.min.js"
  - "node_modules/**"

hook:
  max_size: 5M    # Block files larger than this
  enabled: true

quota:
  warn_at: 80     # Warn at 80% of limit
  limit: 5G       # Your LFS quota
```

## Advanced Usage

### Fetch Only Recent LFS Files

```bash
# Fetch LFS objects only for recent commits (saves bandwidth)
bash scripts/manage.sh fetch-recent --days 30
```

### Lock Files (Prevent Conflicts)

```bash
# Lock a binary file you're editing
bash scripts/manage.sh lock assets/design/logo.psd

# Unlock when done
bash scripts/manage.sh unlock assets/design/logo.psd

# List all locks
bash scripts/manage.sh locks
```

### Export LFS Inventory

```bash
# CSV export of all LFS objects (for auditing)
bash scripts/manage.sh export-csv > lfs-inventory.csv
```

## Troubleshooting

### Issue: "git lfs: command not found"

**Fix:** Run `bash scripts/install.sh` — it installs git-lfs for your OS.

### Issue: "Encountered N file(s) that should have been pointers"

**Fix:** Files were committed without LFS. Migrate them:
```bash
bash scripts/manage.sh fix-pointers
```

### Issue: "LFS: Repository or object not found"

**Fix:** Check remote LFS URL:
```bash
git lfs env
# Ensure the LFS endpoint matches your hosting provider
```

### Issue: Slow clones due to LFS

**Fix:** Use partial clone:
```bash
GIT_LFS_SKIP_SMUDGE=1 git clone <repo-url>
git lfs pull  # Fetch LFS files after
```

## Dependencies

- `git` (2.0+)
- `git-lfs` (auto-installed by install.sh)
- `bash` (4.0+)
- `awk`, `sort`, `du` (standard Unix tools)
